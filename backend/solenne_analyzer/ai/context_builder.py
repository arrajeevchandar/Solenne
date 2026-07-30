from __future__ import annotations

import re
from pathlib import Path

from ..schemas import AnalysisResult


SHORT_TRANSCRIPT_MAX_WORDS = 120
SHORT_TRANSCRIPT_MAX_CHARS = 1_200
MAX_KEY_EXCERPTS = 6
MAX_KEY_EXCERPT_CHARS = 280
MAX_KEY_EXCERPTS_TOTAL_CHARS = 1_400

SALIENCE_TERMS = {
    "achievement",
    "angry",
    "anxious",
    "disappointed",
    "effort",
    "excited",
    "failed",
    "failing",
    "family",
    "feel",
    "feeling",
    "felt",
    "first place",
    "first position",
    "focus",
    "friend",
    "frustrated",
    "goal",
    "grateful",
    "happy",
    "hackathon",
    "holiday",
    "journal",
    "lonely",
    "passed",
    "passing",
    "pressure",
    "proud",
    "regret",
    "relieved",
    "remember",
    "rest",
    "sad",
    "sleep",
    "stress",
    "study",
    "success",
    "target",
    "tired",
    "top",
    "work",
    "worried",
}


def build_insight_context(result: AnalysisResult) -> dict:
    transcript_text = result.transcript.text.strip()
    return {
        "sourceLabel": Path(result.sourceVideo).name,
        "durationSeconds": round(result.durationSeconds, 2),
        "transcript": {
            "paraphrase": result.nlp.paraphrase,
            "wordCount": result.transcript.wordCount,
            "language": result.transcript.language,
            "confidence": result.transcript.confidence,
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


def key_excerpts(text: str) -> list[str]:
    clean_text = " ".join(text.split())
    if not clean_text:
        return []

    # A short journal is already a tightly bounded piece of user context. Keeping it
    # whole avoids dropping a later contrast or explanation merely because it appeared
    # after the first couple of sentences.
    if len(clean_text.split()) <= SHORT_TRANSCRIPT_MAX_WORDS:
        return [_truncate(clean_text, SHORT_TRANSCRIPT_MAX_CHARS)]

    sentences = _sentences(clean_text)
    if not sentences:
        return [_truncate(clean_text, MAX_KEY_EXCERPT_CHARS)]

    selected_indexes = set(range(min(2, len(sentences))))
    later_candidates = [
        (_salience_score(sentence), index)
        for index, sentence in enumerate(sentences[2:], start=2)
    ]
    later_candidates = [
        (score, index) for score, index in later_candidates if score > 0
    ]
    later_candidates.sort(key=lambda item: (-item[0], item[1]))
    for _, index in later_candidates[: MAX_KEY_EXCERPTS - len(selected_indexes)]:
        selected_indexes.add(index)

    excerpts: list[str] = []
    total_chars = 0
    for index in sorted(selected_indexes):
        remaining = MAX_KEY_EXCERPTS_TOTAL_CHARS - total_chars
        if remaining <= 0 or len(excerpts) >= MAX_KEY_EXCERPTS:
            break
        excerpt = _truncate(
            sentences[index],
            min(MAX_KEY_EXCERPT_CHARS, remaining),
        )
        if excerpt and excerpt not in excerpts:
            excerpts.append(excerpt)
            total_chars += len(excerpt)
    return excerpts


def _sentences(text: str) -> list[str]:
    return [
        match.group(0).strip()
        for match in re.finditer(r"[^.!?]+(?:[.!?]+|$)", text)
        if match.group(0).strip()
    ]


def _salience_score(sentence: str) -> int:
    lowered = sentence.lower()
    return sum(
        1
        for term in SALIENCE_TERMS
        if re.search(rf"\b{re.escape(term)}\b", lowered)
    )


def _truncate(text: str, max_chars: int) -> str:
    if len(text) <= max_chars:
        return text
    shortened = text[:max_chars].rstrip()
    if " " in shortened:
        shortened = shortened.rsplit(" ", 1)[0]
    return shortened.rstrip(" ,;:-")


def _key_excerpts(text: str) -> list[str]:
    return key_excerpts(text)
