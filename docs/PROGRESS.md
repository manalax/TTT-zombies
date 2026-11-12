# Implementation Progress

Feature IDs and acceptance criteria are defined in [DESIGN.md §14](DESIGN.md#14-implementation-roadmap-feature-by-feature).
Status: `todo` · `in progress` · `done`. Update this file in the same change as the feature.

| ID | Feature | Status | Notes |
|---|---|---|---|
| **M0** | **Foundations** | | |
| F001 | Project skeleton | done | Godot 4.7.2, Forward+, Jolt; gdUnit4 6.2.3 vendored; gdtoolkit 4.5.0; CI workflow added (runs for the first time on push) |
| F002 | StateMachine & Events bus | done | Hierarchical FSM (ADR 0001); Events bus with 19 typed, local-only signals; skeleton `MatchFlow` in `src/match/` (logic in F019) |
| F003 | Data resource classes + validators | done | ADR 0002. `GameData` + `ValidationReport`; weapons via composition; `ContentDB` registry; `DataSerializer` for MatchSettings/WaveSet; sample content + Betrayal/Vigil presets (`test_short` 3-wave set until F045) |
| **M1** | **Single-player sandbox** | | |
| F010 | First-person controller | done | ADR 0003. Input source → intent → movement HSM → `PlayerMotor`; `StaminaComponent`; `PlayerDefaults`; local prefs in `Settings`; `main` boots `maps/dev/sandbox_arena`; F3 debug overlay. Feel needs a manual playtest |
| F011 | Damage pipeline | done | ADR 0004. `Combat.apply()` → pure `DamagePipeline` (fixed stages); `HealthComponent`, `Hurtbox`, `Hitscan`, `BlockState` (F012 drives it); `cult_friendly_fire_scale`; player Dead state; training dummies; F5/F6/F7 debug keys |
| F012 | Melee v1 | done | ADR 0005. Hold LMB to charge, fire on release (full = heavy); swept-arc `MeleeSweep` (no cap, wall clang); weapon HSM with feint and buffered combo; `PoiseComponent`; guard-break stagger; greatsword; viewmodel; sparring dummy; F8/F9 |
| F013 | Parry/dodge/riposte | done | ADR 0006. Fresh-press parry window counted in ticks (±1 frame) + 0.5 s lockout; parry negates and stuns; parrier-only riposte ×`riposte_mult` (ignores block); `Grounded/Dodge` with attack-only i-frames; unparryable flag + purple sparring dummy; F3 parry timing readout |
| F014 | Firearms v1 | done | ADR 0007. `Loadout` (2 firearms + melee, draw-time switching, `replace_slot`, `grant_ammo`); `AmmoRules` (scarcity divides grants and multiplies costs, caps enforced); semi-auto hitscan `Firearm` (pellets, penetration ×0.6, bloom, ADS, per-round/whole reload, lowered while sprinting); revolver/blunderbuss/rifle; rifle pickup stand; temporary HUD, tracers, hit markers |
| F015 | Basic cultist AI (Acolyte) | done | ADR 0008. `EnemyBase` + brain HSM (Idle/Chase/Windup→Lunge→Recovery, Staggered/Stunned, Dead); `RuntimeNavRegion` (baked at load) + RVO avoidance, staggered repath/target timers; `AITargeting` (nearest Hunter + damage aggro, F031 hook); lunge swing via `MeleeSweep` (parry/block/dodge work); `enemy_killed` on death; spawn points, F10/Shift+F10/F11, AI ms in F3. AC tested at 60 acolytes (AI ≈2.3–2.8 ms/tick headless); rendering FPS needs a manual check |
| F016 | Points economy | done | ADR 0009. `PointRules` (applied × `points_per_damage_mult` × category 1/1.5/2, weak point ×1.5, riposte +50, each award rounded up to 10, no kill bonus, player→cult hits only); `PointsComponent` wallet (`award`, `can_afford`, `try_spend`, `Events.points_changed`); `Economy` autoload on `Combat.damage_applied`; price helpers (door/shop/ammo); `EconomyRules` content; removed `kill_bonus_points` and `kill_bonus_mult`; HUD balance + popups, F12 +1000, F3 last award |
| F017 | Doors & zones | done | ADR 0010. `Zone` (Area3D, `zone_id`, `starts_unlocked`, gates child spawn points); `Door` (DoorData, E to buy via `PointRules.door_price`, permanent; slab sinks, link enabled, zone unlocked, `door_opened`); nav baked with closed doors (`nav_blockers`) plus `NavigationLink3D`s; `Interactable` component + HUD prompt / "Not enough points" + door feed; sandbox annex with two doors (250/750) and a gated spawn point. Pickups deferred |
| F018 | Wall-buy, ammo stations, perk altar | done | ADR 0011. `ShopStation` base + `WallBuy` (buy into `firearm_slot_for_pickup` or the melee slot; refill if owned), `AmmoStation` (held gun, `grant_ammo`), `PerkAltar` (once, `max_perks`); `PerkComponent` + `Player.apply_perks` (Iron Constitution, Second Wind, Sure Grip, Riposte working; 3 stats deferred); per-viewer `Interactable` prompts; whitelists; `Events.item_purchased` feed (weapons and perks); rifle stand retired; sandbox shop in the arena and annex |
| F019 | Wave director v1 + round loop | done | ADR 0012. `MatchManager` drives `MatchFlow` (Lobby = free play, F4 → Intermission ⇄ WaveActive → Victory/Defeat → Results 5 s → sandbox reset); pure `WaveDirector` (counts total × `player_scale`, `budget_points` = alive cap, `spawn_rate`, `delay_s`, weights, KILL_ALL/QUOTA/SURVIVE + timeout) and `WaveRules` (spawn points ≥ `min_spawn_distance_m`, farthest fallback); `Player.respawn`; `dev_twelve` placeholder set (presets use it); HUD round/timer/banners; AC: the TestBot completes 12 waves headless (~150 s of game time in <1 s) |
| **M2** | **Multiplayer** | | |
| F020 | NetTransport abstraction + ENet lobby | todo | |
| F021 | Player replication | todo | |
| F022 | Server-authoritative combat | todo | |
| F023 | Enemy replication + host director | todo | |
| F024 | Steam transport | todo | |
| F025 | Settings replication & lobby UI v1 | todo | |
| **M3** | **Social layer (Betrayal)** | | |
| F030 | Role assignment & secret info channel | todo | |
| F031 | Friendly fire + traitor attack handling | todo | |
| F032 | Exposure: witnessed damage | todo | |
| F033 | Blessed Silver test | todo | |
| F034 | Death, loot bag, conversion queue | todo | |
| F035 | Player-controlled special framework | todo | |
| F036 | Stalker | todo | |
| F037 | Win/loss resolution & role reveal | todo | |
| F038 | Co-op (Vigil) rules | todo | |
| **M4** | **Enemy variety** | | |
| F040 | Hooked Priest | todo | |
| F041 | Plague Bloat | todo | |
| F042 | Abomination | todo | |
| F043 | Zealot, Flagellant | todo | |
| F044 | Director constraints | todo | |
| F045 | Default 12-wave WaveSet + presets | todo | |
| F046 | Boarded windows (barricades) | done | Built ahead of M2. ADR 0013. `Barricade` on the new BARRIER layer (blocks bodies, not attacks or sight); closet spawn points (`EnemySpawnPoint.barricade`); acolyte `Breach` (walk, swipe through, one tearer at a time) and `Climb` (0.8 s, uninterruptible) states; hold-E repair (`Interactable.hold_interval_s`), +10 per plank, uncapped; sandbox: 3 arena windows + 1 annex window, interior spawns removed |
| **M5** | **Content & polish** | | |
| F050 | MVP map greybox (Ashgrave) | todo | |
| F051 | HUD, scoreboard, ping | todo | Pre-work: the temp HUD has a bottom-left health bar + "HP current / max" (red ≤ 25 %) and a melee charge ring around the crosshair (amber = heavy ready), added 2026-11-11 |
| F052 | Text chat | todo | |
| F053 | Perks & consumables | todo | |
| F054 | Audio service | todo | |
| F055 | Performance pass | todo | |
| F056 | Main menu & level select (placeholder) | done | Built ahead of M2. `Game` routes (`load_level`, `go_to_menu`, `reload_level`, `quit` with a swappable `quit_handler`); `main.gd` swaps `MainMenu` ↔ a level `Session` (level, HUD, overlay, `PauseMenu`, debug tools). Play loads the F057 test level. Esc pause menu blocks gameplay input (`Game.gameplay_input_blocked`); F5 reloads the level |
| F057 | Placeholder playable level | done | Built ahead of M2. `maps/dev/test_level`: Start → Hall (750) → Vault (1250); 7 boarded windows with closet spawns (3/2/2); every wall-buy, both ammo stations, all 4 perks; `MatchManager.auto_start` + `end_action = MAIN_MENU`; `tests/world/test_level.gd` |
| **M6** | **Host power tools** | | |
| F060 | Full MatchSettings panel | todo | |
| F061 | In-lobby Wave Editor | todo | |
| F062 | Expansion specials | todo | |
| F063 | Body inspection, sabotage, downed, voice | todo | Stretch |
