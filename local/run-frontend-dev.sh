#!/usr/bin/env bash
# Runs the explorer frontend on the Mac in dev mode (hot reload) on port 3000.
# The local nginx proxy (docker compose in this folder) serves it at http://localhost:8088.
# Settings come from envs/frontend.env.
set -eo pipefail
cd "$(dirname "$0")/../frontend"

cp ../local/envs/frontend.env .env.local

# same steps as tools/scripts/dev.sh, but Next listens on 3000 while the app's public URL is :8088
rm -rf ./public/assets/configs ./public/assets/multichain ./public/assets/envs.js
npx dotenv -e .env.local -- bash -c './deploy/scripts/download_assets.sh ./public/assets/configs'
source ./deploy/scripts/build_sprite.sh
npx dotenv -v NEXT_PUBLIC_ICON_SPRITE_HASH="${NEXT_PUBLIC_ICON_SPRITE_HASH}" -e .env.local -- \
  bash -c './deploy/scripts/make_envs_script.sh && next dev --turbopack -p 3000'
