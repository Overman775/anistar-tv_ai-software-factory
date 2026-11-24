---
id: diagnose-pinned-document-scope-drift
scope: factory
title: Diagnose Project document/scope drift after a planned document edit
applies_when: Implement rejects check registration or report acceptance with Project
  document/scope drift after an authorized edit to a pinned project document.
observed: An approved task edited a required testing guide that also served as a pinned
  policy input. The changed hash blocked check registration and report acceptance
  before Judge started. The corrected workflow preserved the accepted text and verified,
  reviewed and accepted the edited candidate in an isolated reproduction.
roles:
- orchestrator
- developer
tags:
- scope-drift
- pinned-document
- document-snapshot
- правка
- обязательного
- документа
- отчёт
- приёмка
allowed_case: An approved edit may target a pinned normative document. Its edited
  text can become policy at the next intake.
implementation: '[Project policy boundary](../../../contracts/common/project-policy.md#checks-and-change-control)
  · [Document deliverable regression](../../../tooling/tests/factory/project/test_project.py#L1304)'
sources:
  retro/2026-11-14-anistar-tv-golden-screen-profiles/README.md:
  - user:chat/2026-11-21/перенеси-все-уроки#63bcd756edc1d97f11ace1dc942dc9537598d1d0e1215cfed19d1fc10e092241
---
Check the exact path in the accepted instructions and authorized task scope. Use the accepted packet or `.factory/tooling/bin/cli workflow read-project` to recover the baseline text and report any missing or invalid snapshot to the coordinator. Verify the candidate at the same path against the accepted snapshot and refresh evidence if the candidate changed after verification. If the owner authorizes a change to the active requirements, the coordinator refreshes the selected accepted text through `.factory/tooling/bin/cli workflow reintake GRAPH 'REASON' 'AUTHORIZATION' --document PATH`.
