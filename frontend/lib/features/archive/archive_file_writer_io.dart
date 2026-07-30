import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';

class DownloadedArchive {
  const DownloadedArchive({required this.filename, required this.file});

  final String filename;
  final XFile file;
}

Future<DownloadedArchive> writeArchiveFile(
  String filename,
  Stream<List<int>> bytes,
) async {
  final directory = await getTemporaryDirectory();
  final safeName = _safeFilename(filename);
  final file = File('${directory.path}/$safeName');
  final output = file.openWrite();
  try {
    await output.addStream(bytes);
  } finally {
    await output.close();
  }
  return DownloadedArchive(filename: safeName, file: XFile(file.path));
}

String _safeFilename(String value) {
  final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-');
  return safe.isEmpty ? 'solenne-journal-export.zip' : safe;
}
