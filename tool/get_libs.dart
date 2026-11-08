// Downloads the map library (Leaflet) and the fonts into assets/www/vendor,
// so the app works with NO internet on the phone.
// Run once (with internet), from the project folder:   dart run tool/get_libs.dart
import 'dart:io';

const leaflet = 'https://unpkg.com/leaflet@1.9.4/dist';
const leafletFiles = [
  'leaflet.js', 'leaflet.css',
  'images/layers.png', 'images/layers-2x.png',
  'images/marker-icon.png', 'images/marker-icon-2x.png', 'images/marker-shadow.png',
];
const fonts = {
  'barlow': ['Barlow', [400, 500, 600, 700]],
  'barlow-condensed': ['Barlow Condensed', [500, 600, 700]],
};

Future<void> fetch(HttpClient http, String url, String path) async {
  final req = await http.getUrl(Uri.parse(url));
  final res = await req.close();
  if (res.statusCode != 200) throw 'Download failed ($url): HTTP ${res.statusCode}';
  final file = File(path);
  await file.parent.create(recursive: true);
  await res.pipe(file.openWrite());
  stdout.writeln('  ✓ $path');
}

Future<void> main() async {
  final http = HttpClient();
  const out = 'assets/www/vendor';
  stdout.writeln('Map library (Leaflet 1.9.4):');
  for (final f in leafletFiles) {
    await fetch(http, '$leaflet/$f', '$out/leaflet/$f');
  }
  stdout.writeln('Fonts (Barlow):');
  final css = StringBuffer('/* Fonts bundled inside the app (works offline). */\n');
  for (final e in fonts.entries) {
    final family = e.value[0] as String;
    for (final w in e.value[1] as List<int>) {
      final name = '${e.key}-latin-$w-normal.woff2';
      await fetch(http, 'https://cdn.jsdelivr.net/npm/@fontsource/${e.key}@5/files/$name', '$out/fonts/$name');
      css.writeln("@font-face{font-family:'$family';font-style:normal;font-weight:$w;font-display:swap;src:url(fonts/$name) format('woff2');}");
    }
  }
  await File('$out/fonts.css').writeAsString(css.toString());
  http.close();
  stdout.writeln('\nDone. Libraries are now inside the app.');
}
