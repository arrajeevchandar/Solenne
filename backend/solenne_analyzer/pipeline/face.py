from __future__ import annotations

import math
from pathlib import Path

from ..config import AnalyzerConfig, DependencyMissingError
from ..schemas import FacialResult, clamp


def analyze_face(
    video_path: Path,
    config: AnalyzerConfig,
    *,
    duration_seconds: float | None = None,
) -> FacialResult:
    try:
        import cv2
        import numpy as np
    except ImportError as error:
        raise DependencyMissingError(
            "opencv-python and numpy are required for face analysis."
        ) from error

    capture = cv2.VideoCapture(str(video_path))
    if not capture.isOpened():
        return FacialResult(warnings=["video_open_failed"])

    fps = capture.get(cv2.CAP_PROP_FPS) or 30
    sample_period_seconds = 1.0 / max(config.sample_fps, 0.1)
    total = 0
    detected = 0
    brightness_values: list[float] = []
    face_sizes: list[float] = []
    warnings: list[str] = []

    cascade_path = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
    detector = cv2.CascadeClassifier(cascade_path)
    face_detector_available = not detector.empty()
    if not face_detector_available:
        warnings.append("face_detector_unavailable")

    eye_path = cv2.data.haarcascades + "haarcascade_eye_tree_eyeglasses.xml"
    eye_detector = cv2.CascadeClassifier(eye_path)
    eye_detector_available = not eye_detector.empty()
    if not eye_detector_available:
        warnings.append("eye_detector_unavailable")

    frame_count = capture.get(cv2.CAP_PROP_FRAME_COUNT) or 0
    capture_duration = frame_count / fps if frame_count > 0 and fps > 0 else 0.0
    duration_seconds = (
        duration_seconds
        if duration_seconds is not None and duration_seconds > 0
        else capture_duration
    )
    max_frames = int(
        min(
            360,
            max(
                1,
                math.ceil(duration_seconds * max(config.sample_fps, 0.1)) + 1,
            ),
        )
    )
    frame_step_count = 0
    frame_index = 0
    next_sample_seconds = 0.0
    total_width = capture.get(cv2.CAP_PROP_FRAME_WIDTH) or 1
    total_height = capture.get(cv2.CAP_PROP_FRAME_HEIGHT) or 1
    frame_area = total_width * total_height
    best_face_candidate: tuple[float, float] | None = None
    best_technical_candidate: tuple[float, float] | None = None
    best_any_technical_candidate: tuple[float, float] | None = None

    while True:
        ok, frame = capture.read()
        if not ok or frame_step_count >= max_frames:
            break
        current_frame_index = frame_index
        frame_index += 1
        timestamp = _frame_timestamp_seconds(
            capture.get(cv2.CAP_PROP_POS_MSEC),
            current_frame_index,
            fps,
        )
        if timestamp + 0.001 < next_sample_seconds:
            continue
        while next_sample_seconds <= timestamp:
            next_sample_seconds += sample_period_seconds

        frame_step_count += 1
        total += 1
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        brightness = float(np.mean(gray)) / 255
        brightness_values.append(brightness)
        sharpness = _sharpness_score(
            float(cv2.Laplacian(gray, cv2.CV_64F).var())
        )
        exposure = _exposure_score(brightness)
        temporal = _temporal_score(timestamp, duration_seconds)
        technical_score = _weighted_thumbnail_score(
            sharpness=sharpness,
            exposure=exposure,
            temporal=temporal,
        )
        if (
            best_any_technical_candidate is None
            or technical_score > best_any_technical_candidate[0]
        ):
            best_any_technical_candidate = (technical_score, timestamp)
        if _is_usable_thumbnail_position(timestamp, duration_seconds):
            if (
                best_technical_candidate is None
                or technical_score > best_technical_candidate[0]
            ):
                best_technical_candidate = (technical_score, timestamp)

        faces = (
            detector.detectMultiScale(
                gray,
                scaleFactor=1.1,
                minNeighbors=5,
                minSize=(40, 40),
            )
            if face_detector_available
            else ()
        )
        if len(faces) == 0:
            continue

        detected += 1
        largest = max(faces, key=lambda face: face[2] * face[3])
        face_sizes.append(float(largest[2] * largest[3]) / frame_area)
        x, y, width, height = (int(value) for value in largest)
        face_region = gray[y : y + height, x : x + width]
        eyes_visible = 0.0
        if eye_detector_available and face_region.size:
            eyes = eye_detector.detectMultiScale(
                face_region,
                scaleFactor=1.1,
                minNeighbors=4,
                minSize=(10, 10),
            )
            eyes_visible = min(1.0, len(eyes) / 2)
        face_score = _weighted_thumbnail_score(
            face_composition=_face_composition_score(
                largest,
                frame_width=total_width,
                frame_height=total_height,
                face_count=len(faces),
            ),
            sharpness=sharpness,
            exposure=exposure,
            eyes=eyes_visible,
            temporal=temporal,
        )
        if not _is_usable_thumbnail_position(timestamp, duration_seconds):
            continue
        if best_face_candidate is None or face_score > best_face_candidate[0]:
            best_face_candidate = (face_score, timestamp)

    capture.release()

    if total == 0:
        return FacialResult(warnings=[*warnings, "no_frames_sampled"])

    face_ratio = detected / total
    brightness = sum(brightness_values) / max(1, len(brightness_values))
    if face_ratio < 0.35:
        warnings.append("face_not_consistently_visible")
    if brightness < 0.22:
        warnings.append("low_light")

    size_mean = sum(face_sizes) / max(1, len(face_sizes))
    arousal = clamp(abs(brightness - 0.45) * 1.4 + size_mean * 2.0, 0.0, 1.0)
    valence = clamp((brightness - 0.35) * 1.6)
    quality = clamp(
        (face_ratio * 0.7) + (min(brightness, 0.6) / 0.6) * 0.3,
        0.0,
        1.0,
    )
    selection = _select_best_candidate(
        best_face_candidate,
        best_technical_candidate or best_any_technical_candidate,
        duration_seconds=duration_seconds,
    )

    return FacialResult(
        faceDetectedRatio=face_ratio,
        qualityScore=quality,
        valence=valence,
        arousal=arousal,
        confidence=quality,
        warnings=warnings,
        bestFrameTimestampSeconds=(
            selection[1]
            if selection is not None
            else None
        ),
        bestFrameScore=selection[0] if selection else None,
        bestFrameMethod=selection[2] if selection else None,
    )


