import 'package:appwrite/models.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:hive/hive.dart';
import 'package:moviedex/api/api.dart';
import 'package:moviedex/api/models/list_item_model.dart';
import 'package:moviedex/models/download_state_model.dart';
import 'package:moviedex/pages/info_page.dart';
import 'package:moviedex/pages/settings_page.dart';
import 'package:moviedex/pages/auth/login_page.dart'; // Add this import
import 'package:moviedex/pages/auth/signup_page.dart'; // Add this import
import 'package:moviedex/models/downloads_manager.dart';
import 'package:moviedex/services/m3u8_downloader_service.dart';
import 'package:moviedex/services/watch_history_service.dart';
import 'package:moviedex/utils/error_handlers.dart';
import 'package:moviedex/services/list_service.dart';
import 'package:moviedex/pages/my_list_page.dart';
import 'package:moviedex/pages/watch_history_page.dart';
import 'package:moviedex/services/settings_service.dart';
import 'dart:async';
import 'package:moviedex/components/downloads_list.dart';
import 'package:moviedex/services/appwrite_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with AutomaticKeepAliveClientMixin {
  // Add StreamController for list updates
  final _listUpdateController = StreamController<void>.broadcast();
  final _watchHistoryController = StreamController<void>.broadcast();

  late Box _settingsBox;
  bool _isIncognito = false;

  @override
  bool get wantKeepAlive => true; // Keep page state alive

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _checkPendingDownloads();
  }

  Future<void> _initializeServices() async {
    await SettingsService.instance.init();
    await WatchHistoryService.instance.init().then((_) {
      WatchHistoryService.instance.syncWithAppwrite();
    });
    await ListService.instance.init().then((_) {
      ListService.instance.syncWithAppwrite();
    });
    await _initSettings();

    // Listen to incognito mode changes
    SettingsService.instance.incognitoStream.listen((value) {
      if (mounted) {
        setState(() => _isIncognito = value);
        // Refresh lists when incognito mode changes
        _listUpdateController.add(null);
        _watchHistoryController.add(null);
      }
    });
  }

  Future<void> _initSettings() async {
    _settingsBox = await Hive.openBox('settings');
    setState(() {
      _isIncognito = _settingsBox.get('incognitoMode', defaultValue: false);
    });
  }

  @override
  void dispose() {
    _listUpdateController.close();
    _watchHistoryController.close();
    super.dispose();
  }

  Future<void> _exitIncognitoMode() async {
    final settingsService = SettingsService.instance;
    await settingsService.setIncognitoMode(false);

    // Update local state
    setState(() => _isIncognito = false);

    // Refresh lists
    await _handleRefresh();
  }

  Future<void> _handleRefresh() async {
    // Sync data when manually refreshing
    await WatchHistoryService.instance.syncWithAppwrite();
    _listUpdateController.add(null);
    _watchHistoryController.add(null);
  }

  Future<void> _handleWatchHistoryItemTap(ListItem item) async {
    try {
      final data = await Api().getDetails(id: item.contentId, type: item.type);

      if (mounted) {
        // Open custom box for item
        final storage = await Hive.openBox(data.title);

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Infopage(
                id: item.contentId,
                type: item.type,
                name: item.title,
              ),
            ),
          );
        }

        // Close box after navigation
        await storage.close();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _checkPendingDownloads() async {
    final pendingDownloads = DownloadsManager.instance.getPendingDownloads();

    for (var state in pendingDownloads) {
      if (state.status == 'error' || state.status == 'paused') {
        _showResumeDialog(state);
      }
    }
  }

  void _showResumeDialog(DownloadState state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            state.status == 'error' ? 'Download Failed' : 'Download Paused'),
        content: Text('Would you like to resume the download?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              DownloadsManager.instance.clearDownloadState(state.contentId);
            },
            child: const Text('Cancel Download'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resumeDownload(state);
            },
            child: const Text('Resume'),
          ),
        ],
      ),
    );
  }

  void _resumeDownload(DownloadState state) async {
    try {
      await M3U8DownloaderService().resumeDownload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resume error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return FutureBuilder<User?>(
      future: _getCurrentUser(),
      builder: (context, snapshot) {
        final User? currentUser = snapshot.data;

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: const Text("Profile"),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: ((context) => const SettingsPage())));
                },
                tooltip: 'Settings',
                color: Colors.white,
              ),
              const SizedBox(width: 8), // Add some padding
            ],
          ),
          body: Stack(
            children: [
              RefreshIndicator(
                onRefresh: _handleRefresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildProfileHeader(currentUser),
                    ),
                    // My List section with StreamBuilder
                    SliverToBoxAdapter(
                      child: StreamBuilder<void>(
                        stream: _listUpdateController.stream,
                        builder: (context, _) => _buildMyList(),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          children: [
                            // Watch History with StreamBuilder
                            StreamBuilder<void>(
                              stream: _watchHistoryController.stream,
                              builder: (context, _) => _buildWatchHistory(),
                            ),
                            const SizedBox(height: 16),
                            _buildSection(
                              "Downloading",
                              Icons.download_done_rounded,
                              () {},
                              items: [], // Empty list to show empty state
                              children: const [
                                DownloadsList()
                              ], // Add DownloadsList as a child
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isIncognito) _buildIncognitoBanner(),
            ],
          ),
        );
      },
    );
  }

  Future<User?> _getCurrentUser() async {
    try {
      if (await AppwriteService.instance.isLoggedIn()) {
        return await AppwriteService.instance.getCurrentUser();
      }
    } catch (e) {
      print('Error getting current user: $e');
    }
    return null;
  }

  Widget _buildIncognitoBanner() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.only(top: 0, bottom: 0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
          ),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_off_rounded, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Incognito Mode',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: _exitIncognitoMode,
                  child: const Text('Exit'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(User? user) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.2),
                  Colors.white.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  if (user != null) ...[
                    // Logged in user view
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.2),
                        child: Text(
                          user.name.substring(0, 1).toUpperCase() ??
                              user.email.substring(0, 1).toUpperCase() ??
                              'U',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.name ?? 'User',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user.email ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => _handleLogout(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'Logout',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ] else ...[
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 2,
                            ),
                          ),
                          child: const CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.transparent,
                            child: Icon(
                              Icons.person_outline,
                              size: 50,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              "Guest User",
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Login to sync across all devices", // Updated text
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const LoginPage()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.login),
                              SizedBox(width: 8),
                              Text(
                                "Login",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const SignupPage()),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_add),
                              SizedBox(width: 8),
                              Text(
                                "Sign Up",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await AppwriteService.instance.deleteCurrentSession();
      if (mounted) {
        setState(() {
          ErrorHandlers.showSuccessSnackbar(
            context,
            'Successfully logged out',
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorHandlers.showErrorSnackbar(context, e);
      }
    }
  }

  Widget _buildSection(
    String title,
    IconData icon,
    VoidCallback onTap, {
    List<Map>? items,
    List<Widget>? children, // Add children parameter
    Function(int)? onLongPressItem,
    Function(int)? onItemTap, // Add this parameter
    VoidCallback? onHeaderLongPress,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: onHeaderLongPress,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                    ),
                    child: ListTile(
                      leading: Icon(icon, color: Colors.white),
                      title: Text(title,
                          style: const TextStyle(color: Colors.white)),
                      trailing:
                          const Icon(Icons.chevron_right, color: Colors.white),
                      onTap: onTap,
                    ),
                  ),
                ),
                if (items != null && items.isNotEmpty)
                  Container(
                    height: 180, // Increased height
                    padding: const EdgeInsets.all(16),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () =>
                              onItemTap?.call(index), // Add tap handler
                          onLongPress: () => onLongPressItem?.call(index),
                          child: Container(
                            width: 160, // Adjusted width
                            margin: const EdgeInsets.only(right: 16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    items[index]['image'],
                                    fit: BoxFit.cover,
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.9),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 12, // Increased padding
                                    left: 12,
                                    right: 12,
                                    child: Text(
                                      items[index]['title'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else if (children != null)
                  ...children // Add children widgets if provided
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            icon,
                            size: 48,
                            color: Colors.white.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No $title yet",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWatchHistory() {
    final watchHistory = WatchHistoryService.instance.getWatchHistory();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(watchHistory.length),
        child: _buildSection(
          "Watch History",
          Icons.history_rounded,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WatchHistoryPage(),
              ),
            );
          },
          items: watchHistory
              .map((item) => {
                    'title': item.title,
                    'image': item.poster,
                    'id': item.contentId,
                    'type': item.type,
                  })
              .toList(),
          onLongPressItem: (index) =>
              _showHistoryItemOptions(watchHistory[index]),
          onHeaderLongPress: () => _showClearHistoryDialog(),
          onItemTap: (index) => _handleWatchHistoryItemTap(watchHistory[index]),
        ),
      ),
    );
  }

  void _showHistoryItemOptions(ListItem item) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Remove from History'),
              onTap: () async {
                Navigator.pop(context);
                await WatchHistoryService.instance
                    .removeFromHistory(item.contentId.toString());
                _watchHistoryController.add(null); // Refresh list
              },
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Play'),
              onTap: () {
                Navigator.pop(context);
                _handleWatchHistoryItemTap(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Infopage(
                      id: item.contentId,
                      type: item.type,
                      name: item.title,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Watch History?'),
        content:
            const Text('This will remove all items from your watch history. '
                'This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await WatchHistoryService.instance.clearAllHistory();
              _watchHistoryController.add(null); // Refresh list
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Watch history cleared')),
                );
              }
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Widget _buildMyList() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(ListService.instance.getList().length),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const Icon(Icons.playlist_add_check_rounded,
                        color: Colors.white),
                    title: const Text(
                      "My List",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing:
                        const Icon(Icons.chevron_right, color: Colors.white),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyListPage(),
                        ),
                      );
                    },
                  ),
                  if (ListService.instance.getList().isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.playlist_add,
                              size: 48,
                              color: Colors.white.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No items in your list yet",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 180,
                      padding: const EdgeInsets.all(16),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: ListService.instance.getList().length,
                        itemBuilder: (context, index) {
                          final item = ListService.instance.getList()[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => Infopage(
                                    id: item.contentId,
                                    type: item.type,
                                    name: item.title,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 130,
                              margin: const EdgeInsets.only(right: 16),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item.poster,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
