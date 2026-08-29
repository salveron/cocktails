/// The one shape every message reaches a reader through, success and failure
/// alike.
library;

import 'package:flutter/material.dart';

/// Puts [text] on the snackbar the messenger already knows.
void say(ScaffoldMessengerState messenger, String text) =>
    messenger.showSnackBar(SnackBar(content: Text(text)));

/// Runs [action] and answers whether it got through, [refusal] leading the
/// snackbar where it did not.
Future<bool> wentThrough(
  ScaffoldMessengerState messenger,
  String refusal,
  Future<void> Function() action,
) async {
  try {
    await action();
    return true;
  } catch (error) {
    say(messenger, '$refusal: $error');
    return false;
  }
}