def _sharpness_score(laplacian_variance: float) -> float:
    return clamp(laplacian_variance / 500.0, 0.0, 1.0)


def _frame_timestamp_seconds(
    position_milliseconds: float,
    frame_index: int,
    reported_fps: float,
) -> float:
    if math.isfinite(position_milliseconds) and position_milliseconds > 0:
        return position_milliseconds / 1000.0
    usable_fps = reported_fps if 1.0 <= reported_fps <= 240.0 else 30.0
    return max(0.0, frame_index / usable_fps)


def _exposure_score(normalized_brightness: float) -> float:
    return clamp(
        1.0 - (abs(normalized_brightness - 0.5) / 0.5),
        0.0,
        1.0,
    )


def _temporal_score(timestamp: float, duration: float) -> float:
    if duration <= 0:
        return 1.0
    position = clamp(timestamp / duration, 0.0, 1.0)
    edge_distance = min(position, 1.0 - position)
    return clamp(edge_distance / 0.05, 0.0, 1.0)


def _is_usable_thumbnail_position(timestamp: float, duration: float) -> bool:
    if duration <= 0:
        return True
    position = clamp(timestamp / duration, 0.0, 1.0)
    return 0.05 <= position <= 0.95


def _face_composition_score(
    face,
    *,
    frame_width: float,
    frame_height: float,
    face_count: int,
) -> float:
    x, y, width, height = (float(value) for value in face)
    center_x = x + (width / 2)
    center_y = y + (height / 2)
    dx = abs(center_x - (frame_width / 2)) / max(frame_width / 2, 1.0)
    dy = abs(center_y - (frame_height / 2)) / max(frame_height / 2, 1.0)
    centered = clamp(
        1.0 - (((dx * dx) + (dy * dy)) ** 0.5 / (2 ** 0.5)),
        0.0,
        1.0,
    )
    area_fraction = (width * height) / max(frame_width * frame_height, 1.0)
    size_score = clamp(
        1.0 - (abs(area_fraction - 0.18) / 0.18),
        0.0,
        1.0,
    )
    single_face_preference = 1.0 if face_count == 1 else 0.85
    return clamp(
        ((centered * 0.65) + (size_score * 0.35)) * single_face_preference,
        0.0,
        1.0,
    )


def _weighted_thumbnail_score(
    *,
    sharpness: float,
    exposure: float,
    temporal: float,
    face_composition: float | None = None,
    eyes: float = 0.0,
) -> float:
    if face_composition is None:
        return clamp(
            (sharpness * 0.55) + (exposure * 0.35) + (temporal * 0.10),
            0.0,
            1.0,
        )
    return clamp(
        (face_composition * 0.30)
        + (sharpness * 0.25)
        + (exposure * 0.20)
        + (eyes * 0.15)
        + (temporal * 0.10),
        0.0,
        1.0,
    )


def _clamp_timestamp(timestamp: float, duration: float) -> float:
    if duration <= 0:
        return max(0.0, timestamp)
    return clamp(timestamp, 0.0, duration)


def _select_best_candidate(
    face_candidate: tuple[float, float] | None,
    technical_candidate: tuple[float, float] | None,
    *,
    duration_seconds: float,
) -> tuple[float, float, str] | None:
    candidate = face_candidate or technical_candidate
    if candidate is None:
        return None
    method = "face" if face_candidate is not None else "technical"
    return (
        round(clamp(candidate[0], 0.0, 1.0), 4),
        round(_clamp_timestamp(candidate[1], duration_seconds), 3),
        method,
    )
