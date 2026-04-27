import "package:leetcards/Data/PlatformSupport.dart";
import "package:leetcards/Data/RemoteConfigService.dart";
import "package:leetcards/LeetCardsApp.dart";
import "package:leetcards/firebase_options.dart";

import "dart:ui";

import "package:firebase_core/firebase_core.dart";
import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:flutter/material.dart";

Future<void> main() async
{
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform);

  if (crashlyticsSupported)
  {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack)
    {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  await RemoteConfigService.initialize();

  runApp(const LeetCardsApp());
}
