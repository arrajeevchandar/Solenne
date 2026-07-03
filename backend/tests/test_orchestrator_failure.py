import tempfile
import unittest
from pathlib import Path

from solenne_analyzer.config import AnalyzerConfig
from solenne_analyzer.pipeline.orchestrator import PipelineRunner


class OrchestratorFailureTest(unittest.TestCase):
    def test_orchestrator_writes_failed_result_for_missing_video(self):
        with tempfile.TemporaryDirectory() as directory:
            tmp_path = Path(directory)
            output_dir = tmp_path / "outputs"
            result = PipelineRunner(AnalyzerConfig(output_dir=output_dir)).analyze(
                tmp_path / "missing.mp4",
                run_id="missing-video",
            )

            run_dir = output_dir / "missing-video"
            self.assertEqual(result.status, "failed")
            self.assertTrue(result.errorMessage)
            self.assertTrue((run_dir / "analysis.json").exists())
            self.assertTrue((run_dir / "summary.md").exists())
            self.assertTrue((run_dir / "run.log").exists())


if __name__ == "__main__":
    unittest.main()
