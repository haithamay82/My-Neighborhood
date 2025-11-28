import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for handling voice message recording and upload
class VoiceMessageService {
  static const int maxDurationSeconds = 30;
  static const int maxFileSizeBytes = 300 * 1024; // 300KB
  static const int maxBase64SizeBytes = 500 * 1024; // 500KB - fallback to Base64 if file.io fails
  static const String fileIoApiUrl = 'https://file.io';

  final AudioRecorder _recorder = AudioRecorder();
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  String? _currentRecordingPath;

  /// Start recording voice message
  Future<bool> startRecording({
    required Function(int seconds) onDurationUpdate,
    required Function() onMaxDurationReached,
  }) async {
    try {
      // Check microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint('❌ Microphone permission denied');
        return false;
      }

      // Check if recorder is available
      if (!await _recorder.hasPermission()) {
        debugPrint('❌ Recorder permission denied');
        return false;
      }

      // Get temporary directory for recording
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${directory.path}/voice_$timestamp.m4a';

      // Start recording
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      _recordingDuration = 0;
      debugPrint('🎤 Started recording: $_currentRecordingPath');

      // Start timer to track duration
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _recordingDuration++;
        onDurationUpdate(_recordingDuration);

        // Stop at max duration
        if (_recordingDuration >= maxDurationSeconds) {
          timer.cancel();
          stopRecording().then((_) => onMaxDurationReached());
        }
      });

      return true;
    } catch (e) {
      debugPrint('❌ Error starting recording: $e');
      return false;
    }
  }

  /// Stop recording and return file path
  Future<String?> stopRecording() async {
    try {
      _recordingTimer?.cancel();
      _recordingTimer = null;

      final path = await _recorder.stop();
      if (path == null || path.isEmpty) {
        debugPrint('❌ No recording path returned');
        return null;
      }

      _currentRecordingPath = path;
      debugPrint('🛑 Stopped recording: $path');
      debugPrint('📊 Recording duration: $_recordingDuration seconds');

      return path;
    } catch (e) {
      debugPrint('❌ Error stopping recording: $e');
      return null;
    }
  }

  /// Cancel current recording
  Future<void> cancelRecording() async {
    try {
      _recordingTimer?.cancel();
      _recordingTimer = null;

      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
          debugPrint('🗑️ Deleted cancelled recording: $_currentRecordingPath');
        }
      }

      await _recorder.stop();
      _currentRecordingPath = null;
      _recordingDuration = 0;
    } catch (e) {
      debugPrint('❌ Error cancelling recording: $e');
    }
  }

  /// Get current recording duration
  int get currentDuration => _recordingDuration;

  /// Check if currently recording
  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  /// Process voice message: convert to Base64 or upload to file.io
  Future<Map<String, dynamic>> processVoiceMessage(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Voice file not found');
      }

      final fileSize = await file.length();
      final fileBytes = await file.readAsBytes();
      final duration = _recordingDuration;

      // Validate file size and duration
      if (fileSize > maxFileSizeBytes * 2) {
        throw Exception('Voice file too large (max ${maxFileSizeBytes * 2} bytes)');
      }

      if (duration > maxDurationSeconds) {
        throw Exception('Voice message too long (max $maxDurationSeconds seconds)');
      }

      String? data;
      String? url;

      // If file is small enough, use Base64
      if (fileSize <= maxFileSizeBytes) {
        final base64String = base64Encode(fileBytes);
        data = base64String;
        debugPrint('✅ Voice message encoded as Base64 (${fileSize} bytes)');
      } else if (fileSize <= maxBase64SizeBytes) {
        // Try file.io first, fallback to Base64 if it fails
        try {
          url = await _uploadToFileIo(fileBytes);
          debugPrint('✅ Voice message uploaded to file.io: $url');
        } catch (e) {
          debugPrint('⚠️ File.io upload failed, using Base64 fallback: $e');
          // Fallback to Base64 for files up to 500KB
          final base64String = base64Encode(fileBytes);
          data = base64String;
          debugPrint('✅ Voice message encoded as Base64 (fallback, ${fileSize} bytes)');
        }
      } else {
        // File too large, must use file.io
        url = await _uploadToFileIo(fileBytes);
        debugPrint('✅ Voice message uploaded to file.io: $url');
      }

      // Clean up local file
      try {
        await file.delete();
        debugPrint('🗑️ Deleted local voice file: $filePath');
      } catch (e) {
        debugPrint('⚠️ Could not delete local file: $e');
      }

      return {
        'data': data,
        'url': url,
        'duration': duration,
        'fileSize': fileSize,
      };
    } catch (e) {
      debugPrint('❌ Error processing voice message: $e');
      rethrow;
    }
  }

  /// Upload file to file.io API
  Future<String> _uploadToFileIo(List<int> fileBytes) async {
    final client = http.Client();
    try {
      // Use the correct file.io API endpoint (without www)
      final uri = Uri.parse('https://file.io');
      
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
        ),
      );

      // Send request and handle redirects
      var response = await client.send(request).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('File.io upload timeout');
        },
      );
      
      // Handle redirects (301, 302, etc.) - but only if redirect is to a valid API endpoint
      int redirectCount = 0;
      while (response.statusCode >= 300 && response.statusCode < 400 && redirectCount < 5) {
        // Close the previous response stream before creating a new request
        await response.stream.drain();
        
        final location = response.headers['location'];
        if (location == null || location.isEmpty) {
          throw Exception('File.io redirect without location header');
        }
        
        // Check if redirect is to www.file.io (which doesn't support POST) - skip it
        if (location.contains('www.file.io')) {
          debugPrint('⚠️ Redirect to www.file.io detected (not API endpoint), skipping');
          throw Exception('File.io redirect to invalid endpoint: $location');
        }
        
        debugPrint('🔄 Following redirect to: $location');
        
        // Create new request to the redirect location
        final redirectUri = Uri.parse(location);
        final redirectRequest = http.MultipartRequest('POST', redirectUri);
        redirectRequest.files.add(
          http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
          ),
        );
        
        response = await client.send(redirectRequest).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('File.io redirect timeout');
          },
        );
        redirectCount++;
      }
      
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        throw Exception('File.io upload failed: ${response.statusCode} - $responseBody');
      }

      final jsonResponse = jsonDecode(responseBody) as Map<String, dynamic>;
      final fileUrl = jsonResponse['link'] as String?;

      if (fileUrl == null || fileUrl.isEmpty) {
        throw Exception('No link returned from file.io: $responseBody');
      }

      return fileUrl;
    } catch (e) {
      debugPrint('❌ Error uploading to file.io: $e');
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Dispose resources
  void dispose() {
    _recordingTimer?.cancel();
    _recorder.dispose();
  }
}

