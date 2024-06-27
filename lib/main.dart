import 'package:flutter/material.dart';
import 'package:pet_feeder/home_page.dart';
import 'package:pet_feeder/provider.dart';
import 'package:provider/provider.dart';

final appProvider = AppProvider();

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => appProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'PerFeeder',
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
