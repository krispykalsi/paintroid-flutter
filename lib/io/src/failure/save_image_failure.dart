import 'package:paintroid/core/failure.dart';

class SaveImageFailure extends Failure {
  const SaveImageFailure._(super.message);

  static const permissionDenied =
      SaveImageFailure._("Permission to save photos is denied in settings");
  static const unidentified = SaveImageFailure._("Could not save image");
}