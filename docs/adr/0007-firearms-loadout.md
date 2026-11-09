# ADR 0007 — Firearms, Ammo & Loadout

- **Status:** Accepted (F014, 2026-11-09)
- **Code:**
  - `src/combat/firearms/`: `Firearm` + `firearm.tscn` + `states/`, `AmmoRules`, `AmmoState`, `TracerDraw`;
  - `src/player/loadout/loadout.gd`;
  - `src/combat/hitscan.gd` (`cast_through`);
  - `src/world/dev/weapon_pickup_stand.*`;
  - `src/ui/hud/temp_hud.gd`;
  - `src/player/viewmodel/firearm_viewmodel.gd`.
- **Tests:**
  - `tests/combat/test_ammo.gd` (the AC);
  - `tests/combat/test_firearm_math.gd`, `test_hitscan_through.gd`;
  - `tests/player/test_firearm.gd`, `test_loadout.gd`;
  - `tests/ui/test_temp_hud.gd`.

## Context
DESIGN §6.2 and §6.4 set the shape of firearms:
- the loadout is 2 firearms + 1 melee weapon;
- firearms are emergency tools with **scarce** ammo;
- the host's `ammo_scarcity` (0.25–3×) "scales drops and costs".

**AC:** ammo caps are enforced, and the scarcity multiplier is applied (both in tests). Wall-buys and ammo stations (F018) and, later, drops and pickups will build on this. Pickups aren't part of F017 (ADR 0010).

## Decisions

### Scarcity scales ammo gained, never caps
- `AmmoRules.grant(raw) = floor(raw / ammo_scarcity)`; `AmmoRules.cost(raw) = ceil(raw × ammo_scarcity)`. Higher means scarcer.
- `mag_size` and `reserve_cap` are **never scaled** and are always enforced by `AmmoState`:
  - `add_reserve` clamps and returns the amount accepted;
  - `move_to_mag` moves only what the reserve has, up to the magazine size;
  - `take_round` fails on an empty magazine.
- **Every source of ammo goes through a grant**, including the spawn reserve (`AmmoState.fill()`: full magazine + `grant(reserve_cap)`). A scarcer match spawns with less reserve, never with a bigger cap.
- F017/F018 must call `Loadout.grant_ammo(slot, raw)` for ammo and `AmmoRules.cost` for prices.

### Loadout owns slots, ammo and switching
- **Slots:** `[FIREARM_A, FIREARM_B, MELEE]`, plus one `AmmoState` per firearm slot (ammo belongs to the slot, not the weapon node).
- **`setup(ids)`** fills the first two firearms and the first melee weapon; extras warn. Players **spawn with melee active** (pillar 1: melee is the bread and butter).
- **Switching:** keys 1/2/3 and the mouse wheel (empty slots are skipped). The flow is holster (stop the current weapon's machine, which cancels reload/charge/block) → wait the target's `WeaponData.draw_s` → equip. Nothing attacks during the draw.
- **`replace_slot(slot, weapon)`** checks the slot kind, gives the new firearm fresh ammo (`fill`), and returns the old weapon. It's the API for F018 purchases and pickups.
- **Ticking:** `Player.step()` ticks the loadout, then **only** the active weapon (`MeleeWeapon` or `Firearm`). Their scenes stay on the player; equipping swaps their data.

### Firearm
- **States** (ADR 0001, MANUAL tick): `Ready` / `Reloading` / `Lowered`.
- **Semi-auto only:** one shot per attack press, limited by `fire_interval_s`. A press during the cooldown is dropped.
- **Shot:**
  - each of `pellets` picks a direction uniformly over the spread cone (seeded `RandomNumberGenerator`);
  - `Hitscan.cast_through` continues through up to `penetration` additional combatants, each hit once, with damage ×0.6 per combatant passed (`PENETRATION_DAMAGE_MULT`); world geometry stops it;
  - damage = `damage × falloff(distance) × 0.6^index`, as BULLET, with `weakpoint_mult`, through `Combat.apply`.
- **Accuracy:** spread = (`spread_deg` + bloom) × (`ads_spread_mult` while aiming). Bloom grows by `spread_bloom_deg` per shot (capped at `max_bloom_deg`) and recovers at `spread_recovery_deg_s`. **There's no view recoil**; the old `recoil` field was removed.
- **Aim (RMB):** 60% speed, sprint locked, FOV −`aim_fov_delta`. RMB fills both `block_held` and `aim_held`; each weapon reads only its own field.
- **Reload:**
  - a top-up from the reserve with no rounds lost; R, or a press on an empty magazine;
  - whole-magazine reloads add everything at the end of `reload_s`;
  - `reload_per_round` reloads (revolver) add one round every `reload_round_s`, and a fire press with a round loaded interrupts them;
  - sprinting or switching cancels a reload. A cancelled whole-magazine reload adds nothing; a per-round reload keeps the rounds already loaded.
- **Sprint:** the gun is **lowered** and can't fire. Holding aim locks sprint so the gun comes back up.
- **Stun or guard break while holding a gun:** `Firearm.notify_staggered()` blocks firing and aiming for the duration.

### Pickup stand (temporary interactable)
- `WeaponPickupStand`: interact (E) is a camera ray against WORLD within `interact_range_m`, to a node in the group `interactable`, calling `interact(player)`.
- It swaps the stand's weapon into the active firearm slot (or the first empty or first firearm slot when melee is out), and the old gun goes onto the stand.
- F017 generalised this into the `Interactable` component (ADR 0010). The stand now uses it.

### Feedback (local only)
- A greybox gun viewmodel with poses (hip, aim, lowered, reload) and a cosmetic kick plus muzzle flash.
- Tracers (`TracerDraw`).
- `TempHud`: crosshair gap ∝ spread (a dot for melee), the ammo / weapon / RELOADING readout, and hit markers (white, weak-point yellow, kill red). It's a placeholder until F071.

## Consequences
- **Sandbox loadout:** the arena's Player sets `starting_loadout_override` (sword + revolver + blunderbuss). The presets keep `MatchSettings.starting_loadout`.
- **Network (F031/F032):** the new intent fields (`aim_held`, `slot_pressed`, `cycle`, `reload_pressed`, `interact_pressed`) are part of the input packet. The host runs the same loadout and firearm logic.
- **Automatic weapons** (a later repeating carbine) need an `automatic` flag plus a hold-to-fire branch in `Ready`. This is deliberately not added yet.
