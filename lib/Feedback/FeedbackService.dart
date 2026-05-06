import 'package:leetcards/Common/Constants.dart';
import 'package:leetcards/Data/DatabaseService.dart';

import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';

class FeedbackService
{
  static const String m_FeedbackCollectionName = 'feedback';
  static const String m_FlashcardFeedbackCollectionName = 'flashcard_feedback';
  static const int m_MaxMessageLength = 5000;

  // Throws on failure so callers can surface an error to the user.
  static Future<void> submit(String message) async
  {
    final payload = await _buildPayload(message);
    await FirebaseFirestore.instance
      .collection(m_FeedbackCollectionName)
      .add(payload);
  }

  static Future<void> submitForCard(String message, String cardId, CardType cardType) async
  {
    final payload = await _buildPayload(message);
    payload['cardId'] = cardId;
    payload['cardType'] = cardType.name;
    await FirebaseFirestore.instance
      .collection(m_FlashcardFeedbackCollectionName)
      .add(payload);
  }

  static Future<Map<String, dynamic>> _buildPayload(String message) async
  {
    final trimmed = message.trim();
    if (trimmed.isEmpty) throw ArgumentError('message is empty');
    if (trimmed.length > m_MaxMessageLength)
    {
      throw ArgumentError('message exceeds $m_MaxMessageLength characters');
    }

    final user = FirebaseAuth.instance.currentUser;
    final pkg = await PackageInfo.fromPlatform();
    final tier = user != null
      ? (await DatabaseService.getUserTier()).name
      : null;

    return <String, dynamic>{
      'message': trimmed,
      'uid': user?.uid,
      'isGuest': user == null,
      'appVersion': '${pkg.version}+${pkg.buildNumber}',
      'platform': _platformName(),
      'osVersion': _osVersion(),
      'locale': PlatformDispatcher.instance.locale.toLanguageTag(),
      'tier': tier,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static String _platformName()
  {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  // Platform.operatingSystemVersion isn't available on web.
  static String _osVersion() => kIsWeb ? '' : Platform.operatingSystemVersion;
}
