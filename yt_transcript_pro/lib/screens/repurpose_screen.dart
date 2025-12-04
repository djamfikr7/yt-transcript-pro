import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/neu_widgets.dart';

class RepurposeScreen extends StatefulWidget {
  final int projectId;
  final String title;

  const RepurposeScreen({
    Key? key,
    required this.projectId,
    required this.title,
  }) : super(key: key);

  @override
  State<RepurposeScreen> createState() => _RepurposeScreenState();
}

class _RepurposeScreenState extends State<RepurposeScreen>
    with SingleTickerProviderStateMixin {
  final ApiClient _apiClient = ApiClient();
  late TabController _tabController;

  String _summary = '';
  List<String> _keyPoints = [];
  String _socialContent = '';
  String _blogPost = '';

  bool _loadingSummary = false;
  bool _loadingKeyPoints = false;
  bool _loadingSocial = false;
  bool _loadingBlog = false;

  String _summaryStyle = 'concise';
  String _socialPlatform = 'twitter';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _generateSummary() async {
    setState(() => _loadingSummary = true);
    try {
      final result = await _apiClient.summarize(
        widget.projectId,
        style: _summaryStyle,
      );
      setState(() => _summary = result['summary'] ?? 'No summary generated');
    } catch (e) {
      _showError('Summary failed: $e');
    }
    setState(() => _loadingSummary = false);
  }

  Future<void> _generateKeyPoints() async {
    setState(() => _loadingKeyPoints = true);
    try {
      final result = await _apiClient.extractKeyPoints(widget.projectId);
      setState(
        () => _keyPoints = List<String>.from(result['key_points'] ?? []),
      );
    } catch (e) {
      _showError('Key points failed: $e');
    }
    setState(() => _loadingKeyPoints = false);
  }

  Future<void> _generateSocialContent() async {
    setState(() => _loadingSocial = true);
    try {
      final result = await _apiClient.generateSocialContent(
        widget.projectId,
        platform: _socialPlatform,
      );
      setState(
        () => _socialContent = result['content'] ?? 'No content generated',
      );
    } catch (e) {
      _showError('Social content failed: $e');
    }
    setState(() => _loadingSocial = false);
  }

  Future<void> _generateBlog() async {
    setState(() => _loadingBlog = true);
    try {
      final result = await _apiClient.generateBlogPost(widget.projectId);
      setState(() => _blogPost = result['blog'] ?? 'No blog generated');
    } catch (e) {
      _showError('Blog failed: $e');
    }
    setState(() => _loadingBlog = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.red));
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard!'),
        backgroundColor: AppTheme.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppTheme.getCardColor(context),
        title: Text('Repurpose: ${widget.title}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.summarize), text: 'Summary'),
            Tab(icon: Icon(Icons.list), text: 'Key Points'),
            Tab(icon: Icon(Icons.share), text: 'Social'),
            Tab(icon: Icon(Icons.article), text: 'Blog'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryTab(),
          _buildKeyPointsTab(),
          _buildSocialTab(),
          _buildBlogTab(),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: _summaryStyle,
                  items: const [
                    DropdownMenuItem(value: 'concise', child: Text('Concise')),
                    DropdownMenuItem(
                      value: 'detailed',
                      child: Text('Detailed'),
                    ),
                    DropdownMenuItem(
                      value: 'bullet_points',
                      child: Text('Bullet Points'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _summaryStyle = v!),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _loadingSummary ? null : _generateSummary,
                icon: _loadingSummary
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: const Text('Generate'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_summary.isNotEmpty) ...[
            NeuCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Summary',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () => _copyToClipboard(_summary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(_summary),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKeyPointsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: _loadingKeyPoints ? null : _generateKeyPoints,
            icon: _loadingKeyPoints
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lightbulb),
            label: const Text('Extract Key Points'),
          ),
          const SizedBox(height: 16),
          ..._keyPoints.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NeuCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.green, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(point)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: _socialPlatform,
                  items: const [
                    DropdownMenuItem(
                      value: 'twitter',
                      child: Text('Twitter/X'),
                    ),
                    DropdownMenuItem(
                      value: 'linkedin',
                      child: Text('LinkedIn'),
                    ),
                    DropdownMenuItem(
                      value: 'youtube_description',
                      child: Text('YouTube'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _socialPlatform = v!),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _loadingSocial ? null : _generateSocialContent,
                icon: _loadingSocial
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share),
                label: const Text('Generate'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_socialContent.isNotEmpty)
            NeuCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _socialPlatform.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () => _copyToClipboard(_socialContent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(_socialContent),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBlogTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: _loadingBlog ? null : _generateBlog,
            icon: _loadingBlog
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.article),
            label: const Text('Generate Blog Post'),
          ),
          const SizedBox(height: 16),
          if (_blogPost.isNotEmpty)
            NeuCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Blog Post',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () => _copyToClipboard(_blogPost),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(_blogPost),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
