import 'package:flutter/material.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import '../widgets/neu_widgets.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';
import '../main.dart';
import 'transcript_viewer_screen.dart';
import 'search_screen.dart';
import 'favorites_screen.dart';
import 'settings_screen.dart';
import 'queue_screen.dart';

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

  // Filters
  String _statusFilter = 'all';
  String _searchQuery = '';
  bool _showSidebar = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
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

  List<dynamic> get _filteredProjects {
    return _projects.where((p) {
      // Status filter
      if (_statusFilter != 'all' && p['status'] != _statusFilter) return false;
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final title = (p['title'] ?? '').toString().toLowerCase();
        final url = (p['url'] ?? '').toString().toLowerCase();
        if (!title.contains(_searchQuery.toLowerCase()) &&
            !url.contains(_searchQuery.toLowerCase()))
          return false;
      }
      return true;
    }).toList();
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

  Future<void> _pickLocalFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mkv', 'mp3', 'wav', 'webm', 'm4a'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        Navigator.of(context).pop();
        // For now, show a message - backend needs endpoint for local files
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Selected: ${result.files.single.name}\nLocal file upload coming soon!',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.red),
      );
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        title: const Text('Add New Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText: 'https://youtube.com/watch?v=...',
                labelText: 'YouTube URL',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Or upload a local file:',
              style: TextStyle(color: AppTheme.textGray),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickLocalFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Choose File (MP4, MP3, WAV)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_urlController.text.isNotEmpty)
                _createProject(_urlController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green),
            child: const Text('Process URL'),
          ),
        ],
      ),
    );
  }

  void _deleteProject(int projectId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiClient.deleteProject(projectId);
        _loadProjects();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project deleted'),
            backgroundColor: AppTheme.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    }
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
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: AppTheme.getBackground(context),
      body: SafeArea(
        child: Row(
          children: [
            // LEFT SIDEBAR - Project Library (PRD requirement)
            if (_showSidebar && isWide) _buildSidebar(),

            // MAIN CONTENT
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildQuickActions(),
                    const SizedBox(height: 20),
                    Expanded(child: _buildProjectGrid()),
                    const SizedBox(height: 16),
                    _buildBottomNav(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    final statusCounts = {
      'all': _projects.length,
      'completed': _projects.where((p) => p['status'] == 'completed').length,
      'processing': _projects
          .where(
            (p) => p['status'] == 'processing' || p['status'] == 'downloading',
          )
          .length,
      'failed': _projects.where((p) => p['status'] == 'failed').length,
    };

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        border: Border(
          right: BorderSide(color: AppTheme.iconGray.withOpacity(0.2)),
        ),
      ),
      child: Column(
        children: [
          // Sidebar Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.folder_special, color: AppTheme.green, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Project Library',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search projects...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppTheme.getBackground(context),
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),

          // Filter Options
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FILTERS',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textGray,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                _buildFilterTile(
                  'All Projects',
                  'all',
                  Icons.folder,
                  statusCounts['all']!,
                ),
                _buildFilterTile(
                  'Completed',
                  'completed',
                  Icons.check_circle,
                  statusCounts['completed']!,
                ),
                _buildFilterTile(
                  'Processing',
                  'processing',
                  Icons.pending,
                  statusCounts['processing']!,
                ),
                _buildFilterTile(
                  'Failed',
                  'failed',
                  Icons.error,
                  statusCounts['failed']!,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Recent Projects List
          Expanded(
            child: _projects.isEmpty
                ? Center(
                    child: Text(
                      'No projects',
                      style: TextStyle(color: AppTheme.textGray),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _filteredProjects.take(10).length,
                    itemBuilder: (context, index) {
                      final project = _filteredProjects[index];
                      final isCompleted = project['status'] == 'completed';

                      return ListTile(
                        dense: true,
                        leading: Text(
                          _getStatusEmoji(project['status']),
                          style: const TextStyle(fontSize: 16),
                        ),
                        title: Text(
                          project['title'] ?? 'Processing...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing: isCompleted
                            ? Icon(
                                Icons.arrow_forward_ios,
                                size: 12,
                                color: AppTheme.iconGray,
                              )
                            : null,
                        onTap: isCompleted
                            ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TranscriptViewerScreen(
                                    projectId: project['id'],
                                    title: project['title'] ?? 'Transcript',
                                  ),
                                ),
                              )
                            : null,
                      );
                    },
                  ),
          ),

          // Add New Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add),
                label: const Text('New Project'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTile(
    String label,
    String value,
    IconData icon,
    int count,
  ) {
    final isSelected = _statusFilter == value;
    return InkWell(
      onTap: () => setState(() => _statusFilter = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.green.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppTheme.green : AppTheme.iconGray,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(color: isSelected ? AppTheme.green : null),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.green.withOpacity(0.2)
                    : AppTheme.iconGray.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? AppTheme.green : AppTheme.textGray,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (MediaQuery.of(context).size.width > 800)
              IconButton(
                icon: Icon(_showSidebar ? Icons.menu_open : Icons.menu),
                onPressed: () => setState(() => _showSidebar = !_showSidebar),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YT Transcript Pro',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Transcribe • Translate • Dub • Export',
                  style: TextStyle(color: AppTheme.textGray, fontSize: 12),
                ),
              ],
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
              onPressed: () =>
                  themeNotifier.value = themeNotifier.value == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark,
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

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: NeuCard(
            padding: const EdgeInsets.all(16),
            child: InkWell(
              onTap: _showAddDialog,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.add, color: AppTheme.green),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add Project',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'YouTube URL or Local File',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textGray,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: NeuCard(
            padding: const EdgeInsets.all(16),
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QueueScreen()),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.queue, color: Colors.purple),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Batch Queue',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Process multiple URLs',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textGray,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: NeuCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.analytics, color: AppTheme.orange),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_projects.where((p) => p['status'] == 'completed').length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    Text(
                      'Completed',
                      style: TextStyle(fontSize: 12, color: AppTheme.textGray),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectGrid() {
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

    final filtered = _filteredProjects;
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64,
              color: AppTheme.iconGray,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No matching projects'
                  : 'No projects yet',
              style: TextStyle(color: AppTheme.textGray, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Click "Add Project" to get started',
              style: TextStyle(color: AppTheme.textGray, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 3 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.8,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final project = filtered[index];
        return _buildProjectCard(project);
      },
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    final status = project['status'] ?? 'unknown';
    final title = project['title'] ?? 'Processing...';
    final isCompleted = status == 'completed';
    final isProcessing = status == 'downloading' || status == 'processing';

    return NeuCard(
      padding: EdgeInsets.zero,
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusEmoji(status),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: _getStatusColor(status),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: AppTheme.iconGray,
                      size: 20,
                    ),
                    onSelected: (value) {
                      if (value == 'delete') _deleteProject(project['id']);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: Colors.red),
                          title: Text('Delete'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              if (isProcessing)
                LinearProgressIndicator(
                  backgroundColor: _getStatusColor(status).withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation(_getStatusColor(status)),
                ),
              if (isCompleted)
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: AppTheme.green),
                    const SizedBox(width: 4),
                    Text(
                      'Ready to view',
                      style: TextStyle(fontSize: 12, color: AppTheme.green),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: AppTheme.iconGray,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return NeuCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavButton(Icons.home, 'Home', true, null),
          _buildNavButton(
            Icons.search,
            'Search',
            false,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
          _buildNavButton(
            Icons.favorite_border,
            'Completed',
            false,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            ),
          ),
          _buildNavButton(
            Icons.settings,
            'Settings',
            false,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(
    IconData icon,
    String label,
    bool isActive,
    VoidCallback? onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppTheme.green : AppTheme.iconGray,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isActive ? AppTheme.green : AppTheme.iconGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
