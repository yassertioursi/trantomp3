import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

enum ConvertStatus { idle, fetching, downloading, done, error }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenLibrary});

  final VoidCallback? onOpenLibrary;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  final _explode = YoutubeExplode();

  ConvertStatus _status = ConvertStatus.idle;
  String? _title;
  String? _thumbnailUrl;
  double _progress = 0;
  String _statusText = '';
  String _error = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data == null || data.text == null) return;
    setState(() => _controller.text = data.text!.trim());
  }

  Future<void> _convert() async {
    final url = _controller.text.trim();
    if (url.isEmpty) {
      setState(() {
        _status = ConvertStatus.error;
        _error = 'Please paste a YouTube link first';
      });
      return;
    }

    setState(() {
      _status = ConvertStatus.fetching;
      _statusText = 'Fetching video info…';
      _progress = 0;
      _error = '';
    });

    try {
      // Permission (best-effort; modern Android saves to app dir anyway).
      final perm = await Permission.storage.request();
      if (perm.isDenied) {
        await Permission.manageExternalStorage.request();
      }

      final videoId = VideoId.fromString(url);
      final video = await _explode.videos.get(videoId);
      final manifest = await _explode.videos.streamsClient.getManifest(videoId);
      final streamInfo = manifest.audioOnly.withHighestBitrate();

      if (!mounted) return;
      setState(() {
        _title = video.title;
        _thumbnailUrl = video.thumbnails.highResUrl;
        _status = ConvertStatus.downloading;
        _statusText = 'Downloading…';
      });

      final dir = await getApplicationDocumentsDirectory();
      final safeTitle = video.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ');
      final filePath = '${dir.path}/$safeTitle.mp3';

      final dio = Dio();
      await dio.download(
        streamInfo.url.toString(),
        filePath,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          setState(() {
            _progress = received / total;
          });
        },
        deleteOnError: true,
      );

      if (!mounted) return;
      setState(() {
        _status = ConvertStatus.done;
        _statusText = 'Done! Saved to your Library.';
        _progress = 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = ConvertStatus.error;
        _error = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/logo.png',
                height: 26,
                width: 26,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            const Text('TRANTOMP3'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Paste a YouTube video link to convert it to MP3:',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: 'https://youtube.com/watch?v=...',
                prefixIcon: const Icon(Icons.link, color: Colors.grey),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste),
                  onPressed: _pasteFromClipboard,
                  tooltip: 'Paste from clipboard',
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_status == ConvertStatus.idle) ...[
              FilledButton.icon(
                onPressed: _convert,
                icon: const Icon(Icons.download),
                label: const Text('Convert to MP3',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: _status == ConvertStatus.downloading ||
                        _status == ConvertStatus.fetching
                    ? null
                    : _convert,
                icon: const Icon(Icons.download),
                label: const Text('Convert to MP3',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
            const SizedBox(height: 24),
            if (_thumbnailUrl != null && _title != null)
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        _thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Container(color: const Color(0xFF2A2A2A)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _title!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            if (_status == ConvertStatus.downloading ||
                _status == ConvertStatus.fetching) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _status == ConvertStatus.downloading
                      ? _progress
                      : null,
                  minHeight: 8,
                  backgroundColor: const Color(0xFF2A2A2A),
                  color: const Color(0xFFFF0000),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            if (_status == ConvertStatus.done) ...[
              const Icon(Icons.check_circle,
                  color: Color(0xFF4CAF50), size: 48),
              const SizedBox(height: 8),
              Text(_statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF4CAF50))),
            ],
            if (_status == ConvertStatus.error) ...[
              const Icon(Icons.error_outline,
                  color: Color(0xFFFF0000), size: 48),
              const SizedBox(height: 8),
              Text(_statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70)),
              Text(
                _error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFFF0000), fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: widget.onOpenLibrary,
              icon: const Icon(Icons.library_music),
              label: const Text('Go to Library'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFFF0000)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}