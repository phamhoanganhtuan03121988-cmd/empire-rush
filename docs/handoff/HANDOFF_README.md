# EMPIRE RUSH — Claude Handoff Pack

This bundle contains:
- `docs/GAME_RULES_AND_GDD.md` — MVP gameplay rules and technical baseline.
- `docs/CLAUDE_TASK_PROMPT.md` — copy/paste implementation brief for Claude.
- `reference_art/*.png` — concept boards for art direction and UI inspiration; these are not isolated production sprites.

## Suggested GitHub setup
1. Create a new private repository named `empire-rush`.
2. Upload these files into the repository root (or add them through a local clone).
3. Connect Claude to the repository and grant only the repository access it needs.
4. Ask Claude to start with M0 repository audit only.
5. Review the plan before approving implementation; require tests and a feature branch for every milestone.

## Important
Do not put API keys, access tokens, passwords or `.env` secrets in the repo. Do not ask Claude to build all milestones in one prompt. Start with audit, then approve milestone by milestone.
