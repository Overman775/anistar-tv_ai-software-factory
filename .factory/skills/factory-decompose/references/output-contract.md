# Final Assembly and Handoff Contract

## Review request

Obtain the read-only TaskReviewer packet from the bound dispatch. It includes a request tied to the complete file set, source, policy, author and reviewer. Submit the returned report using the [review contract](../../../gates/skills/decompose/review-contract.md). A permitted repair receives a separate assignment and explicit file scope.

## Transactional final assembly

`decompose run prepare-publication --run RUN --request KEY` records the approved candidate and materializes it beside the destination. `decompose run publish --run RUN --request KEY` installs that exact directory. On a lost response, retry with the same key and check the receipt. A foreign directory, including one with identical bytes, belongs to its original creator.

## Handoff

Return the path, approved plan ID/revision, run ID and public task IDs. `decompose run history --run RUN` provides the gate and review receipts. An authorized implementation consumes the completed bundle by its run ID. Creation of tracker tickets, branches and PRs is separately authorized.
