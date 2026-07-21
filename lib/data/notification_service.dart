import 'dart:developer';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// NotificationService — OneSignal implementation
///
/// Handles push notifications via OneSignal (no Firebase setup needed).
/// OneSignal is free, works on Android + iOS, and integrates cleanly
/// with Supabase Edge Functions for server-side triggering.
///
/// ═══════════════════════════════════════════════════════
/// ONE-TIME SETUP (takes ~10 minutes):
/// ═══════════════════════════════════════════════════════
/// 1. Go to https://onesignal.com → Sign up (free)
/// 2. Create App → name it "Makan Mana"
/// 3. Select platform: "Google Android (FCM)"
///    → OneSignal will walk you through Firebase setup FOR you
///    → Much simpler than doing it manually
/// 4. Copy your OneSignal App ID (looks like: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
/// 5. Paste it in your .env file:
///      ONESIGNAL_APP_ID=your-app-id-here
/// 6. Run: flutter pub get
/// ═══════════════════════════════════════════════════════
///
/// Place in: lib/data/notification_service.dart

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  bool _initialized = false;

  // ── Initialize ────────────────────────────────────────────────────────────

  /// Call once in main() before runApp().
  /// Pass the OneSignal App ID from your .env file.
  Future<void> initialize(String appId) async {
    if (_initialized) return;

    // Set log level (remove verbose in production)
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

    // Initialize with your App ID
    OneSignal.initialize(appId);

    // Notification permission request disabled until notifications integration
    // await OneSignal.Notifications.requestPermission(true);
    
    // Listen for foreground notifications
    OneSignal.Notifications.addForegroundWillDisplayListener(
        _onForegroundNotification);

    // Listen for notification taps
    OneSignal.Notifications.addClickListener(_onNotificationClick);

    _initialized = true;
    log('OneSignal initialized ✅');
  }

  // ── Link device to Supabase user ──────────────────────────────────────────

  /// Call this right after a successful Supabase login.
  /// Links the OneSignal device subscription to your user ID,
  /// so Supabase Edge Functions can target specific users.
  Future<void> loginUser(String userId) async {
    await OneSignal.login(userId);
    log('OneSignal linked to user: $userId');
  }

  /// Call on logout to unlink the device.
  Future<void> logoutUser() async {
    await OneSignal.logout();
    log('OneSignal unlinked');
  }

  // ── Tags — used for segmented notification sends ──────────────────────────

  /// Update tags based on user preferences.
  /// OneSignal uses these to segment who receives which notification.
  /// e.g. send "New halal restaurant nearby!" only to halal=true users
  Future<void> updatePreferenceTags({
    bool halal          = false,
    bool vegetarian     = false,
    bool familyFriendly = false,
    String district     = '',
    List<String> cuisines = const [],
  }) async {
    await OneSignal.User.addTagWithKey('halal',          halal.toString());
    await OneSignal.User.addTagWithKey('vegetarian',     vegetarian.toString());
    await OneSignal.User.addTagWithKey('family_friendly',familyFriendly.toString());
    await OneSignal.User.addTagWithKey('district',       district);
    await OneSignal.User.addTagWithKey('cuisines',       cuisines.join(','));
    log('OneSignal preference tags updated');
  }

  /// Toggle a notification category on/off.
  /// categories: 'recommendations', 'wishlist_updates', 'nearby_alerts'
  Future<void> setNotificationCategory(
      String category, bool enabled) async {
    await OneSignal.User.addTagWithKey(
        'notif_$category', enabled.toString());
    log('OneSignal category $category = $enabled');
  }

  // ── Handlers ──────────────────────────────────────────────────────────────

  void _onForegroundNotification(
      OSNotificationWillDisplayEvent event) {
    log('Foreground notification: ${event.notification.title}');
    // Show the notification even when app is open
    event.preventDefault();
    event.notification.display();
  }

  void _onNotificationClick(OSNotificationClickEvent event) {
    final data = event.notification.additionalData;
    log('Notification tapped — type: ${data?["type"]}');

    // Wire navigation here once you have a global navigator key:
    // switch (data?['type']) {
    //   case 'new_recommendation':
    //     navigatorKey.currentState?.pushNamed(AppRoutes.recommendation);
    //   case 'wishlist_update':
    //     navigatorKey.currentState?.pushNamed(AppRoutes.wishlist);
    // }
  }

  // ── Permission helpers ────────────────────────────────────────────────────

  bool get hasPermission => false;

  Future<void> requestPermission() async {
    // Notification permission disabled until notifications feature is enabled
  }
}