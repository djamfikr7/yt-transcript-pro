import 'package:flutter/material.dart';
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
  List<dynamic> _segments = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _language = '';

  @override
  void initState() {
    super.initState();
    _loadTranscript();
  }

  Future<void> _loadTranscript() async {
    try {
      final transcript = await _apiClient.getTranscript(widget.projectId);
      if (mounted) {
        setState(() {
          _segments = transcript['segments'] ?? [];
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
                'Language: ${_language.toUpperCase()}',
                style: TextStyle(fontSize: 12, color: AppTheme.textGray),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              // TODO: Export functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export feature coming soon!')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppTheme.red),
              const SizedBox(height: 16),
              Text(
                'Error loading transcript',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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

    if (_segments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: AppTheme.iconGray,
            ),
            const SizedBox(height: 16),
            Text(
              'No transcript available',
              style: TextStyle(fontSize: 16, color: AppTheme.textGray),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _segments.length,
      itemBuilder: (context, index) {
        final segment = _segments[index];
        final start = (segment['start'] ?? 0.0).toDouble();
        final end = (segment['end'] ?? 0.0).toDouble();
        final text = segment['text'] ?? '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: NeuCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timestamp
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
                  ],
                ),
                const SizedBox(height: 12),
                // Transcript Text
                Text(
                  text.trim(),
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
