import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solenne_frontend/core/errors/user_error_message.dart';

void main() {
  test('permission failures never expose Firebase exception text', () {
    final message = userErrorMessage(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );

    expect(message, 'This action is not available for your account right now.');
    expect(message, isNot(contains('permission-denied')));
  });

  test('unknown implementation errors use caller fallback', () {
    final message = userErrorMessage(
      Exception('Instance of minified:X'),
      fallback: 'The action could not be completed.',
    );

    expect(message, 'The action could not be completed.');
  });
}
