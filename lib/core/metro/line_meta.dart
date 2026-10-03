import 'package:flutter/material.dart';

Color lineColor(String line) {
  switch (line.toLowerCase().trim()) {
    case 'yellow':
      return const Color(0xFFF4B400);
    case 'blue':
      return const Color(0xFF1A73E8);
    case 'red':
      return const Color(0xFFDB4437);
    case 'green':
      return const Color(0xFF0F9D58);
    case 'violet':
      return const Color(0xFF7E57C2);
    case 'orange':
      return const Color(0xFFFB8C00);
    case 'magenta':
      return const Color(0xFFD81B60);
    case 'pink':
      return const Color(0xFFF06292);
    case 'aqua':
      return const Color(0xFF00ACC1);
    case 'grey':
      return const Color(0xFF757575);
    case 'rapid':
      return const Color(0xFF546E7A);
    case 'rapidloop':
      return const Color(0xFF455A64);
    case 'pitampura':
      return const Color(0xFF8E24AA);
    case 'meerutblue':
      return const Color(0xFF1565C0);
    case 'chennaiblue':
      return const Color(0xFF1976D2);
    case 'chennaigreen':
      return const Color(0xFF2E7D32);
    case 'bengalurupurple':
      return const Color(0xFF7B1FA2);
    case 'bengalurugreen':
      return const Color(0xFF388E3C);
    case 'bengaluruyellow':
      return const Color(0xFFF9A825);
    case 'patnablue':
      return const Color(0xFF0288D1);
    case 'patnared':
      return const Color(0xFFC62828);
    case 'golden':
      return const Color(0xFFC5A059); // Golden/Gold
    case 'mumbaiblue':
      return const Color(0xFF1E88E5);
    case 'mumbaiyellow':
      return const Color(0xFFFDD835);
    case 'mumbaired':
      return const Color(0xFFE53935);
    case 'mumbaiaqua':
      return const Color(0xFF00ACC1);
    case 'greenbranch':
      return const Color(0xFF66BB6A);
    case 'bluebranch':
      return const Color(0xFF42A5F5);
    case 'pinkbranch':
      return const Color(0xFFF48FB1);
    default:
      return Colors.blueGrey;
  }
}

String lineName(String line) {
  switch (line.toLowerCase().trim()) {
    case 'yellow':
      return 'Yellow Line';
    case 'blue':
      return 'Blue Line';
    case 'red':
      return 'Red Line';
    case 'green':
      return 'Green Line';
    case 'violet':
      return 'Violet Line';
    case 'orange':
      return 'Orange Line';
    case 'magenta':
      return 'Magenta Line';
    case 'pink':
      return 'Pink Line';
    case 'aqua':
      return 'Aqua Line';
    case 'grey':
      return 'Grey Line';
    case 'rapid':
      return 'Rapid Metro';
    case 'rapidloop':
      return 'Rapid Metro Loop';
    case 'pitampura':
      return 'Pitampura Line';
    case 'meerutblue':
      return 'Meerut Blue Corridor';
    case 'chennaiblue':
      return 'Chennai Blue Line';
    case 'chennaigreen':
      return 'Chennai Green Line';
    case 'bengalurupurple':
      return 'Bengaluru Purple Line';
    case 'bengalurugreen':
      return 'Bengaluru Green Line';
    case 'bengaluruyellow':
      return 'Bengaluru Yellow Line';
    case 'patnablue':
      return 'Patna Blue Corridor';
    case 'patnared':
      return 'Patna Red Corridor';
    case 'golden':
      return 'Golden Line';
    case 'mumbaiblue':
      return 'Mumbai Blue Line 1';
    case 'mumbaiyellow':
      return 'Mumbai Yellow Line 2A';
    case 'mumbaired':
      return 'Mumbai Red Line 7';
    case 'mumbaiaqua':
      return 'Mumbai Aqua Line 3';
    case 'greenbranch':
      return 'Green Line Branch';
    case 'bluebranch':
      return 'Blue Line Branch';
    case 'pinkbranch':
      return 'Pink Line Branch';
    default:
      return line;
  }
}
