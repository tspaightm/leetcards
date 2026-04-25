import "package:leetcards/Data/RemoteConfigService.dart";
import "package:leetcards/LeetCardsApp.dart";
import "package:leetcards/Login/FirebaseOptions.dart";

import "package:firebase_core/firebase_core.dart";
import "package:flutter/material.dart";

Future<void> main() async
{
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform);

  await RemoteConfigService.initialize();

  runApp(const LeetCardsApp());
}
