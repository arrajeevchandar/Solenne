from __future__ import annotations

from pathlib import Path

from ..config import DependencyMissingError
from ..schemas import TranscriptResult, VoiceResult


def analyze_voice(audio_path: Path, transcript: TranscriptResult) -> VoiceResult:
    try:
        import librosa
        import numpy as np
    except ImportError as error:
        raise DependencyMissingError(
            "librosa and numpy are required for voice analysis."
        ) from error

    y, sample_rate = librosa.load(str(audio_path), sr=None, mono=True)
    if y.size == 0:
        return VoiceResult()

    duration = librosa.get_duration(y=y, sr=sample_rate)
    rms = librosa.feature.rms(y=y)[0]
    energy_mean = float(np.mean(rms))
    energy_std = float(np.std(rms))
    silence_threshold = max(0.005, energy_mean * 0.35)
    pause_ratio = float(np.mean(rms < silence_threshold))

    pitch_mean = 0.0
    try:
        f0, _, _ = librosa.pyin(
            y,
            fmin=librosa.note_to_hz("C2"),
            fmax=librosa.note_to_hz("C7"),
            sr=sample_rate,
        )
        pitch_values = f0[~np.isnan(f0)]
        if pitch_values.size:
            pitch_mean = float(np.mean(pitch_values))
    except Exception:
        pitch_mean = 0.0

    speaking_rate = transcript.wordCount / max(duration / 60, 0.1)
    confidence = min(1.0, max(0.1, duration / 30) * (1 - min(0.9, pause_ratio)))

    return VoiceResult(
        energyMean=energy_mean,
        pitchMean=pitch_mean,
        speakingRate=speaking_rate,
        pauseRatio=pause_ratio,
        variability=energy_std,
        confidence=confidence,
    )
