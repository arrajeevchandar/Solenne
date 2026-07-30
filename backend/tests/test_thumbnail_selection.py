from __future__ import annotations

import unittest

from solenne_analyzer.pipeline.face import (
    _clamp_timestamp,
    _exposure_score,
    _face_composition_score,
    _frame_timestamp_seconds,
    _is_usable_thumbnail_position,
    _select_best_candidate,
    _sharpness_score,
    _temporal_score,
    _weighted_thumbnail_score,
)


class ThumbnailSelectionTests(unittest.TestCase):
    def test_face_score_uses_documented_weights(self) -> None:
        score = _weighted_thumbnail_score(
            face_composition=0.8,
            sharpness=0.6,
            exposure=0.7,
            eyes=1.0,
            temporal=0.5,
        )

        self.assertAlmostEqual(score, 0.73)

    def test_no_face_score_uses_technical_weights(self) -> None:
        score = _weighted_thumbnail_score(
            sharpness=0.8,
            exposure=0.6,
            temporal=1.0,
        )

        self.assertAlmostEqual(score, 0.75)

    def test_selection_prefers_any_usable_face_candidate(self) -> None:
        selected = _select_best_candidate(
            (0.64, 7.25),
            (0.92, 10.0),
            duration_seconds=20.0,
        )

        self.assertEqual(selected, (0.64, 7.25, "face"))

    def test_selection_falls_back_to_best_technical_frame(self) -> None:
        selected = _select_best_candidate(
            None,
            (0.81, 12.0),
            duration_seconds=20.0,
        )

        self.assertEqual(selected, (0.81, 12.0, "technical"))

    def test_edge_frames_are_penalized(self) -> None:
        self.assertEqual(_temporal_score(0.0, 100.0), 0.0)
        self.assertAlmostEqual(_temporal_score(2.5, 100.0), 0.5)
        self.assertEqual(_temporal_score(5.0, 100.0), 1.0)
        self.assertEqual(_temporal_score(95.0, 100.0), 1.0)
        self.assertEqual(_temporal_score(100.0, 100.0), 0.0)
        self.assertFalse(_is_usable_thumbnail_position(4.9, 100.0))
        self.assertTrue(_is_usable_thumbnail_position(5.0, 100.0))
        self.assertTrue(_is_usable_thumbnail_position(95.0, 100.0))
        self.assertFalse(_is_usable_thumbnail_position(95.1, 100.0))

    def test_timestamp_is_clamped_to_video_duration(self) -> None:
        self.assertEqual(_clamp_timestamp(-2.0, 20.0), 0.0)
        self.assertEqual(_clamp_timestamp(30.0, 20.0), 20.0)

    def test_centered_single_face_scores_above_off_center_multiple_faces(self) -> None:
        centered = _face_composition_score(
            (360, 180, 280, 280),
            frame_width=1000,
            frame_height=640,
            face_count=1,
        )
        off_center = _face_composition_score(
            (0, 0, 120, 120),
            frame_width=1000,
            frame_height=640,
            face_count=2,
        )

        self.assertGreater(centered, off_center)

    def test_sharpness_and_exposure_are_normalized(self) -> None:
        self.assertEqual(_sharpness_score(0.0), 0.0)
        self.assertEqual(_sharpness_score(500.0), 1.0)
        self.assertEqual(_exposure_score(0.5), 1.0)
        self.assertEqual(_exposure_score(0.0), 0.0)

    def test_frame_timestamp_uses_media_clock_over_webm_timebase_fps(self) -> None:
        self.assertEqual(_frame_timestamp_seconds(3200.0, 96, 1000.0), 3.2)
        self.assertEqual(_frame_timestamp_seconds(0.0, 90, 1000.0), 3.0)


if __name__ == "__main__":
    unittest.main()
