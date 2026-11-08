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
  fixCompileSdk();
}

// Some plugins (e.g. file_picker) are compiled for an older Android version than their
// helper libraries need, and the build stops with "requires ... compile against version 36".
// This makes every library compile against Android 36. It only changes how the app is
// built, not which phones can install it.
const sdk = 36;
void fixCompileSdk() {
  const mark = '// GridNav: compile all plugins against one Android version';
  final kts = File('android/build.gradle.kts');
  final groovy = File('android/build.gradle');
  if (kts.existsSync()) {
    final s = kts.readAsStringSync();
    if (s.contains(mark)) return;
    kts.writeAsStringSync('''$mark
subprojects {
    val fix: (Project) -> Unit = { p ->
        p.extensions.findByName("android")?.let { ext ->
            ext.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType).invoke(ext, $sdk)
        }
    }
    if (state.executed) fix(this) else afterEvaluate { fix(this) }
}

$s''');
  } else if (groovy.existsSync()) {
    final s = groovy.readAsStringSync();
    if (s.contains(mark)) return;
    groovy.writeAsStringSync('''$mark
subprojects { p ->
    def fix = { q -> if (q.hasProperty('android')) q.android.compileSdkVersion $sdk }
    if (p.state.executed) fix(p) else p.afterEvaluate { fix(p) }
}

$s''');
  } else {
    stderr.writeln('! android/build.gradle not found; skipped the compileSdk fix.');
    return;
  }
  stdout.writeln('✓ All plugins compile against Android $sdk.');
}
