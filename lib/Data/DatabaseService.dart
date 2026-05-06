import 'package:leetcards/Common/Constants.dart';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class DatabaseService
{
  static final FirebaseFirestore m_Firestore = FirebaseFirestore.instance;
  static final FirebaseAuth m_Auth = FirebaseAuth.instance;

  static const String m_FundamentalsCollectionName = 'fundamental_flashcards';
  static const String m_FundamentalsMetadataCollectionName = 'fundamental_metadata';
  static const String m_AlgorithmsCollectionName = 'algorithm_flashcards';
  static const String m_AlgorithmsMetadataCollectionName = 'algorithm_metadata';
  static const String m_MetadataCollectionName = 'metadata';
  static const String m_UsersCollectionName = 'users';

  static const String m_AlgorithmsCompletedField = 'algorithmsCompleted';
  static const String m_FundamentalsCompletedField = 'fundamentalsCompleted';

  static DocumentReference<Map<String, dynamic>> _userDoc(String userId) =>
    m_Firestore.collection(m_UsersCollectionName).doc(userId);


  static List<String>? _cachedTopics;
  static Future<List<String>> getAvailableTopics() async
  {
    if (_cachedTopics != null) return _cachedTopics!;
    try
    {
      final doc = await m_Firestore
        .collection(m_MetadataCollectionName)
        .doc('topics')
        .get();

      if (!doc.exists) return [];

      final data = doc.data() as Map<String, dynamic>;
      return _cachedTopics = List<String>.from(data['topics'] ?? []);
    }
    catch (e)
    {
      return [];
    }
  }

  static List<Map<String, dynamic>>? _cachedCollections;
  static Future<List<Map<String, dynamic>>> getAvailableCollections() async
  {
    if (_cachedCollections != null) return _cachedCollections!;
    try
    {
      final doc = await m_Firestore
        .collection(m_MetadataCollectionName)
        .doc('collections')
        .get();

      if (!doc.exists) return [];

      final data = doc.data() as Map<String, dynamic>;
      final names = List<String>.from(data['collections'] ?? []);

      // Collection name doubles as id — membership is matched against the
      // `collections` array on each card's algorithm_metadata doc. Free Preview
      // is applied automatically for free-tier users on Easy, never shown as a
      // picker chip.
      return _cachedCollections = names
        .where((name) => name != AppConstants.freePreviewCollectionId)
        .map((name) => {'id': name, 'name': name})
        .toList();
    }
    catch (e)
    {
      return [];
    }
  }

  // Real-time tier listener — kept in sync with the user doc so webhook-driven
  // updates (payments) are reflected without refetch. tierChanges broadcasts
  // only *actual* changes after the initial snapshot, so subscribers can
  // trigger a silent UI refresh without firing on the first connection.
  static StreamSubscription? _tierSub;
  static String? _tierUid;
  static UserTier _currentTier = UserTier.Free;
  static bool _tierInitialEmitted = false;
  static final StreamController<UserTier> _tierController = StreamController.broadcast();
  static Stream<UserTier> get tierChanges => _tierController.stream;

  static Future<UserTier> getUserTier() async
  {
    final user = m_Auth.currentUser;
    if (user == null)
    {
      await _cancelTierListener();
      return _currentTier = UserTier.Free;
    }
    if (_tierUid == user.uid) return _currentTier;

    await _cancelTierListener();
    _tierUid = user.uid;
    _tierInitialEmitted = false;

    final completer = Completer<UserTier>();
    _tierSub = m_Firestore
      .collection(m_UsersCollectionName)
      .doc(user.uid)
      .snapshots()
      .listen(
        (doc) {
          final tierStr = doc.data()?['tier'] as String?;
          final tier = UserTier.values.firstWhere(
            (t) => t.name == tierStr,
            orElse: () => UserTier.Free);
          final changed = tier != _currentTier;
          _currentTier = tier;
          if (!completer.isCompleted) completer.complete(tier);
          if (_tierInitialEmitted && changed) _tierController.add(tier);
          _tierInitialEmitted = true;
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete(UserTier.Free);
        });

    return completer.future;
  }

  static Future<void> _cancelTierListener() async
  {
    await _tierSub?.cancel();
    _tierSub = null;
    _tierUid = null;
  }

  // Called from AuthService.signOut so the tier listener doesn't keep running
  // against a user doc we can no longer read.
  static Future<void> onSignOut() async
  {
    await _cancelTierListener();
    _currentTier = UserTier.Free;
  }

  // Theme preference persisted on the user doc. Returns null if the uid is
  // unknown, no preference saved, or the read fails — caller decides default.
  static Future<bool?> getDarkModePreference([String? uid]) async
  {
    uid ??= m_Auth.currentUser?.uid;
    if (uid == null) return null;
    try
    {
      final doc = await _userDoc(uid).get();
      return doc.data()?['isDarkMode'] as bool?;
    }
    catch (e)
    {
      return null;
    }
  }

  static Future<void> setDarkModePreference(bool isDarkMode) async
  {
    final user = m_Auth.currentUser;
    if (user == null) return;
    await _userDoc(user.uid).set(
      {'isDarkMode': isDarkMode},
      SetOptions(merge: true));
  }

  static Future<BillingCycle> getBillingCycle() async
  {
    final user = m_Auth.currentUser;
    if (user == null) return BillingCycle.Yearly;
    try
    {
      final doc = await _userDoc(user.uid).get();
      final str = doc.data()?['billingCycle'] as String?;
      return BillingCycle.values.firstWhere(
        (c) => c.name == str,
        orElse: () => BillingCycle.Yearly);
    }
    catch (e)
    {
      return BillingCycle.Yearly;
    }
  }

  static Future<void> setUserTier(UserTier tier, {BillingCycle cycle = BillingCycle.Yearly}) async
  {
    final user = m_Auth.currentUser;
    if (user == null) return;

    final previous = _currentTier;
    final previousCycle = await getBillingCycle();
    await m_Firestore
      .collection(m_UsersCollectionName)
      .doc(user.uid)
      .set({'tier': tier.name, 'billingCycle': cycle.name}, SetOptions(merge: true));
    // Listener will fire with the new value; no manual cache update needed.

    final analytics = FirebaseAnalytics.instance;
    analytics.logEvent(
      name: 'tier_change',
      parameters: {
        'from_tier': previous.name,
        'to_tier': tier.name,
        'from_cycle': previousCycle.name,
        'to_cycle': cycle.name,
      });
    analytics.setUserProperty(name: 'user_tier', value: tier.name);
    analytics.setUserProperty(name: 'billing_cycle', value: cycle.name);
  }

  // In-memory progress for guest sessions — cleared on app restart
  static final Set<String> _guestFundamentals = {};
  static final Set<String> _guestAlgorithms = {};

  // Cached completed IDs for logged-in users. UID-keyed so sign-in/out auto-invalidates.
  static String? _progressCacheUid;
  static Set<String>? _cachedCompletedFundamentals;
  static Set<String>? _cachedCompletedAlgorithms;

  static void _validateProgressCache(String uid)
  {
    if (_progressCacheUid == uid) return;
    _progressCacheUid = uid;
    _cachedCompletedFundamentals = null;
    _cachedCompletedAlgorithms = null;
  }

  static void clearGuestProgress()
  {
    _guestFundamentals.clear();
    _guestAlgorithms.clear();
  }

  static Future<void> saveFundamentalCompletion(String fundamentalId) async
  {
    final user = m_Auth.currentUser;
    if (user == null)
    {
      _guestFundamentals.add(fundamentalId);
      _logCompletion(type: 'fundamental', cardId: fundamentalId, isGuest: true);
      return;
    }
    await _userDoc(user.uid).set(
      {m_FundamentalsCompletedField: FieldValue.arrayUnion([fundamentalId])},
      SetOptions(merge: true));
    _validateProgressCache(user.uid);
    _cachedCompletedFundamentals?.add(fundamentalId);
    _logCompletion(type: 'fundamental', cardId: fundamentalId, isGuest: false);
  }

  static Future<void> saveAlgorithmCompletion(String algorithmId) async
  {
    final user = m_Auth.currentUser;
    if (user == null)
    {
      _guestAlgorithms.add(algorithmId);
      _logCompletion(type: 'algorithm', cardId: algorithmId, isGuest: true);
      return;
    }
    await _userDoc(user.uid).set(
      {m_AlgorithmsCompletedField: FieldValue.arrayUnion([algorithmId])},
      SetOptions(merge: true));
    _validateProgressCache(user.uid);
    _cachedCompletedAlgorithms?.add(algorithmId);
    _logCompletion(type: 'algorithm', cardId: algorithmId, isGuest: false);
  }

  static void _logCompletion({
    required String type,
    required String cardId,
    required bool isGuest,
  })
  {
    FirebaseAnalytics.instance.logEvent(
      name: 'flashcard_completed',
      parameters: {
        'card_type': type,
        'card_id': cardId,
        'is_guest': isGuest ? 1 : 0,
      });
  }

  // Both completed-ID sets now live as arrays on the user doc. One read fills
  // both caches.
  static Future<void> _ensureProgressCache(String uid) async
  {
    _validateProgressCache(uid);
    if (_cachedCompletedAlgorithms != null && _cachedCompletedFundamentals != null) return;
    try
    {
      final doc = await _userDoc(uid).get();
      final data = doc.data() ?? const <String, dynamic>{};
      _cachedCompletedAlgorithms = Set<String>.from(data[m_AlgorithmsCompletedField] ?? const []);
      _cachedCompletedFundamentals = Set<String>.from(data[m_FundamentalsCompletedField] ?? const []);
    }
    catch (e)
    {
      _cachedCompletedAlgorithms ??= {};
      _cachedCompletedFundamentals ??= {};
    }
  }

  static Future<Set<String>> getCompletedFundamentalIds() async
  {
    final user = m_Auth.currentUser;
    if (user == null) return _guestFundamentals;
    await _ensureProgressCache(user.uid);
    return _cachedCompletedFundamentals ?? {};
  }

  static Future<Set<String>> getCompletedAlgorithmIds() async
  {
    final user = m_Auth.currentUser;
    if (user == null) return _guestAlgorithms;
    await _ensureProgressCache(user.uid);
    return _cachedCompletedAlgorithms ?? {};
  }

  static Map<Difficulty, int> _emptyDifficultyIntMap() =>
    {Difficulty.Easy: 0, Difficulty.Medium: 0, Difficulty.Hard: 0};

  static Map<Difficulty, double?> _emptyDifficultyDoubleMap() =>
    {Difficulty.Easy: null, Difficulty.Medium: null, Difficulty.Hard: null};

  // Lightweight per-card index (id + topics + difficulty + collections) sourced
  // from the metadata collection — card metadata is immutable during a session,
  // so after first fetch any topic/collection filter is served entirely
  // client-side. Only assigned on success so a failed fetch doesn't poison the
  // cache. `collections` is empty for card types that don't belong to any
  // curated set (fundamentals).
  static final Map<String, List<({String id, List<String> topics, int difficulty, List<String> collections})>> _cachedContentIndex = {};

  static Future<List<({String id, List<String> topics, int difficulty, List<String> collections})>>
    _getContentIndex(String metadataCollection) async
  {
    final cached = _cachedContentIndex[metadataCollection];
    if (cached != null) return cached;
    final snapshot = await m_Firestore.collection(metadataCollection).get();
    final index = snapshot.docs.map((doc)
    {
      final data = doc.data();
      final topics = (data['topics'] as List?)?.cast<String>() ?? const <String>[];
      final collections = (data['collections'] as List?)?.cast<String>() ?? const <String>[];
      return (
        id: doc.id,
        topics: topics,
        difficulty: data['difficulty'] as int,
        collections: collections);
    }).toList(growable: false);
    return _cachedContentIndex[metadataCollection] = index;
  }

  // Computes completion percentages from the cached content index. First call
  // warms the metadata index; subsequent calls are pure client-side regardless
  // of topic/collection filter.
  static Future<Map<Difficulty, double?>> _computePercentages({
    required String metadataCollection,
    required Future<Set<String>> Function() getCompletedIds,
    String? topic,
    String? collectionId,
  }) async
  {
    try
    {
      Future<T> timed<T>(String label, Future<T> f) async
      {
        final sw = Stopwatch()..start();
        final r = await f;
        debugPrint('[perf] $metadataCollection $label: ${sw.elapsedMilliseconds}ms');
        return r;
      }

      final results = await (
        timed('content-index', _getContentIndex(metadataCollection)),
        timed('completed-ids', getCompletedIds()),
      ).wait;
      final index = results.$1;
      final completedSet = results.$2;

      final swLoop = Stopwatch()..start();
      final totals = _emptyDifficultyIntMap();
      final counts = _emptyDifficultyIntMap();

      for (final card in index)
      {
        if (topic != null && !card.topics.contains(topic)) continue;
        if (collectionId != null && !card.collections.contains(collectionId)) continue;
        final difficulty = Difficulty.values[card.difficulty];
        totals[difficulty] = (totals[difficulty] ?? 0) + 1;
        if (completedSet.contains(card.id))
        {
          counts[difficulty] = (counts[difficulty] ?? 0) + 1;
        }
      }

      final percentages = <Difficulty, double?>{};
      for (final difficulty in Difficulty.values)
      {
        final int total = totals[difficulty] ?? 0;
        final int completed = counts[difficulty] ?? 0;
        percentages[difficulty] = total > 0 ? (completed / total) * 100 : null;
      }
      debugPrint('[perf] $metadataCollection post-processing: ${swLoop.elapsedMilliseconds}ms (${index.length} docs)');
      return percentages;
    }
    catch (e)
    {
      return _emptyDifficultyDoubleMap();
    }
  }

  // Eligible (un-completed) card IDs plus session totals. Pure client-side
  // against the cached content index + completed-IDs cache — zero Firestore
  // calls when the home screen has been visited this session.
  static Future<({List<String> available, int total, int completed})>
    getEligibleFundamentals({required int difficulty, String? topic}) async
  {
    try
    {
      final results = await (
        _getContentIndex(m_FundamentalsMetadataCollectionName),
        getCompletedFundamentalIds(),
      ).wait;
      return _computeEligibleIds(
        index: results.$1,
        completedSet: results.$2,
        difficulty: difficulty,
        topic: topic);
    }
    catch (e)
    {
      return (available: <String>[], total: 0, completed: 0);
    }
  }

  static Future<({List<String> available, int total, int completed})>
    getEligibleAlgorithms({required int difficulty, String? topic, String? collectionId}) async
  {
    try
    {
      final results = await (
        _getContentIndex(m_AlgorithmsMetadataCollectionName),
        getCompletedAlgorithmIds(),
      ).wait;
      return _computeEligibleIds(
        index: results.$1,
        completedSet: results.$2,
        difficulty: difficulty,
        topic: topic,
        collectionId: collectionId);
    }
    catch (e)
    {
      return (available: <String>[], total: 0, completed: 0);
    }
  }

  static ({List<String> available, int total, int completed}) _computeEligibleIds({
    required List<({String id, List<String> topics, int difficulty, List<String> collections})> index,
    required Set<String> completedSet,
    required int difficulty,
    String? topic,
    String? collectionId,
  })
  {
    final available = <String>[];
    int total = 0, completed = 0;
    for (final c in index)
    {
      if (c.difficulty != difficulty) continue;
      if (topic != null && !c.topics.contains(topic)) continue;
      if (collectionId != null && !c.collections.contains(collectionId)) continue;
      total++;
      if (completedSet.contains(c.id))
        completed++;
      else
        available.add(c.id);
    }
    return (available: available, total: total, completed: completed);
  }

  // In-flight dedupe so concurrent prefetches and on-demand fetches for the
  // same id collapse into a single Firestore call. Game screens own their own
  // short-lived parsed-card cache; the DB layer no longer holds bodies across
  // screens, which keeps memory bounded as the card count grows.
  static final Map<String, Map<String, Future<Map<String, dynamic>>>> _inFlightBodyFetches = {};

  static Future<Map<String, dynamic>> _getCardBody(String collection, String id)
  {
    final fetches = _inFlightBodyFetches[collection] ??= {};
    final inFlight = fetches[id];
    if (inFlight != null) return inFlight;

    final sw = Stopwatch()..start();
    final future = () async
    {
      try
      {
        final doc = await m_Firestore.collection(collection).doc(id).get();
        if (!doc.exists) throw StateError('card not found: $id');
        debugPrint('[perf] $collection body $id: ${sw.elapsedMilliseconds}ms');
        return {...doc.data() as Map<String, dynamic>, 'id': doc.id};
      }
      finally
      {
        fetches.remove(id);
      }
    }();
    fetches[id] = future;
    return future;
  }

  static Future<Map<String, dynamic>> getFundamentalById(String id) =>
    _getCardBody(m_FundamentalsCollectionName, id);

  static Future<Map<String, dynamic>> getAlgorithmById(String id) =>
    _getCardBody(m_AlgorithmsCollectionName, id);

  static Future<Map<Difficulty, double?>> getFundamentalCompletionPercentagesByDifficulty({String? topic}) =>
    _computePercentages(
      metadataCollection: m_FundamentalsMetadataCollectionName,
      getCompletedIds: getCompletedFundamentalIds,
      topic: topic);

  static Future<Map<Difficulty, double?>> getAlgorithmCompletionPercentagesByDifficulty({String? topic, String? collectionId}) =>
    _computePercentages(
      metadataCollection: m_AlgorithmsMetadataCollectionName,
      getCompletedIds: getCompletedAlgorithmIds,
      topic: topic,
      collectionId: collectionId);

  // Deletes the user's progress doc. Must run while still authenticated —
  // security rules require request.auth.uid == userId, so calling this AFTER
  // FirebaseAuth.currentUser.delete() will fail.
  static Future<void> deleteAccount() async
  {
    final user = m_Auth.currentUser;
    if (user == null) return;
    await _userDoc(user.uid).delete();
    await _cancelTierListener();
    _currentTier = UserTier.Free;
    _progressCacheUid = null;
    _cachedCompletedAlgorithms = null;
    _cachedCompletedFundamentals = null;
  }

  static Future<void> resetProgress({
    required CardType type,
    required int difficulty,
    String? topic,
    String? collectionId,
  }) async
  {
    final metadataCollection = type == CardType.fundamental
      ? m_FundamentalsMetadataCollectionName
      : m_AlgorithmsMetadataCollectionName;
    final completedField = type == CardType.fundamental
      ? m_FundamentalsCompletedField
      : m_AlgorithmsCompletedField;
    final guestSet = type == CardType.fundamental ? _guestFundamentals : _guestAlgorithms;

    // Reuse the cached metadata index rather than stacking array-contains
    // filters — Firestore rejects more than one per query, and the index is
    // usually already warm from the home screen.
    final index = await _getContentIndex(metadataCollection);
    final ids = <String>[];
    for (final c in index)
    {
      if (c.difficulty != difficulty) continue;
      if (topic != null && !c.topics.contains(topic)) continue;
      if (collectionId != null && !c.collections.contains(collectionId)) continue;
      ids.add(c.id);
    }
    if (ids.isEmpty) return;

    final user = m_Auth.currentUser;
    if (user == null) { guestSet.removeAll(ids); return; }

    await _userDoc(user.uid).set(
      {completedField: FieldValue.arrayRemove(ids)},
      SetOptions(merge: true));

    _validateProgressCache(user.uid);
    final cached = type == CardType.fundamental ? _cachedCompletedFundamentals : _cachedCompletedAlgorithms;
    cached?.removeAll(ids);
  }
}
