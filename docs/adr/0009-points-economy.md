# ADR 0009 — Points Economy

- **Status:** Accepted (F016, 2026-11-10)
- **Code:**
  - `src/economy/`: `PointRules`, `PointAward`, `PointsComponent`;
  - `src/autoload/economy.gd` (the autoload `Economy`);
  - `src/data/economy/economy_rules.gd` + `content/economy/economy_rules/`.
- **Tests:**
  - `tests/economy/test_point_rules.gd` (the AC);
  - `tests/economy/test_points_component.gd`, `test_economy_service.gd`;
  - `tests/ui/test_temp_hud.gd`, `test_debug_actions.gd`;
  - `tests/data/test_misc_data.gd`.

## Context
DESIGN §10.1 says points are earned by **dealing damage** to cultists, scaled by a tier multiplier, with bonuses. Points are private per player and computed on the host. §10.2 lists the sinks (doors, wall-buys, ammo, perks).

**AC:** unit tests for the point rules. F017/F018 will spend through the API built here.

## Decisions

### Formula
```
damage_points = applied × points_per_damage_mult × category_mult(target)   (× weakpoint_mult on a weak-point hit)
award         = round_up_to(damage_points, round_to)  (+ riposte_bonus if the hit was a riposte)
```
- **`applied`** is `DamageResult.applied`, the health actually removed. Overkill, blocked damage and parried hits (0) never pay.
- **`category_mult`** comes from the target's `EnemyData.category`: COMMON 1.0, SPECIAL 1.5, BOSS 2.0. Targets without `EnemyData` (training dummies) count as COMMON.
- **Bonuses:** `weakpoint_mult` is 1.5 and `riposte_bonus` is +50.
- **Rounding:** `round_to` is 10, and every award rounds **up**. Any damaging hit pays at least 10, and balances always end in 0.
  - This favours many small hits, such as blunderbuss pellets (each pellet is an award). That's an accepted trade-off; tune it through `EconomyRules`.
- **No kill bonus.** The kill-bonus fields `EnemyData.kill_bonus_points` and `MatchSettings.kill_bonus_mult` were removed. Old serialized settings that still contain them load with an "unknown field" warning.
- **Where the numbers live:** `EconomyRules` (shipped content, `ContentDB` id `economy_rules`). The host's `points_per_damage_mult` applies on top.

### Eligibility (`PointRules.is_eligible`)
A hit earns points only if all of these hold:
- it was accepted;
- `applied > 0`;
- `source_peer_id > 0` (a player);
- the relation is HOSTILE;
- the target faction is CULT.

That excludes friendly fire, self-damage, world damage and cult attacks. Traitors earn from cultists exactly like Hunters (§5.2), with no special case needed. Converted players (CULT faction, F045) won't earn, because their targets are Hunters.

### Split
- **`PointRules`** (static, pure) holds the formula, eligibility, `round_up`, and the price helpers. It's fully unit-tested, and is where every rule change goes.
- **`PointsComponent`** (a child of `Player`) is the wallet:
  - methods: `reset(starting)` (`MatchSettings.starting_points` on spawn), `award_points(award)`, `award(amount, reason)` (the generic hook for the exposed-traitor bounty and debug; rounded up), `can_afford`, `try_spend(cost, reason)` (never goes negative; changes nothing on failure);
  - signals: `changed`, `awarded`, `spent`, plus `Events.points_changed(peer_id, total, delta)`;
  - every mutation is guarded by `Net.is_authority()`.
- **`Economy`** (autoload, after `Combat`) listens to `Combat.damage_applied` on the authority. It finds the attacker's wallet (`source.get_body()/PointsComponent`) and the target's category, then credits `PointRules.for_hit`. It also provides `wallet_for(peer_id)` and `wallet_of(health)`.

### Sinks API (for F017/F018)
- **Prices:**
  - `PointRules.door_price(base)` uses × `door_cost_mult`;
  - `shop_price(base)` uses × `shop_price_mult` (weapons, perks, items);
  - `ammo_price(base)` uses `AmmoRules.cost`, i.e. × `ammo_scarcity` (ADR 0007).
  - All prices are rounded up to 10.
- **Purchase:** `wallet.try_spend(price, reason)`. It returns false when the player is short, and only then does the purchase fail. The station decides what's granted, e.g. `Loadout.replace_slot` / `grant_ammo`.

### Feedback (local only)
- The `TempHud` shows `POINTS n` plus a floating `+N` per award: yellow on a weak point, with "RIPOSTE" on a riposte.
- F3 shows the balance and the last award breakdown (`PointAward.describe()`).
- F12 grants 1000 points (debug builds).

## Deferred
- **Death point loss** (`death_point_loss`) → F044/F048. The bag or pickup needs a pickup system, which is out of F017 and planned for F044.
- **Friendly-fire point penalty** (`friendly_fire_point_penalty`) and **gifting** (`allow_gifting`): the settings exist, but nothing implements them yet.
- **Exposed-traitor bounty** (`exposed_bounty`) → F042/F047, via `award(bounty, &"bounty")`.
- **Replication (F031/F040):** the balance goes to its owner only (targeted RPC). Other players never see it, per §10.1 (private).
