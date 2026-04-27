import "package:leetcards/Data/DatabaseService.dart";
import "package:leetcards/Data/PlatformSupport.dart";

import "dart:convert";
import "dart:math";

import "package:firebase_analytics/firebase_analytics.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:google_sign_in/google_sign_in.dart";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:sign_in_with_apple/sign_in_with_apple.dart";
import "package:crypto/crypto.dart";

// Discriminated result for sign-in attempts so the UI can render each case
// without inspecting raw exceptions.
sealed class SignInResult
{
  const SignInResult();
}

class SignInSuccess extends SignInResult
{
  final UserCredential credential;
  const SignInSuccess(this.credential);
}

class SignInCancelled extends SignInResult
{
  const SignInCancelled();
}

class SignInConflict extends SignInResult
{
  final String email;
  final String attemptedProviderId;
  const SignInConflict({required this.email, required this.attemptedProviderId});
}

class SignInError extends SignInResult
{
  final Object error;
  const SignInError(this.error);
}

class AuthService
{
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Holds the credential from a sign-in that was rejected because the email is
  // already registered with a different provider. If the user successfully
  // signs in with the original provider during the same app session and the
  // email matches, we link this credential transparently.
  static AuthCredential? _pendingCredential;
  static String? _pendingEmail;

  static bool get hasPendingCredential => _pendingCredential != null;
  static String? get pendingEmail => _pendingEmail;

  Future<SignInResult> signInWithGoogle() => _signIn('google.com');
  Future<SignInResult> signInWithGitHub() => _signIn('github.com');
  Future<SignInResult> signInWithApple()  => _signIn('apple.com');

  Future<void> signOut() async
  {
    await DatabaseService.onSignOut();
    await _auth.signOut();
    if (crashlyticsSupported)
    {
      await FirebaseCrashlytics.instance.setUserIdentifier('');
    }
    if (!kIsWeb) await GoogleSignIn().signOut();
  }

  // Order matters: delete the Firestore doc first (security rules require auth),
  // then delete the auth account. If auth.delete() throws requires-recent-login,
  // re-authenticate via the original provider and retry.
  Future<void> deleteAccount() async
  {
    final user = _auth.currentUser;
    if (user == null) return;

    await DatabaseService.deleteAccount();

    try
    {
      await user.delete();
    }
    on FirebaseAuthException catch (e)
    {
      if (e.code != 'requires-recent-login') rethrow;
      final reauthed = await _reauthenticate(user);
      if (!reauthed) rethrow;
      await user.delete();
    }

    if (!kIsWeb) await GoogleSignIn().signOut();
  }

