# AniStar documentation conventions

## Required Reading (read EVERY time before writing docs)

1. `AGENTS.md` and `docs/README.md` — project rules and documentation indexes
2. Read EXISTING doc files closest in topic to match style/format
3. `docs/templates/README.md` and the matching template before creating a guide,
   ADR, specification, intent, or README. For edits, read the template when changing
   document structure.

## Project Templates

Use `docs/templates/README.md` as the template index. It links the canonical
guide, ADR, specification, intent, and README templates.

Use `docs/templates/docs-template.md` for thematic guides such as `docs/01`–`05`,
`docs/07`, Melos, and VCS. Choose sections by the reader's questions; preserve
shared writing rules without forcing every guide into the same outline.

- The matching template defines the document structure. Its headings take
  precedence over generic numbering and emoji examples below.
- Keep only applicable sections. Remove authoring placeholders and comments
  from completed documents. Preserve essential constraints and source meaning.
- Intent may contain explicit open questions and assumptions. Do not turn them
  into requirements or claim that they block recording the intent.
- Factory Decompose uses its own task template. Do not replace its task format
  with these documentation templates.
- Do not reformat an existing document unless the assigned scope requires it.

## Documentation Style Guide (extracted from existing docs)

### Header Format

```
# [Emoji] [Document Title] | AniStar TV
```

Emoji by topic:

- 🏛️ Architecture, 📂 Structure, 📏 Code style, 🌐 Network/API
- 🧪 Testing, 🌿 VCS/Git, 🚀 Deploy/CI, 📝 Tasks, 🤖 AI/Tooling

### Language & Tone

- Follow [project language rules](language.md): Russian content unless explicitly requested otherwise; preserve required template headings
- English for technical terms: Flutter, BLoC, Riverpod, Provider, DTO, Entity
- Tone: neutral technical prose. Use imperative for instructions. Explain reasons only when the source supports them.
- No conclusion sections — end after last substantive section

### Section Numbering

- Main sections: `## 1. Section Title`
- Subsections: `### 1.1. Subsection` or `### Subsection Title`

### Code Examples

Use language tags: `dart`, `bash`, `yaml`. Format good/bad patterns:

```markdown
**❌ Bad:**
` ``dart
// bad code
` ``

**✅ Good:**
` ``dart
// good code
` ``

> **Почему:** [explanation]
```

### Tables, Callouts, Lists

- Tables: left-aligned (`:---`), bold headers, for comparisons/mappings
- Callouts: `> **Important:**`, `> **Rule:**`, `> **Principle:**`, ⚠️ warnings
- Numbered lists (`1.`) for steps, bullet (`*`) for unordered

### Typography

- **Bold** key terms, *Italic* concepts, `backticks` code/paths
- Horizontal rules (`---`) between major sections
