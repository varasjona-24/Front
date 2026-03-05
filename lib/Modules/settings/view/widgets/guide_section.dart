import 'package:flutter/material.dart';

class GuideSection extends StatelessWidget {
  const GuideSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topics = _guideTopics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Icon(Icons.menu_book_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                'Guía rápida',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: .12)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Funciones poco evidentes',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Atajos, gestos y comportamientos utiles que no siempre se ven a primera vista.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                for (int i = 0; i < topics.length; i++) ...[
                  _GuideTopicTile(topic: topics[i]),
                  if (i != topics.length - 1) ...[
                    const SizedBox(height: 8),
                    Divider(color: theme.dividerColor.withValues(alpha: .12)),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GuideTopicTile extends StatelessWidget {
  const _GuideTopicTile({required this.topic});

  final _GuideTopic topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        leading: Icon(topic.icon),
        title: Text(
          topic.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(topic.subtitle, style: theme.textTheme.bodySmall),
        children: [
          const SizedBox(height: 4),
          for (final tip in topic.tips)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 4, bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tip,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GuideTopic {
  const _GuideTopic({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tips,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> tips;
}

const List<_GuideTopic> _guideTopics = [
  _GuideTopic(
    icon: Icons.headphones_rounded,
    title: 'Audio',
    subtitle: 'Controles y extras del reproductor musical.',
    tips: [
      'Dentro del player de audio puedes cambiar el estilo de portada desde el icono superior derecho antes de la cola.',
      'El modo envolvente se activa con el icono de surround y convive con repeticion una vez o en bucle desde la misma pantalla.',
      'La cola de audio se puede reordenar arrastrando para ajustar el orden de reproduccion.',
      'El crossfade, ecualizador, temporizador de apagado y volumen por defecto viven en Configuracion > Audio.',
    ],
  ),
  _GuideTopic(
    icon: Icons.ondemand_video_rounded,
    title: 'Video',
    subtitle: 'Gestos y utilidades del reproductor de video.',
    tips: [
      'Doble toque en la mitad izquierda o derecha del video retrocede o adelanta 5 segundos.',
      'Arrastre vertical con un dedo cambia el volumen; con dos dedos cambia la velocidad.',
      'Doble toque con dos dedos alterna entre play y pausa.',
      'Al mover la barra de progreso aparece una previsualizacion del frame; ademas puedes guardar una captura desde el icono de camara.',
      'En Android, si el video sigue reproduciendose al salir, puede entrar en PiP automaticamente.',
    ],
  ),
  _GuideTopic(
    icon: Icons.edit_note_rounded,
    title: 'Edicion y metadata',
    subtitle: 'Portadas, artistas y ajustes finos de biblioteca.',
    tips: [
      'Las portadas de canciones, artistas, playlists y listas tematicas pueden venir de archivo local o busqueda web, y luego se recortan en cuadrado.',
      'Si una colaboracion va a contarse en ambos artistas, debe escribirse en el campo Artista con patrones como feat., ft., featuring o with.',
      'Despues del marcador de colaboracion, los invitados pueden separarse con coma, x o &.',
      'Si el titulo sugiere feat o ft pero el campo Artista no lo refleja, al guardar se muestra una advertencia para corregirlo.',
    ],
  ),
  _GuideTopic(
    icon: Icons.archive_rounded,
    title: 'Datos y recuperacion',
    subtitle: 'Respaldo, cookies y comportamiento del sistema.',
    tips: [
      'El respaldo ZIP actual es completo: incluye audio, video, imagenes y metadata offline, por lo que puede tardar y pesar bastante.',
      'Si ciertas descargas de YouTube fallan, puedes actualizar cookies.txt desde Configuracion > Datos y descargas.',
      'En Android, el ahorro de bateria puede ocultar controles en pantalla de bloqueo; desde Settings tienes acceso directo a ese ajuste.',
    ],
  ),
  _GuideTopic(
    icon: Icons.category_rounded,
    title: 'Fuentes y listas',
    subtitle: 'Organizacion extra de la biblioteca.',
    tips: [
      'La seccion Fuentes no solo filtra: organiza la biblioteca por tematicas y origenes para armar vistas mas curadas.',
      'Las listas tematicas admiten sublistas y portada propia, asi que puedes construir jerarquias para navegar tu contenido.',
    ],
  ),
];
