import 'package:flutter/material.dart';
import 'package:moviedex/pages/home_page.dart';
import 'package:hive_flutter/hive_flutter.dart';


void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(MovieDex());
} 

class MovieDex extends StatelessWidget {
  const MovieDex({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movie Dex',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent,
        primary: const Color.fromARGB(255, 25, 106, 247),
        surface: Colors.black,
        onSurface: Colors.white,
        secondary: Color.fromARGB(255, 32, 32, 32),
        onSecondary: Colors.white,
        error: Colors.red,
        onError: Colors.white,
        ),
      ),
      home: const Home()
    );
  }
}

