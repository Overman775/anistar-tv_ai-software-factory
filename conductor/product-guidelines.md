# Product guidelines

## User experience

- Treat keyboard and remote focus as first-class input, not a mobile fallback.
- Keep loading, empty and failure states explicit.
- Preserve playback context when navigating back from details or player screens.
- Keep developer diagnostics out of the primary viewing flow.
- Do not show the viewer direct upstream, CDN or signed resource URLs.

## Terminology

- **Аниме**: item returned by the parser catalog.
- **Серия**: playable item shown on the details screen.
- **Плеер**: full-screen HLS playback experience.
- **Log viewer**: development diagnostic screen for local application logs.

## Copy

- Use short, direct user-facing messages.
- Error text should state what failed and, when possible, the next action.
- Do not expose stack traces, URLs containing credentials or storage details to viewers.
