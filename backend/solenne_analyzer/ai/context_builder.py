from __future__ import annotations

from pathlib import Path

from ..schemas import AnalysisResult


def build_insight_context(result: AnalysisResult) -> dict:
    transcript_text = result.transcript.text.strip()
    return {
        "runId": result.runId,
        "sourceLabel": Path(result.sourceVideo).name,
        "durationSeconds": round(result.durationSeconds, 2),
        "transcript": {
            "paraphrase": result.nlp.paraphrase,
            "wordCount": result.transcript.wordCount,
            "language": result.transcript.language,
            "keyExcerpts": _key_excerpts(transcript_text),
        },
        "metrics": {
            "fused": result.fused.to_dict() if hasattr(result.fused, "to_dict") else {
                "overallValence": result.fused.overallValence,
                "overallArousal": result.fused.overallArousal,
                "engagement": result.fused.engagement,
                "congruence": result.fused.congruence,
                "confidence": result.fused.confidence,
                "modalityWeights": result.fused.modalityWeights,
            },
            "facial": {
                "valence": result.facial.valence,
                "arousal": result.facial.arousal,
                "confidence": result.facial.confidence,
                "faceDetectedRatio": result.facial.faceDetectedRatio,
                "warnings": result.facial.warnings,
            },
            "voice": {
                "energyMean": result.voice.energyMean,
                "pitchMean": result.voice.pitchMean,
                "speakingRate": result.voice.speakingRate,
                "pauseRatio": result.voice.pauseRatio,
                "confidence": result.voice.confidence,
            },
            "text": {
                "sentimentValence": result.nlp.sentimentValence,
                "stressScore": result.nlp.stressScore,
                "topics": result.nlp.topics,
                "keyPhrases": result.nlp.keyPhrases,
                "confidence": result.nlp.confidence,
            },
        },
        "templateInsights": [
            {
                "templateId": insight.templateId,
                "text": insight.text,
                "confidence": insight.confidence,
                "evidence": insight.evidence,
            }
            for insight in result.insights
        ],
        "guardrails": [
            "wellness_journal_only",
            "no_diagnosis",
            "no_medical_advice",
            "do_not_overclaim_face_or_voice",
        ],
    }


def estimate_tokens(payload: dict) -> int:
    return max(1, len(str(payload)) // 4)


def _key_excerpts(text: str) -> list[str]:
    if not text:
        return []
    sentences = [part.strip() for part in text.replace("\n", " ").split(".") if part.strip()]
    selected = sentences[:2]
    for sentence in sentences:
        lowered = sentence.lower()
        if any(term in lowered for term in ["goal", "feel", "happy", "focus", "journal", "remember"]):
            selected.append(sentence)
        if len(selected) >= 6:
            break
    deduped: list[str] = []
    for sentence in selected:
        clean = sentence[:280]
        if clean not in deduped:
            deduped.append(clean)
    return deduped[:6]
