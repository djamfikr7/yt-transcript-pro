import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/neu_widgets.dart';
import '../services/api_client.dart';
import 'transcript_viewer_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final ApiClient _apiClient = ApiClient();
  List<dynamic> _completedProjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompletedProjects();
  }

  Future<void> _loadCompletedProjects() async {
    try {
      final projects = await _apiClient.getProjects();
      setState(() {
        _completedProjects = projects
            .where((p) => p['status'] == 'completed')
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppTheme.getCardColor(context),
        title: const Text('Completed Transcripts'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCompletedProjects,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _completedProjects.isEmpty
          ? Center(
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
                    'No completed transcripts yet',
                    style: TextStyle(color: AppTheme.textGray),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Process a video to see it here',
                    style: TextStyle(color: AppTheme.textGray, fontSize: 12),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _completedProjects.length,
              itemBuilder: (context, index) {
                final project = _completedProjects[index];
                final title = project['title'] ?? 'Untitled';
                final url = project['url'] ?? '';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: NeuCard(
                    padding: EdgeInsets.zero,
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TranscriptViewerScreen(
                            projectId: project['id'],
                            title: title,
                          ),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppTheme.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.play_circle_filled,
                                color: AppTheme.green,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    url,
                                    style: TextStyle(
                                      color: AppTheme.textGray,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: AppTheme.iconGray,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
