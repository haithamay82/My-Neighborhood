import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../l10n/app_localizations.dart';

/// Widget for playing voice messages
class VoiceMessageWidget extends StatefulWidget {
  final String? data; // Base64 string or URL
  final int? duration; // Duration in seconds
  final bool isMe; // Whether this is the current user's message

  const VoiceMessageWidget({
    super.key,
    this.data,
    this.duration,
    required this.isMe,
  });

  @override
  State<VoiceMessageWidget> createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<VoiceMessageWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _duration = Duration(seconds: widget.duration ?? 0);
    
    // Listen to player state
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });

    // Listen to position
    _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    // Listen to duration
    _audioPlayer.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _duration = duration;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadAudio() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      String audioPath;

      if (widget.data != null) {
        // Check if it's a URL or Base64
        if (widget.data!.startsWith('http')) {
          // Download from URL (file.io)
          final response = await http.get(Uri.parse(widget.data!));
          if (response.statusCode == 200) {
            final directory = await getTemporaryDirectory();
            final file = File('${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
            await file.writeAsBytes(response.bodyBytes);
            audioPath = file.path;
          } else {
            throw Exception('Failed to download audio: ${response.statusCode}');
          }
        } else {
          // Decode Base64 and save to temp file
          final bytes = base64Decode(widget.data!);
          final directory = await getTemporaryDirectory();
          final file = File('${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
          await file.writeAsBytes(bytes);
          audioPath = file.path;
        }
      } else {
        throw Exception('No audio data provided');
      }

      await _audioPlayer.setFilePath(audioPath);
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ Error loading audio: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).errorLoadingVoiceMessage(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _togglePlayback() async {
    try {
      if (_audioPlayer.duration == null) {
        await _loadAudio();
      }

      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }
    } catch (e) {
      debugPrint('❌ Error toggling playback: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: widget.isMe
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // כפתור PLAY/PAUSE בולט יותר
          GestureDetector(
            onTap: _isLoading ? null : _togglePlayback,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[700],
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _duration.inMilliseconds > 0
                        ? _position.inMilliseconds / _duration.inMilliseconds
                        : 0,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.isMe
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[600]!,
                    ),
                    minHeight: 2,
                  ),
                ),
                const SizedBox(height: 2),
                // Duration
                Text(
                  _formatDuration(_position),
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isMe
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Duration badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: widget.isMe
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[400],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${widget.duration ?? 0}s',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

