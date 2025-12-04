import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _segments = [];
  List<dynamic> _filteredSegments = [];
  List<dynamic> _translatedSegments = [];
  bool _isLoading = true;
  bool _isTranslating = false;
  bool _showTranslation = false;
  String? _errorMessage;
  String _language = '';
  String _targetLanguage = 'es';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTranscript();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTranscript() async {
    try {
      final transcript = await _apiClient.getTranscript(widget.projectId);
      if (mounted) {
        setState(() {
          _segments = transcript['segments'] ?? [];
          _filteredSegments = _segments;
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

  void _filterSegments(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredSegments = _segments;
      } else {
        _filteredSegments = _segments.where((seg) {
          final text = (seg['text'] ?? '').toString().toLowerCase();
          return text.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _copyFullTranscript() async {
    final text = _segments.map((s) => s['text'] ?? '').join(' ');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transcript copied to clipboard!'),
          backgroundColor: AppTheme.green,
        ),
      );
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
              height: 300,
              child: SingleChildScrollView(child: SelectableText(content)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: content));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard!')),
                    );
                    Navigator.pop(context);
                  }
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
          // Copy Button
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyFullTranscript,
            tooltip: 'Copy all text',
          ),
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
                      ListTile(
                        leading: const Icon(Icons.web),
                        title: const Text('WebVTT (.vtt)'),
                        onTap: () => _exportFile('vtt'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: _filterSegments,
                decoration: InputDecoration(
                  hintText: 'Search transcript...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filterSegments('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppTheme.getCardColor(context),
                ),
              ),
            ),
            // Results count
            if (_searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${_filteredSegments.length} results found',
                  style: TextStyle(color: AppTheme.textGray, fontSize: 12),
                ),
              ),
            // Body
            Expanded(child: _buildBody()),
          ],
        ),
      ),
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

    if (_filteredSegments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty
                  ? Icons.search_off
                  : Icons.description_outlined,
              size: 64,
              color: AppTheme.iconGray,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results for "$_searchQuery"'
                  : 'No transcript available',
              style: TextStyle(fontSize: 16, color: AppTheme.textGray),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredSegments.length,
      itemBuilder: (context, index) {
        final segment = _filteredSegments[index];
        final originalIndex = _segments.indexOf(segment);
        final start = (segment['start'] ?? 0.0).toDouble();
        final end = (segment['end'] ?? 0.0).toDouble();
        final text = segment['text'] ?? '';
        final speaker = segment['speaker'];

        String? translatedText;
        if (_showTranslation &&
            originalIndex >= 0 &&
            originalIndex < _translatedSegments.length) {
          translatedText = _translatedSegments[originalIndex]['text'];
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
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
                    const Spacer(),
                    // Copy segment button
                    IconButton(
                      icon: Icon(
                        Icons.copy,
                        size: 16,
                        color: AppTheme.iconGray,
                      ),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: text));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Segment copied!')),
                          );
                        }
                      },
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
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
