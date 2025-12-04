import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/neu_widgets.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';
import '../main.dart'; // For themeNotifier
import 'transcript_viewer_screen.dart';

/// Modern Home Screen - Connected to Backend
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
    // Auto-refresh every 3 seconds
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
      Navigator.of(context).pop(); // Close dialog
      _loadProjects(); // Refresh list

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
              // Header
              _buildHeader(),

              const SizedBox(height: 32),

              // Main Card
              Expanded(
                child: NeuCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Progress Ring
                      ProgressRing(
                        progress: progress,
                        centerText: '$completedCount/$totalCount',
                      ),

                      const SizedBox(height: 32),

                      // Action Buttons
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

                      // Projects Header
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

                      // Projects List
                      Expanded(child: _buildProjectsList()),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Bottom Navigation
              _buildBottomNav(),
            ],
          ),
        ),
      ),
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
