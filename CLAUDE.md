# CLAUDE.md

Godot 4.x multiplayer game: round-based zombie horde shooter-brawler with traitor dynamics.

- **Source of truth:** `docs/DESIGN.md`. Read §0 (quick reference), §12 (architecture) and the relevant feature in §14 before coding.
- Implement **one feature ID at a time** (F001, F002, …); track progress in `docs/PROGRESS.md`.
- GDScript by default, statically typed. No C# until a feature explicitly calls for it.
- Host-authoritative networking; secret role data is never replicated publicly.
- Gameplay content lives in `/content` as `.tres` resources; greybox placeholders only.
- If a request conflicts with the design doc, ask the user and update the doc in the same change.
