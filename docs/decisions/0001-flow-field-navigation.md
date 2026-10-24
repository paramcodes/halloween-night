# ADR-0001: Flow-field navigation instead of a navmesh

- **Status:** accepted
- **Date:** 2026-10-24
- **Context:** 200 zombies converge on one player through a 120 m village with
  nine houses and doors that open and break. A navmesh per agent is too heavy on
  the CPU target, and Godot's `NavigationAgent3D` does not share work between
  hundreds of bodies.

## Decision

Use one BFS flow field owned by `Village`, rebuilt from the player's cell:

- 2 m cells over 120 m (60 × 60 grid) instead of the 1 m implied by early
  sketches. Halves BFS work and memory with no visible pathing loss at zombie
  scale.
- Rebuild at 4 Hz, not every frame. Zombies sample the field each physics tick.
- House interiors are walkable; door cells are carved open. Blocked rectangles
  cover only the wall ring, so a raider that forces a door can enter.
- House raiders use direct steering to the door instead of the field. A leader
  hierarchy was considered and dropped: the population is one target plus a
  handful of raiders, so the extra bookkeeping bought nothing.
- If the player's cell is blocked or outside the grid, sampling falls back to the
  nearest open cell.

## Consequences

- Paths are coarse (2 m) and can clip a corner; separation steering and collision
  shapes absorb it.
- Zombies do not plan around closed doors for the player objective. Doors are a
  raider target, not a general obstacle.
- Rebuilding the field is O(cells) and happens four times a second, independent
  of horde size.
- A future crowd system can replace `FlowField` behind `Village.flow_direction`
  without touching actors.

## Alternatives rejected

- `NavigationRegion3D` + 200 agents: per-agent path queries and steering cost.
- 1 m cells at 10 Hz: measured unnecessary, four times the BFS cost.
- Flow-field leaders with shared local avoidance: complexity without a second
  destination.
