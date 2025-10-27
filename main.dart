// GENERATED: Jarvis - Cartoon Video Maker (main.dart)
// Place this file at: lib/main.dart

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(JarvisApp());
}

class JarvisApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jarvis - Cartoon Video Maker',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        brightness: Brightness.light,
      ),
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TextEditingController _scriptController = TextEditingController();
  bool _isGenerating = false;
  double _progress = 0.0;
  String? _videoPath;
  List<String> _framePaths = [];

  @override
  void dispose() {
    _scriptController.dispose();
    super.dispose();
  }

  Future<void> _ensurePermissions() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
    }
  }

  List<String> _splitScriptIntoScenes(String script) {
    var raw = script.replaceAll('\r', '\n');
    var lines = raw.split(RegExp(r"\n+"));
    List<String> scenes = [];
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      var parts = line.split(RegExp(r'(?<=[.!?])\s+'));
      for (var p in parts) {
        p = p.trim();
        if (p.isNotEmpty) scenes.add(p);
      }
    }
    return scenes;
  }

  Future<String> _getCacheDirPath() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }

  Future<String> _generateFrameForScene(String sceneText, int index) async {
    final width = 1280;
    final height = 720;
    final rng = Random(sceneText.hashCode + index);

    int r = 100 + rng.nextInt(156);
    int g = 100 + rng.nextInt(156);
    int b = 100 + rng.nextInt(156);
    final backgroundColor = img.getColor(r, g, b);

    final image = img.Image(width, height);
    img.fill(image, backgroundColor);

    int blobW = (width * (0.6 + rng.nextDouble() * 0.3)).toInt();
    int blobH = (height * (0.45 + rng.nextDouble() * 0.35)).toInt();
    int blobX = (width - blobW) ~/ 2 + rng.nextInt(40) - 20;
    int blobY = (height - blobH) ~/ 2 + rng.nextInt(40) - 20;

    int blobColor = img.getColor((r + 60) % 256, (g + 60) % 256, (b + 60) % 256);
    img.fillRect(image, blobX, blobY, blobX + blobW, blobY + blobH, blobColor);

    final font = img.arial_48;

    final maxCharsPerLine = 28;
    final words = sceneText.split(RegExp(r'\s+'));
    List<String> lines = [];
    String cur = '';
    for (var w in words) {
      if ((cur + ' ' + w).trim().length <= maxCharsPerLine) {
        cur = (cur + ' ' + w).trim();
      } else {
        if (cur.isNotEmpty) lines.add(cur);
        cur = w;
      }
    }
    if (cur.isNotEmpty) lines.add(cur);

    int textTotalHeight = lines.length * (font.height + 8);
    int startY = blobY + (blobH - textTotalHeight) ~/ 2;

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      int textWidth = img.measureText(font, line).width;
      int x = (width - textWidth) ~/ 2;
      int y = startY + i * (font.height + 8);
      img.drawString(image, font, x, y, line, color: img.getColor(255, 255, 255));
    }

    final footer = 'Jarvis • ${DateFormat('yyyy-MM-dd – kk:mm').format(DateTime.now())}';
    img.drawString(image, img.arial_24, 20, height - 40, footer, color: img.getColor(245, 245, 245));

    final cachePath = await _getCacheDirPath();
    final fileName = 'frame_${index.toString().padLeft(3, '0')}.png';
    final filePath = '$cachePath/$fileName';
    final png = img.encodePng(image);
    final f = File(filePath);
    await f.writeAsBytes(png);
    return filePath;
  }

  Future<void> _generateVideoFromScript(String script) async {
    setState(() {
      _isGenerating = true;
      _progress = 0.0;
      _videoPath = null;
      _framePaths = [];
    });

    await _ensurePermissions();

    final scenes = _splitScriptIntoScenes(script);
    if (scenes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Script khali hai — kuch likho pehle.')));
      setState(() => _isGenerating = false);
      return;
    }

    final cachePath = await _getCacheDirPath();
    try {
      final dir = Directory(cachePath);
      final files = dir.listSync().where((f) => f.path.contains('frame_') || f.path.endsWith('jarvis_output.mp4'));
      for (var f in files) {
        try { f.deleteSync(); } catch (e) {}
      }
    } catch (e) {}

    int total = scenes.length;
    for (int i = 0; i < scenes.length; i++) {
      final path = await _generateFrameForScene(scenes[i], i);
      _framePaths.add(path);
      setState(() {
        _progress = (i + 1) / (total + 1);
      });
    }

    final outputPath = '$cachePath/jarvis_output_${Uuid().v4().substring(0,8)}.mp4';
    final ffmpegCommand = '-y -framerate 1 -i $cachePath/frame_%03d.png -c:v libx264 -r 30 -pix_fmt yuv420p $outputPath';

    await FFmpegKit.executeAsync(ffmpegCommand, (session) async {
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        setState(() {
          _videoPath = outputPath;
          _progress = 1.0;
          _isGenerating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Video taiyaar hua — path: $outputPath')));
      } else {
        setState(() {
          _isGenerating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('FFmpeg error — check logs.')));
      }
    });
  }

  Widget _buildFramePreview() {
    if (_framePaths.isEmpty) return SizedBox();
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _framePaths.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              children: [
                Container(
                  width: 220,
                  height: 120,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.grey[300]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(_framePaths[index]), fit: BoxFit.cover),
                  ),
                ),
                SizedBox(height: 6),
                Text('Scene ${index + 1}', style: TextStyle(fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Icon(Icons.smart_toy),
          SizedBox(width: 8),
          Text('Jarvis'),
        ]),
      ),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Script likho (har scene newline ya sentence se alag karo):', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _scriptController,
                maxLines: null,
                expands: true,
                decoration: InputDecoration(
                  hintText: '"Ek joker stage par aata hai. Bacche hans rahe hain."\n"Woh balloon nikalta hai..."',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            SizedBox(height: 12),
            if (_isGenerating) ...[
              LinearProgressIndicator(value: _progress),
              SizedBox(height: 8),
              Text('Generating... ${(_progress * 100).toStringAsFixed(0)}%'),
            ],
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.movie_creation),
                    label: Text('Generate Video'),
                    onPressed: _isGenerating
                        ? null
                        : () async {
                            FocusScope.of(context).unfocus();
                            await _generateVideoFromScript(_scriptController.text);
                          },
                    style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: Icon(Icons.refresh),
                  label: Text('Clear'),
                  onPressed: _isGenerating
                      ? null
                      : () {
                          _scriptController.clear();
                          setState(() {
                            _framePaths = [];
                            _videoPath = null;
                          });
                        },
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14)),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildFramePreview(),
            if (_videoPath != null) ...[
              SizedBox(height: 12),
              Text('Video ready: ', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text(_videoPath!, style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
              SizedBox(height: 6),
              Row(children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.open_in_new),
                  label: Text('Open'),
                  onPressed: () async {
                    final p = _videoPath!;
                    if (await File(p).exists()) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('File saved at: $p')));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('File missing.')));
                    }
                  },
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: Icon(Icons.share),
                  label: Text('Share'),
                  onPressed: null,
                ),
              ])
            ]
          ],
        ),
      ),
    );
  }
}
