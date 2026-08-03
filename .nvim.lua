-- Project-local LSP override: run HLS inside the devcontainer.
-- Loaded via 'exrc' (requires vim.o.exrc = true in your init.lua).
local repo_root = vim.fn.expand('<sfile>:p:h')
vim.lsp.config('hls', {
  cmd = { repo_root .. '/hls-docker.sh' },
})
vim.lsp.enable('hls')
