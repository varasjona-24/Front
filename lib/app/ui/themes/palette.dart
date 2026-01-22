import 'package:flutter/material.dart';
import 'app_palette.dart';

const terracotaPalette = AppPalette(
  primary: Color.fromARGB(255, 193, 78, 40), // Dark Coffee (suavizado)
  secondary: Color.fromARGB(255, 154, 54, 54), // Khaki Beige (suavizado)
  accent: Color.fromARGB(255, 200, 132, 108), // Powder Blush (suavizado)
  neutral: Color.fromARGB(255, 228, 190, 180), // Champagne Mist (suavizado)
);
const olivePalette = AppPalette(
  primary: Color.fromARGB(255, 50, 80, 58), // Dark Spruce (suavizado)
  secondary: Color.fromARGB(255, 78, 110, 54), // Muted Olive (suavizado)
  accent: Color.fromARGB(255, 142, 180, 98), // Light Olive (suavizado)
  neutral: Color.fromARGB(255, 178, 214, 198), // Carbon Black (suavizado)
);
const bluePalette = AppPalette(
  primary: Color.fromARGB(255, 35, 85, 160), // Deep Blue (suavizado)
  secondary: Color.fromARGB(255, 100, 170, 210), // Medium Slate Blue (suavizado)
  accent: Color.fromARGB(255, 92, 130, 210), // Soft Blue (suavizado)
  neutral: Color(0xFFB5C6F2), // Light Sky (suavizado)
);
const sunsetPalette = AppPalette(
  primary: Color.fromARGB(255, 214, 167, 74), // Pumpkin Spice (suavizado)
  secondary: Color.fromARGB(255, 200, 180, 90), // Sandy Brown (suavizado)
  accent: Color.fromARGB(255, 186, 140, 80), // Sunlit Clay (suavizado)
  neutral: Color.fromARGB(255, 220, 205, 170), // Powder Blush (suavizado)
);
const purplePalette = AppPalette(
  primary: Color(0xFF8B7FD6), // Medium Slate Blue (suavizado)
  secondary: Color(0xFFB396E6), // Soft Periwinkle (suavizado)
  accent: Color(0xFFC4A2E6), // Mauve (suavizado)
  neutral: Color(0xFFD2C8E6), // Thistle (suavizado)
);
const grayPalette = AppPalette(
  primary: Color(0xFF4A4A4A), // Dark Charcoal
  secondary: Color(0xFF7B7B7B), // Medium Gray
  accent: Color(0xFFA9A9A9), // Silver
  neutral: Color(0xFFD3D3D3), // Light Gray
);

const palettes = {
  'red': terracotaPalette,
  'green': olivePalette,
  'blue': bluePalette,
  'yellow': sunsetPalette,
  'purple': purplePalette,
  'gray': grayPalette,
};
