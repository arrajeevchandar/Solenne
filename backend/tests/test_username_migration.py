import unittest

from solenne_analyzer.worker.username_migration import (
    canonical_username,
    migration_username,
)


class UsernameMigrationTests(unittest.TestCase):
    def test_mixed_case_generated_username_becomes_canonical(self):
        self.assertEqual(
            canonical_username("rajeev_nXxax0"),
            "rajeev_nxxax0",
        )

    def test_collision_uses_lowercase_uid_suffix(self):
        value = migration_username(
            {
                "usernameNormalized": "Taken_Name",
                "displayName": "Rajeev Chander",
            },
            "AbC123XYZ",
            {"taken_name"},
        )

        self.assertEqual(value, "rajeev_chand_abc123")
        self.assertRegex(value, r"^[a-z0-9_]{3,20}$")


if __name__ == "__main__":
    unittest.main()
