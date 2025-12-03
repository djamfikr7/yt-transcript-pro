import 'package:flutter/material.dart';
import '../widgets/neu_widgets.dart';
import '../theme/app_theme.dart';

/// Modern Home Screen - Clean Neumorphic Design
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                      const ProgressRing(progress: 0.75, centerText: 'Ready'),

                      const SizedBox(height: 32),

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          NeuIconButton(
                            icon: Icons.upload_file,
                            label: 'Upload',
                            iconColor: AppTheme.green,
                            onTap: () {
                              // TODO: Upload file
                            },
                          ),
                          NeuIconButton(
                            icon: Icons.link,
                            label: 'URL',
                            onTap: () {
                              _showUrlDialog();
                            },
                          ),
                          NeuIconButton(
                            icon: Icons.add,
                            label: 'Shortcut',
                            onTap: () {
                              // TODO: Shortcut
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Transactions Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Projects',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: AppTheme.iconGray,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Transaction List (Empty State for now)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.video_library_outlined,
                                size: 64,
                                color: AppTheme.iconGray.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No projects yet',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Bottom Navigation
              _buildBottomNav(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Profile Avatar
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.green.withOpacity(0.2),
          ),
          child: const Icon(Icons.person, color: AppTheme.green),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, User',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 2),
              Text(
                'YouTube Transcript Pro',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        // Notification Badge
        Stack(
          children: [
            NeuButton(
              size: 48,
              onTap: () {
                // TODO: Show notifications
              },
              child: const Icon(Icons.notifications_outlined, size: 22),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        // Theme Toggle
        NeuButton(
          size: 48,
          onTap: () {
            // TODO: Toggle theme
          },
          child: Icon(
            Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode
                : Icons.dark_mode,
            size: 22,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return NeuCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      borderRadius: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home, 'Home', true),
          _buildNavItem(Icons.analytics_outlined, 'Analytics', false),
          _buildNavItem(Icons.wallet_outlined, 'Payments', false),
          _buildNavItem(Icons.more_horiz, 'More', false),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: isActive ? AppTheme.green : AppTheme.iconGray,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isActive ? AppTheme.green : AppTheme.iconGray,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  void _showUrlDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: NeuCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter YouTube URL',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 20),
              NeuTextField(
                hint: 'https://youtube.com/watch?v=...',
                controller: _urlController,
                prefixIcon: Icons.link,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      // TODO: Process URL
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Process'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
