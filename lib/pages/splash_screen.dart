import 'package:flutter/material.dart';
import 'package:moviedex/services/update_service.dart';
import 'dart:ui' as ui;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:moviedex/services/settings_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _isNavigating = false;
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  String _version = '';
  @override
  void initState() {
    PackageInfo.fromPlatform().then((info) {
      setState(() => _version = info.version);
    });
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    super.initState();
    _controller.forward();
    _initializeAndCheck();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeAndCheck() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    try {
      await SettingsService.instance.init();
      final showUpdateDialog = SettingsService.instance.showUpdateDialog;
      final update = await UpdateService.instance.checkForUpdate();
      final latestRelease = await UpdateService.instance.getLatestRelease();

      if (!mounted) return;

      if (update && showUpdateDialog && latestRelease != null) {
        await _showUpdateDialog(latestRelease);
      } else {
        _navigateToHome();
      }
    } catch (e) {
      debugPrint('Error checking updates: $e');
      _navigateToHome();
    }
  }

  Future<void> _showUpdateDialog(Map<String, dynamic> update) async {
    if (!mounted) return;

    final currentVersion = _version;
    final newVersion =
        update['tag_name']?.toString().replaceAll("v", "").split("-")[0] ?? '';
    final hasChangelog = update['body']?.toString().isNotEmpty ?? false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('A new version of MovieDex is available!'),
              const SizedBox(height: 8),
              Text(
                'Current version: $currentVersion\nNew version: $newVersion',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (hasChangelog) ...[
                const SizedBox(height: 16),
                const Text('What\'s new:'),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Markdown(
                      data: update['body']?.toString() ?? '',
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(fontSize: 14, color: Colors.white),
                        strong: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        h1: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        h2: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        a: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                        listBullet: const TextStyle(color: Colors.white),
                      ),
                      onTapLink: (text, href, title) {
                        if (href != null) {
                          launchUrl(Uri.parse(href),
                              mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToHome();
            },
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => _handleUpdate(update, context),
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpdate(
      Map<String, dynamic> update, BuildContext context) async {
    try {
      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Downloading update...'),
            ],
          ),
        ),
      );

      final downloadUrl = update['assets'].first['browser_download_url'];
      final tagName = update['tag_name']?.toString() ?? '';

      // Check if this is an update that might cause package conflicts
      bool isConflictPossible = false;
      try {
        PackageInfo packageInfo = await PackageInfo.fromPlatform();
        final String currentVersion = packageInfo.version;
        final String currentBuildNumber = packageInfo.buildNumber;

        // Major version change might indicate package structure changes
        List<int> currentVersionParts =
            currentVersion.split('.').map(int.parse).toList();
        String newVersionCleaned = tagName.replaceAll('v', '').split('-')[0];
        List<int> newVersionParts =
            newVersionCleaned.split('.').map(int.parse).toList();

        // Check if major or minor version changed
        if (newVersionParts[0] > currentVersionParts[0] ||
            (newVersionParts[0] == currentVersionParts[0] &&
                newVersionParts[1] > currentVersionParts[1])) {
          isConflictPossible = true;
        }
      } catch (e) {
        // If we can't determine, assume conflict is possible
        isConflictPossible = true;
      }

      if (isConflictPossible && Platform.isAndroid) {
        // On Android, suggest uninstall and reinstall for major updates
        if (!mounted) return;
        Navigator.pop(context); // Close progress dialog

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Update Method'),
            content: const Text(
                'This update might conflict with your existing app. Would you like to:'),
            actions: [
              TextButton(
                onPressed: () async {
                  // Try direct update anyway
                  Navigator.pop(context);
                  await _proceedWithDirectUpdate(downloadUrl, tagName);
                },
                child: const Text('Try Direct Update'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(context);
                  // Open browser for manual download
                  final Uri url = Uri.parse(downloadUrl);
                  await launchUrl(url, mode: LaunchMode.externalApplication);

                  if (!mounted) return;
                  Navigator.pop(context); // Close update dialog

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Please uninstall the current app before installing the new version'),
                      duration: Duration(seconds: 8),
                    ),
                  );
                  _navigateToHome();
                },
                child: const Text('Manual Download'),
              ),
            ],
          ),
        );
      } else {
        // Direct update for iOS or non-major Android updates
        await _proceedWithDirectUpdate(downloadUrl, tagName);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close progress dialog
      Navigator.pop(context); // Close update dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Update failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      _navigateToHome();
    }
  }

  Future<void> _proceedWithDirectUpdate(
      String downloadUrl, String tagName) async {
    await UpdateService.instance.downloadAndInstallUpdate(
      downloadUrl,
      tagName,
    );

    if (!mounted) return;
    Navigator.pop(context); // Close progress dialog
    Navigator.pop(context); // Close update dialog

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Update downloaded. Installing...')),
    );
  }

  void _navigateToHome() {
    if (!mounted || _isNavigating) return;
    _isNavigating = true;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background design elements
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                ),
              ),
            ),
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.2),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                                BoxShadow(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.1),
                                  blurRadius: 60,
                                  spreadRadius: 20,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: BackdropFilter(
                                filter:
                                    ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surface
                                        .withOpacity(0.1),
                                  ),
                                  child: Image.asset(
                                    'assets/images/icon-bg.png',
                                    width: 200,
                                    height: 200,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            'MovieDex',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your Ultimate Movie Companion',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.7),
                                  letterSpacing: 0.5,
                                ),
                          ),
                          const SizedBox(height: 40),
                          Container(
                            width: 40,
                            height: 40,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.2),
                                width: 2,
                              ),
                            ),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Version $_version',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
