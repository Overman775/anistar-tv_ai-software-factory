---
name: factory-meta-retune-lessons
description: "Revise a factory procedure from confirmed cases or audit agent instructions for edge cases to move into lessons. Route lesson card edits to factory-lessons, including catalog maintenance."
---

# Retune agent instructions

Coordinator: assign the target role or procedure and the cited cases to the
[configured Teacher](../factory-lessons/references/dispatch.md) with
the [Retune procedure](references/retune.md). For an instruction audit, include
the role, its contract, gates and additional documents actually selected for that
assignment. Use one representative assignment per affected role and stage.
Coordinate the independent trial workers requested by Teacher and return their
results for assessment.

Open the direct assignment with `cli lessons retune init --request KEY --case CASE --counterexample COUNTEREXAMPLE --baseline CURRENT --candidate PROPOSED --instructions AUTHORITY`. Use `lessons retune status --run RUN` to resume. Claim and bind Teacher through this assignment. Register each independent worker and case with `trial` and preserve its ticket with `result`. Teacher uses `conclude` to record a justified skip, keep the current procedure after regression, or propose a supported improvement. Procedure changes retain their own approval boundary.
