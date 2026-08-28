from __future__ import annotations

from dataclasses import dataclass
import importlib.util
from pathlib import Path
import tempfile

import httpx

from ..config import AnalyzerConfig
from ..pipeline.media import _ffmpeg_executable
from .config import WorkerConfig


@dataclass(frozen=True)
class DoctorCheck:
    name: str
    status: str
    detail: str
    critical: bool = False


def run_worker_doctor(
    config: WorkerConfig,
    *,
    gateway=None,
    check_remote: bool = True,
) -> list[DoctorCheck]:
    checks: list[DoctorCheck] = []
    checks.append(_firebase_check(config, gateway) if check_remote else _firebase_file_check(config))
    checks.append(
        DoctorCheck(
            "cloudinary_admin",
            "ok" if config.has_cloudinary_admin_credentials else "warning",
            "configured" if config.has_cloudinary_admin_credentials else "deletion and export disabled",
        )
    )
    try:
        ffmpeg = Path(_ffmpeg_executable())
        checks.append(DoctorCheck("ffmpeg", "ok", ffmpeg.name, critical=True))
    except Exception:
        checks.append(DoctorCheck("ffmpeg", "failed", "unavailable", critical=True))

    missing = [
        package
        for package in ("faster_whisper", "cv2", "mediapipe", "librosa", "soundfile")
        if importlib.util.find_spec(package) is None
    ]
    checks.append(
        DoctorCheck(
            "ml_imports",
            "failed" if missing else "ok",
            ",".join(missing) if missing else "available",
            critical=bool(missing),
        )
    )
    checks.append(
        DoctorCheck(
            "whisper",
            "ok" if config.whisper_model.strip() else "failed",
            config.whisper_model.strip() or "model not configured",
            critical=not bool(config.whisper_model.strip()),
        )
    )
    checks.append(_groq_check(check_remote=check_remote))
    try:
        with tempfile.TemporaryDirectory(prefix="solenne-doctor-") as value:
            probe = Path(value) / "probe"
            probe.write_text("ok", encoding="ascii")
            if probe.read_text(encoding="ascii") != "ok":
                raise OSError("temporary storage verification failed")
        checks.append(DoctorCheck("temporary_storage", "ok", "writable", critical=True))
    except OSError:
        checks.append(DoctorCheck("temporary_storage", "failed", "not writable", critical=True))
    return checks


def doctor_ready(checks: list[DoctorCheck]) -> bool:
    return not any(check.critical and check.status == "failed" for check in checks)


def _firebase_file_check(config: WorkerConfig) -> DoctorCheck:
    account = config.firebase_service_account
    valid = account is None or account.is_file()
    return DoctorCheck(
        "firebase_admin",
        "ok" if valid else "failed",
        "credential source configured" if valid else "service account file missing",
        critical=not valid,
    )


def _firebase_check(config: WorkerConfig, gateway) -> DoctorCheck:
    try:
        if gateway is None:
            from .firebase_gateway import FirebaseGateway

            gateway = FirebaseGateway(config)
        list(gateway.db.collection("analysis_jobs").limit(1).stream())
        return DoctorCheck("firebase_admin", "ok", "read access confirmed", critical=True)
    except Exception as error:
        text = str(error).lower()
        temporary = "429" in text or "quota" in text or "unavailable" in text
        return DoctorCheck(
            "firebase_admin",
            "warning" if temporary else "failed",
            "temporarily unavailable" if temporary else "access rejected",
            critical=not temporary,
        )


def _groq_check(*, check_remote: bool) -> DoctorCheck:
    config = AnalyzerConfig.from_env(enable_llm_insights=True)
    if not config.groq_api_key:
        return DoctorCheck("groq", "failed", "API key missing", critical=True)
    if not config.groq_model:
        return DoctorCheck("groq", "failed", "model missing", critical=True)
    if not check_remote:
        return DoctorCheck("groq", "ok", config.groq_model, critical=True)
    try:
        response = httpx.get(
            "https://api.groq.com/openai/v1/models",
            headers={"Authorization": f"Bearer {config.groq_api_key}"},
            timeout=15,
        )
        if response.status_code in {401, 403}:
            return DoctorCheck("groq", "failed", "authentication rejected", critical=True)
        if response.status_code == 429:
            return DoctorCheck("groq", "warning", "rate limited", critical=False)
        response.raise_for_status()
        models = {str(item.get("id", "")) for item in response.json().get("data", [])}
        if config.groq_model not in models:
            return DoctorCheck("groq", "failed", "configured model unavailable", critical=True)
        return DoctorCheck("groq", "ok", config.groq_model, critical=True)
    except httpx.TransportError:
        return DoctorCheck("groq", "warning", "network check unavailable", critical=False)
    except (httpx.HTTPStatusError, ValueError, TypeError):
        return DoctorCheck("groq", "warning", "remote check unavailable", critical=False)

