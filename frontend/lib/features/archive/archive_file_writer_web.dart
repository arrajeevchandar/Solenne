import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';

class DownloadedArchive {
  const DownloadedArchive({required this.filename, required this.file});

  final String filename;
  final XFile file;
}

Future<DownloadedArchive> writeArchiveFile(
  String filename,
  Stream<List<int>> bytes,
) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in bytes) {
    builder.add(chunk);
  }
  final safeName = _safeFilename(filename);
  return DownloadedArchive(
    filename: safeName,
    file: XFile.fromData(
      builder.takeBytes(),
      mimeType: 'application/zip',
      name: safeName,
    ),
  );
}

String _safeFilename(String value) {
  final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-');
  return safe.isEmpty ? 'solenne-journal-export.zip' : safe;
}
