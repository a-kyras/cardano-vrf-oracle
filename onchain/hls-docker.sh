#!/bin/sh
# Runs haskell-language-server inside the plinth devcontainer for use as an
# nvim LSP cmd. Requires the same-path mount from docker-compose.override.yml,
# which reads HOST_REPO_PATH from this script rather than a hard-coded path —
# so this file (and the repo) can be relocated to any machine/path unchanged.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export HOST_REPO_PATH="$SCRIPT_DIR"

COMPOSE="docker compose -f $SCRIPT_DIR/.devcontainer/docker-compose.yml -f $SCRIPT_DIR/.devcontainer/docker-compose.override.yml"
$COMPOSE up -d plinth >/dev/null 2>&1
exec $COMPOSE exec -T plinth haskell-language-server-wrapper --lsp
