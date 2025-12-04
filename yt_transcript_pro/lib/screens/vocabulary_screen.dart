import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/neu_widgets.dart';

class VocabularyScreen extends StatefulWidget {
  final int projectId;
  final String title;

  const VocabularyScreen({
    Key? key,
    required this.projectId,
    required this.title,
  }) : super(key: key);

  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen> {
  final ApiClient _apiClient = ApiClient();

  List<Map<String, dynamic>> _vocabulary = [];
  List<Map<String, dynamic>> _selectedWords = [];
  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _extractVocabulary();
  }

  Future<void> _extractVocabulary() async {
    setState(() => _isLoading = true);

    try {
      // Get transcript and extract vocabulary locally
      final transcript = await _apiClient.getTranscript(widget.projectId);
      final segments = transcript['segments'] as List<dynamic>? ?? [];

      // Extract all words and count frequency
      final Map<String, int> wordFrequency = {};
      final RegExp wordRegex = RegExp(
        r'\b[a-zA-Z]{4,}\b',
      ); // Only words 4+ chars

      for (var segment in segments) {
        final text = (segment['text'] ?? '').toString().toLowerCase();
        final matches = wordRegex.allMatches(text);
        for (var match in matches) {
          final word = match.group(0)!;
          wordFrequency[word] = (wordFrequency[word] ?? 0) + 1;
        }
      }

      // Filter out common words and sort by frequency
      final commonWords = {
        'that',
        'this',
        'with',
        'have',
        'will',
        'from',
        'they',
        'been',
        'were',
        'said',
        'each',
        'which',
        'their',
        'time',
        'very',
        'when',
        'come',
        'could',
        'made',
        'like',
        'just',
        'over',
        'such',
        'than',
        'into',
        'some',
        'then',
        'them',
        'these',
        'only',
        'would',
        'about',
        'there',
        'other',
        'more',
        'what',
        'your',
        'also',
        'here',
        'know',
      };

      final filteredWords =
          wordFrequency.entries
              .where((e) => e.value >= 2 && !commonWords.contains(e.key))
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _vocabulary = filteredWords
            .take(50)
            .map(
              (e) => {
                'word': e.key,
                'frequency': e.value,
                'context': _findContext(segments, e.key),
              },
            )
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _findContext(List<dynamic> segments, String word) {
    for (var segment in segments) {
      final text = (segment['text'] ?? '').toString();
      if (text.toLowerCase().contains(word.toLowerCase())) {
        // Return a snippet around the word
        return text.length > 100 ? '${text.substring(0, 100)}...' : text;
      }
    }
    return '';
  }

  void _toggleWordSelection(Map<String, dynamic> word) {
    setState(() {
      if (_selectedWords.contains(word)) {
        _selectedWords.remove(word);
      } else {
        _selectedWords.add(word);
      }
    });
  }

  Future<void> _exportToAnki() async {
    setState(() => _isExporting = true);

    final words = _selectedWords.isNotEmpty ? _selectedWords : _vocabulary;

    // Generate Anki-compatible TSV format
    final StringBuffer ankiContent = StringBuffer();
    ankiContent.writeln('#separator:tab');
    ankiContent.writeln('#html:true');
    ankiContent.writeln('#columns:Front\tBack\tTags');

    for (var word in words) {
      final front = word['word'];
      final back =
          'Frequency: ${word['frequency']}<br><br><i>${word['context']}</i>';
      ankiContent.writeln('$front\t$back\tyt-transcript-pro');
    }

    await Clipboard.setData(ClipboardData(text: ankiContent.toString()));

    setState(() => _isExporting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${words.length} words copied! Paste into Anki import.',
          ),
          backgroundColor: AppTheme.green,
          action: SnackBarAction(
            label: 'How?',
            onPressed: () => _showAnkiInstructions(),
            textColor: Colors.white,
          ),
        ),
      );
    }
  }

  void _showAnkiInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import to Anki'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Open Anki and click "Import"'),
            SizedBox(height: 8),
            Text('2. Create a new text file and paste the copied content'),
            SizedBox(height: 8),
            Text('3. Save as .txt file and import into Anki'),
            SizedBox(height: 8),
            Text('4. Make sure field separator is set to "Tab"'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppTheme.getCardColor(context),
        title: Text('Vocabulary: ${widget.title}'),
        actions: [
          if (_vocabulary.isNotEmpty)
            TextButton.icon(
              onPressed: _isExporting ? null : _exportToAnki,
              icon: _isExporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(
                'Export ${_selectedWords.isEmpty ? 'All' : '${_selectedWords.length}'} to Anki',
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: TextStyle(color: AppTheme.textGray)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _extractVocabulary,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_vocabulary.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, size: 64, color: AppTheme.iconGray),
            const SizedBox(height: 16),
            Text(
              'No vocabulary found',
              style: TextStyle(color: AppTheme.textGray),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Stats bar
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.getCardColor(context),
          child: Row(
            children: [
              Icon(Icons.auto_stories, color: AppTheme.green),
              const SizedBox(width: 8),
              Text('${_vocabulary.length} unique words found'),
              const Spacer(),
              if (_selectedWords.isNotEmpty)
                Chip(
                  label: Text('${_selectedWords.length} selected'),
                  deleteIcon: const Icon(Icons.clear, size: 16),
                  onDeleted: () => setState(() => _selectedWords.clear()),
                ),
            ],
          ),
        ),

        // Word list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _vocabulary.length,
            itemBuilder: (context, index) {
              final word = _vocabulary[index];
              final isSelected = _selectedWords.contains(word);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: NeuCard(
                  padding: EdgeInsets.zero,
                  child: InkWell(
                    onTap: () => _toggleWordSelection(word),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: isSelected
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.green,
                                width: 2,
                              ),
                            )
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: AppTheme.green,
                                  size: 20,
                                )
                              else
                                Icon(
                                  Icons.circle_outlined,
                                  color: AppTheme.iconGray,
                                  size: 20,
                                ),
                              const SizedBox(width: 12),
                              Text(
                                word['word'],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${word['frequency']}x',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (word['context'].isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              word['context'],
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textGray,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
