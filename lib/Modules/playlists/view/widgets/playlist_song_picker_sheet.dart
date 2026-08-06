import 'dart:io';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';

import '../../../../app/models/media_item.dart';

class PlaylistSongPickerSheet extends StatefulWidget {
  const PlaylistSongPickerSheet({
    super.key,
    required this.title,
    required this.allItems,
    required this.submitLabelBuilder,
    this.emptySubmitLabel,
    this.initialSelectedKeys = const <String>{},
    this.lockedSelectedKeys = const <String>{},
    this.emptyLibraryLabelKey = 'playlists.detail.no_new_songs',
  });

  final String title;
  final List<MediaItem> allItems;
  final String Function(int selectedCount) submitLabelBuilder;
  final String? emptySubmitLabel;
  final Set<String> initialSelectedKeys;
  final Set<String> lockedSelectedKeys;
  final String emptyLibraryLabelKey;

  @override
  State<PlaylistSongPickerSheet> createState() =>
      _PlaylistSongPickerSheetState();

  static String keyFor(MediaItem item) {
    final publicId = item.publicId.trim();
    return publicId.isNotEmpty ? publicId : item.id.trim();
  }
}

class _PlaylistSongPickerSheetState extends State<PlaylistSongPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selected = <String>{};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected
      ..addAll(widget.initialSelectedKeys)
      ..addAll(widget.lockedSelectedKeys);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MediaItem> get _filteredItems {
    final normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return widget.allItems;
    return widget.allItems
        .where((item) {
          return item.title.toLowerCase().contains(normalizedQuery) ||
              item.displaySubtitle.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.trim().toLowerCase();
    final items = _filteredItems;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.playlist_add_rounded),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(tr('common.close')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (value) {
                      setState(() => _query = value);
                    },
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.trim().isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            ),
                      hintText: tr('home.search.by_title_artist'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(
                          Icons.library_music_rounded,
                          size: 18,
                        ),
                        label: Text(
                          tr(
                            'playlists.detail.available_count',
                            args: ['${widget.allItems.length}'],
                          ),
                        ),
                      ),
                      Chip(
                        avatar: const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                        ),
                        label: Text(
                          tr(
                            'playlists.detail.selected_count',
                            args: ['${_selected.length}'],
                          ),
                        ),
                      ),
                      if (normalizedQuery.isNotEmpty)
                        Chip(
                          avatar: const Icon(
                            Icons.filter_alt_rounded,
                            size: 18,
                          ),
                          label: Text(
                            tr(
                              'home.search.results',
                              args: ['${items.length}'],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          normalizedQuery.isEmpty
                              ? tr(widget.emptyLibraryLabelKey)
                              : tr('edit.no_songs_found'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (ctx, i) => _songTile(ctx, items[i]),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _selected.isEmpty ? null : _submit,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    _selected.isEmpty
                        ? widget.emptySubmitLabel ??
                              tr('playlists.detail.select_songs')
                        : widget.submitLabelBuilder(_selected.length),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _songTile(BuildContext context, MediaItem item) {
    final key = PlaylistSongPickerSheet.keyFor(item);
    final checked = _selected.contains(key);
    final locked = widget.lockedSelectedKeys.contains(key);
    final thumb = item.effectiveThumbnail;

    return Material(
      color: checked
          ? Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.5)
          : Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: checked
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: locked ? null : () => _toggle(key, checked),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 48,
            height: 48,
            child: thumb == null || thumb.isEmpty
                ? ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.music_note_rounded),
                  )
                : Image(
                    image: thumb.startsWith('http')
                        ? NetworkImage(thumb)
                        : FileImage(File(thumb)) as ImageProvider,
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          item.displaySubtitle.isEmpty
              ? tr('edit.unknown_artist')
              : item.displaySubtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Checkbox(
          value: checked,
          onChanged: locked ? null : (v) => _toggle(key, checked),
        ),
      ),
    );
  }

  void _toggle(String key, bool checked) {
    setState(() {
      if (checked) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
  }

  void _submit() {
    final selected = widget.allItems.where((item) {
      return _selected.contains(PlaylistSongPickerSheet.keyFor(item));
    }).toList();
    Navigator.of(context).pop(selected);
  }
}
