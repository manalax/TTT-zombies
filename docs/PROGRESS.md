# Implementation Progress

Feature IDs and acceptance criteria are defined in [DESIGN.md §14](DESIGN.md#14-implementation-roadmap-feature-by-feature).
Status: `todo` · `in progress` · `done`. Update this file in the same change as the feature.

| ID | Feature | Status | Notes |
|---|---|---|---|
| **M0** | **Foundations** | | |
| F001 | Project skeleton | done | Godot 4.7.2, Forward+, Jolt; gdUnit4 6.2.3 vendored; gdtoolkit 4.5.0; CI workflow added (runs for the first time on push) |
| F002 | StateMachine & Events bus | done | Hierarchical FSM (ADR 0001); Events bus with 19 typed, local-only signals; skeleton `MatchFlow` in `src/match/` (logic in F019) |
| F003 | Data resource classes + validators | done | ADR 0002. `GameData` + `ValidationReport`; weapons via composition; `ContentDB` registry; `DataSerializer` for MatchSettings/WaveSet; sample content + Betrayal/Vigil presets (`test_short` 3-wave set until F065) |
| **M1** | **Single-player sandbox** | | |
| F010 | First-person controller | todo | |
| F011 | Damage pipeline | todo | |
| F012 | Melee v1 | todo | Owns heavy-attack input decision (hold `attack_light` vs. separate key) |
| F013 | Parry/dodge/riposte | todo | |
| F014 | Firearms v1 | todo | |
| F015 | Basic cultist AI (Acolyte) | todo | |
| F016 | Points economy | todo | |
| F017 | Doors & zones | todo | |
| F018 | Wall-buy, ammo stations, perk altar | todo | |
| F019 | Wave director v1 + round loop | todo | |
| **M2** | **Multiplayer** | | |
| F030 | NetTransport abstraction + ENet lobby | todo | |
| F031 | Player replication | todo | |
| F032 | Server-authoritative combat | todo | |
| F033 | Enemy replication + host director | todo | |
| F034 | Steam transport | todo | |
| F035 | Settings replication & lobby UI v1 | todo | |
| **M3** | **Social layer (Betrayal)** | | |
| F040 | Role assignment & secret info channel | todo | |
| F041 | Friendly fire + traitor attack handling | todo | |
| F042 | Exposure: witnessed damage | todo | |
| F043 | Blessed Silver test | todo | |
| F044 | Death, loot bag, conversion queue | todo | |
| F045 | Player-controlled special framework | todo | |
| F046 | Stalker | todo | |
| F047 | Win/loss resolution & role reveal | todo | |
| F048 | Co-op (Vigil) rules | todo | |
| **M4** | **Enemy variety** | | |
| F060 | Hooked Priest | todo | |
| F061 | Plague Bloat | todo | |
| F062 | Abomination | todo | |
| F063 | Zealot, Flagellant | todo | |
| F064 | Director constraints | todo | |
| F065 | Default 12-wave WaveSet + presets | todo | |
| **M5** | **Content & polish** | | |
| F070 | MVP map greybox (Ashgrave) | todo | |
| F071 | HUD, scoreboard, ping | todo | |
| F072 | Text chat | todo | |
| F073 | Perks & consumables | todo | |
| F074 | Audio service | todo | |
| F075 | Performance pass | todo | |
| **M6** | **Host power tools** | | |
| F080 | Full MatchSettings panel | todo | |
| F081 | In-lobby Wave Editor | todo | |
| F082 | Expansion specials | todo | |
| F083 | Body inspection, sabotage, downed, voice | todo | Stretch |
