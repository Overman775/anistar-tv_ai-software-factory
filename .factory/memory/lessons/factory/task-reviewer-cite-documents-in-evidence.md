---
id: task-reviewer-cite-documents-in-evidence
scope: factory
title: Cite project documents in TaskReviewer evidence
applies_when: TaskReviewer returns a strict ReviewReport, including the final review
  after a bounded repair, and needs to cite required project documents it read.
observed: Both repaired task sets matched fresh review requests. Both APPROVE reports
  failed strict validation because they added project_documents_read. Both reruns
  passed strict validation with paths in the existing evidence fields.
roles:
- task-reviewer
tags:
- review-report
- schema
- evidence
- document-paths
- extra-field
- итоговый-отчёт
- проверка-задачи
- лишнее-поле
- прочитанных-документов
- отклонён
- после-исправления
- схема
allowed_case: A project document path may also appear in findings[].evidence when
  it supports that finding.
implementation: '[TaskReviewer evidence contract](../../../gates/skills/decompose/review-contract.md)'
sources:
  experiments/2026-11-18-audit-task-reviewer-packet/README.md:
  - user:chat/2026-11-21/перенеси-все-уроки#75991e9cef403e9e91699322524c7683368b7ccce123a3be4ea48336e81cbecc
---
Use exactly the ReviewReport keys. Put actual paths of project documents read in the relevant criteria[].evidence and, where pertinent to a finding, findings[].evidence. After a repair, use the coordinator’s fresh binding to the final task bytes and recheck the complete task set before approving.
