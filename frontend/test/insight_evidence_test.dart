import 'package:flutter_test/flutter_test.dart';
import 'package:solenne_frontend/features/journals/insight_evidence.dart';

void main() {
  test('parses evidence v2 and accepts only credential-free HTTPS links', () {
    final evidence = InsightEvidence.fromMap(const {
      'schemaVersion': 2,
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
    expect(evidence.userEvidence.single.displayValue, 'work');
    expect(evidence.externalReferences.single.safeUri, isNotNull);
  });

  test('legacy and malformed evidence remain safe', () {
    final legacy = InsightEvidence.fromMap(const {
      'metrics': {'pauseRatio': 0.4},
    });
    final unsafe = ExternalReference.fromMap(const {
      'url': 'https://user:password@example.org/source',
    });

    expect(legacy.isV2, isFalse);
    expect(legacy.hasContent, isFalse);
    expect(unsafe.safeUri, isNull);
  });
}
