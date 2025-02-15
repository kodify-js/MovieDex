/**
 * MovieDex - Open Source Movie & TV Show Streaming Application
 * https://github.com/kodify-js/MovieDex-Flutter
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

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:moviedex/api/models/cache_model.dart';
import 'package:moviedex/api/models/watch_history_model.dart';
import 'package:moviedex/models/download_state_model.dart';
import 'package:moviedex/pages/info_page.dart';
import 'package:moviedex/pages/movie_page.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:moviedex/pages/profile_page.dart';
import 'package:moviedex/pages/tvshow_page.dart';
import 'package:moviedex/providers/downloads_provider.dart';
import 'package:moviedex/services/downloads_manager.dart';
import 'package:moviedex/services/list_service.dart';
import 'package:provider/provider.dart';
import 'package:moviedex/providers/theme_provider.dart';
import 'package:moviedex/services/cache_service.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/services/watch_history_service.dart';
import 'package:moviedex/api/models/list_item_model.dart';
import 'package:moviedex/pages/splash_screen.dart';
import 'firebase_options.dart'; 
import 'package:moviedex/components/responsive_navigation.dart';
import 'package:moviedex/services/background_download_service.dart';

/// Initialize core application services in required order
Future<void> initializeServices() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  await Hive.initFlutter();
  _registerHiveAdapters();
  
  // Initialize services in dependency order
  await ListService.instance.init();
  await WatchHistoryService.instance.init();
  await CacheService().init();
  await DownloadsManager.instance.init();
  await Hive.openBox('settings');
  
  // Initialize background service
  await BackgroundDownloadService.instance.init();
}

void _registerHiveAdapters() {
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
    Hive.registerAdapter(WatchHistoryItemAdapter());
  }
  if (!Hive.isAdapterRegistered(5)) {
    Hive.registerAdapter(ListItemAdapter());
  }
  if (!Hive.isAdapterRegistered(6)) {
    Hive.registerAdapter(DownloadItemAdapter());
  }
  if(!Hive.isAdapterRegistered(7)){
    Hive.registerAdapter(DownloadStateAdapter());
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeServices();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: DownloadsProvider.instance),
      ],
      child: const MovieDex(),
    ),
  );
}

class MovieDex extends StatefulWidget {
  const MovieDex({super.key});

  @override
  State<MovieDex> createState() => _MovieDexState();
}

class _MovieDexState extends State<MovieDex> {
  @override
  void initState() {
    super.initState();
    // Remove deep linking initialization
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movie Dex',
      debugShowCheckedModeBanner: false,
      theme: Provider.of<ThemeProvider>(context).getTheme(context),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const HomePage(),
      },
      onGenerateRoute: (settings) {
        print(settings.name);
        if (settings.name!.contains('/movie')) {
          if(settings.name!.split('/')[2]!=""){
            return MaterialPageRoute(
              builder: (context) => Infopage(
                id: int.parse(settings.name!.split('/')[2].toString()),
                type: 'movie',
                name: '',
              ),
            );
          }
        }
        if (settings.name!.contains('/tv')) {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => Infopage(
                id: int.parse(settings.name!.split('/')[2].toString()),
                type: 'tv',
                name: '',
            ),
          );
        }
        return null;
      },
    );
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
      bottomNavigationBar: !isDesktop ? ResponsiveNavigation(
        currentIndex: currentIndex,
        onTap: (index) => setState(() => currentIndex = index),
        items: _navItems,
      ) : null,
    );
  }
}

