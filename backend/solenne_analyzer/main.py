from __future__ import annotations

import argparse
import json
from pathlib import Path

from .config import AnalyzerConfig, DEFAULT_OUTPUT_DIR
from .pipeline.orchestrator import PipelineRunner


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="solenne-analyzer",
        description="Analyze a local Solenne video journal file.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    analyze = subparsers.add_parser("analyze", help="Analyze a local video file.")
    analyze.add_argument("video", type=Path, help="Path to the local video file.")
    analyze.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help="Directory where analysis output folders are written.",
    )
    analyze.add_argument(
        "--run-id",
        default=None,
        help="Optional stable run id for repeatable output paths.",
    )
    analyze.add_argument(
        "--whisper-model",
        default="small",
        help="faster-whisper model name. Use base for faster local smoke tests.",
    )
    analyze.add_argument(
        "--max-video-seconds",
        type=int,
        default=180,
        help="Maximum accepted video duration for this run.",
    )
    analyze.add_argument(
        "--enable-llm-insights",
        action="store_true",
        default=None,
        help="Generate Groq-backed AI insight cards when GROQ_API_KEY is configured.",
    )
    analyze.add_argument(
        "--llm-model",
        default=None,
        help="Groq model id for AI insights. Defaults to GROQ_MODEL or llama-3.1-8b-instant.",
    )
    analyze.add_argument(
        "--json",
        action="store_true",
        help="Print the full analysis result JSON to stdout.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "analyze":
        config = AnalyzerConfig.from_env(
            output_dir=args.output_dir,
            whisper_model=args.whisper_model,
            max_video_seconds=args.max_video_seconds,
            enable_llm_insights=args.enable_llm_insights,
            groq_model=args.llm_model,
        )
        result = PipelineRunner(config).analyze(args.video, run_id=args.run_id)
        if args.json:
            print(json.dumps(result.to_dict(), indent=2, ensure_ascii=False))
        else:
            print(f"status={result.status}")
            print(f"runId={result.runId}")
            print(f"output={config.output_dir / result.runId}")
            if result.errorMessage:
                print(f"error={result.errorMessage}")
        return 0 if result.status == "complete" else 1
    return 2
