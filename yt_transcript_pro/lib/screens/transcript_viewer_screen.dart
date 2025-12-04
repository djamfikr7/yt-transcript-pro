import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/neu_widgets.dart';

class TranscriptViewerScreen extends StatefulWidget {
  final int projectId;
  final String title;

  const TranscriptViewerScreen({
    Key? key,
    required this.projectId,
    required this.title,
  }) : super(key: key);

  @override
  State<TranscriptViewerScreen> createState() => _TranscriptViewerScreenState();
}

class _TranscriptViewerScreenState extends State<TranscriptViewerScreen> {
  final ApiClient _apiClient = ApiClient();
  List<dynamic> _segments = [];
  List<dynamic> _translatedSegments = [];
  bool _isLoading = true;
  bool _isTranslating = false;
  bool _showTranslation = false;
  String? _errorMessage;
  String _language = '';
  String _targetLanguage = 'es';

  @override
  void initState() {
    super.initState();
    _loadTranscript();
  }

  Future<void> _loadTranscript() async {
    try {
      final transcript = await _apiClient.getTranscript(widget.projectId);
      if (mounted) {
        setState(() {
          _segments = transcript['segments'] ?? [];
          _language = transcript['language'] ?? 'unknown';
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _translateTranscript() async {
    if (_translatedSegments.isNotEmpty) {
      setState(() => _showTranslation = !_showTranslation);
      return;
    }

    setState(() => _isTranslating = true);

    try {
      final result = await _apiClient.translateProject(
        widget.projectId,
        _targetLanguage,
      );
      if (mounted) {
        setState(() {
          _translatedSegments = result['segments'] ?? [];
          _showTranslation = true;
          _isTranslating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Translation failed: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
        setState(() => _isTranslating = false);
      }
    }
  }

  Future<void> _exportFile(String format) async {
    Navigator.pop(context);
    try {
      final content = await _apiClient.getExportContent(
        widget.projectId,
        format,
      );
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.getCardColor(context),
            title: Text('Exported ${format.toUpperCase()}'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(child: SelectableText(content)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard!')),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Copy'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    }
  }

  String _formatTime(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppTheme.getCardColor(context),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 16)),
            if (_language.isNotEmpty)
              Text(
                'Language: ${_language.toUpperCase()}${_showTranslation ? " → ${_targetLanguage.toUpperCase()}" : ""}',
                style: TextStyle(fontSize: 12, color: AppTheme.textGray),
              ),
          ],
        ),
        actions: [
          // Translate Button
          IconButton(
            icon: _isTranslating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.translate,
                    color: _showTranslation ? AppTheme.green : null,
                  ),
            onPressed: _isTranslating ? null : _translateTranscript,
            tooltip: 'Translate to Spanish',
          ),
          // Export Button
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppTheme.getCardColor(context),
                  title: const Text('Export Transcript'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.description),
                        title: const Text('Text File (.txt)'),
                        onTap: () => _exportFile('txt'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.closed_caption),
                        title: const Text('Subtitles (.srt)'),
                        onTap: () => _exportFile('srt'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppTheme.red),
              const SizedBox(height: 16),
              const Text(
                'Error loading transcript',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textGray),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadTranscript,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_segments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: AppTheme.iconGray,
            ),
            const SizedBox(height: 16),
            Text(
              'No transcript available',
              style: TextStyle(fontSize: 16, color: AppTheme.textGray),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _segments.length,
      itemBuilder: (context, index) {
        final segment = _segments[index];
        final start = (segment['start'] ?? 0.0).toDouble();
        final end = (segment['end'] ?? 0.0).toDouble();
        final text = segment['text'] ?? '';
        final speaker = segment['speaker'];

        String? translatedText;
        if (_showTranslation && index < _translatedSegments.length) {
          translatedText = _translatedSegments[index]['text'];
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: NeuCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: AppTheme.green),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatTime(start)} - ${_formatTime(end)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (speaker != null) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          speaker,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.orange,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  text.trim(),
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
                if (translatedText != null) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    translatedText.trim(),
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: AppTheme.green,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
