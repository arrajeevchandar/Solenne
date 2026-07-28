from __future__ import annotations

from dataclasses import asdict
from typing import Any

from ..schemas import AnalysisResult


ANALYSIS_VERSION = "2026-07-v3-rich-grounded"


def analysis_result_to_firestore(result: AnalysisResult) -> dict[str, Any]:
    payload = {
        "analysisStatus": "complete",
        "analysisStep": "complete",
        "analysisVersion": ANALYSIS_VERSION,
        "analysisError": None,
        "transcript": {
            "text": result.transcript.text,
            "wordCount": result.transcript.wordCount,
            "language": result.transcript.language,
            "confidence": result.transcript.confidence,
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
