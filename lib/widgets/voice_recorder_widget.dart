import 'package:flutter/material.dart';
import '../services/voice_message_service.dart';
import '../l10n/app_localizations.dart';
import 'dart:async';

/// Widget for recording voice messages
class VoiceRecorderWidget extends StatefulWidget {
  final Function(String? filePath) onRecordingComplete;
  final Function() onCancel;

  const VoiceRecorderWidget({
    super.key,
    required this.onRecordingComplete,
    required this.onCancel,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  final VoiceMessageService _voiceService = VoiceMessageService();
  int _recordingDuration = 0;
  Timer? _durationTimer;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _voiceService.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final started = await _voiceService.startRecording(
      onDurationUpdate: (seconds) {
        if (mounted) {
          setState(() {
            _recordingDuration = seconds;
          });
        }
      },
      onMaxDurationReached: () {
        _stopRecording();
      },
    );

    if (started && mounted) {
      setState(() {
        _recordingDuration = 0;
      });

      // Start duration timer
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration = timer.tick;
          });
        }
      });
    }
  }

  Future<void> _stopRecording() async {
    _durationTimer?.cancel();
    final filePath = await _voiceService.stopRecording();
    
    if (mounted) {
      setState(() {
        _recordingDuration = 0;
      });

      if (filePath != null) {
        widget.onRecordingComplete(filePath);
      }
    }
  }

  Future<void> _cancelRecording() async {
    _durationTimer?.cancel();
    await _voiceService.cancelRecording();
    
    if (mounted) {
      setState(() {
        _recordingDuration = 0;
      });

      widget.onCancel();
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[200]!, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Recording indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).recording,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Duration display
          Text(
            _formatDuration(_recordingDuration),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '/ ${_formatDuration(30)}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          // Progress indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _recordingDuration / 30,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 16),
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Cancel button
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.grey),
                onPressed: _cancelRecording,
                iconSize: 40,
              ),
              // Stop/Send button
              ElevatedButton(
                onPressed: _stopRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(20),
                ),
                child: const Icon(Icons.stop, size: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

