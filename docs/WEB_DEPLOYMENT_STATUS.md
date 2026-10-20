# EMPIRE RUSH web deployment status

Checked 2026-10-20, 09:24 UTC.

| | |
|---|---|
| Live URL | https://phamhoanganhtuan03121988-cmd.github.io/empire-rush/ |
| Default branch | `main` (still at M0; not modified) |
| Deployment branch | `claude/empire-rush-web-pwa-launch` (allowed in the `github-pages` environment) |
| Deployed commit | `3fbfcb0`: "Merge pull request #2" (mobile visual + audio pass) |
| Deploy run | web-pwa #10, push: https://github.com/phamhoanganhtuan03121988-cmd/empire-rush/actions/runs/39397213015 |
| Independent live check | pages-live-check #1: https://github.com/phamhoanganhtuan03121988-cmd/empire-rush/actions/runs/39400388072 |

## Why web-pwa #11 shows "deploy: skipped"

Merging PR #2 into `claude/empire-rush-web-pwa-launch` produced one commit, `3fbfcb0`. That commit started **two** web-pwa runs.

| Run | Event | Why it ran | build | webkit | deploy |
|---|---|---|---|---|---|
| **#10** [39397213015](https://github.com/phamhoanganhtuan03121988-cmd/empire-rush/actions/runs/39397213015) | `push` to `claude/empire-rush-web-pwa-launch` | the merge itself | success | success | **success**, live check passed |
| **#11** [39397219105](https://github.com/phamhoanganhtuan03121988-cmd/empire-rush/actions/runs/39397219105) | `pull_request` (PR #1, launch branch → `main`) | PR #1's head moved to the merge commit | success | success | **skipped (by design)** |

The deploy job's condition allows only:
- a `push` to `main` or `claude/empire-rush-web-pwa-launch`;
- a manual `workflow_dispatch` run on those two branches.

A `pull_request` run never publishes, so code that is not merged never reaches the site. Run #11 was the PR #1 check of the same commit, so its skipped deploy was correct.

Nothing was broken:
- `on`: run #10 was triggered;
- `needs` and `if`: both evaluated true for the push run;
- environment rule: the branch is allowed;
- permissions: `pages: write`, `id-token: write`;
- concurrency: the separate `pages-deploy` group did not cancel anything.

The confusion was that the two runs share one commit and the PR run did not say that it does not deploy.

## What changed (branch `claude/empire-rush-pages-deploy-fix`)

1. **The PR run says it does not publish.** The web-build summary of a `pull_request` run says "Not deployed: pull_request run" and names the run that does publish. The deploy condition is unchanged: still never from a PR.
2. **The deploy job verifies content, not just reachability.** Before, it only checked that the page, manifest, wasm and pck responded. Now it downloads the artifact it deployed and runs `scripts/web/verify_live.sh`, which checks:
   - every file is served (HTTP 200) with **the same SHA-256** as the deployed artifact (it waits for the Pages CDN to switch over, up to 5 minutes);
   - `index.wasm` is served as `application/wasm`;
   - markers of the latest changes are in the live files:
     - the iPhone audio unlock (`TrackedAudioContext`) in the page;
     - the audio bus layout (`default_bus_layout`) in the game data;
     - the HUD sound icon (`sound_off.svg`) in the game data;
   - the build stamp inside the live `index.pck` (`data/build_info.json`) names the commit the run deployed.
3. **`pages-live-check.yml`**, a read-only workflow (push to this branch, or run by hand). It finds the newest web-pwa push run whose deploy job succeeded, downloads what that run published, and runs the same comparison against the live site. It deploys nothing.

Not changed:
- triggers, branch filters, the deploy condition, permissions and the environment;
- the WebKit job and every test step;
- game code, rules and assets.

## Live-site verification (pages-live-check #1, 09:24 UTC)

Compared with the artifact of deploy run #10 (commit `3fbfcb0`):

| File | HTTP | Size (bytes) | SHA-256 live = deployed |
|---|---|---|---|
| index.html | 200 | 12 075 | yes |
| index.js | 200 | 279 815 | yes |
| index.wasm | 200 (`application/wasm`) | 39 514 754 | yes |
| index.pck | 200 | 6 961 312 | yes |
| index.manifest.json | 200 | 669 | yes |
| index.service.worker.js | 200 | 5 857 | yes |
| index.offline.html, worklets, 5 icons | 200 | — | yes (all) |

Markers present on the live site:
- `TrackedAudioContext`;
- `default_bus_layout`;
- `sound_off.svg`;
- build stamp **`3fbfcb0`**.

The live site is the merged mobile visual + audio build. The build before PR #2 had an `index.pck` of 6 945 792 bytes and none of these markers.

## Status by step

| Step | Status | Evidence |
|---|---|---|
| Build | success | run #10 web-build: export + browser e2e, responsive, screen tour |
| Tests | success | run #10: e2e, responsive, tour, WebKit 6/6; `tests` workflow green on `3fbfcb0` |
| Deploy job | success | run #10 deploy: `actions/deploy-pages@v4` "Reported success" |
| Live site | verified | pages-live-check #1: byte-identical to the deployed artifact, markers and build stamp `3fbfcb0` |

## Remaining manual actions

- **None for the current deployment.**
- The stronger check inside the deploy job (item 2) runs on the next deploy, once this branch is merged into `claude/empire-rush-web-pwa-launch`. Until then the old reachability check applies there, and `pages-live-check` covers the content check.
- **Run by hand:** a manual "Run workflow" button appears only for workflows on the default branch (`main`). On this branch, the live check runs on push.
- An installed iPhone app picks up a new deploy one launch late: close it and open it again while online, twice.
