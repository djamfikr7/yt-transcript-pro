import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/neu_widgets.dart';
import '../services/api_client.dart';
import 'transcript_viewer_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ApiClient _apiClient = ApiClient();
  List<dynamic> _projects = [];
  List<dynamic> _filteredProjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    try {
      final projects = await _apiClient.getProjects();
      setState(() {
        _projects = projects;
        _filteredProjects = projects;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _filterProjects(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProjects = _projects;
      } else {
        _filteredProjects = _projects.where((p) {
          final title = (p['title'] ?? '').toString().toLowerCase();
          final url = (p['url'] ?? '').toString().toLowerCase();
          return title.contains(query.toLowerCase()) ||
              url.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppTheme.getCardColor(context),
        title: const Text('Search Projects'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterProjects,
              decoration: InputDecoration(
                hintText: 'Search by title or URL...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterProjects('');
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProjects.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: AppTheme.iconGray,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No projects found',
                          style: TextStyle(color: AppTheme.textGray),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredProjects.length,
                    itemBuilder: (context, index) {
                      final project = _filteredProjects[index];
                      final title = project['title'] ?? 'Untitled';
                      final status = project['status'] ?? 'unknown';
                      final isCompleted = status == 'completed';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: NeuCard(
                          padding: const EdgeInsets.all(16),
                          child: ListTile(
                            leading: Icon(
                              isCompleted ? Icons.check_circle : Icons.pending,
                              color: isCompleted
                                  ? AppTheme.green
                                  : AppTheme.orange,
                            ),
                            title: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textGray,
                              ),
                            ),
                            trailing: isCompleted
                                ? const Icon(Icons.arrow_forward_ios, size: 16)
                                : null,
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
}
