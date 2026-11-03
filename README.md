# RoxChain Explorer

Block explorer for the RoxChain network, based on **Blockscout**.

## What's in this repo

| Folder | Upstream | Version | Commit | Licence |
|---|---|---|---|---|
| `backend/` | [blockscout/blockscout](https://github.com/blockscout/blockscout) (indexer + API, Elixir) | `v10.2.6` (15 Apr 2026) | `90f7dd8e9348123b74dfd23f69ab7da76191a820` | GPL-3.0 |
| `frontend/` | [blockscout/frontend](https://github.com/blockscout/frontend) (UI, Next.js) | `v2.7.2` (6 Apr 2026) | `446c409eeb54274aab90ff371a705f9699cd84ef` | GPL-3.0 |

Both folders are copied unchanged from those tags, without their git history.

## Why these versions

These are the **last GPL-3.0 releases**. Later versions use the "Blockscout Software Licence":
- backend from `v11.0.0`, 22 Apr 2026;
- frontend from `v2.7.3`, 21 Apr 2026.

That licence requires a "Powered by Blockscout" footer, can be changed or revoked by Blockscout at any time, and needs a commercial licence for paid use. **Don't merge or copy code from newer upstream versions into this repo.**

Other consequences:
- **No public Docker images for these versions.** Since v10, Blockscout publishes its images to a private registry, so we build ours from these folders: `backend/docker/Dockerfile` and `frontend/Dockerfile`.
- **No upstream fixes after these versions** that we can use. We patch the code ourselves.
- **GPL-3.0 obligations:** keep the licence files and notices, and mark files we modify. If we ever *distribute* the explorer (for example, give it to a client to run), we must provide its source under GPL-3.0. Running it ourselves as a website doesn't trigger this.
- **Optional microservices** (stats, smart-contract-verifier, sig-provider, visualizer, from [blockscout/blockscout-rs](https://github.com/blockscout/blockscout-rs)): MIT until 28 Apr 2026, the new licence after. If we add them, use releases from before that date.

## Changes from upstream

- **Backend:** code for other chains removed (Optimism, Arbitrum, Celo, zkSync, Filecoin, and so on); only the default chain type remains.
- **Frontend:**
  - RoxChain branding: logo, favicons, colours, footer, titles. "Blockscout" removed from the UI.
  - Removed: all ads and sponsored banners, the page-view tracking call to Blockscout, the API docs page, the contract verification pages, the "Other" menu and the "Add network" button.
  - Sidebar groups are listed in place (heading + links) instead of fly-out menus.
  - Unit names come from settings (`bitrox` / `Gbitrox` instead of wei / Gwei).
  - New settings: `NEXT_PUBLIC_HOMEPAGE_HERO_TITLE`, `NEXT_PUBLIC_NETWORK_TESTNET_LABEL`, `NEXT_PUBLIC_NETWORK_BLOCK_PERIOD_SECONDS`.

## Running locally

`local/` runs the explorer against the RoxChain devnet RPC (`https://ro-dev.roxchain.io`):

```sh
cd local
cp .env.example .env                         # then set POSTGRES_PASSWORD and SECRET_KEY_BASE (not committed)
docker compose -p roxchain-explorer up -d   # Postgres, backend, nginx proxy on http://localhost:8088
./run-frontend-dev.sh                        # frontend in dev mode (hot reload) on the Mac
```

Settings are in `local/envs/backend.env` and `local/envs/frontend.env`, logos in `local/branding/`. Secrets live only in `local/.env`, which is not committed.

Notes:
- In `frontend.env`, values containing `#` (colours) must be in single quotes, or they are cut at the `#`.
- The proxy forwards `/rpc` to the devnet RPC, because the RPC node rejects browser calls from other origins (CORS). In production, allow the explorer's domain in the RPC nodes' CORS settings or keep the proxy.
- Always point the backend at the history/RPC nodes, never at pruned validators.
