import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

String userErrorMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'The email or password is incorrect.',
      'email-already-in-use' =>
        'An account already exists for this email address.',
      'weak-password' =>
        'Choose a stronger password with at least 6 characters.',
      'invalid-email' => 'Enter a valid email address.',
      'too-many-requests' =>
        'Too many attempts were made. Wait a moment, then try again.',
      'network-request-failed' =>
        'Solenne could not reach Firebase. Check your connection and retry.',
      _ => fallback,
    };
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        'This action is not available for your account right now.',
      'unavailable' || 'network-request-failed' =>
        'Solenne could not reach the cloud. Check your connection and retry.',
      'resource-exhausted' =>
        'The service is temporarily at capacity. Please try again later.',
      'already-exists' => 'That item already exists.',
      'not-found' => 'This item is no longer available.',
      _ => fallback,
    };
  }
  if (error is TimeoutException) {
    return 'The request took too long. Check your connection and retry.';
  }
  if (error is StateError) {
    final message = error.message.toString().trim();
    if (message.isNotEmpty && !message.contains('Exception')) return message;
  }
  final text = error.toString().replaceFirst(RegExp(r'^.*Exception:\s*'), '');
  if (text.isNotEmpty &&
      !text.contains('permission-denied') &&
      !text.contains('stack') &&
      !text.contains('Instance of')) {
    return text;
  }
  return fallback;
}
