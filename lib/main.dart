import 'package:flutter/material.dart';
import 'package:moviedex/pages/home_page.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:moviedex/pages/profile_page.dart';
import 'package:provider/provider.dart';
import 'package:moviedex/providers/theme_provider.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
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
        const Home(),
        const ProfilePage(),
                ][currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'My Dex',
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