  Future<bool> _reauthenticate(User user) async
  {
    final providerId = user.providerData.isNotEmpty
      ? user.providerData.first.providerId
      : '';

    switch (providerId)
    {
      case 'google.com':
        if (kIsWeb)
        {
          final cred = await user.reauthenticateWithPopup(GoogleAuthProvider());
          return cred.user != null;
        }
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return false;
        final googleAuth = await googleUser.authentication;
        await user.reauthenticateWithCredential(
          GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken));
        return true;
      case 'github.com':
        final provider = GithubAuthProvider();
        if (kIsWeb)
        {
          await user.reauthenticateWithPopup(provider);
        }
        else
        {
          await user.reauthenticateWithProvider(provider);
        }
        return true;
      case 'apple.com':
        if (kIsWeb)
        {
          final provider = AppleAuthProvider()
            ..addScope('email')
            ..addScope('name');
          await user.reauthenticateWithPopup(provider);
          return true;
        }
        final cred = await _getAppleCredentialNative();
        if (cred == null) return false;
        await user.reauthenticateWithCredential(cred);
        return true;
      default:
        return false;
    }
  }

  Future<SignInResult> _signIn(String providerId) async
  {
    try
    {
      final userCred = await _providerSignIn(providerId);
      if (userCred == null) return const SignInCancelled();

      DatabaseService.clearGuestProgress();

      await _tryLinkPending(userCred.user);
      _clearPending();

      final uid = userCred.user?.uid;
      if (uid != null && crashlyticsSupported)
      {
        await FirebaseCrashlytics.instance.setUserIdentifier(uid);
      }

      // First-time vs returning auth — both share the provider id as method.
      final isNew = userCred.additionalUserInfo?.isNewUser ?? false;
      final analytics = FirebaseAnalytics.instance;
      if (isNew)
      {
        await analytics.logSignUp(signUpMethod: providerId);
      }
      else
      {
        await analytics.logLogin(loginMethod: providerId);
      }

      return SignInSuccess(userCred);
    }
    on FirebaseAuthException catch (e, stack)
    {
      if (e.code == 'account-exists-with-different-credential')
      {
        final email = e.email ?? '';
        if (e.credential != null && email.isNotEmpty)
        {
          _pendingCredential = e.credential;
          _pendingEmail = email;
        }
        return SignInConflict(email: email, attemptedProviderId: providerId);
      }
      if (crashlyticsSupported)
      {
        await FirebaseCrashlytics.instance.recordError(
          e, stack,
          reason: 'sign-in failed',
          information: ['provider: $providerId', 'code: ${e.code}'],
          fatal: false);
      }
      return SignInError(e);
    }
    catch (e, stack)
    {
      if (crashlyticsSupported)
      {
        await FirebaseCrashlytics.instance.recordError(
          e, stack,
          reason: 'sign-in failed',
          information: ['provider: $providerId'],
          fatal: false);
      }
      return SignInError(e);
    }
  }

  // If a previous attempt left a pending credential and the user we just signed
  // in as has the same email, attach it so both providers work going forward.
  // Failures are swallowed — silent best-effort.
  Future<void> _tryLinkPending(User? user) async
  {
    if (user == null) return;
    final pending = _pendingCredential;
    final pendingEmail = _pendingEmail;
    if (pending == null || pendingEmail == null) return;
    if (user.email != pendingEmail) return;

    try
    {
      await user.linkWithCredential(pending);
    }
    catch (e, stack)
    {
      if (crashlyticsSupported)
      {
        await FirebaseCrashlytics.instance.recordError(
          e, stack,
          reason: 'pending credential link failed',
          fatal: false);
      }
    }
  }

  void _clearPending()
  {
    _pendingCredential = null;
    _pendingEmail = null;
  }

  Future<UserCredential?> _providerSignIn(String providerId) async
  {
    switch (providerId)
    {
      case 'google.com':
        if (kIsWeb) return _auth.signInWithPopup(GoogleAuthProvider());
        final GoogleSignInAccount? user = await GoogleSignIn().signIn();
        if (user == null) return null;
        final GoogleSignInAuthentication auth = await user.authentication;
        return _auth.signInWithCredential(GoogleAuthProvider.credential(
          accessToken: auth.accessToken,
          idToken: auth.idToken));
      case 'github.com':
        final GithubAuthProvider provider = GithubAuthProvider();
        provider.addScope('user:email');
        return kIsWeb
          ? _auth.signInWithPopup(provider)
          : _auth.signInWithProvider(provider);
      case 'apple.com':
        if (kIsWeb)
        {
          final provider = AppleAuthProvider()
            ..addScope('email')
            ..addScope('name');
          return _auth.signInWithPopup(provider);
        }
        final cred = await _getAppleCredentialNative();
        if (cred == null) return null;
        return _auth.signInWithCredential(cred);
      default:
        return null;
    }
  }

  // Apple requires a SHA256-hashed nonce in the ID token request and the raw
  // nonce when constructing the Firebase credential — Firebase verifies the
  // hash matches to prevent replay attacks.
  Future<OAuthCredential?> _getAppleCredentialNative() async
  {
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final AuthorizationCredentialAppleID apple;
    try
    {
      apple = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce);
    }
    on SignInWithAppleAuthorizationException catch (e)
    {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }

    final idToken = apple.identityToken;
    if (idToken == null) return null;

    return OAuthProvider('apple.com').credential(
      idToken: idToken,
      rawNonce: rawNonce);
  }

  String _generateNonce([int length = 32])
  {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
