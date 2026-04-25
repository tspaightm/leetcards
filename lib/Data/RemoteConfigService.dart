import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService
{
  static const String m_PlusPriceKey = 'PlusTierPricePerMonth';
  static const String m_ProPriceKey  = 'ProTierPricePerMonth';

  static final FirebaseRemoteConfig _rc = FirebaseRemoteConfig.instance;

  // Defaults match the current hardcoded prices so the first launch (before
  // fetchAndActivate lands) shows the right number without a network round-trip.
  static Future<void> initialize() async
  {
    // ensureInitialized must run before any other method — without it, the web
    // delegate's lazy setInitialValues trips a null→int cast on a fresh session.
    await _rc.ensureInitialized();

    await _rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1)));

    await _rc.setDefaults(<String, Object>{
      m_PlusPriceKey: 5,
      m_ProPriceKey:  10});

    // Fire-and-forget — fresh values apply on the next read after this resolves.
    _rc.fetchAndActivate();
  }

  static int get plusPricePerMonth => _rc.getInt(m_PlusPriceKey);
  static int get proPricePerMonth  => _rc.getInt(m_ProPriceKey);
}
