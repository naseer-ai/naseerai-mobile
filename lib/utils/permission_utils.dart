import 'package:permission_handler/permission_handler.dart';

/// Requests storage permissions for Android external storage access.
Future<bool> requestStoragePermission() async {
  final status = await Permission.storage.status;
  if (status.isGranted) {
    return true;
  }
  final result = await Permission.storage.request();
  return result.isGranted;
}
