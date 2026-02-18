# Abstraction Guide (Phase 1-4)

This guide explains how the project was refactored so main classes act as **containers/orchestrators** and delegate pure logic to shared modules.

## Core Pattern

- **Container scripts** own scene state, signals, and sequencing.
- **Helper scripts** (`RefCounted` + `static func`) own deterministic logic, math, classification, and policy.
- This split keeps gameplay behavior easier to tune, test, and reuse.

---

## Gun + Camera Systems

### Container scripts
- `scripts/player/gun.gd`
- `scripts/game/third_person_camera.gd`

### Delegated helpers
- `scripts/core/math/gun_motion_math.gd`
- `scripts/core/math/camera_orbit_math.gd`
- `scripts/core/math/slow_time_math.gd`

### Why
- Gun and camera had dense math and branch-heavy behavior.
- Extracting pure math reduced risk when tuning recoil, orbit, and slow-time.
- Containers now mostly read state -> call helper -> apply outputs.

---

## Combat / Hit Detection

### Container scripts
- `scripts/enemies/enemy.gd`
- `scripts/player/bullet.gd`

### Delegated helpers
- `scripts/core/combat/enemy_hitbox_util.gd`
- `scripts/core/combat/bullet_hit_util.gd`

### Why
- Hitbox naming, area classification, and node traversal were repeated concerns.
- Shared combat helpers prevent drift between enemy and bullet expectations.

---

## Spawn + World Systems

### Container scripts
- `scripts/game/enemy_spawner.gd`
- `scripts/game/endless_chunk_manager.gd`

### Delegated helpers
- `scripts/core/spawn/enemy_spawn_balance.gd`
- `scripts/core/world/chunk_grid_util.gd`

### Why
- Balance curves and chunk-grid calculations are algorithmic and reusable.
- Keeping them out of scene scripts makes spawning/chunk rules easier to iterate safely.

---

## Score + Run Flow

### Container scripts
- `scripts/core/score_system.gd`
- `scripts/game/game_controller.gd`
- `scripts/ui/hud.gd`

### Delegated helpers
- `scripts/core/score/score_calculator.gd`
- `scripts/core/flow/game_run_flow.gd`
- `scripts/core/ui/hud_texts.gd`

### Why
- Game flow and scoring contain many policy decisions (ad button states, bonus logic, score formulas).
- Extracting these decisions avoids logic duplication and keeps UI/game-controller cleaner.

---

## Ads Provider Layer

### Container scripts
- `scripts/ads/providers/mobile_ad_provider.gd`
- `scripts/ads/providers/steam_ad_provider.gd`

### Delegated helpers
- `scripts/ads/providers/provider_signal_bridge.gd`
- `scripts/ads/providers/provider_settings_util.gd`

### Why
- Provider implementations must map many plugin naming variants.
- Shared bridge/settings helpers remove repeated boilerplate and lower integration errors.

---

## Visual Wrapper Reuse

### Container scripts
- `scripts/player/gun.gd`
- `scripts/player/bullet.gd`

### Delegated helper
- `scripts/core/visual/visual_wrapper_builder.gd`

### Why
- Both scripts used near-identical wrapper-instantiation logic.
- Shared helper ensures wrapper behavior stays consistent across projectile/weapon visuals.

---

## How to Extend This Architecture

When adding a new feature:

1. Put pure decision/math code in a helper module under `scripts/core/**`.
2. Keep Node/Scene interactions in container scripts.
3. If two scripts need the same logic, move it immediately to a shared helper.
4. Keep helper inputs explicit (no hidden scene access) so behavior is predictable.

This keeps gameplay iteration fast while preserving maintainability as systems grow.
