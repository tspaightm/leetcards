import "dart:io" show Platform;

import "package:flutter/foundation.dart" show kIsWeb;

// firebase_crashlytics only ships native plugins for Android, iOS, and macOS.
// Calling its API on web/Windows/Linux throws an assertion at startup.
bool get crashlyticsSupported =>
  !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);
