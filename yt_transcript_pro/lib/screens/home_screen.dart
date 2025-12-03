import 'package:flutter/material.dart';
import '../widgets/neu_widgets.dart';
import '../theme/app_theme.dart';

/// Main Home Screen with 3-pane layout
/// Left: Project Library | Center: Video Player & Timeline | Right: Transcript Editor
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _processVideo() {
    if (_urlController.text.isEmpty) return;

    setState(() => _isProcessing = true);

    // TODO: Call backend API
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [AppTheme.backgroundDark, AppTheme.surfaceDark]
                : [AppTheme.backgroundLight, const Color(0xFFC3CFE2)],
          ),
        ),
        child: Column(
          children: [
            // Header Bar
            _buildHeaderBar(),

            // Main Content - 3 Pane Layout
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Sidebar - Project Library
                    SizedBox(width: 300, child: _buildProjectLibrary()),

                    const SizedBox(width: 16),

                    // Center Panel - Video Player & Timeline
                    Expanded(child: _buildCenterPanel()),

                    const SizedBox(width: 16),

                    // Right Sidebar - Transcript Editor
                    SizedBox(width: 350, child: _buildTranscriptPanel()),
                  ],
                ),
              ),
            ),

            // Status Bar
            _buildStatusBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBar() {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      borderRadius: 0,
      child: Row(
        children: [
          // Logo/Title
          const Icon(Icons.video_library, size: 32, color: AppTheme.primary),
          const SizedBox(width: 12),
          Text(
            'YT Transcript Pro',
            style: Theme.of(
              context,
            ).textTheme.displayLarge?.copyWith(fontSize: 24),
          ),

          const SizedBox(width: 40),

          // URL Input
          Expanded(
            child: NeuTextField(
              hint: 'Paste YouTube URL...',
              controller: _urlController,
              prefixIcon: Icons.link,
            ),
          ),

          const SizedBox(width: 16),

          // Language Selector
          NeuButton(
            text: 'English',
            icon: Icons.language,
            onPressed: () {
              // TODO: Show language picker
            },
          ),

          const SizedBox(width: 16),

          // Process Button
          NeuButton(
            text: 'Process',
            icon: Icons.play_arrow,
            color: AppTheme.primary,
            isLoading: _isProcessing,
            onPressed: _isProcessing ? null : _processVideo,
          ),
        ],
      ),
    );
  }

  Widget _buildProjectLibrary() {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'Projects',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Bar
          const NeuTextField(
            hint: 'Search projects...',
            prefixIcon: Icons.search,
          ),

          const SizedBox(height: 16),

          // Project List (Empty State)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_library_outlined,
                    size: 64,
                    color: Colors.grey.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No projects yet',
                    style: TextStyle(
                      color: Colors.grey.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Paste a YouTube URL to start',
                    style: TextStyle(
                      color: Colors.grey.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterPanel() {
    return GlassPanel(
      child: Column(
        children: [
          // Video Player Placeholder
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_circle_outline,
                      size: 80,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Video Player',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Timeline Placeholder
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'Timeline & Waveform',
                style: TextStyle(
                  color: Colors.grey.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptPanel() {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.article, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'Transcript',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.translate, size: 20),
                onPressed: () {
                  // TODO: Toggle translation view
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Transcript Content (Empty State)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 64,
                    color: Colors.grey.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No transcript yet',
                    style: TextStyle(
                      color: Colors.grey.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      borderRadius: 0,
      child: Row(
        children: [
          // Status Indicator
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: AppTheme.success,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.success.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _isProcessing ? 'Processing...' : 'Ready',
            style: const TextStyle(fontSize: 13),
          ),

          const Spacer(),

          // GPU Memory Monitor Placeholder
          const Icon(Icons.memory, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            'GPU: N/A',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
