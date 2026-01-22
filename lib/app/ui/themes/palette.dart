import 'package:flutter/material.dart';
import 'app_palette.dart';

const terracotaPalette = AppPalette(
  primary: Color.fromARGB(255, 170, 88, 60), // Terracota suave
  secondary: Color.fromARGB(255, 150, 74, 72), // Arcilla apagada
  accent: Color.fromARGB(255, 202, 148, 128), // Melocotón suave
  neutral: Color.fromARGB(255, 226, 198, 188), // Nube cálida
);
const olivePalette = AppPalette(
  primary: Color.fromARGB(255, 62, 86, 66), // Verde musgo
  secondary: Color.fromARGB(255, 96, 118, 76), // Oliva apagado
  accent: Color.fromARGB(255, 150, 176, 112), // Salvia clara
  neutral: Color.fromARGB(255, 186, 206, 190), // Niebla verdosa
);
const bluePalette = AppPalette(
  primary: Color.fromARGB(255, 54, 90, 150), // Azul profundo suave
  secondary: Color.fromARGB(255, 110, 150, 196), // Azul grisáceo
  accent: Color.fromARGB(255, 118, 140, 188), // Azul neblina
  neutral: Color(0xFFC2CEE6), // Cielo pálido
);
const sunsetPalette = AppPalette(
  primary: Color.fromARGB(255, 196, 154, 92), // Ocre suave
  secondary: Color.fromARGB(255, 190, 170, 110), // Arena apagada
  accent: Color.fromARGB(255, 178, 136, 96), // Arcilla cálida
  neutral: Color.fromARGB(255, 216, 204, 180), // Beige humo
);
const grayPalette = AppPalette(
  primary: Color(0xFF4F4F4F), // Carbón suave
  secondary: Color(0xFF7A7A7A), // Gris medio
  accent: Color(0xFFA3A3A3), // Plata
  neutral: Color(0xFFD0D0D0), // Gris claro
);

const palettes = {
  'red': terracotaPalette,
  'green': olivePalette,
  'blue': bluePalette,
  'yellow': sunsetPalette,
  'gray': grayPalette,
};
