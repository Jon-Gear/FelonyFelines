# Scene trees

Scene roles (*.tscn) grouped by role, matching the ARCHITECTURE.md layout. Each
scene is self-contained; the `FlowController` decides which scene loads next.

```
scenes/
  menu/       ← menu scenes
  levels/     ← level scenes
  ui/         ← shared UI (health bars, ammo bar, wave/points board, pause, split-screen composite)
```

Not yet populated during migration — current scenes still live under `src/`
(`src/menu`, `src/environment/levels`, …). They move here as the restructure rolls
out, without changing behavior.