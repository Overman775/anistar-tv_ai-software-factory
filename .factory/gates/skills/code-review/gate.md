# Code Review completion gate

The coordinator finishes with `cli review run finish`
after current source, complete mandatory assignment coverage, exact command results,
independent findings and QA have been checked. See the skill's references/run-contract.md.
The underlying `cli review validate` remains the structural validator.

A complete report can conclude NEEDS_WORK. Completion does not grant merge, PR
publication or code acceptance. Partial results retain valid findings and blockers.
