# Claude Code / Claude Agent — EMPIRE RUSH implementation task

You are the lead Godot engineer for **EMPIRE RUSH**, a mobile-first online strategy-party board game. Work in the connected GitHub repository and treat GitHub as the source of truth. The project uses **Godot 4.7.2 and GDScript** unless the repository already contains a documented compatible version; inspect before changing project settings.

## Primary objective
Deliver a playable, testable vertical slice in milestones. Do not attempt to implement every feature in one giant change. Start by auditing the repository, writing a short plan, and opening a milestone checklist. Follow `docs/GAME_RULES_AND_GDD.md` as the product baseline.

## Non-negotiable engineering rules
1. Preserve existing working code and project conventions. Do not overwrite or delete files without explaining why in the plan.
2. Server-authoritative: client must never decide dice outcomes, cash, property ownership, turn order, auction winner, bankruptcy or match victory.
3. Separate domain/game rules from UI, scenes and animation. Rules must be unit-testable without rendering.
4. All currency uses integers. All state-changing commands have IDs and are idempotent.
5. Do not hard-code board/property/event/character balance values in UI scripts; load them from data/resources.
6. Never claim tests pass unless you actually ran them and include command/output summary.
7. Do not run an infinite test loop or leave long-running processes unattended. Every test has a clear timeout and log.
8. Keep changes small, reviewed and committed on a feature branch. Do not push directly to `main`.
9. Do not add real-money gambling, pay-to-win combat/economy stats, or unlicensed assets.
10. Reference art under `reference_art/` is visual direction only, not a set of production-ready sprites. Use placeholders until assets are correctly isolated, licensed and optimized.

## First response / audit
- Inspect repository files, branches, Godot version, current tests and existing networking/backend patterns.
- Identify what can be reused and what must be new; do not assume another game's rules or assets can be copied blindly.
- Check repository permissions and Git remote. Never print secrets or tokens.
- Create/update `docs/IMPLEMENTATION_PLAN.md` with milestones, dependencies, risks and acceptance tests.
- Report the actual current repo state and blockers before implementing.

## Milestones

### M0 — Repository and design baseline
Deliver:
- `docs/GAME_RULES_AND_GDD.md` reviewed and committed if absent.
- `docs/IMPLEMENTATION_PLAN.md`.
- `docs/PROTOCOL.md` with command/event schema and versioning.
- `docs/ASSET_REGISTER.csv`.
- A minimal reproducible test command documented in README.

Acceptance:
- Clean import/open in Godot 4.7.2.
- No untracked files accidentally omitted.
- Plan includes a hard scope boundary for MVP.

### M1 — Offline rules prototype
Implement:
- 28-space board data model (21 properties, 7 districts of 3, Start, 2 City Event, 2 Opportunity, Rest/inspection and Special).
- 2d6 turn loop, Start reward, buy/pass, rent, upgrades levels 0–3, auction, simple trade, events, insolvency/rescue, bankruptcy, match end.
- Basic AI or scripted test players so a full game can be simulated without humans.
- Basic UI is allowed to use placeholder art.
- Unit tests for movement, purchase, rent, upgrade eligibility, insufficient funds, trade atomicity, auction deadline, timeout, bankruptcy and endgame.

Acceptance:
- Run 100 simulated matches without soft-lock.
- No invalid money/property state.
- Provide exact test commands and logs.

### M2 — Visual vertical slice
Build one polished board section first, then extend the board:
- Isometric miniature-city camera and board with consistent scale.
- Token movement and dice roll animation.
- One property tile with three visible upgrade states.
- Mobile-first HUD, property detail panel and action buttons.
- Art direction follows `reference_art/`; do not copy illegible text from concept images.
- Include low/medium/high quality options where practical.

Acceptance:
- Provide a runnable scene/build and screenshots.
- Main UI readable on a 9:16 Android viewport and 16:9 PC viewport.
- Animation never blocks or changes authoritative game state.
- If final assets are not ready, clearly label placeholders.

### M3 — Online foundation
First decide the smallest reliable server architecture after inspecting existing repo/backend patterns. Prefer reusing a known, functioning WebSocket deployment pattern if appropriate, but do not couple the rules to a specific transport.
Implement:
- Room creation/join and player seats.
- Server-side turn timer and dice RNG.
- Commands/events with protocol version, command_id, expected_state_version.
- Server validation and authoritative state.
- Snapshot on join/reconnect.
- Idempotency and stale-command rejection.
- Integration test with at least two clients; target four clients before acceptance.

Acceptance:
- Four clients complete a full test match.
- Repeated command does not double-charge or duplicate ownership.
- Reconnect restores exact state.
- Automated test reports zero state divergence.

### M4 — MVP integration and polish
Implement:
- Full 28-space board, 12 event cards, 3 character abilities.
- Private rooms first; matchmaking can remain feature-flagged until stable.
- Results screen, match history placeholder/API, audio, reduced-motion option and mobile safe areas.
- Basic telemetry for match duration, disconnects, timeouts, invalid commands and crash events.

Acceptance:
- Median match duration 22–27 minutes; P90 <=35 minutes in playtests.
- No blocker/critical issues.
- Android build installs and launches on a documented baseline device.
- README has setup, run, test, build and server deployment instructions.

### M5 — Closed test readiness
- Run regression tests and 100 simulated matches after any rules/balance changes.
- Create a known-issues list, rollback instructions and deployment checklist.
- Do not implement store/payment systems until core retention and fairness are validated.

## Git workflow
- Create a feature branch such as `claude/empire-rush-m0-baseline`.
- Commit after each milestone with descriptive messages.
- Push branch only if GitHub authorization is available.
- Never commit credentials, `.env` secrets, local caches, export binaries or machine-specific paths.
- If push fails, keep commits locally, report the exact permission failure and provide a safe patch/bundle workflow; do not repeatedly retry blindly.

## Required final report after each milestone
1. Summary of implemented behavior.
2. Files added/modified.
3. Exact commands executed.
4. Tests passed/failed with actual counts and relevant log excerpts.
5. Screenshots/build artifact path if available.
6. Remaining bugs and risks.
7. Commit hash and remote branch status.
8. The next milestone and its acceptance criteria.

Start with the repository audit and M0 only. Do not jump to M1 until the plan and baseline are reviewed. If any requirement conflicts with the existing repository, stop and explain the conflict with options rather than silently breaking existing functionality.
