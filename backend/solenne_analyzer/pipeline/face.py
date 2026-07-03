from __future__ import annotations

from pathlib import Path

from ..config import AnalyzerConfig, DependencyMissingError
from ..schemas import FacialResult, clamp


def analyze_face(video_path: Path, config: AnalyzerConfig) -> FacialResult:
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
    frame_interval = max(1, int(fps / max(config.sample_fps, 0.1)))
    total = 0
    detected = 0
    brightness_values: list[float] = []
    face_sizes: list[float] = []
    warnings: list[str] = []

    cascade_path = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
    detector = cv2.CascadeClassifier(cascade_path)
    if detector.empty():
        return FacialResult(warnings=["face_detector_unavailable"])

    max_frames = int(max(30, min(360, (capture.get(cv2.CAP_PROP_FRAME_COUNT) or 0) / frame_interval)))
    frame_step_count = 0
    frame_index = 0
    total_width = capture.get(cv2.CAP_PROP_FRAME_WIDTH) or 1
    total_height = capture.get(cv2.CAP_PROP_FRAME_HEIGHT) or 1
    frame_area = total_width * total_height

    while True:
        ok, frame = capture.read()
        if not ok or frame_step_count >= max_frames:
            break
        if frame_index % frame_interval != 0:
            frame_index += 1
            continue
        frame_index += 1
        frame_step_count += 1
        total += 1
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        brightness_values.append(float(np.mean(gray)) / 255)
        faces = detector.detectMultiScale(
            gray,
            scaleFactor=1.1,
            minNeighbors=5,
            minSize=(40, 40),
        )
        if len(faces) > 0:
            detected += 1
            largest = max(faces, key=lambda face: face[2] * face[3])
            face_sizes.append(float(largest[2] * largest[3]) / frame_area)

    capture.release()

    if total == 0:
        return FacialResult(warnings=["no_frames_sampled"])

    face_ratio = detected / total
    brightness = sum(brightness_values) / max(1, len(brightness_values))
    if face_ratio < 0.35:
        warnings.append("face_not_consistently_visible")
    if brightness < 0.22:
        warnings.append("low_light")

    size_mean = sum(face_sizes) / max(1, len(face_sizes))
    arousal = clamp(abs(brightness - 0.45) * 1.4 + size_mean * 2.0, 0.0, 1.0)
    valence = clamp((brightness - 0.35) * 1.6)
    quality = clamp((face_ratio * 0.7) + (min(brightness, 0.6) / 0.6) * 0.3, 0.0, 1.0)

    return FacialResult(
        faceDetectedRatio=face_ratio,
        qualityScore=quality,
        valence=valence,
        arousal=arousal,
        confidence=quality,
        warnings=warnings,
    )
