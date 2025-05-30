/**
 * MovieDex - Open Source Movie & TV Show Streaming Application
 * https://github.com/kodify-js/MovieDex
 * 
 * Copyright (c) 2024 MovieDex Contributors
 * Licensed under MIT License
 * 
 * Main application entry point that handles:
 * - Core service initialization
 * - Local database setup
 * - Authentication configuration
 * - Theme and UI management
 * - Navigation structure
 */
import 'package:flutter/material.dart';
import 'package:moviedex/api/models/cache_model.dart';
import 'package:moviedex/models/download_state_model.dart';
import 'package:moviedex/pages/info_page.dart';
import 'package:moviedex/pages/movie_page.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:moviedex/pages/profile_page.dart';
import 'package:moviedex/pages/tvshow_page.dart';
import 'package:moviedex/providers/downloads_provider.dart';
import 'package:moviedex/models/downloads_manager.dart';
import 'package:moviedex/services/list_service.dart';
import 'package:provider/provider.dart';
import 'package:moviedex/providers/theme_provider.dart';
import 'package:moviedex/services/cache_service.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/services/watch_history_service.dart';
import 'package:moviedex/api/models/list_item_model.dart';
import 'package:moviedex/pages/splash_screen.dart';
import 'package:moviedex/components/responsive_navigation.dart';
import 'package:moviedex/services/background_download_service.dart';
import 'package:moviedex/services/update_service.dart';

/// Initialize core application services in required order
Future<void> initializeServices() async {
  try {
    await Hive.initFlutter();
    _registerHiveAdapters();

    // Initialize critical services first
    await Hive.openBox('settings');

    // Initialize services in dependency order with error handling
    await _initializeWithFallback(() => ListService.instance.init());
    await _initializeWithFallback(() => WatchHistoryService.instance.init());
    await _initializeWithFallback(() => CacheService().init());
    await _initializeWithFallback(() => DownloadsManager.instance.init());

    // Initialize background service only when app is actively opened
    // Don't auto-start on boot to prevent crashes
    await _initializeWithFallback(
        () => BackgroundDownloadService.instance.init());
  } catch (e) {
    debugPrint('Error initializing services: $e');
    // Continue with app startup even if some services fail
  }
}

Future<void> _initializeWithFallback(
    Future<void> Function() initFunction) async {
  try {
    await initFunction();
  } catch (e) {
    debugPrint('Service initialization failed: $e');
    // Continue with app startup
  }
}

void _registerHiveAdapters() {
  try {
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(CacheModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ContentclassAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(SeasonAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(ListItemAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(DownloadItemAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(DownloadStateAdapter());
    }
  } catch (e) {
    debugPrint('Error registering Hive adapters: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize update service with error handling
  try {
    await UpdateService.instance.initialize();
  } catch (e) {
    debugPrint('Update service initialization failed: $e');
  }

  await initializeServices();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  // Add a global navigator key
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: DownloadsProvider.instance),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) => MaterialApp(
          title: 'MovieDex',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.getTheme(context),
          navigatorKey: navigatorKey,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
          },
          onGenerateRoute: (settings) {
            print('onGenerateRoute called with: ${settings.name}');

            if (settings.name == '/home') {
              return MaterialPageRoute(
                builder: (context) => const HomePage(),
              );
            }

            if (settings.name?.contains('/movie') ?? false) {
              try {
                final parts = settings.name!.split('/');
                if (parts.length >= 4) {
                  final title = parts[2].replaceAll("-", " ");
                  final id = int.parse(parts[3]);
                  return MaterialPageRoute(
                    builder: (context) => Infopage(
                      id: id,
                      type: 'movie',
                      title: title,
                    ),
                  );
                }
              } catch (e) {
                print('Error parsing movie route: $e');
              }
            }

            if (settings.name?.contains('/tv') ?? false) {
              try {
                final parts = settings.name!.split('/');
                if (parts.length >= 4) {
                  final title = parts[2].replaceAll("-", " ");
                  final id = int.parse(parts[3]);
                  return MaterialPageRoute(
                    builder: (context) => Infopage(
                      id: id,
                      type: 'tv',
                      title: title,
                    ),
                  );
                }
              } catch (e) {
                print('Error parsing TV route: $e');
              }
            }

            // Default fallback
            return MaterialPageRoute(
              builder: (context) => const HomePage(),
            );
          },
          onUnknownRoute: (settings) {
            print('onUnknownRoute called with: ${settings.name}');
            // Handle deep links that come through as unknown routes
            final routeName = settings.name;

            if (routeName?.contains('/movie') ?? false) {
              try {
                final parts = routeName!.split('/');
                if (parts.length >= 4) {
                  final title = parts[2].replaceAll("-", " ");
                  final id = int.parse(parts[3]);
                  return MaterialPageRoute(
                    builder: (context) => DeepLinkHandler(
                      child: Infopage(
                        id: id,
                        type: 'movie',
                        title: title,
                      ),
                    ),
                  );
                }
              } catch (e) {
                print('Error parsing movie deep link: $e');
              }
            }

            if (routeName?.contains('/tv') ?? false) {
              try {
                final parts = routeName!.split('/');
                if (parts.length >= 4) {
                  final title = parts[2].replaceAll("-", " ");
                  final id = int.parse(parts[3]);
                  return MaterialPageRoute(
                    builder: (context) => DeepLinkHandler(
                      child: Infopage(
                        id: id,
                        type: 'tv',
                        title: title,
                      ),
                    ),
                  );
                }
              } catch (e) {
                print('Error parsing TV deep link: $e');
              }
            }

            return MaterialPageRoute(
              builder: (context) => const HomePage(),
            );
          },
        ),
      ),
    );
  }
}

// Handler for deep links that shows splash first
class DeepLinkHandler extends StatefulWidget {
  final Widget child;

  const DeepLinkHandler({super.key, required this.child});

  @override
  State<DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

class _DeepLinkHandlerState extends State<DeepLinkHandler> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _handleSplash();
  }

  void _handleSplash() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _showSplash = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return const SplashScreen();
    }
    return widget.child;
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentIndex = 0;
  final List<Widget> _pages = const [
    Movie(),
    Tvshows(),
    ProfilePage(),
  ];

  final List<NavigationDestination> _navItems = const [
    NavigationDestination(
      icon: Icon(Icons.movie_outlined),
      selectedIcon: Icon(Icons.movie_rounded),
      label: 'Movies',
    ),
    NavigationDestination(
      icon: Icon(Icons.tv_outlined),
      selectedIcon: Icon(Icons.tv_rounded),
      label: 'TV Shows',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 800;

    return Scaffold(
      body: Row(
        children: [
          if (isDesktop)
            ResponsiveNavigation(
              currentIndex: currentIndex,
              onTap: (index) => setState(() => currentIndex = index),
              items: _navItems,
            ),
          Expanded(
            child: IndexedStack(
              index: currentIndex,
              children: _pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: !isDesktop
          ? ResponsiveNavigation(
              currentIndex: currentIndex,
              onTap: (index) => setState(() => currentIndex = index),
              items: _navItems,
            )
          : null,
    );
  }
}
