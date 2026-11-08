// Prepares the Android part after "flutter create": app name, GPS and internet permissions.
// Run from the project folder:   dart run tool/setup_android.dart
import 'dart:io';

void main() {
  final f = File('android/app/src/main/AndroidManifest.xml');
  if (!f.existsSync()) {
    stderr.writeln('android/ folder not found. First run:  flutter create --platforms=android --org rw.gridnav .');
    exit(1);
  }
  var m = f.readAsStringSync();

  // App name shown under the icon
  m = m.replaceFirst(RegExp(r'android:label="[^"]*"'), 'android:label="GridNav"');

  // Permissions: internet (background map tiles), GPS
  const perms = ['INTERNET', 'ACCESS_COARSE_LOCATION', 'ACCESS_FINE_LOCATION'];
  for (final p in perms) {
    if (!m.contains('android.permission.$p')) {
      m = m.replaceFirst('<application', '<uses-permission android:name="android.permission.$p" />\n    <application');
    }
  }
  if (!m.contains('android.hardware.location.gps')) {
    m = m.replaceFirst('<application', '<uses-feature android:name="android.hardware.location.gps" android:required="false" />\n    <application');
  }

  // Allow opening web links (Google Maps) in other apps (Android 11+)
  if (!m.contains('android.intent.action.VIEW') || !m.contains('android:scheme="https"')) {
    const q = '''
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>''';
    if (m.contains('<queries>')) {
      m = m.replaceFirst('<queries>', '<queries>$q');
    } else {
      m = m.replaceFirst('</manifest>', '    <queries>$q\n    </queries>\n</manifest>');
    }
  }
  f.writeAsStringSync(m);
  stdout.writeln('✓ AndroidManifest.xml ready (name GridNav, internet + GPS permissions).');
}
