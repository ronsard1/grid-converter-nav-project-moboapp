// GridNav — Flutter app.
//
// How it is built (in simple words):
//  • The GridNav screens (HTML/CSS/JavaScript in assets/www) are shown inside a WebView.
//    They contain all the maths: grid ↔ lat/lon conversion, route planning, printed papers.
//  • Flutter adds the phone's own features. The screens ask for them through a
//    "channel" called GridNavNative (see assets/www/js/native.js):
//      print   → Android print screen (choose a printer or "Save as PDF")
//      share   → share a file (WhatsApp, email, Drive…)
//      save    → choose a folder and save a file (backups)
//      pick    → choose a backup file to restore
//      gps     → current position from the phone's GPS
//      copy    → copy text to the clipboard
//      open    → open a link in another app (Google Maps)
//  • All data is saved inside the app on the phone. No account, no internet needed.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

const paper = Color(0xFFE8E5D6); // khaki map-paper background
const gridBlue = Color(0xFF4B5320); // olive drab
const ink = Color(0xFF1B1F16);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: paper,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: ink,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const GridNavApp());
}

class GridNavApp extends StatelessWidget {
  const GridNavApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GridNav',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: gridBlue, useMaterial3: true, scaffoldBackgroundColor: paper),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final WebViewController _web;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(paper)
      ..addJavaScriptChannel('GridNavNative', onMessageReceived: (m) => _onMessage(m.message))
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onNavigationRequest: (req) {
          // Links to websites (e.g. Google Maps) open in the phone's browser/apps, not inside GridNav.
          final u = req.url;
          if (u.startsWith('http://') || u.startsWith('https://')) {
            launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadFlutterAsset('assets/www/index.html');
  }

  // ---------------------------------------------------------------- bridge
  Future<void> _onMessage(String raw) async {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final id = msg['id'];
    final cmd = (msg['cmd'] ?? '') as String;
    final a = (msg['args'] is Map) ? Map<String, dynamic>.from(msg['args'] as Map) : <String, dynamic>{};
    Object? result;
    String? error;
    try {
      switch (cmd) {
        case 'print':
          result = await _print(a);
        case 'share':
          result = await _share(a);
        case 'save':
          result = await _save(a);
        case 'pick':
          result = await _pick();
        case 'gps':
          result = await _gps();
        case 'copy':
          await Clipboard.setData(ClipboardData(text: (a['text'] ?? '').toString()));
          result = true;
        case 'open':
          result = await launchUrl(Uri.parse((a['url'] ?? '').toString()), mode: LaunchMode.externalApplication);
        default:
          error = 'Unknown command: $cmd';
      }
    } catch (e) {
      error = e is String ? e : e.toString().replaceFirst('Exception: ', '');
    }
    await _web.runJavaScript('window.__gnReply(${jsonEncode(id)}, ${jsonEncode(result)}, ${jsonEncode(error)});');
  }

  String _safeName(Object? n, String fallback) {
    final s = (n ?? fallback).toString().replaceAll(RegExp(r'[^\w.\- ]+'), '_');
    return s.isEmpty ? fallback : s;
  }

  /// Opens Android's print screen with the page rendered as A4 (printer or "Save as PDF").
  Future<bool> _print(Map<String, dynamic> a) async {
    final html = (a['html'] ?? '').toString();
    final name = _safeName(a['name'], 'GridNav');
    final landscape = a['landscape'] == true;
    final format = landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;
    return Printing.layoutPdf(
      name: name,
      format: format,
      dynamicLayout: false,
      onLayout: (PdfPageFormat f) => Printing.convertHtml(format: format, html: html),
    );
  }

  /// Writes the text to a temporary file and opens the Android share sheet.
  Future<String> _share(Map<String, dynamic> a) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_safeName(a['filename'], 'GridNav.json')}');
    await file.writeAsString((a['text'] ?? '').toString());
    final r = await Share.shareXFiles(
      [XFile(file.path, mimeType: (a['mime'] ?? 'application/json').toString())],
      subject: (a['title'] ?? 'GridNav').toString(),
    );
    return r.status == ShareResultStatus.dismissed ? 'cancelled' : 'shared';
  }

  /// Lets the user choose a folder/name, then saves the file there.
  Future<String> _save(Map<String, dynamic> a) async {
    final bytes = Uint8List.fromList(utf8.encode((a['text'] ?? '').toString()));
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save GridNav backup',
      fileName: _safeName(a['filename'], 'GridNav-backup.json'),
      bytes: bytes,
    );
    if (path == null) return 'cancelled';
    try {
      // Some Android versions return a real path without writing: make sure the file is there.
      final f = File(path);
      if (!await f.exists() || await f.length() == 0) await f.writeAsBytes(bytes);
    } catch (_) {/* content:// locations are written by the picker itself */}
    return path;
  }

  /// Lets the user choose a backup file; returns its text.
  Future<Map<String, dynamic>?> _pick() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    if (r == null || r.files.isEmpty) return null;
    final f = r.files.first;
    final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
    if (bytes == null) throw 'Could not read that file.';
    return {'name': f.name, 'text': utf8.decode(bytes, allowMalformed: true)};
  }

  /// Current GPS position (works without internet).
  Future<Map<String, dynamic>> _gps() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'Location is turned off. Turn on Location (GPS) in the phone settings.';
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw 'Location permission was refused. Allow it in Settings → Apps → GridNav → Permissions.';
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 40)),
    );
    return {'lat': pos.latitude, 'lon': pos.longitude, 'acc': pos.accuracy};
  }

  // ---------------------------------------------------------------- back button
  Future<void> _onBack() async {
    // Let the GridNav screens handle Back first (close a dialog, leave the map, go back a screen).
    try {
      final r = await _web.runJavaScriptReturningResult('window.__gnBack ? window.__gnBack() : false');
      if (r == true || r.toString() == 'true') return;
    } catch (_) {}
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: paper,
        body: SafeArea(
          child: Stack(children: [
            WebViewWidget(controller: _web),
            if (!_loaded)
              const ColoredBox(
                color: paper,
                child: Center(child: CircularProgressIndicator(color: gridBlue)),
              ),
          ]),
        ),
      ),
    );
  }
}
