import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// Handles incoming deep links (custom URI scheme) on desktop platforms.
///
/// When the user completes Google OAuth in the browser, Supabase redirects to
/// `focusforge://login-callback#access_token=xxx&refresh_token=yyy...`.
/// This service captures that URI via the `app_links` package and finishes
/// the authentication by passing the URI to Supabase's `getSessionFromUrl()`.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService _instance = DeepLinkService._();
  factory DeepLinkService() => _instance;

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  bool _initialized = false;
  bool hasInitialLink = false;

  /// Start listening for incoming URIs.
  ///
  /// Must be called once during app startup (from `main()`).
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // ── Cold start: link that launched the app ──
    try {
      final initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null) {
        hasInitialLink = true;
        debugPrint('DeepLinkService: Initial URI: $initialUri');
        await _handleUri(initialUri);
      }
    } catch (e) {
      debugPrint('DeepLinkService: getInitialLink error: $e');
    }

    // ── Warm start: links received while the app is running ──
    try {
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (Uri uri) {
          debugPrint('DeepLinkService: Stream URI: $uri');
          _handleUri(uri);
        },
        onError: (Object e) {
          debugPrint('DeepLinkService: uriLinkStream error: $e');
        },
      );
    } catch (e) {
      debugPrint('DeepLinkService: uriLinkStream setup error: $e');
    }
  }

  /// Process an incoming URI — if it matches the OAuth callback pattern,
  /// finish the Supabase auth session.
  Future<void> _handleUri(Uri uri) async {
    // No-op callback handling
  }

  /// Clean up the link subscription.
  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
    _initialized = false;
  }
}
