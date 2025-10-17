import 'package:shared_preferences/shared_preferences.dart';

/// Utility class for managing onboarding state
class OnboardingUtils {
  static const String _onboardingKey = 'onboarding_completed';

  /// Check if onboarding has been completed
  static Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(_onboardingKey) ?? false;
    print('DEBUG: OnboardingUtils.isOnboardingCompleted() = $completed');
    return completed;
  }

  /// Mark onboarding as completed
  static Future<void> markOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    print(
      'DEBUG: OnboardingUtils.markOnboardingCompleted() - onboarding marked as completed',
    );

    // Verify the save
    final verifyCompleted = prefs.getBool(_onboardingKey) ?? false;
    print(
      'DEBUG: OnboardingUtils verification - onboarding completed: $verifyCompleted',
    );
  }

  /// Reset onboarding (for testing purposes)
  static Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboardingKey);
  }

  /// Clear all app preferences (for testing purposes)
  static Future<void> clearAllPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Reset onboarding for testing (keeps other preferences)
  static Future<void> resetOnboardingForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboardingKey);
  }
}
