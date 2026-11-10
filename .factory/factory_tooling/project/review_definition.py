"""Canonical factory review directions and minimum criteria; shared by all consumers."""

DIRECTIONS = {
    "system-design": "ArchitectureReviewer",
    "runtime-safety": "CodeReviewer",
    "verification-quality": "AcceptanceReviewer",
}
CORE_CRITERIA = [
    ("SYS-BOUNDARIES", "system-design", "Are ownership, layers and dependencies coherent?"),
    (
        "SYS-CONTRACTS",
        "system-design",
        "Are public/data contracts and affected consumers preserved?",
    ),
    ("RUN-BEHAVIOR", "runtime-safety", "Is behavior correct, including edges and concurrency?"),
    ("RUN-FAILURES", "runtime-safety", "Are errors, cancellation, retry and lifecycle safe?"),
    (
        "RUN-SECURITY",
        "runtime-safety",
        "Are trust boundaries, access and sensitive data protected?",
    ),
    (
        "SYS-INTENT",
        "verification-quality",
        "Which requested outcomes are missing, partial, incorrect or exceeded?",
    ),
    (
        "VER-COVERAGE",
        "verification-quality",
        "Do tests cover changed behavior and meaningful failure risks?",
    ),
    (
        "VER-TEST-QUALITY",
        "verification-quality",
        "Are tests deterministic and asserting real behavior?",
    ),
    (
        "VER-CHANGE-SAFETY",
        "verification-quality",
        "Is evidence sufficient for affected consumers and platforms?",
    ),
]
