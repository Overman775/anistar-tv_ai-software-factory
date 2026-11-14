PLAN = """# Plan: Trusted certificate authority for payment WebView
plan_id: payment-webview-trusted-ca
revision: 1
plan_state: PLAN_READY
status: draft
approved_revision: none
source: spec
handoff_recommendation: direct

## What changes
- Problem/goal: allow a trusted certificate authority only for payment WebView.
- Observable outcome: payment opens with a valid chain.
- In scope:
  - CAP-01 — certificate verification, limited by the platform context.
- Out of scope: changing all WebView.
- Source and context: local specification.

## How it works
### Main flow
1. Payment WebView starts loading an allowed host.
2. Platform verifies the certificate against the chosen trust contract.
3. Successful verification continues loading, failure stops it.

### Exceptions and branches
| Condition | Behavior | Related decision |
| :--- | :--- | :--- |
| Unknown host | Special trust verification does not apply | D-01 |

## Solution structure
| Area/owner | Responsibility and change | Why | Decision |
| :--- | :--- | :--- | :--- |
| Platform boundary | Limits special trust verification to the payment context | Do not expand trust globally | D-01 |

### Contract and evidence
| Applicability | Contract type | Behaviorally significant details | Evidence |
| :--- | :--- | :--- | :--- |
| CAP-01 | platform_plugin_api | Host and certificate participate in native verification | `official_fact`: API platform |

## Key decisions
| ID | Decision | Why | Applicability | Verification/constraint |
| :--- | :--- | :--- | :--- | :--- |
| D-01 | Special trust verification is limited to the payment host | Do not expand trust of ordinary WebView | CAP-01 | Unknown host is rejected |

## Unknowns and boundaries
- External dependencies and handling: absent.
- Research, timebox and outcome: not required.
- Risks: accidental expansion of special trust verification.

## Readiness and verification
### Acceptance criteria
| ID | Applicability | Criterion | Verification |
| --- | --- | --- | --- |
| AC-01 | CAP-01 | Allowed host opens, unknown host receives no special trust | Verify allowed and unknown hosts |

### Developer acceptance and readiness
- Acceptance: allowed host opens, unknown host receives no special trust verification.
- Readiness: solution and platform boundary defined.

### QA checks
- Verify successful payment host and unknown host failure.

## Handoff
- Recommendation: `direct`.
- Why: one capability and a stable boundary.
- What the next stage receives: approved semantic plan.
- Warning/conditions: platform checks are mandatory.
- Continuation: awaiting user choice.
- Recommendation alone does not authorize continuation.
"""
