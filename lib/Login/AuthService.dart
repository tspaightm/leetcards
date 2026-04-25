import "package:leetcards/Data/DatabaseService.dart";

import "package:firebase_auth/firebase_auth.dart";
import "package:google_sign_in/google_sign_in.dart";
import "package:flutter/foundation.dart" show kIsWeb;

class AuthService
{
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserCredential?> signInWithGoogle() => _signIn('google.com');
  Future<UserCredential?> signInWithGitHub() => _signIn('github.com');

  Future<void> signOut() async
  {
    await DatabaseService.onSignOut();
    await _auth.signOut();
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
      default:
        return false;
    }
  }

  Future<UserCredential?> _signIn(String providerId) async
  {
    try
    {
      final cred = await _providerSignIn(providerId);
      if (cred != null) DatabaseService.clearGuestProgress();
      return cred;
    }
    on FirebaseAuthException catch (e)
    {
      return e.code == 'account-exists-with-different-credential'
        ? _linkToExistingAccount(e)
        : null;
    }
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
      default:
        return null;
    }
  }

  // The email already belongs to another provider. Sign in with that provider,
  // then link the pending credential so both work going forward.
  Future<UserCredential?> _linkToExistingAccount(FirebaseAuthException e) async
  {
    final pending = e.credential;
    if (pending == null) return null;

    final existingProviderId = pending.providerId == 'github.com' ? 'google.com' : 'github.com';
    final existing = await _providerSignIn(existingProviderId);
    if (existing == null) return null;

    await existing.user?.linkWithCredential(pending);
    DatabaseService.clearGuestProgress();
    return existing;
  }
}
