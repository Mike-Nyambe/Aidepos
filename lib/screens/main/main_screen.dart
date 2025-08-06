import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();

    // Set status bar style for main screen
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
  }

  void _handleQuit() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quit Application'),
        content: const Text('Are you sure you want to quit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Handle quit logic here
              SystemNavigator.pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF6B35),
            ),
            child: const Text('Quit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Header with back arrow and greeting
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFFFF6B35),
                          size: 24,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Hello John Doe',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF6B35),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Balance the back button
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Main feature cards
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Start Counting Card
                          _buildFeatureCard(
                            iconPath: 'assets/icons/barcode-scanner.png',
                            title: 'Start Counting',
                            description:
                                'Lorem ipsum dolor dolor contour ipsum lorem consectetur dolor contour ipsum dolor.',
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Start Counting tapped'),
                                  backgroundColor: Color(0xFFFF6B35),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 20),

                          // Master Data Card
                          _buildFeatureCard(
                            iconPath: 'assets/icons/folder.png',
                            title: 'Master Data',
                            description:
                                'Lorem ipsum dolor dolor contour ipsum lorem consectetur dolor contour ipsum dolor.',
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Master Data tapped'),
                                  backgroundColor: Color(0xFFFF6B35),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 20),

                          // Settings Card
                          _buildFeatureCard(
                            iconPath: 'assets/icons/setting.png',
                            title: 'Settings',
                            description:
                                'Lorem ipsum dolor dolor contour ipsum lorem consectetur dolor contour ipsum dolor.',
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Settings tapped'),
                                  backgroundColor: Color(0xFFFF6B35),
                                ),
                              );
                            },
                          ),

                          const SizedBox(
                            height: 100,
                          ), // Extra space for quit button
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Quit button - positioned absolute
          Positioned(
            bottom: 30,
            right: 20,
            child: TextButton.icon(
              onPressed: _handleQuit,
              icon: const Icon(
                Icons.logout,
                color: Color(0xFFFF6B35),
                size: 20,
              ),
              label: const Text(
                'Quit',
                style: TextStyle(
                  color: Color(0xFFFF6B35),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required String iconPath,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF6B35), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Custom icon at the top
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Image.asset(
                      iconPath,
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                      color: const Color(0xFFFF6B35),
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to default icons if custom icons don't exist
                        IconData fallbackIcon;
                        if (iconPath.contains('scanner')) {
                          fallbackIcon = Icons.qr_code_scanner;
                        } else if (iconPath.contains('files')) {
                          fallbackIcon = Icons.folder_copy_outlined;
                        } else {
                          fallbackIcon = Icons.settings;
                        }
                        return Icon(
                          fallbackIcon,
                          color: const Color(0xFFFF6B35),
                          size: 32,
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),

                const SizedBox(height: 8),

                // Description
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
