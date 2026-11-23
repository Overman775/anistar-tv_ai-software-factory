---
name: factory-lessons
description: "Manage project or factory lessons on owner request: remember an observed case, edit a card, delete it, review a search miss or misapplied lesson, merge duplicates or audit the catalog."
---

# Manage lessons

Use `sh .factory/tooling/bin/python.sh .factory/tooling/bin/lessons.py` from the checkout.
Register `user INCIDENT SOURCE OBSERVATION` with the actual message reference and relevant excerpt.
Reuse the case incident if known, otherwise the message reference. Keep the exact inputs on retry.
Select the operation at intake:

- Save a case: add `--capture`. For another actual occurrence contributing evidence to an existing case use `--new-observation`. A standing preference belongs in USER.md.
- Edit or review a named card: include the failed query or application example when available and add `--edit ID`. Clarify an ambiguous target first.
- Delete: use `--delete ID` only for an explicit owner request. This pins the current card.
- Audit, merge, replace or retire cards: add `--audit`. These are editorial updates.

On resumption, [dispatch ready events](references/dispatch.md) without registering them again.
For a reply to an outstanding question use `waiting` and `route EVENT` to identify it.
Register any newly authorized work with the reply reference first, then close the old
request with `complete EVENT --cancelled-by REPLY_REF`. On cancellation just close it.
[Dispatch the registered event](references/dispatch.md).
