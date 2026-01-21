import 'package:flutter/material.dart';
import 'app_palette.dart';

const terracotaPalette = AppPalette(
  primary: Color.fromARGB(255, 223, 65, 12), // Dark Coffee
  secondary: Color.fromARGB(255, 173, 29, 29), // Khaki Beige
  accent: Color.fromARGB(255, 214, 127, 92), // Powder Blush
  neutral: Color.fromARGB(255, 240, 184, 170), // Champagne Mist
);
const olivePalette = AppPalette(
  primary: Color.fromARGB(255, 48, 81, 51), // Dark Spruce
  secondary: Color.fromARGB(255, 53, 122, 11), // Muted Olive
  accent: Color.fromARGB(255, 161, 203, 83), // Light Olive
  neutral: Color.fromARGB(255, 173, 227, 204), // Carbon Black
);
const bluePalette = AppPalette(
  primary: Color.fromARGB(255, 18, 65, 152), // Deep Blue
  secondary: Color.fromARGB(255, 80, 183, 227), // Medium Slate Blue
  accent: Color.fromARGB(255, 75, 114, 231), // Soft Blue
  neutral: Color(0xFFA3BDFF), // Light Sky
);
const sunsetPalette = AppPalette(
  primary: Color.fromARGB(255, 243, 183, 43), // Pumpkin Spice
  secondary: Color.fromARGB(226, 222, 195, 43), // Sandy Brown
  accent: Color.fromARGB(255, 199, 132, 50), // Sunlit Clay
  neutral: Color.fromARGB(255, 232, 213, 156), // Powder Blush
);
const purplePalette = AppPalette(
  primary: Color(0xFF8575FB), // Medium Slate Blue
  secondary: Color(0xFFB185FF), // Soft Periwinkle
  accent: Color(0xFFC799FF), // Mauve
  neutral: Color(0xFFD4C0EB), // Thistle
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
