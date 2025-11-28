import 'package:flutter/material.dart';
import '../services/audio_service.dart';

class AudioSettingsScreen extends StatefulWidget {
  const AudioSettingsScreen({super.key});

  @override
  State<AudioSettingsScreen> createState() => _AudioSettingsScreenState();
}

class _AudioSettingsScreenState extends State<AudioSettingsScreen> with AudioMixin {
  final AudioService _audioService = AudioService();
  bool _isEnabled = true;
  double _volume = 0.7;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isEnabled = _audioService.isEnabled;
      _volume = _audioService.volume;
    });
  }

  Future<void> _toggleAudio() async {
    setState(() {
      _isEnabled = !_isEnabled;
    });
    await _audioService.setEnabled(_isEnabled);
    if (_isEnabled) {
      await playSuccessSound();
    }
  }

  Future<void> _setVolume(double volume) async {
    setState(() {
      _volume = volume;
    });
    await _audioService.setVolume(volume);
  }

  Future<void> _testSound() async {
    await playButtonSound();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('הגדרות צליל'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? const Color(0xFF9C27B0) // סגול יפה
            : Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // הפעלת/כיבוי צלילים
            Card(
              child: ListTile(
                leading: Icon(
                  _isEnabled ? Icons.volume_up : Icons.volume_off,
                  color: _isEnabled ? Colors.green : Colors.grey,
                ),
                title: const Text('הפעל צלילים'),
                subtitle: Text(_isEnabled ? 'צלילים מופעלים' : 'צלילים כבויים'),
                trailing: Switch(
                  value: _isEnabled,
                  onChanged: (value) => _toggleAudio(),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // עוצמת קול
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.volume_up,
                          color: _isEnabled ? Colors.blue : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'עוצמת קול: ${(_volume * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Slider(
                      value: _volume,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      onChanged: _isEnabled ? _setVolume : null,
                      activeColor: _isEnabled ? Colors.blue : Colors.grey,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'שקט',
                          style: TextStyle(
                            color: _isEnabled ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          'רועש',
                          style: TextStyle(
                            color: _isEnabled ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // בדיקת צלילים
            Card(
              child: ListTile(
                leading: const Icon(Icons.play_arrow, color: Colors.blue),
                title: const Text('בדוק צלילים'),
                subtitle: const Text('לחץ לבדיקת צליל כפתור'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: _isEnabled ? _testSound : null,
                enabled: _isEnabled,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // רשימת צלילים
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'צלילי אירועים:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSoundItem('לחיצת כפתור', AudioEvent.buttonClick),
                    _buildSoundItem('הצלחה', AudioEvent.success),
                    _buildSoundItem('שגיאה', AudioEvent.error),
                    _buildSoundItem('התראה חדשה', AudioEvent.newMessage),
                    _buildSoundItem('בקשה חדשה', AudioEvent.newRequest),
                    _buildSoundItem('התחברות', AudioEvent.loginSuccess),
                    _buildSoundItem('תשלום', AudioEvent.paymentSuccess),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundItem(String name, AudioEvent event) {
    return ListTile(
      title: Text(name),
      trailing: IconButton(
        icon: const Icon(Icons.play_arrow),
        onPressed: _isEnabled ? () => _audioService.playSound(event) : null,
      ),
    );
  }
}
