# EMPIRE RUSH

Mobile-first online strategy-party board game. 2–4 players, 20–30 minute matches, stylized-realism 3D miniature city.
Godot 4.7.2 / GDScript, server-authoritative multiplayer.

**Status: M0 (repository + design baseline).** There is no gameplay yet.

## Documents
- [Game rules & GDD](docs/GAME_RULES_AND_GDD.md): the product baseline
- [Implementation plan](docs/IMPLEMENTATION_PLAN.md): milestones, architecture, risks
- [Protocol](docs/PROTOCOL.md): client/server command and event contract (draft)
- [M0 audit report](docs/M0_AUDIT_REPORT.md): repo state, art vs GDD conflicts, open decisions
- [Asset register](docs/ASSET_REGISTER.csv): every external asset and its license
- `reference_art/`: concept boards, **direction only, not shippable assets**

## Layout
```
client/    Godot 4.7.2 project (open client/project.godot)
server/    authoritative server (runtime chosen in M3)
docs/      design + engineering docs
scripts/   tooling (tests)
```

## Requirements
- Godot **4.7.2-stable** (standard build, not .NET): https://godotengine.org/download/archive/4.7.2-stable/

## Run tests
```bash
# godot on PATH:
scripts/run_tests.sh
# or point at the binary:
GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64 scripts/run_tests.sh
```
The script imports the project headless, runs every `client/tests/**/test_*.gd`, writes logs to `logs/`, and exits non-zero on any failure. The default timeout is 300 s (`TEST_TIMEOUT_SECS`).

## Rules for contributors
- Work on feature branches. Never push directly to `main`.
- Never commit secrets (`.env`, keystores, tokens).
- All currency is integer RC. The client never decides dice, cash, ownership, turns or victory.
