---
name: factory-meta-retro
description: "Review how the agent factory works as a whole. Use retrospectives to identify improvements to its environment, instructions, tools, and agent collaboration for future runs."
metadata:
  credits:
    - skill: retro
      author: Matt Pocock
      url: "https://github.com/mattpocock/skills/blob/main/skills/engineering/retro/SKILL.md"
      description: "Session retrospectives that identify improvements to the coding agent's environment for future runs."
---

# Factory Meta Retro

## Goal

Suggest improvements to the agent factory's environment and working practices
so future runs produce better results with fewer errors and less unnecessary work.
Use experience from actual work to identify changes worth making.

## Scope and Approach

Start with the experience the user wants to examine. Default to the current
session. Read the available history, work results, and relevant instructions.
Choose sources and investigation depth that help explain what happened.
State any gaps in the evidence and distinguish observations from assumptions.

The subject is the factory as a whole: its instructions, skills, roles,
tools, checks, and how they work together. Examine task results to understand
what the factory helped or hindered, rather than turning the retrospective
into a general code review.

Use the session as a starting point to examine the whole factory. Follow the
connections you find. You can examine adjacent stages, other roles and tools,
test a new hypothesis, or identify an opportunity before an explicit failure occurs.
Explain why that broader investigation helps. Respect the scope the user sets.

## Possible Directions

These are examples, not a required checklist or an exhaustive list.
The cues suggest where to start, not conditions that must hold.
Choose useful directions and add your own.

- **Navigation and information access.** How easily can agents find relevant code,
  documentation, and work results? Which connections, logs, or tools would clarify the situation?
  Useful clues include prolonged searches, hidden dependencies, and missing information.
- **Checks and feedback.** What could detect an error sooner or show that the task
  is complete? Examine existing checks and how they are actually used.
  Start here when an error escaped detection, feedback arrived late, or no routine check covers a relevant risk.
- **Instructions and standards.** Which rules help agents make decisions? Which
  rules conflict, repeat each other, are outdated, or make no difference?
  Look here when agents misinterpret instructions, repeat mistakes, or carry excessive guidance.
- **Context and work cost.** Where does an agent read unnecessary material, repeat
  searches, lose important information, or receive excessive tool output?
  Repeated tool calls, truncated output, and repeated explanations are useful clues.
- **Agent collaboration.** How well is work distributed? What gets lost between
  roles and stages? Where does coordination help, and where does it add unnecessary work?
  Look for lost requirements, duplicate effort, unclear ownership, or repeated handoffs.
- **Environment design.** Which changes to skills, tools, automation, or project
  organization could make future runs simpler and more reliable?
  Consider recurring workarounds and manual steps that suitable tooling could remove.

## Choosing Improvements

Find the cause of the difficulty and a suitable place to address it.
Before adding a rule or tool, check whether the necessary mechanism already exists.
Removing, simplifying, or restoring an existing solution can also be an improvement.

For checks, distinguish absence from a check that exists but was skipped,
disconnected from the workflow, or broken. Inspect the actual command and available
results before recommending a duplicate. Repairing or connecting an existing check
may address the problem better than adding another.

Read the repository's check commands and their actual hook/CI configuration.
Check whether relevant checks run through pre-commit, pre-push or CI and whether
those runs cover the changed scope. If neither hooks nor CI run them, treat the
missing routine execution as an improvement candidate even before an error
escapes. Choose an integration point that fits the existing workflow; the
presence of a command alone does not establish automatic coverage.

Distinguish responsibility for following rules from independent verification.
The agent doing the work needs to know and follow the constraints relevant to its task.
A reviewer independently evaluates the result and decisions that require judgment.
Classify rule violations before proposing a remedy. For mechanical violations
(such as a banned API, import pattern or file-location rule), prefer a deterministic
check in the existing linter, hook or CI over adding another prose instruction.
Keep standards that require judgment in the relevant review guidance. If a
mechanical check is impractical, explain the limitation and recommend a proportionate
alternative.
Apply this principle to the actual workflow rather than prescribing a fixed set of roles.

When responsibility is unclear, ask which participant lacked information or feedback,
and at what point. Improve guidance or feedback there instead of duplicating rules
for every agent.

Protect the context shared by agents. Keep details near the task, in a relevant
skill or reference document, and keep general instructions short.
Do not turn every incident into a universal prohibition. Preserve what already works.

## Output

Present the most useful proposals in priority order. Explain what led to each
proposal, what should change, and why it would help. Where useful, identify a
specific place to change, a tradeoff, or a way to check the effect.
Choose the format and level of detail to fit the material.
Concluding that no changes are needed is a valid outcome.

By default, finish with recommendations. Apply changes when the user requests them.
Respond in the user's language.

## Attribution

See [CREDITS.md](CREDITS.md) for Matt Pocock's original `retro` skill and the
Factory adaptation details.
