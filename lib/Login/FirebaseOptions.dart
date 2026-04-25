import "package:firebase_core/firebase_core.dart" show FirebaseOptions;
import "package:flutter/foundation.dart" show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions
{
  static FirebaseOptions get currentPlatform
  {
    if (kIsWeb)
    {
      return web;
    }

    switch (defaultTargetPlatform)
    {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          "DefaultFirebaseOptions have not been configured for linux - you can reconfigure this by running the FlutterFire CLI again.");
      default:
        throw UnsupportedError(
          "DefaultFirebaseOptions are not supported for this platform.");
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyBALuZ6S1Q8f0PDYgfo06u2sv9okMMm5j0",
    appId: "1:681586210729:web:20e27b96929301503076b8",
    messagingSenderId: "681586210729",
    projectId: "leetcards-5a25d",
    authDomain: "leetcards-5a25d.firebaseapp.com",
    storageBucket: "leetcards-5a25d.firebasestorage.app",
    measurementId: "G-40DPRTCGCX");

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyBrIkl-oQyMJtZLPnkCsfxNmLXf4VPEiV8",
    appId: "1:681586210729:android:b0c18d34969fabb03076b8",
    messagingSenderId: "681586210729",
    projectId: "leetcards-5a25d",
    storageBucket: "leetcards-5a25d.firebasestorage.app");

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "AIzaSyASCxsGzBLmhaomuYbbp551zCg8RMolD5k",
    appId: "1:681586210729:ios:0201313ce69883fa3076b8",
    messagingSenderId: "681586210729",
    projectId: "leetcards-5a25d",
    storageBucket: "leetcards-5a25d.firebasestorage.app",
    iosClientId: "681586210729-5ati1ts4o68vi8l8ogk64lqivrrsfiin.apps.googleusercontent.com",
    iosBundleId: "com.example.leetcards");

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: "AIzaSyASCxsGzBLmhaomuYbbp551zCg8RMolD5k",
    appId: "1:681586210729:ios:0201313ce69883fa3076b8",
    messagingSenderId: "681586210729",
    projectId: "leetcards-5a25d",
    storageBucket: "leetcards-5a25d.firebasestorage.app",
    iosClientId: "681586210729-5ati1ts4o68vi8l8ogk64lqivrrsfiin.apps.googleusercontent.com",
    iosBundleId: "com.example.leetcards");

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: "AIzaSyBALuZ6S1Q8f0PDYgfo06u2sv9okMMm5j0",
    appId: "1:681586210729:web:2b150b9f782db8e43076b8",
    messagingSenderId: "681586210729",
    projectId: "leetcards-5a25d",
    authDomain: "leetcards-5a25d.firebaseapp.com",
    storageBucket: "leetcards-5a25d.firebasestorage.app",
    measurementId: "G-3V13TCN53X");
}
