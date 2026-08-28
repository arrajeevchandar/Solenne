from __future__ import annotations

import unittest

from solenne_analyzer.ai.groq_client import groq_error_code
from solenne_analyzer.worker.dispatcher import _is_quota_error
from solenne_analyzer.worker.queue_wakeup import FirestoreQueueWakeup


class DispatcherEventTests(unittest.TestCase):
    def test_quota_errors_are_classified_without_matching_unrelated_errors(self):
        self.assertTrue(_is_quota_error(RuntimeError("429 Quota exceeded")))
        self.assertFalse(_is_quota_error(RuntimeError("camera unavailable")))

    def test_queue_snapshot_sets_one_local_event(self):
        wakeup = FirestoreQueueWakeup(db=None)
        self.assertFalse(wakeup.event.is_set())
        wakeup._on_snapshot([], [object()], None)
        self.assertTrue(wakeup.event.is_set())

    def test_groq_failures_have_stable_codes(self):
        self.assertEqual(groq_error_code(401), "groq_auth")
        self.assertEqual(groq_error_code(404), "groq_model_unavailable")
        self.assertEqual(groq_error_code(429), "groq_rate_limited")
        self.assertEqual(groq_error_code(None), "groq_transport")


if __name__ == "__main__":
    unittest.main()
