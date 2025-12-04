import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/neu_widgets.dart';
import 'repurpose_screen.dart';
import 'dubbing_screen.dart';
import 'vocabulary_screen.dart';

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
  final ScrollController _scrollController = ScrollController();

  VideoPlayerController? _videoController;
  YoutubePlayerController? _ytController;
  List<dynamic> _segments = [];
  List<dynamic> _filteredSegments = [];
  List<dynamic> _translatedSegments = [];
  Map<String, dynamic>? _projectDetails;
  String? _videoId;

  bool _isLoading = true;
  bool _isTranslating = false;
  bool _showTranslation = false;
  bool _showVideoPlayer = true;
  String? _errorMessage;
  String _language = '';
  String _targetLanguage = 'es';
  String _searchQuery = '';
  int _currentSegmentIndex = 0;

  // Speaker colors for diarization
  final Map<String, Color> _speakerColors = {};
  final List<Color> _availableColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
  ];

  @override
  void initState() {
    super.initState();
    _loadProjectDetails();
    _loadTranscript();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _videoController?.dispose();
    _ytController?.close();
    super.dispose();
  }

  Future<void> _loadProjectDetails() async {
    try {
      final details = await _apiClient.getProject(widget.projectId);
      if (mounted) {
        setState(() => _projectDetails = details);
        // Initialize video player if we have video URL
        if (details['url'] != null) {
          _initVideoPlayer(details['url']);
        }
      }
    } catch (e) {
      debugPrint('Failed to load project details: $e');
    }
  }

  void _initVideoPlayer(String youtubeUrl) {
    // Extract video ID from YouTube URL
    final videoId = _extractVideoId(youtubeUrl);
    if (videoId != null) {
      setState(() => _videoId = videoId);
      _ytController = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showControls: true,
          mute: false,
          showFullscreenButton: true,
          loop: false,
        ),
      );
    }
  }

  String? _extractVideoId(String url) {
    // Handle various YouTube URL formats
    final patterns = [
      RegExp(r'(?:youtube\.com\/watch\?v=)([^&]+)'),
      RegExp(r'(?:youtu\.be\/)([^?]+)'),
      RegExp(r'(?:youtube\.com\/embed\/)([^?]+)'),
      RegExp(r'(?:youtube\.com\/v\/)([^?]+)'),
    ];
    for (var pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) return match.group(1);
    }
    return null;
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
          _assignSpeakerColors();
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

  void _assignSpeakerColors() {
    int colorIndex = 0;
    for (var segment in _segments) {
      final speaker = segment['speaker'];
      if (speaker != null && !_speakerColors.containsKey(speaker)) {
        _speakerColors[speaker] =
            _availableColors[colorIndex % _availableColors.length];
        colorIndex++;
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
          content: Text('Transcript copied!'),
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
            title: Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.green),
                const SizedBox(width: 8),
                Text('Exported ${format.toUpperCase()}'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 350,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.getBackground(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          content,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: content));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Copied!')));
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy All'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppTheme.red,
        ),
      );
    }
  }

  void _scrollToSegment(int index) {
    setState(() => _currentSegmentIndex = index);
    _scrollController.animateTo(
      index * 120.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  String _formatTime(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AppTheme.getBackground(context),
      appBar: _buildAppBar(),
      body: SafeArea(child: isWide ? _buildWideLayout() : _buildNarrowLayout()),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.getCardColor(context),
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (_language.isNotEmpty)
            Text(
              'Language: ${_language.toUpperCase()}${_showTranslation ? " → ${_targetLanguage.toUpperCase()}" : ""}',
              style: TextStyle(fontSize: 11, color: AppTheme.textGray),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.copy),
          onPressed: _copyFullTranscript,
          tooltip: 'Copy all',
        ),
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
          tooltip: 'Translate',
        ),
        IconButton(
          icon: const Icon(Icons.download),
          onPressed: () => _showExportDialog(),
          tooltip: 'Export',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.auto_awesome),
          tooltip: 'AI Tools',
          onSelected: (value) {
            if (value == 'repurpose') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RepurposeScreen(
                    projectId: widget.projectId,
                    title: widget.title,
                  ),
                ),
              );
            } else if (value == 'dubbing') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DubbingScreen(
                    projectId: widget.projectId,
                    title: widget.title,
                  ),
                ),
              );
            } else if (value == 'vocabulary') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VocabularyScreen(
                    projectId: widget.projectId,
                    title: widget.title,
                  ),
                ),
              );
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'repurpose',
              child: ListTile(
                leading: Icon(Icons.summarize),
                title: Text('AI Repurpose'),
              ),
            ),
            const PopupMenuItem(
              value: 'dubbing',
              child: ListTile(
                leading: Icon(Icons.record_voice_over),
                title: Text('AI Dubbing'),
              ),
            ),
            const PopupMenuItem(
              value: 'vocabulary',
              child: ListTile(
                leading: Icon(Icons.book),
                title: Text('Vocabulary Builder'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showExportDialog() {
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
              title: const Text('Plain Text (.txt)'),
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
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        // LEFT: Video + Timeline (PRD: 3-pane layout)
        if (_showVideoPlayer)
          SizedBox(
            width: 400,
            child: Column(
              children: [
                _buildVideoSection(),
                const SizedBox(height: 8),
                _buildTimeline(),
              ],
            ),
          ),

        // CENTER: Transcript
        Expanded(flex: 2, child: _buildTranscriptPane()),

        // RIGHT: Translation (if enabled)
        if (_showTranslation) Expanded(flex: 1, child: _buildTranslationPane()),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        if (_showVideoPlayer) _buildVideoSection(),
        Expanded(child: _buildTranscriptPane()),
      ],
    );
  }

  Widget _buildVideoSection() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            children: [
              // YouTube Player or fallback
              if (_ytController != null && _videoId != null)
                YoutubePlayer(controller: _ytController!)
              else
                Container(
                  color: Colors.black87,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_circle_outline,
                          size: 64,
                          color: Colors.white54,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Video Preview',
                          style: TextStyle(color: Colors.white54),
                        ),
                        const SizedBox(height: 16),
                        if (_projectDetails?['url'] != null)
                          ElevatedButton.icon(
                            onPressed: () async {
                              final url = Uri.parse(_projectDetails!['url']);
                              if (await canLaunchUrl(url)) {
                                await launchUrl(
                                  url,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Open on YouTube'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              // Close button
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => setState(() => _showVideoPlayer = false),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    if (_segments.isEmpty) return const SizedBox.shrink();

    final totalDuration = _segments.isNotEmpty
        ? (_segments.last['end'] ?? 0.0).toDouble()
        : 0.0;

    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: NeuCard(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            // Timeline bar
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // Background
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.iconGray.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      // Segment markers
                      ..._segments.asMap().entries.map((entry) {
                        final index = entry.key;
                        final segment = entry.value;
                        final start = (segment['start'] ?? 0.0).toDouble();
                        final left = totalDuration > 0
                            ? (start / totalDuration) * constraints.maxWidth
                            : 0.0;
                        final speaker = segment['speaker'];
                        final color = speaker != null
                            ? _speakerColors[speaker] ?? AppTheme.green
                            : AppTheme.green;

                        return Positioned(
                          left: left,
                          top: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () => _scrollToSegment(index),
                            child: Container(
                              width: 3,
                              decoration: BoxDecoration(
                                color: index == _currentSegmentIndex
                                    ? color
                                    : color.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            // Time labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '0:00',
                  style: TextStyle(fontSize: 10, color: AppTheme.textGray),
                ),
                Text(
                  _formatTime(totalDuration),
                  style: TextStyle(fontSize: 10, color: AppTheme.textGray),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscriptPane() {
    return Container(
      margin: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
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
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
              ),
            ),
          ),

          // Speaker legend (if diarization available)
          if (_speakerColors.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 12,
                children: _speakerColors.entries
                    .map(
                      (e) => Chip(
                        avatar: CircleAvatar(
                          backgroundColor: e.value,
                          radius: 8,
                        ),
                        label: Text(
                          e.key,
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor: e.value.withOpacity(0.15),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
            ),

          // Results count
          if (_searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${_filteredSegments.length} results',
                style: TextStyle(color: AppTheme.textGray, fontSize: 12),
              ),
            ),

          // Transcript list
          Expanded(child: _buildSegmentList()),
        ],
      ),
    );
  }

  Widget _buildTranslationPane() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.green.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.green.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.translate, color: AppTheme.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Translation (${_targetLanguage.toUpperCase()})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.green,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _showTranslation = false),
                  color: AppTheme.green,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _translatedSegments.length,
              itemBuilder: (context, index) {
                final segment = _translatedSegments[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    segment['text'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppTheme.green.withOpacity(0.9),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textGray),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTranscript,
              child: const Text('Retry'),
            ),
          ],
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
              size: 48,
              color: AppTheme.iconGray,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results for "$_searchQuery"'
                  : 'No transcript',
              style: TextStyle(color: AppTheme.textGray),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _filteredSegments.length,
      itemBuilder: (context, index) {
        final segment = _filteredSegments[index];
        final originalIndex = _segments.indexOf(segment);
        return _buildSegmentCard(
          segment,
          originalIndex,
          index == _currentSegmentIndex,
        );
      },
    );
  }

  Widget _buildSegmentCard(
    Map<String, dynamic> segment,
    int originalIndex,
    bool isActive,
  ) {
    final start = (segment['start'] ?? 0.0).toDouble();
    final end = (segment['end'] ?? 0.0).toDouble();
    final text = segment['text'] ?? '';
    final speaker = segment['speaker'];
    final speakerColor = speaker != null ? _speakerColors[speaker] : null;

    String? translatedText;
    if (_showTranslation &&
        originalIndex >= 0 &&
        originalIndex < _translatedSegments.length) {
      translatedText = _translatedSegments[originalIndex]['text'];
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NeuCard(
        padding: const EdgeInsets.all(12),
        child: InkWell(
          onTap: () => setState(() => _currentSegmentIndex = originalIndex),
          child: Container(
            decoration: isActive
                ? BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: speakerColor ?? AppTheme.green,
                        width: 3,
                      ),
                    ),
                  )
                : null,
            padding: isActive ? const EdgeInsets.only(left: 8) : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (speakerColor ?? AppTheme.green).withOpacity(
                          0.15,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: speakerColor ?? AppTheme.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_formatTime(start)} - ${_formatTime(end)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: speakerColor ?? AppTheme.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (speaker != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              speakerColor?.withOpacity(0.2) ??
                              AppTheme.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          speaker,
                          style: TextStyle(
                            fontSize: 11,
                            color: speakerColor ?? AppTheme.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.copy,
                        size: 16,
                        color: AppTheme.iconGray,
                      ),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied!')),
                        );
                      },
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      tooltip: 'Copy segment',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Original text
                Text(
                  text.trim(),
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
                // Translated text
                if (translatedText != null) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Text(
                    translatedText.trim(),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: AppTheme.green,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
