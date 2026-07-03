import unittest

from solenne_analyzer.pipeline.fusion import fuse_modalities
from solenne_analyzer.schemas import FacialResult, NlpResult, VoiceResult


class FusionTest(unittest.TestCase):
    def test_fusion_combines_available_modalities(self):
        fused = fuse_modalities(
            FacialResult(valence=0.2, arousal=0.4, confidence=0.8),
            VoiceResult(
                energyMean=0.08,
                pauseRatio=0.2,
                variability=0.1,
                confidence=0.7,
            ),
            NlpResult(sentimentValence=0.5, stressScore=0.2, confidence=0.9),
        )

        self.assertGreater(fused.confidence, 0.7)
        self.assertGreater(fused.overallValence, 0)
        self.assertGreaterEqual(fused.overallArousal, 0)
        self.assertLessEqual(fused.overallArousal, 1)
        self.assertGreaterEqual(fused.congruence, 0)
        self.assertLessEqual(fused.congruence, 1)
        self.assertEqual(set(fused.modalityWeights), {"face", "voice", "text"})

    def test_fusion_handles_missing_modalities(self):
        fused = fuse_modalities(
            FacialResult(),
            VoiceResult(),
            NlpResult(sentimentValence=-0.6, stressScore=0.7, confidence=0.8),
        )

        self.assertLess(fused.overallValence, 0)
        self.assertEqual(fused.modalityWeights, {"text": 1.0})


if __name__ == "__main__":
    unittest.main()
