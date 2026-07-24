from __future__ import annotations

import hashlib
import re
from typing import Any

from ..ai.context_builder import key_excerpts
from ..schemas import AnalysisResult
from .models import ClaimType, ObservationFact


CLAIM_TERMS: dict[ClaimType, set[str]] = {
    "reflective_journaling": {
        "feel",
        "felt",
        "think",
        "realized",
        "remember",
        "reflection",
        "journal",
        "reflect",
    },
    "rest_routines": {
        "sleep",
        "rest",
        "tired",
        "exhausted",
        "bedtime",
        "walk",
        "exercise",
        "awake",
        "nap",
        "sleepy",
        "fatigue",
        "woke",
        "asleep",
        "insomnia",
    },
    "workload_breaks": {
        "work",
        "job",
        "office",
        "manager",
        "meeting",
        "deadline",
        "study",
        "college",
        "class",
        "exam",
        "assignment",
        "project",
        "pressure",
        "hackathon",
        "unproductive",
        "productive",
    },
    "social_connection": {
        "friend",
        "family",
        "mother",
        "father",
        "partner",
        "lonely",
        "relationship",
        "team",
        "date",
        "crush",
        "together",
    },
    "grounding_routines": {
        "overwhelmed",
        "tense",
        "worried",
        "anxious",
        "pressure",
        "pause",
        "calm",
        "stress",
        "stressed",
    },
}

# Genuine emotional-processing signals. A single one of these is too common to route a
# journal to reflective_journaling (nearly every entry says "feel"), so we only treat
# them as a reflective-journaling signal when several appear together — that cluster is
# what distinguishes an emotionally reflective entry from an incidental mention.
EMOTION_TERMS: frozenset[str] = frozenset(
    {
        "happy",
        "sad",
        "proud",
        "disappointed",
        "grateful",
        "guilty",
        "ashamed",
        "hopeful",
        "hopeless",
        "excited",
        "nervous",
        "angry",
        "frustrated",
        "lonely",
        "relieved",
        "content",
        "emotional",
        "emotions",
        "mixed",
        "conflicted",
        "regret",
        "grief",
        "joy",
        "fear",
    }
)
EMOTION_CLUSTER_THRESHOLD = 2


def build_observation_facts(
    result: AnalysisResult,
    *,
    min_confidence: float,
) -> list[ObservationFact]:
    journal_ids = (result.runId,)
    transcript_confidence = max(0.0, min(1.0, result.transcript.confidence))
    nlp_confidence = max(0.0, min(1.0, result.nlp.confidence))
    signal_confidence = min(transcript_confidence, nlp_confidence)
    facts: list[ObservationFact] = [
        ObservationFact(
            evidenceId="fact_word_count",
            kind="word_count",
            label="Words in this reflection",
            value=result.transcript.wordCount,
            sourcePath="transcript.wordCount",
            journalIds=journal_ids,
            confidence=transcript_confidence,
        ),
        ObservationFact(
            evidenceId="fact_transcript_confidence",
            kind="transcript_confidence",
            label="Transcript confidence",
            value=round(transcript_confidence, 4),
            sourcePath="transcript.confidence",
            journalIds=journal_ids,
            confidence=transcript_confidence,
        ),
        ObservationFact(
            evidenceId="fact_duration",
            kind="duration",
            label="Recording duration in seconds",
            value=round(result.durationSeconds, 2),
            sourcePath="durationSeconds",
            journalIds=journal_ids,
            confidence=1.0,
        ),
    ]
    if not result.transcript.text.strip() or signal_confidence < min_confidence:
        return facts

    for topic in result.nlp.topics:
        clean = _normalize(topic)
        if not clean:
            continue
        facts.append(
            ObservationFact(
                evidenceId=_fact_id("topic", clean),
                kind="topic",
                label="Theme present in this reflection",
                value=clean.replace("_", " "),
                sourcePath="nlp.topics",
                journalIds=journal_ids,
                confidence=signal_confidence,
                claimTypes=_claim_types(clean),
            )
        )
    for phrase in result.nlp.keyPhrases:
        clean = _normalize(phrase)
        if not clean:
            continue
        claim_types = _claim_types(clean)
        if not claim_types:
            continue
        facts.append(
            ObservationFact(
                evidenceId=_fact_id("phrase", clean),
                kind="key_phrase",
                label="Word present in this reflection",
                value=clean.replace("_", " "),
                sourcePath="nlp.keyPhrases",
                journalIds=journal_ids,
                confidence=signal_confidence,
                claimTypes=claim_types,
            )
        )
    # Catch claim terms spoken in the transcript/paraphrase even if NLP topics were vague.
    # Skip reflective_journaling here — words like "reflection"/"feel" are too common in journals.
    spoken = f"{result.nlp.paraphrase} {result.transcript.text}".lower()
    spoken_tokens = set(re.findall(r"[a-z0-9]+", spoken))
    for claim_type, terms in CLAIM_TERMS.items():
        if claim_type == "reflective_journaling":
            continue
        hits = sorted(spoken_tokens.intersection(terms))
        for term in hits[:3]:
            facts.append(
                ObservationFact(
                    evidenceId=_fact_id("phrase", term),
                    kind="key_phrase",
                    label="Word present in this reflection",
                    value=term,
                    sourcePath="transcript.text",
                    journalIds=journal_ids,
                    confidence=signal_confidence,
                    claimTypes=(claim_type,),
                )
            )

    # An emotionally reflective entry (several distinct feeling words together) routes to
    # reflective_journaling, so expressive-writing evidence can surface for entries that
    # are about processing emotions rather than a concrete topic like work or sleep.
    emotion_hits = sorted(spoken_tokens.intersection(EMOTION_TERMS))
    if len(emotion_hits) >= EMOTION_CLUSTER_THRESHOLD:
        for term in emotion_hits[:3]:
            facts.append(
                ObservationFact(
                    evidenceId=_fact_id("phrase", term),
                    kind="key_phrase",
                    label="Word present in this reflection",
                    value=term,
                    sourcePath="transcript.text",
                    journalIds=journal_ids,
                    confidence=signal_confidence,
                    claimTypes=("reflective_journaling",),
                )
            )
    return _dedupe(facts)


def build_journal_narrative(result: AnalysisResult) -> dict[str, Any]:
    paraphrase = " ".join((result.nlp.paraphrase or "").split())[:500]
    topics = [
        " ".join(str(item).split())
        for item in result.nlp.topics
        if str(item).strip()
    ][:8]
    phrases = [
        " ".join(str(item).split())
        for item in result.nlp.keyPhrases
        if str(item).strip()
    ][:12]
    return {
        "paraphrase": paraphrase,
        "keyExcerpts": key_excerpts(result.transcript.text),
        "topics": topics,
        "keyPhrases": phrases,
    }


def _claim_types(value: str) -> tuple[ClaimType, ...]:
    tokens = set(value.replace("_", " ").split())
    return tuple(
        claim_type
        for claim_type, terms in CLAIM_TERMS.items()
        if tokens.intersection(terms)
    )


def _normalize(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", value.strip().lower()).strip("_")


def _fact_id(kind: str, value: str) -> str:
    digest = hashlib.sha1(value.encode("utf-8")).hexdigest()[:8]
    slug = value[:36].strip("_") or kind
    return f"fact_{kind}_{slug}_{digest}"


def _dedupe(facts: list[ObservationFact]) -> list[ObservationFact]:
    output: list[ObservationFact] = []
    seen: set[str] = set()
    for fact in facts:
        if fact.evidenceId not in seen:
            seen.add(fact.evidenceId)
            output.append(fact)
    return output
