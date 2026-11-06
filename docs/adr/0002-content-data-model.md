# ADR 0002 — Content Data Model, Validation & Serialization

- **Status:** Accepted (F003, 2026-11-06)
- **Code:** `src/data/**`, `src/autoload/content_db.gd` (class `ContentRegistry`, autoload `ContentDB`)
- **Tests:** `tests/data/`. Fixtures live in `tests/data/fixtures/content/`.

## Context
DESIGN rule 2 is "data over code". Weapons, enemies, waves, perks, doors, loot and host settings must be authored as Godot resources, checked for mistakes, and found by id. `MatchSettings` and custom wave sets must also be sent over the network (F035) and shared between hosts (F081).

## Decisions

### Class model
- **`GameData`** (extends `Resource`) is the base for all *top-level* content. It provides:
  - `id` (snake_case `StringName`), `display_name` and `description`;
  - `validate() -> ValidationReport`, which runs the base checks and then the subclass's `_validate(report)`.
- **Sub-resources** (`MeleeStats`, `FirearmStats`, `WaveData`, `WaveEntry`, `LootEntry`) extend plain `Resource`. Their owner calls `validate_into(report, source_path)` on them, so every issue carries a path such as `WaveSet:test_short.waves[2].entries[0].count_max`.
- **Weapons use composition.** One `WeaponData` has an explicit `slot` (FIREARM or MELEE) and optional `melee_stats` / `firearm_stats`.
  - The slot's primary stats are required.
  - The other set is an optional hybrid behaviour, e.g. a bayonet bash on a rifle.

### Validation
- `ValidationReport` holds **errors** (the content is broken) and **warnings** (legal but questionable).
- Following DESIGN §9, host settings only error on impossible values; questionable combinations are warnings shown to the host.
- **Standalone content** (an item saved as its own `.tres`) is validated once, by `ContentDB`. **Embedded content** is validated by its owner (`GameData.validate_embedded`), so a shared enemy's issues aren't repeated by every wave that uses it.

### Layout & registry
- Each item lives at `res://content/<category...>/<id>/<id>.tres`. The `id` must equal the file name and its folder name. Ids are unique per type, keyed by the script's `class_name`.
- At startup, `ContentDB` scans `res://content` (`ResourceLoader.list_directory`, which handles export remaps). It indexes items by `[type][id]` and records layout problems; when duplicates collide, the first definition found is kept.
- `ContentDB.validate_all()` combines:
  - the layout problems found by the scan;
  - each item's `validate()` result;
  - cross-reference checks: `MatchSettings` weapon and perk ids must resolve, and the `starting_loadout` may have at most 2 firearms and 1 melee weapon.
- Debug builds `push_error` any errors at boot. The test `test_all_shipped_content_validates` must stay green.

### Serialization (`DataSerializer`)
- Resources become JSON-safe dicts. The top-level dict carries `"schema": 1` and `"type": "<Class>"`.
- **Standalone `GameData`** becomes `{"ref": "<Type>:<id>"}` and is resolved through `ContentDB` on decode. Every peer ships the same content, so only the id needs to travel.
- **Embedded resources** are written inline. This covers custom, host-made wave sets.
- **Enums** are written by constant name, so reordering an enum doesn't break saved presets.
- **Asset slots** (textures, scenes) are never serialized. Peers load them locally.
- **Untrusted input:** `from_dict` only instantiates classes in `DataSerializer.ALLOWED_TYPES` and never decodes Variant objects (`str_to_var`, `bytes_to_var`).
  - Unknown fields produce a warning and are skipped.
  - A type mismatch is an error, and the field keeps its default.
  - The caller must still run `validate()` on the result.

## Consequences
- **New content is data-only:** a new folder, a `.tres` file, and a passing content test.
- **New fields** are added to the class with a default. Older dicts still decode, because missing keys keep their defaults. A breaking change bumps `SCHEMA_VERSION`.
- **New data classes** must be added to `ALLOWED_TYPES` before they can be serialized.
- **Typed containers only.** Untyped arrays, and dictionaries holding objects, are rejected by the serializer.
