# EMPIRE RUSH

Mobile-first online strategy-party board game. 2–4 players, 20–30 minute matches, stylized-realism 3D miniature city.
Godot 4.7.2 / GDScript, server-authoritative multiplayer.

**Status: M1 (offline rules prototype) awaiting owner review.** Full MVP rules run headless with tests and simulations. There is no UI yet.

## Documents
- [Game rules & GDD](docs/GAME_RULES_AND_GDD.md): the product baseline
- [Implementation plan](docs/IMPLEMENTATION_PLAN.md): milestones, architecture, risks
- [Protocol](docs/PROTOCOL.md): client/server command and event contract (draft)
- [M0 audit report](docs/M0_AUDIT_REPORT.md): repo state, art vs GDD conflicts, open decisions
- [Implemented rules (M1)](docs/RULES_M1.md): exact formulas, timers, timeout defaults
- [M1 report](docs/M1_REPORT.md): tests, simulation metrics, balance draft, open questions
- [Asset register](docs/ASSET_REGISTER.csv): every external asset and its license
- `reference_art/`: concept boards, **direction only, not shippable assets**

## Layout
```
client/    Godot 4.7.2 project (open client/project.godot)
           scripts/domain = pure rules engine, scripts/sim = bots + simulator
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
The script imports the project headless, runs every `client/tests/**/test_*.gd`, writes logs to `logs/`, and exits non-zero on any failure or GDScript runtime error. The default timeout is 300 s (`TEST_TIMEOUT_SECS`).

## Run simulations
```bash
GODOT=/path/to/godot scripts/run_simulation.sh --matches=100 --players=2,3,4 --seed=1
GODOT=/path/to/godot scripts/run_simulation.sh --matches=2000 --players=4 --seed=100000 --summary=1 --out=$PWD/logs/sim.json
```
This plays complete bot matches against the rules engine. It checks invariants after every step and prints duration, win rates by seat and character, bankruptcies, cash and failures. It exits non-zero on any stuck match, invariant violation or rejected bot command.

## Rules data
Balance, board, event cards, characters and opportunities live in `client/data/rules/*.json` and are validated when loaded. All values are **DRAFT** until the owner approves them.

## Rules for contributors
- Work on feature branches. Never push directly to `main`.
- Never commit secrets (`.env`, keystores, tokens).
- All currency is integer RC. The client never decides dice, cash, ownership, turns or victory.
