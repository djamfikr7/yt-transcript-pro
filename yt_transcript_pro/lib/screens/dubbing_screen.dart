import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/neu_widgets.dart';

class DubbingScreen extends StatefulWidget {
  final int projectId;
  final String title;

  const DubbingScreen({Key? key, required this.projectId, required this.title})
    : super(key: key);

  @override
  State<DubbingScreen> createState() => _DubbingScreenState();
}

class _DubbingScreenState extends State<DubbingScreen> {
  final ApiClient _apiClient = ApiClient();

  String _selectedLang = 'en';
  String _selectedGender = 'female';
  bool _isGenerating = false;
  String? _downloadUrl;
  Map<String, dynamic>? _voices;

  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    try {
      final voices = await _apiClient.getTtsVoices();
      setState(() => _voices = voices);
    } catch (e) {
      // Fallback to default voices
      setState(
        () => _voices = {
          'en': {'male': 'en-US-GuyNeural', 'female': 'en-US-JennyNeural'},
          'es': {'male': 'es-ES-AlvaroNeural', 'female': 'es-ES-ElviraNeural'},
          'fr': {'male': 'fr-FR-HenriNeural', 'female': 'fr-FR-DeniseNeural'},
        },
      );
    }
  }

  Future<void> _generateDub() async {
    setState(() {
      _isGenerating = true;
      _downloadUrl = null;
    });

    try {
      final result = await _apiClient.generateDub(
        widget.projectId,
        lang: _selectedLang,
        gender: _selectedGender,
      );
      setState(() {
        _downloadUrl = result['download_url'];
        _isGenerating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dub generated successfully!'),
          backgroundColor: AppTheme.green,
        ),
      );
    } catch (e) {
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generation failed: $e'),
          backgroundColor: AppTheme.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppTheme.getCardColor(context),
        title: Text('Dub: ${widget.title}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            NeuCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.record_voice_over,
                    size: 48,
                    color: AppTheme.green,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'AI Voice Dubbing',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Generate natural-sounding audio from your transcript',
                    style: TextStyle(color: AppTheme.textGray),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Language Selection
            NeuCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Language',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildLangChip('en', 'English 🇬🇧'),
                      _buildLangChip('es', 'Spanish 🇪🇸'),
                      _buildLangChip('fr', 'French 🇫🇷'),
                      _buildLangChip('de', 'German 🇩🇪'),
                      _buildLangChip('ar', 'Arabic 🇸🇦'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Gender Selection
            NeuCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Voice',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGenderButton(
                          'female',
                          'Female',
                          Icons.face_3,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGenderButton('male', 'Male', Icons.face),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Generate Button
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateDub,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _isGenerating
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.play_arrow, size: 28),
                label: Text(
                  _isGenerating ? 'Generating...' : 'Generate Dub',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Download Section
            if (_downloadUrl != null) ...[
              const SizedBox(height: 24),
              NeuCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.check_circle, size: 48, color: AppTheme.green),
                    const SizedBox(height: 16),
                    const Text(
                      'Dub Ready!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        // In a real app, you'd open the download URL
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Download URL: $_downloadUrl'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Download Audio'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLangChip(String code, String label) {
    final isSelected = _selectedLang == code;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.green.withOpacity(0.3),
      onSelected: (_) => setState(() => _selectedLang = code),
    );
  }

  Widget _buildGenderButton(String gender, String label, IconData icon) {
    final isSelected = _selectedGender == gender;
    return InkWell(
      onTap: () => setState(() => _selectedGender = gender),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.green.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.green : AppTheme.iconGray,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppTheme.green : AppTheme.iconGray,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.green : AppTheme.textGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
