import 'package:flutter/foundation.dart';

abstract final class LegalConfig {
  static const operatorName = String.fromEnvironment(
    'SOLENNE_LEGAL_OPERATOR',
    defaultValue: 'Solenne prototype project',
  );
  static const contactEmail = String.fromEnvironment(
    'SOLENNE_LEGAL_CONTACT',
    defaultValue: 'contact-required-before-release@example.invalid',
  );

  static const termsVersion = '2026-08-12-v1';
  static const privacyVersion = '2026-08-12-v1';
  static const aiConsentVersion = '2026-08-12-v1';

  static bool get isProductionReady =>
      contactEmail.isNotEmpty && !contactEmail.endsWith('.invalid');

  static void assertProductionReady() {
    if (kReleaseMode && !isProductionReady) {
      throw StateError(
        'Set SOLENNE_LEGAL_OPERATOR and SOLENNE_LEGAL_CONTACT before release.',
      );
    }
  }
}

enum LegalDocumentKind { terms, privacy, aiConsent }

extension LegalDocumentContent on LegalDocumentKind {
  String get title => switch (this) {
    LegalDocumentKind.terms => 'Terms and Conditions',
    LegalDocumentKind.privacy => 'Privacy Policy',
    LegalDocumentKind.aiConsent => 'Data and AI Consent',
  };

  String get version => switch (this) {
    LegalDocumentKind.terms => LegalConfig.termsVersion,
    LegalDocumentKind.privacy => LegalConfig.privacyVersion,
    LegalDocumentKind.aiConsent => LegalConfig.aiConsentVersion,
  };

  String get body => switch (this) {
    LegalDocumentKind.terms => _terms,
    LegalDocumentKind.privacy => _privacy,
    LegalDocumentKind.aiConsent => _aiConsent,
  };
}

const _terms =
    '''
Effective version: ${LegalConfig.termsVersion}

1. Eligibility
Solenne is intended only for people aged 18 or older. By creating an account, you confirm that you are legally able to enter this agreement.

2. Wellness service, not medical care
Solenne is a private reflection and wellness-journaling tool. It is not a medical device, therapist, doctor, emergency service, diagnosis, or substitute for professional care. Insights may be incomplete or wrong and must not be used for medical decisions.

3. Crisis limitations
Solenne does not continuously monitor entries and cannot guarantee detection of crisis language. If you may harm yourself or another person, contact local emergency services or a qualified crisis service immediately.

4. Your account and conduct
You are responsible for account security and for content you record, write, upload, or share. Do not upload unlawful content, impersonate another person, harass users, or share content without the rights and consent needed to do so.

5. Your content
You retain ownership of your journal content. You grant ${LegalConfig.operatorName} the limited permission needed to store, process, analyze, display, export, share at your direction, and delete that content in order to operate Solenne.

6. Sharing
Journal sharing is deliberate and recipient-specific inside the app. Recipients may still copy, record, or redistribute what they receive. Revoking a share stops later in-app access but cannot erase copies already made. Prototype Cloudinary media links may remain accessible to a person who retained the direct URL.

7. AI-generated output
Transcripts, metrics, summaries, and suggestions are probabilistic. They may mishear speech, miss context, or infer an incorrect pattern. Solenne does not promise accuracy, diagnosis, or a particular outcome.

8. Availability and changes
The prototype may be interrupted, changed, or discontinued. We may update these terms and will record the version accepted for new material changes.

9. Termination
You may stop using Solenne and request deletion through available account controls. We may restrict accounts used unlawfully or to harm others.

10. Liability
To the maximum extent permitted by law, the prototype is supplied without warranties. Nothing excludes rights or liabilities that cannot legally be excluded.

11. Governing law
These terms are governed by the laws of India, subject to mandatory consumer and privacy protections that apply where you live.

12. Contact
Operator: ${LegalConfig.operatorName}
Contact: ${LegalConfig.contactEmail}

This prototype text requires professional legal review and real operator details before public release.
''';

const _privacy =
    '''
Effective version: ${LegalConfig.privacyVersion}

1. Data controller
${LegalConfig.operatorName} operates this prototype. Contact: ${LegalConfig.contactEmail}.

2. Data collected
We process account details, display name, username, profile photo, friend relationships, sharing choices, written journals, audio, video, transcripts, timestamps, technical logs, and generated face, voice, language, fused wellness metrics, and AI insights.

3. Purposes
Data is used to authenticate you, store and retrieve journals, run the analysis you request, generate reflections, provide sharing, support deletion/export, prevent abuse, and diagnose service failures.

4. Sensitive information
Journal content and inferred wellbeing signals may reveal highly sensitive personal or health-related information. Processing that information for analysis relies on your explicit consent. You can withdraw future AI processing consent in Profile.

5. Processors and transfers
Firebase provides authentication and database services, Cloudinary stores media, and Groq processes minimized transcript-derived context and metrics to draft insights. Processing may occur outside your country, including in the United States, under the providers' contractual and security arrangements.

6. Groq processing
Raw video and audio are not sent to Groq. Solenne sends transcript or written text context plus compact metrics. Groq states that inference customer data is not retained by default, but troubleshooting or abuse-monitoring data may be held temporarily unless Zero Data Retention is enabled.

7. Sharing
Only entries you explicitly select are exposed to accepted friends in the app. Share records omit raw analysis metrics and diagnostics. A transcript is included only when you enable its share toggle.

8. Retention and deletion
Account and journal information is retained while needed to provide the service. Journal deletion removes its Firestore record, analysis job, shares, and Cloudinary media through the deletion worker. Backups and completed operational receipts may expire later according to service controls.

9. Security
We use Firebase authentication and security rules, encrypted HTTPS transport, least-data share projections, and backend-only service credentials. No system is completely secure. The current unsigned Cloudinary prototype cannot revoke a copied direct media URL.

10. Your choices
You may review or edit profile data, change username, choose and revoke shares, export supported data, delete journals, and withdraw future AI consent. Applicable law may provide additional access, correction, deletion, restriction, objection, portability, or complaint rights.

11. Children
Solenne is not offered to anyone under 18 and we do not knowingly process children's journals.

12. Changes and contact
Material policy changes require a new version and, when appropriate, renewed acknowledgement. Contact ${LegalConfig.contactEmail} for privacy requests.

This global prototype policy requires professional review for each launch country.
''';

const _aiConsent =
    '''
Effective version: ${LegalConfig.aiConsentVersion}

By selecting this consent, you explicitly authorize Solenne to process the journal entries you submit, including written text, microphone audio, camera video, facial-expression signals, voice/prosody signals, transcripts, themes, sentiment-related language, and other inferred wellness signals.

You understand that:

- Video journals may use face, voice, transcription, language, and fused analysis.
- Voice journals use voice, transcription, language, and fused analysis but do not use face analysis.
- Written journals use language analysis and AI insight generation without face, voice, or transcription analysis.
- Minimized transcript-derived or written context and compact metrics may be sent to Groq to draft summaries, themes, suggestions, and reflection questions.
- Raw audio and video are not sent to Groq by Solenne's analysis worker.
- AI and ML results are probabilistic observations, not facts, diagnoses, clinical assessments, or medical advice.
- Withdrawing consent stops new analysis and sharing actions. It does not silently erase existing journals or completed results; use deletion controls when you want those removed.
- Sharing is optional and separate. Nothing is shared with friends until you select a completed journal and recipients.

You may withdraw or restore consent in Profile. Restoring consent applies to future actions and does not automatically reprocess older journals.
''';
