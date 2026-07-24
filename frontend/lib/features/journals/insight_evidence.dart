class InsightEvidence {
  const InsightEvidence({
    required this.schemaVersion,
    required this.userEvidence,
    required this.externalReferences,
    required this.verification,
  });

  final int schemaVersion;
  final List<UserEvidenceItem> userEvidence;
  final List<ExternalReference> externalReferences;
  final VerificationMetadata verification;

  bool get isV2 => schemaVersion == 2;
  bool get isSafetyBypass => verification.reason == 'safety_bypass';
  bool get hasContent =>
      userEvidence.isNotEmpty || externalReferences.isNotEmpty;

  factory InsightEvidence.fromMap(Map<String, dynamic> map) {
    return InsightEvidence(
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 0,
      userEvidence: _mapList(
        map['userEvidence'],
      ).map(UserEvidenceItem.fromMap).toList(growable: false),
      externalReferences: _mapList(
        map['externalReferences'],
      ).map(ExternalReference.fromMap).toList(growable: false),
      verification: VerificationMetadata.fromMap(
        _dynamicMap(map['verification']),
      ),
    );
  }
}

class UserEvidenceItem {
  const UserEvidenceItem({
    required this.evidenceId,
    required this.label,
    required this.value,
    required this.sourcePath,
    required this.journalIds,
    required this.confidence,
  });

  final String evidenceId;
  final String label;
  final Object? value;
  final String sourcePath;
  final List<String> journalIds;
  final double confidence;

  String get displayValue {
    final current = value;
    if (current is double) return current.toStringAsFixed(2);
    return current?.toString() ?? '';
  }

  factory UserEvidenceItem.fromMap(Map<String, dynamic> map) {
    return UserEvidenceItem(
      evidenceId: map['evidenceId'] as String? ?? '',
      label: map['label'] as String? ?? '',
      value: map['value'],
      sourcePath: map['sourcePath'] as String? ?? '',
      journalIds: _stringList(map['journalIds']),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ExternalReference {
  const ExternalReference({
    required this.claimCardId,
    required this.sourceId,
    required this.title,
    required this.publisher,
    required this.year,
    required this.url,
    required this.doi,
    required this.pmid,
    required this.matchedClaim,
    required this.limitations,
    required this.supportLevel,
  });

  final String claimCardId;
  final String sourceId;
  final String title;
  final String publisher;
  final int? year;
  final String url;
  final String? doi;
  final String? pmid;
  final String matchedClaim;
  final String limitations;
  final String supportLevel;

  Uri? get safeUri {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    if (uri.userInfo.isNotEmpty) return null;
    return uri;
  }

  String get publicationLine {
    final parts = <String>[
      if (publisher.trim().isNotEmpty) publisher.trim(),
      if (year != null) year.toString(),
    ];
    return parts.join(' · ');
  }

  factory ExternalReference.fromMap(Map<String, dynamic> map) {
    return ExternalReference(
      claimCardId: map['claimCardId'] as String? ?? '',
      sourceId: map['sourceId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      publisher: map['publisher'] as String? ?? '',
      year: (map['year'] as num?)?.toInt(),
      url: map['url'] as String? ?? '',
      doi: map['doi'] as String?,
      pmid: map['pmid'] as String?,
      matchedClaim: map['matchedClaim'] as String? ?? '',
      limitations: map['limitations'] as String? ?? '',
      supportLevel: map['supportLevel'] as String? ?? '',
    );
  }
}

class VerificationMetadata {
  const VerificationMetadata({
    required this.status,
    required this.method,
    required this.catalogVersion,
    required this.reason,
  });

  final String status;
  final String method;
  final String? catalogVersion;
  final String? reason;

  factory VerificationMetadata.fromMap(Map<String, dynamic> map) {
    return VerificationMetadata(
      status: map['status'] as String? ?? '',
      method: map['method'] as String? ?? '',
      catalogVersion: map['catalogVersion'] as String?,
      reason: map['reason'] as String?,
    );
  }
}

Map<String, dynamic> _dynamicMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! Iterable) return const [];
  return value.whereType<Map>().map(_dynamicMap).toList(growable: false);
}

List<String> _stringList(Object? value) {
  if (value is! Iterable) return const [];
  return value
      .whereType<Object>()
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
