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
| F010 | First-person controller | done | ADR 0003. Input source → intent → movement HSM → `PlayerMotor`; `StaminaComponent`; `PlayerDefaults`; local prefs in `Settings`; `main` boots `maps/dev/sandbox_arena`; F3 debug overlay. Feel needs a manual playtest |
| F011 | Damage pipeline | done | ADR 0004. `Combat.apply()` → pure `DamagePipeline` (fixed stages); `HealthComponent`, `Hurtbox`, `Hitscan`, `BlockState` (F012 drives it); `cult_friendly_fire_scale`; player Dead state; training dummies; F5/F6/F7 debug keys |
| F012 | Melee v1 | done | ADR 0005. Hold LMB to charge, fire on release (full = heavy); swept-arc `MeleeSweep` (no cap, wall clang); weapon HSM with feint and buffered combo; `PoiseComponent`; guard-break stagger; greatsword; viewmodel; sparring dummy; F8/F9 |
| F013 | Parry/dodge/riposte | done | ADR 0006. Fresh-press parry window counted in ticks (±1 frame) + 0.5 s lockout; parry negates and stuns; parrier-only riposte ×`riposte_mult` (ignores block); `Grounded/Dodge` with attack-only i-frames; unparryable flag + purple sparring dummy; F3 parry timing readout |
| F014 | Firearms v1 | done | ADR 0007. `Loadout` (2 firearms + melee, draw-time switching, `replace_slot`, `grant_ammo`); `AmmoRules` (scarcity divides grants and multiplies costs, caps enforced); semi-auto hitscan `Firearm` (pellets, penetration ×0.6, bloom, ADS, per-round/whole reload, lowered while sprinting); revolver/blunderbuss/rifle; rifle pickup stand; temporary HUD, tracers, hit markers |
| F015 | Basic cultist AI (Acolyte) | done | ADR 0008. `EnemyBase` + brain HSM (Idle/Chase/Windup→Lunge→Recovery, Staggered/Stunned, Dead); `RuntimeNavRegion` (baked at load) + RVO avoidance, staggered repath/target timers; `AITargeting` (nearest Hunter + damage aggro, F041 hook); lunge swing via `MeleeSweep` (parry/block/dodge work); `enemy_killed` on death; spawn points, F10/Shift+F10/F11, AI ms in F3. AC tested at 60 acolytes (AI ≈2.3–2.8 ms/tick headless); rendering FPS needs a manual check |
| F016 | Points economy | done | ADR 0009. `PointRules` (applied × `points_per_damage_mult` × category 1/1.5/2, weak point ×1.5, riposte +50, each award rounded up to 10, no kill bonus, player→cult hits only); `PointsComponent` wallet (`award`, `can_afford`, `try_spend`, `Events.points_changed`); `Economy` autoload on `Combat.damage_applied`; price helpers (door/shop/ammo); `EconomyRules` content; removed `kill_bonus_points` and `kill_bonus_mult`; HUD balance + popups, F12 +1000, F3 last award |
| F017 | Doors & zones | done | ADR 0010. `Zone` (Area3D, `zone_id`, `starts_unlocked`, gates child spawn points); `Door` (DoorData, E to buy via `PointRules.door_price`, permanent; slab sinks, link enabled, zone unlocked, `door_opened`); nav baked with closed doors (`nav_blockers`) plus `NavigationLink3D`s; `Interactable` component + HUD prompt / "Not enough points" + door feed; sandbox annex with two doors (250/750) and a gated spawn point. Pickups deferred |
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
