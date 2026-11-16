import 'package:flutter/material.dart';

const campusNavy = Color(0xFF192948);
const campusPurple = Color(0xFF6553C7);
const campusBackground = Color(0xFFF5F6FA);

ThemeData campusTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: campusPurple),
  scaffoldBackgroundColor: campusBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: campusNavy,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
    elevation: 0,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: campusNavy,
    ),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    margin: const EdgeInsets.symmetric(vertical: 6),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: Color(0xFFE5E7EF)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFF8F9FC),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.all(16),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  dividerTheme: const DividerThemeData(color: Color(0xFFE5E7EF)),
);
