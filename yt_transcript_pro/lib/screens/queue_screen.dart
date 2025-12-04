import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/neu_widgets.dart';
import 'transcript_viewer_screen.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({Key? key}) : super(key: key);

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  final ApiClient _apiClient = ApiClient();
  final TextEditingController _urlController = TextEditingController();

  List<dynamic> _projects = [];
  List<String> _pendingUrls = [];
  bool _isLoading = true;
  bool _isProcessingQueue = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _loadProjects(),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    try {
      final projects = await _apiClient.getProjects();
      if (mounted) {
        setState(() {
          _projects = projects;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addToQueue(String url) {
    if (url.isNotEmpty && !_pendingUrls.contains(url)) {
      setState(() {
        _pendingUrls.add(url);
        _urlController.clear();
      });
    }
  }

  void _removeFromQueue(int index) {
    setState(() => _pendingUrls.removeAt(index));
  }

  Future<void> _processQueue() async {
    if (_pendingUrls.isEmpty) return;

    setState(() => _isProcessingQueue = true);

    for (int i = 0; i < _pendingUrls.length; i++) {
      final url = _pendingUrls[i];
      try {
        await _apiClient.createProject(url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Started: ${i + 1}/${_pendingUrls.length}'),
              backgroundColor: AppTheme.green,
            ),
          );
        }
        // Small delay between requests
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed: $url'),
              backgroundColor: AppTheme.red,
            ),
          );
        }
      }
    }

    setState(() {
      _pendingUrls.clear();
      _isProcessingQueue = false;
    });

    _loadProjects();
  }

  List<dynamic> get _processingProjects => _projects
      .where((p) => p['status'] == 'downloading' || p['status'] == 'processing')
      .toList();

  List<dynamic> get _completedProjects =>
      _projects.where((p) => p['status'] == 'completed').toList();

  List<dynamic> get _failedProjects =>
      _projects.where((p) => p['status'] == 'failed').toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppTheme.getCardColor(context),
        title: const Text('Batch Queue'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadProjects),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Add URLs section
            NeuCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.playlist_add, color: AppTheme.green),
                      const SizedBox(width: 8),
                      const Text(
                        'Add to Queue',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          decoration: InputDecoration(
                            hintText: 'Paste YouTube URL...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: _addToQueue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _addToQueue(_urlController.text),
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tip: Add multiple URLs, then click "Process All"',
                    style: TextStyle(fontSize: 12, color: AppTheme.textGray),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Pending Queue
            if (_pendingUrls.isNotEmpty) ...[
              NeuCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.queue, color: AppTheme.orange),
                        const SizedBox(width: 8),
                        Text(
                          'Pending (${_pendingUrls.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _isProcessingQueue ? null : _processQueue,
                          icon: _isProcessingQueue
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.play_arrow),
                          label: Text(
                            _isProcessingQueue
                                ? 'Processing...'
                                : 'Process All',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._pendingUrls.asMap().entries.map(
                      (e) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${e.key + 1}.',
                              style: TextStyle(
                                color: AppTheme.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e.value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                size: 18,
                                color: AppTheme.red,
                              ),
                              onPressed: () => _removeFromQueue(e.key),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Processing
            if (_processingProjects.isNotEmpty) ...[
              _buildProjectSection(
                'Processing',
                _processingProjects,
                AppTheme.orange,
                Icons.sync,
              ),
              const SizedBox(height: 16),
            ],

            // Completed
            if (_completedProjects.isNotEmpty) ...[
              _buildProjectSection(
                'Completed',
                _completedProjects,
                AppTheme.green,
                Icons.check_circle,
              ),
              const SizedBox(height: 16),
            ],

            // Failed
            if (_failedProjects.isNotEmpty)
              _buildProjectSection(
                'Failed',
                _failedProjects,
                AppTheme.red,
                Icons.error,
              ),

            // Empty state
            if (_projects.isEmpty && _pendingUrls.isEmpty && !_isLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.queue_music,
                        size: 64,
                        color: AppTheme.iconGray,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No projects in queue',
                        style: TextStyle(
                          color: AppTheme.textGray,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add YouTube URLs above to get started',
                        style: TextStyle(
                          color: AppTheme.textGray,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectSection(
    String title,
    List<dynamic> projects,
    Color color,
    IconData icon,
  ) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                '$title (${projects.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...projects
              .take(5)
              .map(
                (p) => InkWell(
                  onTap: p['status'] == 'completed'
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TranscriptViewerScreen(
                              projectId: p['id'],
                              title: p['title'] ?? 'Transcript',
                            ),
                          ),
                        )
                      : null,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        if (p['status'] == 'downloading' ||
                            p['status'] == 'processing')
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: color,
                            ),
                          )
                        else
                          Icon(icon, size: 16, color: color),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            p['title'] ?? 'Processing...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        if (p['status'] == 'completed')
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: AppTheme.iconGray,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          if (projects.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+ ${projects.length - 5} more',
                style: TextStyle(color: AppTheme.textGray, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
