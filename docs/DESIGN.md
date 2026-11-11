# Working Title: *Vigil of Ash* — Design Document

> **Status:** v0.1, draft agreed with the project owner. **Engine:** Godot **4.7.2** (mono build installed; C# unused until §12.4). Forward+ renderer, Jolt 3D physics.
> **How to use this document:** it is written for incremental implementation by Claude sessions. Read §0 first, then jump to the feature you are building in §14 (Roadmap). Every feature has an ID, dependencies and acceptance criteria. Do not implement more than one feature ID per session unless they are tiny.

---

## 0. Quick Reference for Implementers

| Topic | Decision |
|---|---|
| Genre | Round-based first-person co-op/social-deduction horde shooter-brawler |
| Players | 2–8 (default 6). Traitor mode requires ≥4 by default (host can override with a warning) |
| Perspective | First-person |
| Languages | **GDScript by default.** C# only for profiled hot paths (see §12.4). Do not add C# until a feature explicitly calls for it |
| Networking | Listen-server, **host-authoritative**. Transport abstracted: Steam (GodotSteam) first-class, ENet for LAN/direct-IP/dev |
| Maps | Hand-built, door-gated zones unlocked with points |
| Art/audio | **Greybox + placeholders only.** Assets are referenced via swappable slots (§13) |
| Content | Data-driven: weapons, enemies, waves, perks are Godot `Resource` (`.tres`) files |
| Modes | Traitor mode ("Betrayal") and Co-op mode ("Vigil") |
| Win | Hunters survive to **end of Round 12**; traitors (and the cult) win by eliminating all living Hunters first |

**Guiding rules**
1. **Server decides, clients display.** All damage, points, spawns, role assignment and win checks run on the host. Clients send *inputs/intents* only.
2. **Data over code.** Adding a weapon, enemy or wave must not require editing core scripts.
3. **Secret information stays on the server.** A traitor's role is sent only to that traitor's peer (and to others only once exposed).
4. **Greybox first.** A feature is "done" when it plays well with primitives. Visual polish is a separate track.
5. **Everything the host can tune goes through one `MatchSettings` resource** (§9). Never hard-code a number that a host might reasonably want to change.

---

## 1. Vision & Pillars

**Pitch:** Late-medieval knights and Victorian gothic horror, in the vein of *Bloodborne*. A band of **Hunters** holds out against waves of a demonic cult. Somewhere among them is a **traitor** wearing a Hunter's face. Every death feeds the cult: fall to its blades or to a friend's betrayal, and you rise as one of its horrors.

**Pillars**
1. **Dread through scarcity.** Ammo is rare and expensive; melee is the bread and butter, firearms are for emergencies and priority targets.
2. **Trust is a resource.** Spending points, sharing space, and who-was-where-when matter. The traitor creates doubt just by being near you.
3. **Death is not an exit.** Dead Hunters become the enemy (in Betrayal mode) — the squad shrinks and the horde gains intelligence.
4. **Escalation you can read.** Waves ramp predictably; special enemies force different responses (L4D2-style counters).
5. **The host is the game master.** Wave composition and rules are broadly customisable (Firefight-style).

**Tone/aesthetic:** gothic, damp, candlelit; plate and mail alongside tailcoats, flintlock/early-cartridge firearms, silver, holy symbols, blood-red cult sigils. Palette for greybox: desaturated greys with a single red accent for cult, warm amber for Hunters/interactables.

---

## 2. Decision Log (resolved with owner)

| # | Decision | Notes |
|---|---|---|
| D1 | GDScript + C# hybrid | GDScript default; C# reserved for perf-critical systems. Requires Godot **.NET** build if/when used |
| D2 | First-person | Viewmodel-based melee/firearms |
| D3 | Listen-server with Steam/relay | Abstract transport behind `NetTransport` (§12.2) |
| D4 | Hand-built, door-gated zone maps | |
| D5 | Traitor: hidden role, revealed on exposure | |
| D6 | Dead Hunter respawns as a special enemy after a delay (Betrayal mode) | |
| D7 | Converted players are on the **cult's** side | They win if Hunters are wiped |
| D8 | MVP specials: **4**, expandable via data | Roster in §7 |
| D9 | Loadout: **2 firearms + 1 melee** | Scarce ammo |
| D10 | Traitor has **no special equipment**; only a different win condition | Exposure tells are the social hook (§5.3) |
| D11 | 2–8 players | |
| D12 | Greybox/placeholders | |
| D13 | Melee: stamina-based light/heavy, block, parry, dodge | |
| D14 | Exposure: blessed-silver test + witnessed damage | |
| D15 | Co-op death: spectate, **respawn next wave as a Hunter**; no conversion | |
| D16 | Waves are data-driven `Resource`s; **in-lobby editor is a later milestone**; MVP ships presets | |

Open/assumed items are in §15.

---

## 3. Game Modes

### 3.1 Betrayal (traitor mode)
- Roles: **Hunter**, **Traitor** (secretly a Hunter-in-disguise), and **Cultist** (converted dead Hunters; player-controlled specials).
- Friendly fire: **ON by default** (needed for traitor play; host-configurable).
- Hunter win: at least one living Hunter at the **end of Round 12** (and all traitors dead or Round 12 cleared – see §4.4).
- Traitor/Cult win: **no living non-traitor Hunters** before Round 12 ends.
- Dead Hunters (killed by traitor, cultists, or friendly fire) convert into specials (§6).

### 3.2 Vigil (co-op mode)
- No traitors. Friendly fire **OFF by default**.
- Objective: survive through Round 12.
- Dead Hunters **spectate, then respawn at the start of the next wave as a Hunter** (D15). No conversion.
- Loss: all Hunters dead simultaneously (a "wipe") — host option to allow checkpoint retry (post-MVP).

> Mode is just a preset of `MatchSettings`; the same code paths run both. Do not fork the codebase per mode.

---

## 4. Core Match Flow

### 4.1 Lifecycle (state machine on the server)
`Lobby → Loading → Intermission(R1 setup) → WaveActive → WaveClear/Intermission → … → WaveActive(R12) → Victory | Defeat → Results → Lobby`

- **Intermission** (default 30 s, host-configurable): shop access, door purchases, respawn of dead co-op players, role-reveal hints. Skippable by majority vote (host option).
- A wave ends when its **kill quota is met** (or timer, whichever the wave resource specifies).
- Round counter 1..N; N defaults to 12 (host-configurable 3–30).
- *Implemented in F019* ([ADR 0012](adr/0012-wave-director.md)):
  - **The loop:** `MatchManager` drives `MatchFlow`. A plain `intermission_s` countdown (no skip vote, no regen yet) leads into each wave.
  - **Ending:** clearing round `min(final_round, set length)` gives Victory; no living Hunter gives Defeat. Results lasts 5 s.
  - **Sandbox:** the arena is free play until F4, and returns to free play after Results (players revived, enemies cleared).

### 4.2 Role assignment (Betrayal)
- Server assigns at match start. Traitor count = `floor(players / hunters_per_traitor)`, min 1 if `traitors_enabled`; default ratio 1 traitor per 5 players (so 4–5 → 1, 6–9 → 1 up to 8 players; host can set ratio or exact count).
- Each client receives **only its own role** (RPC to a single peer). A traitor does *not* learn other traitors by default (host option: traitors know each other).
- Roles are stored server-side in `RoleComponent` on each player; clients get `is_exposed` replicated publicly.

### 4.3 Dying and conversion (Betrayal)
1. Player's HP reaches 0 → "killed outright" (no down state by default; `downed_state` is a later host option).
2. Body drops loot; player enters **Cult Respawn Queue** (default delay 15 s, tied to wave pacing; host-configurable).
3. They respawn as a player-controlled special (§7) at a cult spawn point out of Hunter line of sight. Class assigned from a pool (default: random weighted by what the director wants; later: player choice).
4. Converted players have an independent cooldown/respawn if their special dies (default: re-queue as the same or a different special with a longer delay each time).
5. A traitor who dies also converts (they were secretly aligned with the cult but die as monsters; they now play as Cultists).

### 4.4 Win/Loss
- **Hunters win:** survive past Round `N` with ≥1 living non-converted Hunter. In Betrayal, remaining traitors are not required to be dead — it is a pure survive objective for Hunters.
- **Traitor/Cult win:** zero living, non-traitor Hunters at any time before end of Round `N`.
- **Vigil:** win = Round `N` complete; lose = all Hunters dead simultaneously with none queued to respawn.
- Edge: if only traitors remain alive among Hunters, Betrayal immediately resolves as a traitor/cult win.

---

## 5. Roles & Social Systems

### 5.1 Hunter
Standard player. Earns points, buys gear, opens doors, may attempt to expose suspects.

### 5.2 Traitor
- Looks and plays identically to a Hunter; same loadout rules, same shop (D10).
- **Objective:** eliminate all non-traitor Hunters.
- **AI targeting:** cultist AI treats traitors as **non-hostile** while hidden, and (assumed, §15) remains passive toward them even after exposure — exposure changes how Hunters treat them, not the AI.
- Traitors earn points from cultist damage like Hunters (keeps their cover plausible) and **no points for Hunter damage**.
- Hunters killed by a traitor convert like any other death.

### 5.3 Exposure (D14)
Three triggers:
1. **Witnessed aggression.** If a traitor damages or kills a Hunter while at least one *other living Hunter* has line-of-sight to them within `witness_radius` (default 20 m, FOV-checked on server), they become **Exposed**. Brief 0.5 s grace on the first hit (to avoid friendly-fire misfires) is a host option.
2. **Blessed Silver test.** Purchasable consumable item (*Blessed Silver Vial*; cost/stock configurable). Using it on a target within 2 m for a 2 s channel: a traitor is **Exposed** (visible reaction), a Hunter is unaffected but is told "clear" privately to the tester and publicly broadcast "X was tested" (tester accountable). Limited stock per round.
3. **Body inspection (later milestone).** Inspecting a corpse reports damage type/weapon class (not killer identity) — TTT-style evidence.

**Exposed state:** a public HUD marker, a sigil on the nameplate, voice-line sting. Exposed traitors keep playing; Hunters are expected to kill them. A kill of an exposed traitor gives the killer a point bounty (default 500; configurable).

### 5.4 Communication
- Proximity text/voice is a later milestone; MVP uses text chat with global + team channel (Hunters; cultists have their own private channel in Betrayal).
- Ping/marker system (late MVP) to point out suspicious activity.

---

## 6. Players, Movement & Combat

### 6.1 Player stats (defaults, all in `PlayerDefaults.tres`)
Health 100, regen only between waves (host option); Stamina 100 (regen 20/s after 1 s idle); walk/sprint speeds 4.5/7 m/s; jump; crouch.
*Implemented in F010:* the class is `PlayerDefaults` (`src/data/player/player_defaults.gd`), shipped as `content/player/player_defaults/player_defaults.tres`. The controller design is in [ADR 0003](adr/0003-player-controller.md). In F010 only sprinting drains stamina (12/s); reaching 0 locks sprint until stamina regenerates to 30. Sprint is grounded and forward-only (within 45°). Crouch is hold or toggle (a player preference), with a ceiling check.

### 6.2 Loadout (D9)
- Slot 1: Firearm A, Slot 2: Firearm B, Slot 3: Melee. Plus a single-use consumable quick slot (heal item, silver vial, throwable).
- Swap, buy, and pick up replace slots. Each melee/firearm is a `WeaponData` resource.
- *Implemented in F014* ([ADR 0007](adr/0007-firearms-loadout.md)):
  - `Loadout` holds slots 1/2 (firearms) and 3 (melee), with per-slot ammo, and players spawn with melee out;
  - keys 1/2/3 and the wheel switch weapons, with a short draw time;
  - `Loadout.replace_slot()` is the purchase/pickup API.

### 6.3 Melee (D13) — the core of the game
- **Light attack:** fast, low stamina, low stagger. **Heavy attack:** hold to charge, high damage/stagger, high stamina.
  - *Implemented in F012* ([ADR 0005](adr/0005-melee.md)):
    - LMB fires **on release**: full charge gives an overhead heavy; an earlier release gives a horizontal light.
    - Lights alternate sides, and a light released near the end of recovery is buffered and chains into the next.
    - Block during windup **feints**.
    - Attacking needs stamina > 0, and the cost may exhaust you.
    - Attacking or blocking slows you and stops sprinting.
    - Swings are swept arcs that hit everything they touch (one hit per target). A wall in the arc **clangs** and ends the swing.
    - Stagger builds **poise**; crossing `stagger_resist` staggers the target.
    - A guard break staggers the blocker for 1 s.
- **Block:** hold; reduces damage by `block_reduction`; drains stamina based on damage absorbed; 0 stamina = guard break and stagger.
  - It only covers a **frontal arc**, `block_arc_deg` (default 120°), and only melee damage.
  - A hit the remaining stamina can't pay for is still fully blocked, but drains stamina to 0 (guard break). The next hit lands in full.
  - The math is in [ADR 0004](adr/0004-damage-pipeline.md).
- **Parry:** a block pressed within the parry window (default 200 ms) stuns the attacker and opens a **riposte** window (bonus damage). Not all enemies are parryable (Abomination attacks must be dodged).
- **Dodge:** brief i-frame sidestep/backstep costing stamina.
- *Implemented in F013* ([ADR 0006](adr/0006-parry-dodge.md)):
  - **Parry:**
    - only a *fresh* block press opens the 200 ms window, measured in physics ticks (±1 frame);
    - a missed window locks parrying out for 0.5 s;
    - a parry negates the hit (no stamina) and stuns the attacker for `parry_stun_s`.
  - **Riposte:** the parrier's next melee hit on that stunned attacker deals × `riposte_mult` and ignores block.
  - **Dodge:**
    - Alt + direction (a backstep without input): about 3 m over 0.3 s, with i-frames for the first 0.2 s;
    - costs 20 stamina, with a 0.4 s cooldown;
    - cancels block and recovery;
    - the i-frames negate melee, bullets and blasts, but not falls or hazards.
  - **Unparryable attacks** ignore parry *and* block, so they must be dodged.
- **Hit detection:** server-authoritative; swing = a time-windowed shape query (`ShapeCast3D`) along the weapon's swing arc during the animation's "active frames". Clients play the swing instantly (prediction) and the server confirms hits.
- **Weapon archetypes (MVP):** Arming Sword, Greatsword, Mace/Warhammer, Spear, Flail. Parameters: damage, reach, swing times, stamina cost, stagger, block power, parry window, special.
- Melee damage grants points per hit, with more for a weak-point hit and a bonus for a riposte. There is no kill bonus (§10.1).

### 6.4 Firearms
Pistol-class and long-gun-class (flintlock-flavoured but cartridge-based for rate of fire): Revolver, Blunderbuss (shotgun-like), Rifle, Repeating Carbine, later Crossbow (silent, rare ammo). Each: damage, falloff, mag size, reserve cap, reload time, spread, recoil pattern, penetration.

**Ammo scarcity (design requirement):**
- Reserve ammo caps are low (default ~2 magazines).
- Ammo is obtained from (a) rare world pickups, (b) wall-buy ammo purchases at a high point cost that scales per weapon tier, (c) cultist drops with low chance. Host multiplier `ammo_scarcity` (0.25×–3×) scales drops and costs.
- *Implemented in F014* ([ADR 0007](adr/0007-firearms-loadout.md)):
  - **Scarcity:** `ammo_scarcity` **divides every ammo grant** (including the spawn reserve) and **multiplies ammo costs**. Higher is scarcer, and caps are never scaled.
  - **Firing:** semi-auto hitscan, with pellets and penetration (×0.6 per combatant passed). Accuracy is spread bloom; there's no view recoil.
  - **Aiming and sprint:** RMB aims (tighter, slower, zoom). The gun is lowered while sprinting.
  - **Reload:** an interruptible top-up, done per round on the revolver.
  - **Guns:** revolver, blunderbuss, rifle.

### 6.5 Friendly fire
Per-mode default in §3, host-toggle, plus `friendly_fire_scale` (0–200%). Melee friendly fire is always scaled by the same factor. Reflected/self-damage can be disabled independently.

Cult-on-cult damage happens only from attacks flagged `hits_allies` (explosions, sweeps), scaled by `cult_friendly_fire_scale`. Ordinary cult melee never hurts other cultists. World damage (falls, hazards) ignores friendly-fire rules. Implemented in F011: see [ADR 0004](adr/0004-damage-pipeline.md).

---

## 7. Enemies

### 7.1 Common cultists (AI-controlled)
| Type | Role | Notes |
|---|---|---|
| Acolyte | Fodder melee | Slow-moderate, low HP, swarm |
| Zealot | Fast melee | Charges, low HP |
| Flagellant | Heavy melee | Armoured; parry-able |
| Cultist Gunman (later) | Ranged | Scarce, dangerous |

Common AI: navmesh pathing to nearest valid target (NOT traitors); simple melee attack state machine; attack telegraphs that are parry-readable. Perf budget: ≥60 active AI at 60 fps on host; use group/tick throttling (§12.5).

> Implemented in F015 (Acolyte): see [ADR 0008](adr/0008-enemy-ai.md).
> - **Movement:** a navmesh baked at map load, RVO avoidance (enemies do not collide with each other, but do collide with players). Path and target updates run on staggered timers.
> - **Targeting:** the nearest living Hunter, but whoever last damaged the enemy takes priority for `aggro_memory_s`.
> - **Attack:** a telegraph (glow + raised arm) that tracks slowly, then the direction locks and it lunges with a `MeleeSweep` swing, followed by a punishable recovery.
> - **Reactions:** poise stagger and parry stun interrupt it.
> - **Death:** emits `Events.enemy_killed`.

### 7.2 Special enemies (L4D2-inspired, re-themed)

**MVP roster (D8):**

| Special | L4D2 analogue | Behaviour | Counterplay |
|---|---|---|---|
| **Stalker** | Hunter | Lurks, leaps and pins a target with claws | Hear the screech, parry/dodge the leap, kill quickly while pinned (teammate melee) |
| **Hooked Priest** | Smoker | Long-range chain/hook yanks and strangles a target from range | Cut the chain with melee/hit the priest; line-of-sight break |
| **Plague Bloat** | Boomer | Bursts into a cloud/gore that draws all nearby cultists | Shoot at range; avoid bursting near allies; cloud drains stamina |
| **Abomination** | Tank | Huge HP, ground-pound, thrown debris, hard to stagger | Kite, dodge (not parryable), focus fire |

**Expansion roster (data-only additions):** Brute (Charger), Acid Witch (Spitter, area denial), Gargoyle (Jockey, steers a player), Weeping Bride (Witch — passive until startled, one-hit killer).

All specials are defined by `EnemyData` resources and implemented as a state machine on a common `SpecialBase`. **Both AI-controlled and player-controlled variants share the same abilities**; the controller (AI vs player) is the only difference (§7.3).

### 7.3 Player-controlled specials (cult conversion)
- Converted players use the same first-person controller with an `EnemyData`-defined ability set (movement overrides, 1–3 abilities with cooldowns).
- Cult spawn points are placed out of Hunter LOS; the server picks the one furthest from Hunters that satisfies spawn rules.
- Tradeoff: converted players are strong but fragile and respawn on a timer, so they **harass** rather than snowball. The AI Director limits total specials (§8.3) counting players.
- Converted players have no points economy, but get "cult favour" (cosmetic score) for kills.

### 7.4 Director (Spawner)
A light "AI Director" decides *when/where* to spawn enemies within a wave's budget and enforces constraints (spawn out of sight, special caps, spacing). Implemented as `WaveDirector` (server only). Details in §8.

---

## 8. Waves & Rounds

### 8.1 Wave structure
A **Round** is one wave resource instance. Round 12 is the final. Each wave is defined by `WaveData` (a `Resource`):

```
WaveData
  - round_index: int (informational)
  - budget_points: int           # director spends this on spawns
  - entries: Array[WaveEntry]
      - enemy: EnemyData
      - count: int (or min/max)
      - weight: float
      - spawn_group: enum {ANY, ZONE_ONLY, ELITE_ROOM}
      - delay: float
  - special_cap: int             # concurrent specials (player + AI)
  - boss: EnemyData (optional)
  - modifiers: Array[WaveModifier]   # e.g. fast, armoured, fog, no_hud_markers
  - spawn_rate: float
  - timeout_s: float (optional)
  - clear_condition: enum {KILL_ALL, KILL_QUOTA, SURVIVE_TIME}
```

> Implemented in F003: `src/data/waves/` (`WaveSet`, `WaveData`, `WaveEntry`, `WaveModifier`). The field names in the code are authoritative. See [ADR 0002](adr/0002-content-data-model.md).
>
> F019 semantics ([ADR 0012](adr/0012-wave-director.md)):
> - **Counts:** each entry's count is rolled and scaled by `player_scale[living Hunters]`, and is the wave's **total**.
> - **`budget_points`** caps the summed `budget_cost` of the wave's **living** enemies, so big waves trickle in at `spawn_rate`.
> - **Clearing:** a wave clears on its `clear_condition` (or `timeout_s`). Leftovers from quota or time waves keep fighting.
> - **Modifiers** and enemy multipliers aren't applied yet (F044/F045).
> - **Placeholder set:** `dev_twelve` is the 12-round placeholder set used by the presets until F045.

A **`WaveSet`** is an ordered `Array[WaveData]` (12 by default). Presets (MVP): *Default*, *Horde* (huge swarm, few specials), *Specials Only*, *Slow Burn*.

### 8.2 Default difficulty curve (shipping preset)
| Rounds | Content |
|---|---|
| 1–2 | Acolytes only, small counts. Tutorial pacing |
| 3–4 | + Zealots; first Plague Bloat in R4 |
| 5–6 | + Flagellants; Stalker introduced R5; Hooked Priest R6 |
| 7–9 | Mixed with 2–3 specials; elite rooms |
| 10–11 | Heavy pressure, specials cap rises; mini-event in R10 |
| 12 | Final stand: Abomination boss wave + swarms; survive until quota met |

Tune numbers in data only (spreadsheet-style `.tres` or `.csv` import is acceptable).

### 8.3 Director rules
- Spawns only at valid `SpawnPoint` nodes not visible to any living Hunter's camera frustum within `min_spawn_distance` (default 15 m).
- Obeys `special_cap`, per-type cooldowns, "breather" periods (no special spawns for N seconds after a hit).
- Scales counts by living player count (`player_scale` curve in settings).
- Unlocked-zone gating: only spawns in/adjacent to opened zones (plus "ambient" spawns in closed zones for door-opening tension — configurable).
- *F019 implements:* active (unlocked-zone) points only, at least `min_spawn_distance_m` from every living Hunter, picked at random (seeded). If none qualify, it falls back to the farthest active point. Visibility, caps, breathers and ambient spawns are F044.
- *F046:* a spawn point can sit in a **closet** behind a boarded window (`EnemySpawnPoint.barricade`). Enemies spawned there must breach the window before they reach anyone (§11).

### 8.4 Host customisation of waves (Firefight-style)
- **MVP:** pick preset; adjust a few global sliders (enemy health ×, damage ×, spawn rate ×, special frequency ×).
- **Later (M-WaveEditor):** an in-lobby editor to build/edit `WaveSet`s: per-wave enemy composition, counts, modifiers, timers; save/load presets as `.tres`/JSON and share via lobby.
- Data format must remain editor-friendly: plain resources with exported fields and validation (`WaveData.validate()`).

---

## 9. Host Customisation: `MatchSettings`

Single `Resource` replicated to all clients when the lobby locks. It is implemented in F003 as `src/data/match/match_settings.gd`, which is authoritative for field names and defaults. The presets are in `content/match_presets/`. Draft fields (group by category in the lobby UI):

**Lobby / Players**
- `max_players` (2–8), `mode` (BETRAYAL/VIGIL), `public/private`, `allow_join_in_progress`, `late_join_role` (hunter or spectator)

**Roles**
- `traitors_enabled`, `traitor_count_mode` (ratio/exact), `hunters_per_traitor` (default 5), `traitors_know_each_other`, `exposed_bounty`

**Rules**
- `friendly_fire` + `friendly_fire_scale`, `self_damage`, `cult_friendly_fire_scale` (F011), `final_round` (default 12), `intermission_s`, `player_health_mult`, `regen_mode`, `conversion_enabled` (Betrayal default on), `respawn_delay_cult_s`, `coop_respawn_rule`

**Economy**
- `points_per_damage_mult` (F016: scales points per damage before rounding), `starting_points`, `shop_price_mult`, `ammo_scarcity` (F014: divides ammo grants, multiplies ammo costs, never scales caps), `door_cost_mult`, `loot_quality`

**Enemies / Waves**
- `wave_set` (resource), `enemy_health_mult`, `enemy_damage_mult`, `enemy_speed_mult`, `special_freq_mult`, `special_cap_override`, `player_scale_curve`

**Weapons/Perks**
- `allowed_weapons[]` (whitelist/blacklist), `allowed_perks[]`, `starting_loadout`

**Misc**
- `match_seed`, `spawn_visibility_rules`, `hud_options` (hide nameplates, hide minimap), `voice/proximity`

Validation: `MatchSettings.validate()` returns warnings (e.g., "Traitor mode with <4 players") — warn, never hard-block, except impossible values.

---

## 10. Economy, Shops & Progression

### 10.1 Points (per player)
- **Earned by dealing damage** to cultists (not kills only): `points = damage_dealt × tier_multiplier`, so supporting fire is rewarded. Bonuses: weak-point, parry-riposte, exposed-traitor kill.
- *Implemented in F016* ([ADR 0009](adr/0009-points-economy.md)):
  - **Formula:** `applied × points_per_damage_mult × category mult`. The category is the target's: COMMON 1.0, SPECIAL 1.5, BOSS 2.0.
  - **Bonuses:** ×1.5 on a weak-point hit, +50 for a landed riposte.
  - **Rounding:** each award is rounded **up** to a multiple of 10, so any damaging hit pays at least 10.
  - **No kill bonus.** Overkill never pays, because only damage actually removed counts.
  - **Who earns:** only a player's hostile hit on a cult target (training dummies included).
  - **Tuning:** the numbers are in `content/economy/economy_rules`.
- **Barricade repair** (F046, [ADR 0013](adr/0013-barricades.md)): +10 per plank nailed back (`BarricadeData.repair_points`, rounded like every award). Uncapped, and it pays at any time, intermission included.
- Points are **per-player and private**; not shareable by default (host option `allow_gifting`).
- Not earned for friendly-fire damage (negative penalty option).
- Traitors earn points from cultists normally (cover).

### 10.2 Spend
1. **Doors** — open zones (`DoorData.cost` × `door_cost_mult`, F017). Opening zones expands spawn areas, unlocks better loot (§10.4).
2. **Wall-buy stations** — weapons and ammo; costly ammo to enforce scarcity.
3. **Perk altars** (Victorian-gothic "Sacraments"): e.g., *Iron Constitution* (+HP), *Second Wind* (stamina regen), *Sure Grip* (faster reload), *Riposte* (stronger parry), *Alms of the Dead* (extra loot), *Hallowed Edge* (damage vs specials). Max perks configurable (default 4).
4. **Mystery chest / Reliquary** — random weapon for a fee (later milestone).
5. **Consumables** — healing draught, Blessed Silver Vial, throwables.

*Implemented in F018* ([ADR 0011](adr/0011-shops-perks.md)):
- **Wall-buys** sell a weapon for `shop_price(wall_cost)`. A firearm goes into the active, empty or first firearm slot, and the old one is discarded. If you already own the gun, the wall-buy refills its reserve for `ammo_price(ammo_cost)`. A melee wall-buy replaces the melee slot.
- **Ammo stations** refill the held gun's reserve (`grant_ammo`, so scarcity and the cap apply).
- **Perk altars** sell one perk each, once, up to `max_perks`.
  - Working perks: Iron Constitution (+25 max and current HP), Second Wind (stamina regen ×1.5), Sure Grip (reload ×1.4 faster), Riposte (riposte ×1.3).
  - `parry_window_add`, `loot_luck_mult` and `special_damage_mult` aren't implemented yet.
- **Whitelists:** `allowed_weapons` / `allowed_perks` disable stations.
- **Announcements:** weapon and perk purchases are announced publicly; ammo refills aren't.

### 10.3 Death/point penalty
Dying in Co-op: lose a fraction of points (default 25%, configurable) — dropped as a pickup. In Betrayal, dying converts you; your points drop on the body as a lootable bag (an incentive and a suspicion tell).

### 10.4 Loot tables
Zones have `LootTable` resources; deeper zones carry higher tier weights. Pickup frequency scaled by `ammo_scarcity` and `loot_quality`.

---

## 11. Maps & Level Design

- **Structure:** each map is a Godot scene composed of **Zones** (`Zone` node = area + navmesh region + spawn points + loot spawns + doors). Zones are linked by **Doors** with a point cost. Enemies enter through **boarded windows** (barricades) from spawn closets outside the playable area.
- **MVP map ("Ashgrave Cathedral & Cloister"):** 5–6 zones, hub start (Crypt Chapel), progressing to nave, cloister, bell tower, catacombs, and a final sanctum for Round 12. Greybox with clear sightlines/ambush spots, choke points, and loops for kiting.
- **Gameplay-affordances to include:** cult spawn points (player-controlled specials), safe-ish retreat corners, silver-vial pickup spots, sabotage spots for traitors (e.g., collapsing a door barricade) — *sabotage is a stretch goal, not in MVP.*
- **Navigation:** one `NavigationRegion3D` per zone; doors toggle navmesh regions/links.
- *Implemented in F017* ([ADR 0010](adr/0010-doors-zones.md)):
  - **Zones:** a `Zone` is an Area3D with a `zone_id`. Its child `EnemySpawnPoint`s are active only while it's unlocked, and the start zone uses `starts_unlocked`.
  - **Doors:** a `Door` uses `DoorData`. Pressing E spends `PointRules.door_price` (× `door_cost_mult`), and the door opens **permanently**. Opening any door into a zone unlocks it, and other doors into the same zone are bought separately.
  - **Navigation:** one navmesh is baked with closed doors as walls (`nav_blockers`). Each door enables its `NavigationLink3D` when opened, so the map is never re-baked.
  - **Announcements:** every door opening is announced publicly ("Player N opened the X"), without the cost.
- *Implemented in F046* ([ADR 0013](adr/0013-barricades.md)):
  - **Boarded windows:** a `Barricade` fills a gap in a wall. It holds `BarricadeData.plank_count` planks (6) and sits on the BARRIER physics layer: it always blocks bodies, but shots, swings and sight lines pass through.
  - **Closets:** each window has a small closet outside with its spawn point. The closet is its own nav island.
  - **Enemies:** an enemy spawned in a closet walks to the window and tears one plank per `EnemyData.barricade_tear_s` (one tearer per window; the rest wait). It swipes through at any player within reach. At zero planks, it climbs in (0.8 s, one at a time, can't be interrupted) and then chases normally.
  - **Players:** hold E on the inside to nail a plank back every 0.75 s for points (§10.1).
- **Verticality:** moderate; no climbing mechanics in MVP.
- Level data files: `maps/<map_id>/map.tscn`, `map_data.tres`.

---

## 12. Technical Architecture (Godot)

### 12.1 Project layout
```
/project.godot
/docs/DESIGN.md                (this file)
/docs/adr/                     (architecture decision records; add as decisions arise)
/src
  /autoload                    # singletons: Game, Net, Settings, Events, Audio
  /core                        # state machine, utils, resource validators
  /net                         # transport abstraction, lobby, replication helpers
  /match                       # MatchManager, WaveDirector, RoleService, EconomyService
  /player                      # PlayerController, components (Health, Stamina, Loadout, Role)
  /combat                      # WeaponBase, MeleeWeapon, Firearm, Hitbox/Hurtbox, DamageEvent
  /enemies                     # EnemyBase, AIController, specials/<name>/
  /world                       # Zone, Door, Shop, Pickup, SpawnPoint, LootTable
  /ui                          # HUD, lobby UI, shop UI, scoreboard, settings editor
  /data                        # Resource script classes (WeaponData, EnemyData, WaveData, ...)
/content                       # actual .tres data instances (weapons, enemies, waves, perks)
/maps
/assets                        # placeholders → final art (see §13)
/tests                         # GUT/gdUnit4 tests
```

### 12.2 Networking
- Use Godot's **high-level multiplayer API** (`MultiplayerAPI`, RPCs, `MultiplayerSpawner`, `MultiplayerSynchronizer`).
- **Transport abstraction:** `NetTransport` interface with `EnetTransport` (default for dev/LAN/direct IP) and `SteamTransport` (GodotSteam `SteamMultiplayerPeer`, lobbies + relay). The rest of the code only talks to Godot's `MultiplayerPeer`/`multiplayer`, so swapping transport must not touch gameplay code.
- Server peer id = 1. All authoritative systems check `multiplayer.is_server()`.
- **Replication:** player transform/state via `MultiplayerSynchronizer` (client-authoritative *input* → server-simulated movement is the target; for MVP, accept owner-authoritative movement with server validation of speed/teleports). Enemy state is server-simulated and replicated at a reduced rate with interpolation.
- **Secret data:** role info is held only in the server's `RoleService` and pushed via targeted `rpc_id`. Never replicate role fields in a public synchronizer.
- **Lag/prediction:** melee swings & firing play locally immediately; hits are resolved on the server using the shooter's reported aim and a bounded lag-compensation window (≤150 ms rewind of enemy positions). Keep it simple for MVP: hitscan resolves on server using the shooter's camera ray; server accepts it if within tolerance.
- **Join/leave:** handle host migration as *not supported* (match ends if the host leaves). Late join per `MatchSettings`.

### 12.3 Core systems (component style)
- **Player** is a `CharacterBody3D` with child components: `HealthComponent`, `StaminaComponent`, `LoadoutComponent`, `RoleComponent` (server-owned), `PointsComponent`, `PerkComponent`, `ExposureComponent`.
- **Damage pipeline** (implemented in F011; fixed stage order in [ADR 0004](adr/0004-damage-pipeline.md); entry point `Combat.apply()`): a single `DamageEvent` object (source, target, amount, type, weakpoint, weapon) processed by `DamageService` on the server → applies mods (block/parry/perks/FF scale) → emits `damage_applied` signal → `EconomyService` awards points, `RoleService` checks exposure, `ConversionService` handles death.
- **Event bus:** autoload `Events` with typed signals (`wave_started`, `player_died`, `player_exposed`, `door_opened`, …). Systems communicate through signals, not direct node paths.
- **State machines:** a reusable hierarchical `StateMachine` (node + `State` children) for enemies, weapons and match flow. See [ADR 0001](adr/0001-hierarchical-state-machine.md).

### 12.4 GDScript / C# split (D1)
- All gameplay logic starts in **GDScript** with static typing everywhere (`var x: int`, typed arrays, `class_name`).
- Candidate C# modules **only if profiling shows need**: `WaveDirector` spawn-point scoring, crowd AI steering/avoidance, lag-compensation history buffers. Interop boundary: C# classes expose methods called from GDScript; keep them stateless where possible. Adding C# requires: Godot .NET build, `*.csproj`, CI note in README. **Do not add C# during early milestones.**

### 12.5 Performance targets
- 60 FPS on host at 8 players + 60 active AI + 8 player-specials on a mid-range PC.
- Techniques: AI tick throttling by distance/LOD, pooled enemies/projectiles/decals, `MultiMesh` for crowds if needed, shared navmesh queries, spatial hash for director visibility checks.

### 12.6 Testing
- Use **gdUnit4** (or GUT) for unit tests of pure logic: damage math, economy, wave budgeting, role assignment, win conditions, settings validation.
- Provide a **headless server test** scene that simulates a match with bots for smoke testing netcode.
- Any new data class must ship with a validator test.

---

## 13. Assets, Audio & UI (Placeholder Strategy — D12)

- **Greybox only:** capsules/boxes for characters, primitive viewmodels (box sword), coloured materials by faction: Hunter amber, Cult red, Neutral grey.
- **Asset slots:** every `*Data` resource has optional `scene`, `icon`, `sfx_*` fields; if null, the code uses a built-in placeholder. Replacing art = filling a slot, never editing logic.
- **Naming:** `snake_case`; folder per content item: `/content/weapons/arming_sword/{arming_sword.tres, model.glb, icon.png, sfx_swing.ogg}`.
- **Audio:** placeholder beeps/noise; audio via an `AudioService` with named cue keys (`"melee_swing"`, `"parry_success"`, `"special_stalker_screech"`). Directional audio matters for specials (counterplay) — implement spatialised cues from the start.
- **UI (MVP):** HUD (HP, stamina, ammo, points, round, role icon, exposed markers), shop prompts, scoreboard, lobby menu with the settings panel, end-of-match results with a **role reveal** screen. Controller support is stretch.

---

## 14. Implementation Roadmap (feature-by-feature)

Each ID is a self-contained work item. Check dependencies first. "AC" = acceptance criteria. Mark items done in `docs/PROGRESS.md` (create when starting M0).

**Numbering:** milestone M*n* owns IDs F0*n*0–F0*n*9 (M0 → F00x, M1 → F01x, M2 → F02x, …). New items take the next free ID in their milestone's band. *(The M2–M6 IDs were renumbered on 2026-11-10 to follow this rule; they had skipped F02x and F05x.)*

### M0 — Foundations
- **F001 Project skeleton.** Godot project, folder layout §12.1, autoload stubs, input map, lint/format config, gdUnit4 installed, `README` with run instructions. *AC:* project opens and runs an empty main scene; test runner executes one passing test.
- **F002 StateMachine & Events bus.** Reusable `StateMachine`, autoload `Events`. *AC:* unit tests for transitions and signals.
- **F003 Data resource classes + validators.** `WeaponData`, `EnemyData`, `WaveData`, `PerkData`, `DoorData`, `LootTable`, `MatchSettings`. *AC:* each has `validate()`; tests; one sample `.tres` each.

### M1 — Single-player sandbox (no networking yet, but written server-authoritative)
- **F010 First-person controller.** Move, sprint, jump, crouch, look; stamina component. *AC:* feels responsive in a greybox arena.
- **F011 Damage pipeline.** `DamageEvent`, `DamageService`, `HealthComponent`, hurtboxes. *AC:* tests for block/FF scaling/armor math.
- **F012 Melee v1.** Light/heavy, swing arcs, hit detection, stamina cost, block. *AC:* can kill a training dummy using a sword; guard break works.
- **F013 Parry/dodge/riposte.** *AC:* parry window correct to ±1 frame; riposte bonus applied.
- **F014 Firearms v1.** Hitscan, mag/reserve ammo, reload, recoil; 2-firearm + melee loadout & swap. *AC:* ammo caps enforced; scarcity multiplier applied in tests.
- **F015 Basic cultist AI (Acolyte).** Navmesh chase + telegraphed melee. *AC:* 30 acolytes chase a player without frame drops. *(Tested headless at 60, the §12.5 target, against an AI time budget per tick; rendering FPS is a manual check.)*
- **F016 Points economy.** Damage→points, point sinks API. *AC:* unit tests for point rules. *(Done: see [ADR 0009](adr/0009-points-economy.md); there is no kill bonus.)*
- **F017 Doors & zones.** `Zone`, `Door` with cost, nav toggling. *AC:* opening a door unlocks a zone and spawn points. *(Done: see [ADR 0010](adr/0010-doors-zones.md). Pickups are not part of F017.)*
- **F018 Wall-buy & ammo stations, perk altar.** *AC:* purchases deduct points, replace loadout slots correctly. *(Done: see [ADR 0011](adr/0011-shops-perks.md).)*
- **F019 Wave director v1 + round loop.** Spawn by budget, intermission, round counter to 12. *AC:* a bot-assisted run completes 12 waves headless. *(Done: see [ADR 0012](adr/0012-wave-director.md).)*

### M2 — Multiplayer
- **F020 NetTransport abstraction + ENet lobby.** Host/join by IP, lobby list of peers. *AC:* two instances connect and see each other.
- **F021 Player replication.** Spawn/despawn players, movement sync with validation. *AC:* 4 clients move smoothly with host.
- **F022 Server-authoritative combat.** Melee and gun hits resolved on the host; clients predict. *AC:* damage/points identical across peers.
- **F023 Enemy replication + director on host.** *AC:* 8 players, 60 AI, stable.
- **F024 Steam transport.** GodotSteam lobbies + relay. *AC:* friends can join without port forwarding. *(Can proceed in parallel after F020.)*
- **F025 Settings replication & lobby UI v1** (`MatchSettings` editor MVP). *AC:* host changes apply on all clients when the match starts.

### M3 — Social layer (Betrayal)
- **F030 Role assignment & secret info channel.** *AC:* tests prove no role data is exposed to non-owners.
- **F031 Friendly fire rules + traitor attack handling.** *AC:* FF scale respected; AI ignores hidden traitors.
- **F032 Exposure: witnessed damage.** Server LOS/FOV witness check. *AC:* tests with mock players; exposure broadcast works.
- **F033 Blessed Silver test.** Item, channel, results. *AC:* traitor exposed, hunter cleared; stock limits enforced.
- **F034 Death, loot bag, conversion queue (Betrayal).** *AC:* killed Hunter appears in cult queue after delay.
- **F035 Player-controlled special framework** (`SpecialBase` with controller abstraction) + **F036 Stalker** as the first playable special. *AC:* a converted player controls a Stalker with leap-pin.
- **F037 Win/loss resolution, results & role reveal screen.** *AC:* all edge cases in §4.4 covered by tests.
- **F038 Co-op mode (Vigil) rules** incl. spectate + next-wave respawn (D15). *AC:* preset flips mode without forking code.

### M4 — Enemy variety
- **F040 Hooked Priest, F041 Plague Bloat, F042 Abomination** (AI + player-controlled). *AC:* each has documented counterplay & tests.
- **F043 Zealot, Flagellant common types.**
- **F044 Director constraints** (special caps, breathers, visibility rules, player-scale). *AC:* property-style tests on spawn legality.
- **F045 Default 12-wave `WaveSet`** and presets. *AC:* balanced playtest checklist in `docs/BALANCE.md`.
- **F046 Boarded windows (barricades)**: spawn closets, plank tearing, swipes through the window, climbing in, hold-to-repair for points. *AC:* enemies breach a window plank by plank and climb in; players repair it for points. *(Built ahead of M2, on 2026-11-11.)*

### M5 — Content & polish for a playable
- **F050 MVP map greybox** (Ashgrave) with 5–6 zones, spawn points, loot tables.
- **F051 HUD & scoreboard & ping system.**
- **F052 Text chat (global/team/cult).**
- **F053 Perks (6–8) & consumables.**
- **F054 Audio service + placeholder cues; spatial cues for specials.**
- **F055 Performance pass** and optional C# port of proven hot spots (§12.4).

### M6 — Host power tools
- **F060 Full `MatchSettings` panel** (all §9 fields) with presets & validation warnings.
- **F061 In-lobby Wave Editor** (Firefight-style), save/load/share `WaveSet`s.
- **F062 Expansion specials** (Brute, Acid Witch, Gargoyle, Weeping Bride).
- **F063 Body inspection, sabotage, downed state, proximity voice** (stretch).

---

## 15. Open Questions & Assumptions (confirm before implementing the affected feature)

| # | Item | Current assumption |
|---|---|---|
| Q1 | Do cultists attack **exposed** traitors? | No — AI ignores all traitors; only Hunters can punish exposure |
| Q2 | Traitor win while some Hunters survive Round 12? | No — Hunters win if ≥1 survives Round 12 |
| Q3 | Can players pick which special they respawn as? | Initially random/director-weighted; player choice is a later toggle |
| Q4 | Voice chat | Out of MVP scope; text chat first |
| Q5 | Number of traitors at 8 players | 1 by default; host can raise |
| Q6 | Point loss on death in Vigil | 25% default |
| Q7 | Late join handling | Joins as spectator, becomes a Hunter next wave (Vigil) / Cult spectator (Betrayal) |
| Q8 | Perk list and exact weapon stats | Placeholder numbers; tune during M5 |
| Q9 | Final project/game name | "Vigil of Ash" is a working title only |
| Q10 | Downed state (revive) | Off by default; later host option |

---

## 16. Conventions for Claude Sessions

1. **Read this file's §0, §12 and the relevant feature in §14 before coding.** If a task contradicts the doc, ask the user and update the doc in the same change.
2. **One feature ID per session/PR.** Name branches `feat/F0xx-short-name`. Update `docs/PROGRESS.md` and tick the AC.
3. **GDScript style:** static typing, `class_name`, signals over direct node refs, `@export` for tunables, no magic numbers in logic (use `Resource` defaults).
4. **Server authority:** any state-changing logic is guarded by `multiplayer.is_server()` (or a no-network equivalent via a `Net.is_authority()` helper that returns true in single-player).
5. **Tests required** for pure logic (damage math, economy, role assignment, win conditions, director rules, settings validation).
6. **Never** put secret role data in a replicated property.
7. **Record decisions:** non-trivial architecture choices get a short `docs/adr/NNNN-title.md`.
8. **Placeholders over blockers:** if art/audio is missing, use the placeholder slot; do not stall.
9. **Keep content in `/content` as `.tres`**; do not hard-code stats in scripts.
10. **Verify by running** the game or tests (`scripts/run_tests.sh`, plus `gdformat --check` / `gdlint` on `src tests`), and report honestly if something could not be verified.
