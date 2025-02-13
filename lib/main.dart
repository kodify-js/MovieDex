import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:moviedex/api/models/cache_model.dart';
import 'package:moviedex/api/models/watch_history_model.dart';
import 'package:moviedex/pages/movie_page.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:moviedex/pages/profile_page.dart';
import 'package:moviedex/pages/tvshow_page.dart';
import 'package:moviedex/services/list_service.dart';
import 'package:provider/provider.dart';
import 'package:moviedex/providers/theme_provider.dart';
import 'package:moviedex/services/cache_service.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/services/watch_history_service.dart';
import 'package:moviedex/api/models/list_item_model.dart';
import 'firebase_options.dart'; 

void main() async {
  // This needs to be called first
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // Initialize Hive
  await Hive.initFlutter();
  
  // Register Hive adapters
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
  
  // Initialize services in order
  await ListService.instance.init();
  await WatchHistoryService.instance.init();
  final cacheService = CacheService();
  await cacheService.init();
  
  // Open settings box
  await Hive.openBox('settings');
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
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
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movie Dex',
      debugShowCheckedModeBanner: false,
      theme: Provider.of<ThemeProvider>(context).getTheme(context),
      home: Scaffold(
        body: IndexedStack(
          index: currentIndex,
          children: const [
            Movie(),
            Tvshows(),
            ProfilePage(), // ProfilePage will handle auth state
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (value) => setState(() => currentIndex = value),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.movie),
              label: 'Movie',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.tv),
              label: 'Tv Shows',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Me',
            ),
          ],
        ),
      ),
    );
  }
}

