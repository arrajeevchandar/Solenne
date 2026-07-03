from __future__ import annotations

import re
from collections import Counter

from ..schemas import NlpResult, clamp


STRESS_TERMS = {
    "stress",
    "stressed",
    "stressful",
    "anxious",
    "anxiety",
    "overwhelmed",
    "tired",
    "exhausted",
    "angry",
    "sad",
    "lonely",
    "worried",
    "pressure",
}

CALM_TERMS = {
    "calm",
    "peace",
    "peaceful",
    "better",
    "grateful",
    "thankful",
    "happy",
    "relieved",
    "hopeful",
    "good",
}

TOPIC_TERMS = {
    "work": {"work", "job", "office", "manager", "meeting", "deadline"},
    "study": {"college", "class", "exam", "assignment", "study", "project"},
    "relationships": {"friend", "family", "mother", "father", "partner"},
    "health": {"sleep", "food", "exercise", "health", "body", "walk"},
    "self_reflection": {"feel", "felt", "think", "realized", "remember"},
}


def analyze_text(text: str) -> NlpResult:
    normalized = text.strip()
    if not normalized:
        return NlpResult(paraphrase="", confidence=0.0)

    words = _words(normalized)
    sentiment = _sentiment(normalized, words)
    stress_score = _stress_score(words)
    topics = _topics(words)
    key_phrases = _key_phrases(words)

    return NlpResult(
        sentimentValence=sentiment,
        stressScore=stress_score,
        topics=topics,
        keyPhrases=key_phrases,
        paraphrase=_paraphrase(normalized),
        confidence=min(1.0, max(0.2, len(words) / 80)),
    )


def _words(text: str) -> list[str]:
    return re.findall(r"[a-zA-Z']+", text.lower())


def _sentiment(text: str, words: list[str]) -> float:
    try:
        from vaderSentiment.vaderSentiment import SentimentIntensityAnalyzer

        compound = SentimentIntensityAnalyzer().polarity_scores(text)["compound"]
        return clamp(float(compound))
    except ImportError:
        if not words:
            return 0.0
        pos = sum(1 for word in words if word in CALM_TERMS)
        neg = sum(1 for word in words if word in STRESS_TERMS)
        return clamp((pos - neg) / max(1, pos + neg + 2))


def _stress_score(words: list[str]) -> float:
    if not words:
        return 0.0
    hits = sum(1 for word in words if word in STRESS_TERMS)
    return min(1.0, hits / max(4, len(words) * 0.08))


def _topics(words: list[str]) -> list[str]:
    word_set = set(words)
    scored = [
        (topic, len(word_set.intersection(terms)))
        for topic, terms in TOPIC_TERMS.items()
    ]
    return [topic for topic, score in sorted(scored, key=lambda item: -item[1]) if score > 0][:3]


def _key_phrases(words: list[str]) -> list[str]:
    stop = {
        "the",
        "and",
        "that",
        "this",
        "with",
        "was",
        "were",
        "for",
        "you",
        "but",
        "just",
        "today",
        "really",
    }
    counts = Counter(word for word in words if len(word) > 3 and word not in stop)
    return [word for word, _ in counts.most_common(8)]


def _paraphrase(text: str) -> str:
    sentences = re.split(r"(?<=[.!?])\s+", text)
    selected = [sentence.strip() for sentence in sentences if sentence.strip()][:2]
    if not selected:
        return text[:220]
    return " ".join(selected)[:300]
