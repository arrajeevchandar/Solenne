# Entity Lifecycles (Runtime)

**Purpose:** State machines for data and user behavior at runtime — not calendar planning.

| Entity | Document | States / Stages |
|--------|----------|-----------------|
| User journey | [User-Journey-Lifecycle](./User-Journey-Lifecycle.md) | 8 stages |
| Journal entry | [Journal-Entry-Lifecycle](./Journal-Entry-Lifecycle.md) | 7 states |
| Analysis job | [Analysis-Job-Lifecycle](./Analysis-Job-Lifecycle.md) | 4 states |
| Analysis pipeline | [Analysis-Pipeline-Lifecycle](./Analysis-Pipeline-Lifecycle.md) | 9 steps |
| Personal baseline | [Baseline-Lifecycle](./Baseline-Lifecycle.md) | 4 phases |
| Insight | [Insight-Lifecycle](./Insight-Lifecycle.md) | 6 stages |
| Consent & data | [Consent-Data-Lifecycle](./Consent-Data-Lifecycle.md) | 5 stages |

## Who Implements What

| Entity | Primary module |
|--------|----------------|
| User journey | M1 → M2 → M3 → M4 → M5 |
| Journal entry | M2 |
| Analysis job | M2 creates; M3 processes |
| Analysis pipeline | M3 |
| Baseline | M3 writes; M4 reads |
| Insight | M3 generates; M4 displays |
| Consent & data | M1 creates; M5 manages |
