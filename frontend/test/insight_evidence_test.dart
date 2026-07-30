import 'package:flutter_test/flutter_test.dart';
import 'package:solenne_frontend/features/journals/insight_evidence.dart';

void main() {
  test('parses evidence v2 and accepts only credential-free HTTPS links', () {
    final evidence = InsightEvidence.fromMap(const {
      'schemaVersion': 2,
      'rationale':
          'The reflection named work and a deadline, so this insight stays close to those words.',
      'userEvidence': [
        {
          'evidenceId': 'fact-1',
          'label': 'Theme',
          'value': 'work',
          'sourcePath': 'nlp.topics',
          'journalIds': ['entry-1'],
          'confidence': 0.8,
        },
      ],
      'externalReferences': [
        {
          'claimCardId': 'claim-1',
          'sourceId': 'source-1',
          'title': 'Source',
          'publisher': 'Publisher',
          'year': 2024,
          'url': 'https://example.org/source',
          'matchedClaim': 'Reviewed claim.',
          'limitations': 'General context.',
          'supportLevel': 'moderate',
        },
      ],
      'verification': {
        'status': 'source_supported',
        'method': 'curated_claim_match',
      },
    });

    expect(evidence.isV2, isTrue);
    expect(
      evidence.rationale,
      'The reflection named work and a deadline, so this insight stays close to those words.',
    );
    expect(evidence.userEvidence.single.displayValue, 'work');
    expect(evidence.externalReferences.single.safeUri, isNotNull);

    final roundTripped = InsightEvidence.fromMap(evidence.toMap());
    expect(roundTripped.rationale, evidence.rationale);
    expect(roundTripped.userEvidence.single.label, 'Theme');
    expect(roundTripped.externalReferences.single.title, 'Source');
    expect(roundTripped.verification.status, 'source_supported');
  });

  test('rationale alone counts as expandable v2 evidence', () {
    final evidence = InsightEvidence.fromMap(const {
      'schemaVersion': 2,
      'rationale': 'The explanation remains available without source rows.',
      'userEvidence': [],
      'externalReferences': [],
      'verification': {
        'status': 'user_data_only',
        'method': 'personal_evidence',
      },
    });

    expect(evidence.hasContent, isTrue);
    expect(
      InsightEvidence.fromMap(evidence.toMap()).rationale,
      'The explanation remains available without source rows.',
    );
  });

  test('external references alone do not create expandable evidence', () {
    final evidence = InsightEvidence.fromMap(const {
      'schemaVersion': 2,
      'userEvidence': [],
      'externalReferences': [
        {
          'claimCardId': 'claim-1',
          'sourceId': 'source-1',
          'title': 'Stored audit source',
          'url': 'https://example.org/source',
        },
      ],
      'verification': {
        'status': 'source_supported',
        'method': 'curated_claim_match',
      },
    });

    expect(evidence.externalReferences, hasLength(1));
    expect(evidence.hasContent, isFalse);
  });

  test('legacy and malformed evidence remain safe', () {
    final legacy = InsightEvidence.fromMap(const {
      'metrics': {'pauseRatio': 0.4},
    });
    final oldV2 = InsightEvidence.fromMap(const {
      'schemaVersion': 2,
      'userEvidence': [
        {'label': 'Theme', 'value': 'work'},
      ],
      'externalReferences': [],
      'verification': {'status': 'user_data_only'},
    });
    final malformedRationale = InsightEvidence.fromMap(const {
      'schemaVersion': 2,
      'rationale': 42,
      'verification': {'status': 'user_data_only'},
    });
    final unsafe = ExternalReference.fromMap(const {
      'url': 'https://user:password@example.org/source',
    });

    expect(legacy.isV2, isFalse);
    expect(legacy.hasContent, isFalse);
    expect(oldV2.isV2, isTrue);
    expect(oldV2.rationale, isNull);
    expect(oldV2.hasContent, isTrue);
    expect(malformedRationale.rationale, isNull);
    expect(unsafe.safeUri, isNull);
  });
}
