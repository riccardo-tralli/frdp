import 'package:flutter/material.dart';
import 'package:frdp_example/const/rradius.dart';
import 'package:frdp_example/const/spaces.dart';

class Light {
  static ThemeData get make => ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: Colors.blue,
      onPrimary: Colors.white,
      secondary: Colors.blueAccent,
      onSecondary: Colors.white,
      error: Colors.red,
      onError: Colors.white,
      surface: Colors.white,
      onSurface: Colors.grey.shade900,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderSide: BorderSide(width: 0, color: Colors.transparent),
        borderRadius: BorderRadius.circular(RRadius.medium),
      ),
      activeIndicatorBorder: BorderSide(width: 0, color: Colors.transparent),
      hintStyle: TextStyle(color: Colors.grey.shade400),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size.fromHeight(52)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RRadius.medium),
          ),
        ),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.grey.shade300,
      thickness: 1,
      space: Spaces.none,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RRadius.medium),
      ),
      tileColor: Colors.grey.shade100,
      selectedTileColor: Colors.blue.shade50,
      contentPadding: EdgeInsets.only(left: Spaces.medium, right: Spaces.small),
    ),
  );
}
