# ADR-0002 — HealthManager stays authoritative for its entity during the restructure

Status: **Accepted**

Deciders: Restructure spec (`RESTRUCTURE_PLAN.md`, "Rollout decision"), issue
Jon-Gear/FelonyFelines#14

Date: 2026-09-21

## Context

Every combatant (players and enemies) carries a `HealthManager` node
(`src/entities/base_templates/base_entity/functions/HealthManager.gd`). It holds
current + max health and silently acts as the authority for damage, death, and
revive. The split-screen, respawn, and death flows all read
`health_manager.is_dead()` directly. The target architecture
(`ARCHITECTURE.md`) says authoritative life facts live in `AppState`
(`BrothersState`) and change through a `CombatService`. Flipping health to
state-authoritative in one step would touch every entity, every death flow, and
the split-screen at the same time — a wide, risky blast radius with no seam.

## Decision

During the restructure, `HealthManager` **stays authoritative for its entity's
health**. It reports changes through `CombatService`, which reconciles them into
state. Flipping to `AppState`-authoritative health is explicitly deferred and
optional (listed in the spec's Out of Scope).

Reads that exist today (`health_manager.is_dead()` in respawn, split-screen,
death, closest-player logic) keep working until their owning flow is migrated; as
each flow moves onto a service, it reads state instead.

## Consequences

- Migration steps stay small and runnable (user story 22): each flow migrates
  when its service lands, not all at once.
- For the duration of the migration there are two views of health — the node's
  and state's — kept in sync through `CombatService`. This is a known, bounded
  duplication, not a new pattern.
- The eventual flip to state-authoritative health is a separate, deliberate,
  optional task.