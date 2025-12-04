import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/neu_widgets.dart';
import '../main.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppTheme.getCardColor(context),
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Appearance Section
            _buildSectionHeader(context, 'Appearance'),
            NeuCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeNotifier,
                    builder: (context, mode, _) {
                      return SwitchListTile(
                        title: const Text('Dark Mode'),
                        subtitle: const Text('Toggle dark/light theme'),
                        value: mode == ThemeMode.dark,
                        activeColor: AppTheme.green,
                        onChanged: (value) {
                          themeNotifier.value = value
                              ? ThemeMode.dark
                              : ThemeMode.light;
                        },
                        secondary: Icon(
                          mode == ThemeMode.dark
                              ? Icons.dark_mode
                              : Icons.light_mode,
                          color: AppTheme.green,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // API Configuration Section
            _buildSectionHeader(context, 'Backend'),
            NeuCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.cloud, color: AppTheme.green),
                    title: const Text('API Server'),
                    subtitle: const Text('http://localhost:8000'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Connected',
                        style: TextStyle(color: AppTheme.green, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Features Section
            _buildSectionHeader(context, 'Features'),
            NeuCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildFeatureTile(
                    'Transcription',
                    'Whisper AI',
                    Icons.mic,
                    true,
                  ),
                  const Divider(),
                  _buildFeatureTile(
                    'Translation',
                    'Argos Translate',
                    Icons.translate,
                    true,
                  ),
                  const Divider(),
                  _buildFeatureTile(
                    'AI Content',
                    'Gemini API',
                    Icons.auto_awesome,
                    true,
                  ),
                  const Divider(),
                  _buildFeatureTile(
                    'Text-to-Speech',
                    'Edge TTS',
                    Icons.record_voice_over,
                    true,
                  ),
                  const Divider(),
                  _buildFeatureTile(
                    'Speaker Diarization',
                    'Pyannote',
                    Icons.people,
                    false,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // About Section
            _buildSectionHeader(context, 'About'),
            NeuCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.info_outline, color: AppTheme.green),
                    title: const Text('YT Transcript Pro'),
                    subtitle: const Text('Version 1.0.0'),
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.code, color: AppTheme.green),
                    title: const Text('GitHub'),
                    subtitle: const Text(
                      'github.com/djamfikr7/yt-transcript-pro',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.textGray,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFeatureTile(
    String name,
    String engine,
    IconData icon,
    bool enabled,
  ) {
    return ListTile(
      leading: Icon(icon, color: enabled ? AppTheme.green : AppTheme.iconGray),
      title: Text(name),
      subtitle: Text(
        engine,
        style: TextStyle(fontSize: 12, color: AppTheme.textGray),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: enabled
              ? AppTheme.green.withOpacity(0.2)
              : AppTheme.iconGray.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          enabled ? 'Active' : 'Needs Setup',
          style: TextStyle(
            color: enabled ? AppTheme.green : AppTheme.iconGray,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
