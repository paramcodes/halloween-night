# ADR-0002: A local test harness instead of GUT or gdUnit4

- **Status:** accepted
- **Date:** 2026-10-24
- **Context:** Phase 0 asks for a test framework with three passing tests. GUT
  and gdUnit4 both work, but each adds an addon tree, its own runner scene, and
  a network dependency during setup. CI must run headless and prove it fails
  when a test breaks.

## Decision

Ship a small harness in `tests/support/test_case.gd`:

- Subclasses implement `run()` and call `check(condition, message)` or
  `check_equal(actual, expected, message)`.
- `tests/test_runner.gd` instantiates every registered suite, counts assertions
  and failures, prints one line per failure, and exits non-zero on any failure.
- Suites run in a normal Godot process, so they can build the real village,
  spawn real zombies, and step the real physics loop.
- The runner scene is `tests/test_runner.tscn`; the command is
  `godot --headless --path . res://tests/test_runner.tscn`.

## Consequences

- No addon updates, no import of third-party test code, and no extra CI step.
- No fixtures, mocks, parameterised cases, or GUI runner. Tests are plain
  GDScript and must clean up after themselves.
- Integration tests can be slow (the current suite takes about 33 s). Keep unit
  tests pure and reserve scene construction for the two integration suites.
- If the suite grows past a few hundred tests, revisit this decision rather than
  extending the harness indefinitely.

## Alternatives rejected

- GUT: more features than needed, an addon tree to vendor and keep updated.
- gdUnit4: same, plus a heavier runner.
- Plain `assert()`: aborts the process on the first failure and reports no
  summary, so CI output is unhelpful.
