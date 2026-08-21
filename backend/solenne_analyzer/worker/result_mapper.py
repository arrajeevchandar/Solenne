from __future__ import annotations

from dataclasses import asdict
from typing import Any

from ..schemas import AnalysisResult


ANALYSIS_VERSION = "2026-08-v9-gpt-oss-insights"


def analysis_result_to_firestore(result: AnalysisResult) -> dict[str, Any]:
    payload = _result_payload(result)
    payload.update({
        "analysisStatus": "complete",
        "analysisStep": "complete",
        "analysisVersion": ANALYSIS_VERSION,
        "analysisError": None,
        "analysisErrorCode": None,
    })
    return payload


def analysis_failure_to_firestore(result: AnalysisResult) -> dict[str, Any]:
    payload = _result_payload(result)
    payload.update({
        "analysisVersion": ANALYSIS_VERSION,
        "analysisErrorCode": (
            "ai_insights_unavailable"
            if result.insightProvider == "groq_error"
            else "pipeline_failed"
        ),
        "aiInsights": [],
    })
    return payload


def _result_payload(result: AnalysisResult) -> dict[str, Any]:
    payload = {
        "entryType": result.entryType,
        "analysisModalities": result.analysisModalities,
        "modalityStatus": {
            "face": "complete" if "face" in result.analysisModalities else "not_applicable",
            "voice": "complete" if "voice" in result.analysisModalities else "not_applicable",
            "transcript": "complete" if "transcript" in result.analysisModalities else "not_applicable",
            "text": "complete",
        },
        "transcript": {
            "text": result.transcript.text,
            "wordCount": result.transcript.wordCount,
            "language": result.transcript.language,
            "confidence": result.transcript.confidence,
            "languageConfidence": result.transcript.languageConfidence,
        },
        "facial": asdict(result.facial),
        "voice": asdict(result.voice),
        "nlp": asdict(result.nlp),
        "fused": asdict(result.fused),
        "templateInsights": [asdict(insight) for insight in result.insights],
        "aiInsights": [asdict(insight) for insight in result.aiInsights],
        "insightProvider": result.insightProvider,
        "llmDiagnostics": asdict(result.llmDiagnostics),
    }
    if result.groundingShadowInsights:
        payload["groundingShadowInsights"] = [
            asdict(insight) for insight in result.groundingShadowInsights
        ]
    return payload
