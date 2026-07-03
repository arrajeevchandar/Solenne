from __future__ import annotations

from ..config import AnalyzerConfig
from ..schemas import FacialResult, FusedResult, NlpResult, VoiceResult, clamp


def fuse_modalities(
    facial: FacialResult,
    voice: VoiceResult,
    nlp: NlpResult,
    config: AnalyzerConfig | None = None,
) -> FusedResult:
    config = config or AnalyzerConfig()
    signals = {
        "face": (facial.valence, facial.arousal, facial.confidence, config.face_weight),
        "voice": (
            _voice_valence(voice),
            _voice_arousal(voice),
            voice.confidence,
            config.voice_weight,
        ),
        "text": (nlp.sentimentValence, nlp.stressScore, nlp.confidence, config.text_weight),
    }
    usable = {
        name: values
        for name, values in signals.items()
        if values[2] > 0.05 and values[3] > 0
    }
    if not usable:
        return FusedResult()

    weighted = {
        name: confidence * base_weight
        for name, (_, _, confidence, base_weight) in usable.items()
    }
    total_weight = sum(weighted.values()) or 1.0
    normalized_weights = {
        name: weight / total_weight for name, weight in weighted.items()
    }

    valence = sum(
        usable[name][0] * normalized_weights[name] for name in usable
    )
    arousal = sum(
        usable[name][1] * normalized_weights[name] for name in usable
    )
    confidence = min(1.0, sum(values[2] for values in usable.values()) / len(usable))
    congruence = _congruence([values[0] for values in usable.values()])
    engagement = clamp((1 - voice.pauseRatio) * 0.4 + abs(arousal) * 0.3 + confidence * 0.3, 0.0, 1.0)

    return FusedResult(
        overallValence=clamp(valence),
        overallArousal=clamp(arousal, 0.0, 1.0),
        engagement=engagement,
        congruence=congruence,
        confidence=confidence,
        modalityWeights=normalized_weights,
    )


def _voice_valence(voice: VoiceResult) -> float:
    energy_component = clamp((voice.energyMean - 0.03) * 8)
    pause_component = clamp(0.5 - voice.pauseRatio)
    return clamp((energy_component + pause_component) / 2)


def _voice_arousal(voice: VoiceResult) -> float:
    return clamp(voice.energyMean * 8 + voice.variability * 0.4, 0.0, 1.0)


def _congruence(values: list[float]) -> float:
    if len(values) < 2:
        return 1.0
    spread = max(values) - min(values)
    return clamp(1 - (spread / 2), 0.0, 1.0)
