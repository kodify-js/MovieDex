import 'package:flutter/material.dart';
import 'package:moviedex/api/models/cache_model.dart';
import 'package:moviedex/api/models/watch_history_model.dart';
import 'package:moviedex/pages/movie_page.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:moviedex/pages/profile_page.dart';
import 'package:moviedex/pages/tvshow_page.dart';
import 'package:provider/provider.dart';
import 'package:moviedex/providers/theme_provider.dart';
import 'package:moviedex/api/services/cache_service.dart';
import 'package:moviedex/api/class/content_class.dart';
import 'package:moviedex/api/services/watch_history_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  
  // Initialize services
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
        body:[
        const Movie(),
        const Tvshows(),
        const ProfilePage(),
                ][currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
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
          currentIndex: currentIndex,
          onTap: (value){
            setState(() => currentIndex = value);
          },
        ), 
      ),
    );
  }
}

