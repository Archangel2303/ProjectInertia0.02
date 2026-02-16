# Production Readiness TODO

## Priority Order

### P0 - Blocker
- [ ] Fix compile warning in `scripts/player/gun.gd` by renaming `_register_external_rotation_influence(scale: float)` parameter (`scale`) so it does not shadow `Node3D.scale`.

### P1 - Production Hardening
- [ ] Remove or build-gate debug UI/input paths in `scripts/game/game_controller.gd` and `scripts/ui/hud.gd` so debug panels/toasts cannot ship unintentionally.

### P2 - Content Readiness
- [ ] Replace/augment debug level usage with final level scenes beyond `scenes/levels/level_debug_01.tscn`.
- [ ] Verify level select flow and target-kill balancing against final level content.

### P3 - Determinism Verification
- [ ] Run repeated level/endless sessions and confirm seeded spawner behavior is deterministic in `scripts/game/enemy_spawner.gd` (spawn order/timing/content within intended constraints).

### P4 - State/Scoring Regression Verification
- [ ] Regression-test level clear conditions and scoring behavior after enemy cleanup and queued-for-deletion handling in:
  - `scripts/core/score_system.gd`
  - `scripts/game/game_controller.gd`

### P5 - Release QA
- [ ] Smoke-test restart/menu transitions, ad reward paths, high-score persistence, and input maps across desktop/mobile targets.
