import 'package:flutter/material.dart';
import 'store/pocket_store.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

class PocketDayApp extends StatelessWidget {
  final PocketStore store;
  final bool autoRefresh;
  const PocketDayApp({super.key, required this.store, this.autoRefresh = true});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'PocketDay',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: Home(store: store, autoRefresh: autoRefresh),
  );
}
