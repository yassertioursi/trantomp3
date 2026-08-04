import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final AudioPlayer _player = AudioPlayer();
  final List<File> _files = [];
  String? _playingPath;

  @override
  void initState() {
    super.initState();
    _loadFiles();
    _player.playerStateStream.listen((state) {
      if (mounted && state.processingState == ProcessingState.completed) {
        setState(() => _playingPath = null);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final files = await dir
        .list()
        .where((e) => e is File && e.path.toLowerCase().endsWith('.mp3'))
        .cast<File>()
        .toList();
    if (!mounted) return;
    setState(() => _files
      ..clear()
      ..addAll(files));
  }

  Future<void> _playPause(File file) async {
    if (_playingPath == file.path) {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
      setState(() {});
    } else {
      await _player.stop();
      await _player.setFilePath(file.path);
      await _player.play();
      setState(() => _playingPath = file.path);
    }
  }

  Future<void> _delete(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        title: const Text('Delete file?'),
        content: Text(file.uri.pathSegments.last),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF0000)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (_playingPath == file.path) {
      await _player.stop();
      _playingPath = null;
    }
    try {
      await file.delete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      return;
    }
    if (!mounted) return;
    setState(() => _files.remove(file));
  }

  String _fileName(File file) {
    final name = file.uri.pathSegments.last;
    return name.endsWith('.mp3') ? name.substring(0, name.length - 4) : name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFiles,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _files.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.music_off, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No MP3 files yet',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _files.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final file = _files[index];
                final isPlaying = _playingPath == file.path;
                final isPaused =
                    isPlaying && !(_player.playing);

                return Card(
                  child: ListTile(
                    leading: Icon(
                      isPlaying
                          ? (isPaused
                              ? Icons.pause_circle
                              : Icons.play_circle)
                          : Icons.music_note,
                      color: isPlaying ? const Color(0xFFFF0000) : Colors.white,
                      size: 36,
                    ),
                    title: Text(
                      _fileName(file),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(_formatBytes(file.lengthSync())),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(isPlaying && !isPaused
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled),
                          color: const Color(0xFFFF0000),
                          onPressed: () => _playPause(file),
                          tooltip: isPlaying && !isPaused ? 'Pause' : 'Play',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: Colors.grey,
                          onPressed: () => _delete(file),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}