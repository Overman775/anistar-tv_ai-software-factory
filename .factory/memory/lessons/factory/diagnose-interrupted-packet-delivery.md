---
id: diagnose-interrupted-packet-delivery
scope: factory
title: Measure a packet when delivery stops before readiness
applies_when: A native packet handoff stalls or stops before the worker confirms readiness,
  and packet size may be contributing.
observed: In the favorites bookmark run, the first packet was 458,273 bytes in 39
  chunks and delivery stopped before readiness. After long documents moved to file-based
  reading, the packet was 150,117 bytes in 13 chunks and the worker completed the
  assignment. The incident did not establish a size threshold or the cause of the
  logged read-packet errors.
roles:
- orchestrator
tags:
- packet
- delivery
- diagnostics
- size
- chunks
- instructions
- передача
- большого
- пакета
- оборвалась
- готовности
- агента
- размер
- части
- документы
allowed_case: A large packet can stay intact when required materials are available
  to the worker and the worker confirms the full delivery.
implementation: '[Native packet preparation and diagnostics](../../../workflow/README.md)'
sources:
  retro/2026-11-11-anistar-tv-favorite-bookmark/README.md:
  - user:chat/2026-11-21/перенеси-все-уроки#1c25dd0eda3c4cf476c3a3b6a0c15760b07fb01a9073f86ca1ac6d30c3ca37b0
---
After claiming the node, run `.factory/tooling/bin/cli workflow prepare-packet NODE --with-diagnostics --json`. Compare `bytes` and `chunks` with the failed attempt. Use `section_bytes` and `largest_instructions` to locate the biggest documents or sections. When the handoff supports pinned file-based reading, move suitable long materials there and verify the required contents, hashes and read receipts. Compare the new size and chunk count and check completion of the current delivery. Send only `bootstrap` to the bound worker.
