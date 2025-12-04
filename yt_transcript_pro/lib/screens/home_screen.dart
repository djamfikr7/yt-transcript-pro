import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/neu_widgets.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';
import '../main.dart';
import 'transcript_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final ApiClient _apiClient = ApiClient();

  List<dynamic> _projects = [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadProjects();
    });
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
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load projects';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createProject(String url) async {
    try {
      await _apiClient.createProject(url);
      _urlController.clear();
      Navigator.of(context).pop();
      _loadProjects();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project created! Processing...'),
            backgroundColor: AppTheme.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    }
  }

  void _showUrlDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        title: const Text('Enter YouTube URL'),
        content: TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            hintText: 'https://youtube.com/watch?v=...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_urlController.text.isNotEmpty) {
                _createProject(_urlController.text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green),
            child: const Text('Process'),
          ),
        ],
      ),
    );
  }

  String _getStatusEmoji(String status) {
    switch (status) {
      case 'created':
        return '⏳';
      case 'downloading':
        return '⬇️';
      case 'processing':
        return '⚙️';
      case 'completed':
        return '✅';
      case 'failed':
        return '❌';
      default:
        return '📄';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.green;
      case 'failed':
        return AppTheme.red;
      case 'downloading':
      case 'processing':
        return AppTheme.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _projects
        .where((p) => p['status'] == 'completed')
        .length;
    final totalCount = _projects.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.getBackground(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              Expanded(
                child: NeuCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      ProgressRing(
                        progress: progress,
                        centerText: '$completedCount/$totalCount',
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          NeuIconButton(
                            icon: Icons.link,
                            label: 'URL',
                            iconColor: AppTheme.green,
                            onTap: _showUrlDialog,
                          ),
                          NeuIconButton(
                            icon: Icons.refresh,
                            label: 'Refresh',
                            onTap: _loadProjects,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Projects',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          if (_isLoading)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: AppTheme.iconGray,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(child: _buildProjectsList()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildBottomNav(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YT Transcript Pro',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Transcribe • Translate • Export',
              style: TextStyle(color: AppTheme.textGray, fontSize: 12),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(
                themeNotifier.value == ThemeMode.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
                color: AppTheme.iconGray,
              ),
              onPressed: () {
                themeNotifier.value = themeNotifier.value == ThemeMode.dark
                    ? ThemeMode.light
                    : ThemeMode.dark;
              },
            ),
            const CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.green,
              child: Icon(Icons.person, color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProjectsList() {
    if (_isLoading && _projects.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 48, color: AppTheme.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: TextStyle(color: AppTheme.textGray)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProjects,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 48,
              color: AppTheme.iconGray,
            ),
            const SizedBox(height: 16),
            Text('No projects yet', style: TextStyle(color: AppTheme.textGray)),
            const SizedBox(height: 8),
            Text(
              'Tap URL to add a YouTube video',
              style: TextStyle(color: AppTheme.textGray, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _projects.length,
      itemBuilder: (context, index) {
        final project = _projects[index];
        final status = project['status'] ?? 'unknown';
        final title = project['title'] ?? 'Processing...';
        final isCompleted = status == 'completed';
        final isProcessing = status == 'downloading' || status == 'processing';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: isCompleted
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TranscriptViewerScreen(
                        projectId: project['id'],
                        title: title,
                      ),
                    ),
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context).withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getStatusColor(status).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _getStatusEmoji(status),
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCompleted)
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: AppTheme.iconGray,
                        ),
                    ],
                  ),
                  if (isProcessing) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      backgroundColor: _getStatusColor(status).withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation(
                        _getStatusColor(status),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return NeuCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavIcon(Icons.home, true),
          _buildNavIcon(Icons.search, false),
          _buildNavIcon(Icons.favorite_border, false),
          _buildNavIcon(Icons.settings, false),
        ],
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, bool isActive) {
    return Icon(
      icon,
      color: isActive ? AppTheme.green : AppTheme.iconGray,
      size: 28,
    );
  }
}
