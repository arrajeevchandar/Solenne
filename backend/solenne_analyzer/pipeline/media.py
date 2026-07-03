from __future__ import annotations

import subprocess
from pathlib import Path

from ..config import AnalyzerConfig, DependencyMissingError, MediaValidationError


SUPPORTED_EXTENSIONS = {".mp4", ".mov", ".webm", ".mkv", ".avi"}


def validate_video(video_path: Path, config: AnalyzerConfig) -> float:
    if not video_path.exists():
        raise MediaValidationError(f"Input video does not exist: {video_path}")
    if not video_path.is_file():
        raise MediaValidationError(f"Input path is not a file: {video_path}")
    if video_path.suffix.lower() not in SUPPORTED_EXTENSIONS:
        raise MediaValidationError(
            f"Unsupported video extension {video_path.suffix}. "
            f"Use one of: {', '.join(sorted(SUPPORTED_EXTENSIONS))}"
        )
    duration = probe_duration(video_path)
    if duration and duration > config.max_video_seconds + 5:
        raise MediaValidationError(
            f"Video is {duration:.1f}s; max supported duration is "
            f"{config.max_video_seconds}s for this milestone."
        )
    return duration


def extract_audio(video_path: Path, output_wav: Path, config: AnalyzerConfig) -> Path:
    output_wav.parent.mkdir(parents=True, exist_ok=True)
    ffmpeg = _ffmpeg_executable()
    command = [
        ffmpeg,
        "-y",
        "-i",
        str(video_path),
        "-vn",
        "-ac",
        "1",
        "-ar",
        str(config.audio_sample_rate),
        str(output_wav),
    ]
    try:
        completed = subprocess.run(
            command,
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError as error:
        raise DependencyMissingError(
            "ffmpeg is required. Install ffmpeg and make sure it is on PATH."
        ) from error
    except subprocess.CalledProcessError as error:
        raise MediaValidationError(
            f"ffmpeg failed while extracting audio: {error.stderr[-1000:]}"
        ) from error
    if completed.stderr:
        output_wav.with_suffix(".ffmpeg.log").write_text(completed.stderr, encoding="utf-8")
        return output_wav


def probe_duration(video_path: Path) -> float:
    try:
        import cv2
    except ImportError as error:
        raise DependencyMissingError(
            "opencv-python is required for duration probing. Run pip install -r backend/requirements.txt."
        ) from error

    capture = cv2.VideoCapture(str(video_path))
    if not capture.isOpened():
        return 0.0
    fps = capture.get(cv2.CAP_PROP_FPS) or 0.0
    frames = capture.get(cv2.CAP_PROP_FRAME_COUNT) or 0.0
    capture.release()
    if fps <= 0 or frames <= 0:
        return 0.0
    return float(frames / fps)


def _ffmpeg_executable() -> str:
    try:
        import imageio_ffmpeg

        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError as error:
        raise DependencyMissingError(
            "imageio-ffmpeg is required so the analyzer can run without system ffmpeg."
        ) from error
