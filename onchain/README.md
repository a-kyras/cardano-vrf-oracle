# Plinth development environment setup

How to get a working build environment for [Plinth](https://plutus.cardano.intersectmbo.org/docs/)
(the Haskell subset that compiles to Plutus Core) and prove it works.

This repository *is* the proof. It's a minimal Plinth project — one validator that accepts
everything, plus a blueprint generator — and nothing else. If `cabal build all` is green and it emits
a `plutus.json`, your toolchain is correct and you can start writing real validators.

You can either use the provided devcontainer to run the prerequisite toolchain in VS Code or as a plain docker image
or use nix.  
Follow either §2 for nix setup instructions or §8 for devcontainer setup.  
**Generally, the devcontainer is easier to set up and get runnning.**

```bash
git clone <this-repo> && cd <this-repo>

# run the devcontainer OR set up nix
nix develop            # iff using nix, read §2 first — Nix needs configuring, and this takes a while

# then, inside that shell:
cabal update
cabal build all
cabal run gen-blueprint -- ./plutus.json
```

Verified on macOS arm64, 2026-07-31, against Plutus **1.66.0.0** / GHC **9.6.6**.

Terminology, briefly: you write **Plinth** (formerly "Plutus Tx"), using the `plutus-tx` /
`plutus-tx-plugin` packages, which compile to
**Plutus Core / UPLC**, the only thing the chain executes.

---

## 1. Prerequisites

| Tool                       | Needed?      | Why                                                                              |
|----------------------------|--------------|----------------------------------------------------------------------------------|
| **Nix**, flakes enabled    | **Required** | Supplies GHC 9.6.6 *and* three native crypto libraries. This is the whole setup. |
| **git**                    | **Required** | Flakes read your source through git — even if you never commit. See §2.3.        |
| `direnv`                   | Optional     | Auto-enter the shell on `cd`. §5.                                                |
| ghcup / a host GHC / cabal | **No**       | Nix provides them. A host ghcup install can actively break things — §7.          |
| `cardano-cli`              | **No**       | Not needed to compile or to produce a blueprint.                                 |

### Why Nix is not merely a convenience

Two hard constraints make the "just use ghcup" path a dead end, particularly on macOS.

**1. The GHC version is gated in the package itself.** `plutus-tx-plugin` is a GHC plugin compiled
against GHC's internals, so it declares itself unbuildable elsewhere:

```cabal
common ghc-version-support
  if !((impl(ghc >=9.6) && impl(ghc <9.7)) || (impl(ghc >=9.12) && impl(ghc <9.13)))
    buildable: False
```

**2. Three native C libraries, none of them the version your package manager has.** Pulled in
transitively by `cardano-crypto-class`:

| Library | Requirement | From Homebrew? |
|---|---|---|
| `libblst` | `>=0.3.14` | Not in core — build from source *and* hand-write its `.pc` file |
| `libsodium` | IOG's **VRF fork** | Plain libsodium lacks the VRF symbols |
| `libsecp256k1` | `--enable-module-schnorrsig --enable-experimental` | Standard build lacks the modules |

Satisfying these by hand means three source builds, `sudo`, and authoring a pkg-config file. Nix
does all three for free, which is why IntersectMBO's own
[plinth-template](https://github.com/IntersectMBO/plinth-template) labels manual setup
*"not recommended"*.

---

## 2. Nix setup

**For the mechanics, follow IOG's
[nix setup guide](https://github.com/input-output-hk/iogx/blob/main/doc/nix-setup-guide.md)** —
installing Nix, becoming a trusted user, and adding the IOG binary cache, with the NixOS,
multi-user and single-user variants. It's maintained by IOG and there's no point duplicating it here.

⏱ **Budget real time.** Expect an hour or more to get from nothing to a first successful build — it
downloads several GB. This happens once per machine; every later Plinth project reuses the same store.

Then read the four points below: three things the guide doesn't cover, and one it gets actively wrong
for this template.

### 2.1 Verify the binary cache is really being used

The IOG guide tells you to become a trusted user. It does not give you a way to confirm it, and this
is the step that most often fails — **silently**:

```bash
nix store info      # must print  Trusted: 1
```

If it prints `Trusted: 0`, stop and fix `trusted-users` before going further. Nix ignores
flake-supplied substituters for untrusted users, so the symptom is not an error — it's Nix quietly
deciding to build GHC and all of Plutus from source instead, which you can sit through for a long time
before getting suspicious. Nix does warn, once, in a line easily lost in the scrollback:

```
warning: ignoring untrusted substituter 'https://cache.iog.io', you are not a trusted user
```

Answer `y` to both prompts on your first `nix develop`, too — declining `accept-flake-config` has the
same effect as being untrusted.

### 2.2 Apple Silicon: ignore that guide's `--system` advice

The IOG guide tells Mac users to pass `--system x86_64-darwin`. **That is wrong for this template.**
`nix/outputs.nix` gives `aarch64-darwin` the full jobset and `x86_64-darwin` an empty one, so arm64 is
the natively built and cached target. Forcing x86_64 puts you on an uncached platform and rebuilds
the world under Rosetta.

Use plain `nix develop`.

### 2.3 Flakes only see git-tracked files

**Nix copies only git-tracked files into the store; untracked files are excluded silently.**

A fresh clone of this repo is fine — everything here is committed. This bites you the moment you
**add** a file: create `src/MyValidator.hs`, run `nix develop`, and Nix builds a source tree that
doesn't contain it. Same story if you start a project from scratch with `git init` and never
`git add`, where the failure is louder and stranger:

```
warning: Git tree '/path/to/project' is dirty          ← the actual clue
error: ... The package location glob './*.cabal' does not match any files or directories.
```

That reads like a cabal problem and is purely a git-visibility one — `packages: ./.` resolved against
a store copy containing no `.cabal` file.

**Fix:** `git add -A` before `nix develop`. Staging is enough, no commit needed, and the
`Git tree ... is dirty` warning is harmless.

### 2.4 Never run `nix flake update`

It looks like routine hygiene. It breaks three things at once:

1. **haskell.nix ↔ nixpkgs skew.** haskell.nix picks a bootstrap GHC from nixpkgs through a fallback
   chain; pair a recent haskell.nix with a nixpkgs that dropped those point releases and every
   fallback misses → `error: attribute 'ghc943' missing`, at evaluation time.
2. **hackage/CHaP desync from `cabal.project`.** The lock's hackage and CHaP revisions must not be
   newer than the `index-state` timestamps in `cabal.project`, or cabal resolves against an index
   Nix never fetched.
3. **Total loss of cache hits.** IOG's CI builds *the template's locked inputs*. Any other
   combination of revisions isn't in `cache.iog.io`, so you compile GHC and all of Plutus from
   source — even with `Trusted: 1`.

The lock here looks alarmingly old (haskell.nix from 2025-07, nixpkgs from 2024-11) while
hackage/CHaP are current. **That is deliberate**: the Nix layer is frozen at a tested combination
and only the package indices move. Old is correct.

If you already ran it, restore upstream's lock:

```bash
cp flake.lock flake.lock.bak
curl -sL https://raw.githubusercontent.com/IntersectMBO/plinth-template/main/flake.lock \
  -o flake.lock
```

---

## 3. Enter the shell

From the repository root:

```bash
nix develop
```

First run asks you to accept the flake's trusted settings — answer `y`. Then:

```bash
ghc --version         # must print 9.6.6
cabal --version       # whatever the shell pins; anything 3.8+ is fine
```

If `ghc --version` prints anything else, see §7 — `nix develop` drops you into **bash**, and a ghcup
line in `~/.bashrc` will shadow Nix's GHC from inside an otherwise correct shell.

Evaluation is slow the first time — haskell.nix reads every `.cabal` in the dependency closure to
build a Nix-level plan — and is cached afterwards, so later `nix develop` calls are near-instant.

---

## 4. Build

From inside the shell:

```bash
cabal update
cabal build all
cabal run gen-blueprint -- ./plutus.json
```

You should get a `plutus.json` with `preamble.plutusVersion == "v3"` and a non-empty
`validators[0].compiledCode` hex string:

```bash
python3 -c "import json; d=json.load(open('plutus.json')); \
  print(d['preamble']['plutusVersion'], len(d['validators'][0]['compiledCode']))"
# → v3 12
```

Twelve hex characters is not a mistake — an unconditional success compiles to almost nothing. The
`validators[0].hash` field is the script hash your off-chain code would derive an address from.

That is a real compiled Plutus V3 script on disk. **This is the checkpoint** — everything past it is
about writing validators, not about setup.

The first run takes a while (§2); after that, rebuilds are seconds.

**If you see GHC itself being compiled, the cache is not working** — go back to §2.1 rather than
waiting it out; that path is far slower and often fails outright. `cabal update` reporting a newer
index-state than the build uses is expected; `cabal.project`'s pin wins, don't "fix" it.

---

## 5. Editor and ergonomics

**direnv** — an `.envrc` containing `use flake` is already here, so:

```bash
direnv allow
```

Now entering the directory loads the shell automatically. `.direnv` is already in `.gitignore`.

**HLS** comes from the dev shell, not your host. It's declared in `nix/shell.nix` and pinned to the
same GHC as the build, which is the point — a host HLS built against a different GHC cannot load
these modules.

- Launch your editor **from inside the shell** (`nix develop` then `code .`), or use direnv plus an
  editor extension that respects it (VS Code: *direnv*; JetBrains/Emacs/Vim: equivalents exist).
  Otherwise the editor finds a host `haskell-language-server` — or none — and reports errors that
  aren't real.
- Run `cabal build` once before expecting HLS to work; it needs the build plan and interface files.
- Modules compiled with `plinth-options` load slowly, because the flags that make the plugin work
  also disable the optimisations that make GHC fast. Expected, not a misconfiguration.

---

## 6. What each file is for

| Path | Role |
|---|---|
| `flake.nix`, `flake.lock` | Pins the entire toolchain. Copied verbatim from `plinth-template` — see §2.4. |
| `nix/project.nix` | `compiler-nix-name = "ghc966"`; maps CHaP into the build. |
| `nix/shell.nix` | What lands in your `PATH` inside `nix develop`: cabal, HLS. |
| `cabal.project` | The CHaP repository stanza + `index-state` pins. |
| `always-true.cabal` | The `plinth-options` / `ghc-only-options` split. |
| `src/AlwaysTrue.hs` | On-chain code. Compiled to UPLC by the plugin. |
| `app/GenBlueprint.hs` | Plain GHC code that serialises the compiled script to a CIP-57 blueprint. |

Three things worth internalising:

- **Plutus packages are not on Hackage.** They live in CHaP (`chap.intersectmbo.org`), which is why
  `cabal.project` is mandatory and why `cabal install plutus-tx` will never work.
- **`index-state` pins both Hackage and CHaP to a timestamp.** It is what makes builds reproducible.
  Removing it buys you dependency hell.
- **`plinth-options` vs `ghc-only-options` is load-bearing.** Any module containing on-chain code
  needs that pile of `-fno-full-laziness -fno-specialise -fno-strictness …` flags, because GHC's
  normal optimisations produce Core the plugin can't compile. Modules that merely *use* a compiled
  result (the blueprint generator) must **not** import `plinth-options` — they use ordinary GHC
  features like `GADTs` that the Plinth option set omits.

---

## 7. Troubleshooting

These arrive one at a time, each hidden behind the previous. **Not one of them names its actual
cause**, so read the *first* lines of output, not the last.

| Symptom | Actual cause | Fix |
|---|---|---|
| `plutus-tx-plugin: library is not buildable in the current environment`, followed by 60 "rejected" versions | **Not** a version conflict — a `buildable: False` guard matched. Your GHC is out of the 9.6/9.12 window. | Get onto GHC 9.6.6. Inside `nix develop` this shouldn't happen; if it does, see the ghcup row below. |
| `pkg-config package libsodium-any, not found` / `libblst-any, not found` | The native-library wall (§1). Read `libsodium-any` as "package `libsodium`, any version" — no package by that literal name exists, don't search for it. | Build inside `nix develop`. Homebrew cannot satisfy these. |
| `The package location glob './*.cabal' does not match any files or directories`, under a haskell.nix stack trace | Untracked files. The real clue is the `warning: Git tree ... is dirty` line **above** the error. | `git add -A` (§2.3). |
| `error: attribute 'ghc943' missing` | Someone ran `nix flake update`. | Restore upstream's `flake.lock` (§2.4). |
| GHC itself compiles from source, then `git clone` failures from `gitlab.haskell.org` | The binary cache isn't being used. The clone errors are fallout — Nix decided to build GHC itself, which means cloning GHC and its submodules. Scroll up to the *first* warning. | §2.1. |
| `nix: command not found` but `/nix` exists | Shell init block missing. macOS updates overwrite `/etc/zshrc` and strip Nix's sourcing line — often leaving `/etc/bashrc` intact, so bash works and zsh doesn't. | Add the block to `~/.zshrc` (below), where updates can't touch it. |
| The GHC-gate error *inside* a working `nix develop` | `nix develop` gives you **bash**, so it sources `~/.bashrc`. A ghcup line there puts ghcup's GHC ahead of Nix's on `PATH`. | Keep ghcup out of `~/.bashrc`. |
| `cabal update` reports a newer index-state than the build uses | Expected. `cabal.project` pins `index-state` and that pin wins. | Nothing. Don't delete the pin. |

Shell init block, for the `command not found` case:

```bash
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi
```

Before reinstalling Nix, confirm it's actually broken:

```bash
/nix/var/nix/profiles/default/bin/nix --version   # works? then it's a PATH problem
ls /Library/LaunchDaemons/ | grep -i nix          # daemons present? (macOS)
dscl . -list /Users | grep -c nixbld              # expect 32 (macOS)
```

---

## 8. Docker alternative (no Nix)

If you don't want Nix installed at all, [`.devcontainer/`](.devcontainer/) builds an equivalent
toolchain with plain Docker — no binary cache, so the first build compiles GHC's dependency closure
and the three native libraries from source (§1). Budget 10–20 minutes once; the `cabal-store` volume
makes rebuilds fast after that.

**Versions are hand-pinned to match the Nix side** — GHC 9.6.6, cabal 3.16.1.0, HLS 2.9.0.1, and the
same `libsodium` / `libsecp256k1` / `libblst` revisions as `flake.lock`. If you bump anything in
`nix/` or `flake.lock`, update [`.devcontainer/Dockerfile`](.devcontainer/Dockerfile) to match — it
isn't derived from the flake, so nothing enforces this automatically. The Dockerfile's comments cite
which `flake.lock` node each pin corresponds to.

### 8.1 Build and enter the shell

From the repository root:

```bash
docker compose -f .devcontainer/docker-compose.yml up -d --build
docker compose -f .devcontainer/docker-compose.yml exec plinth bash
```

Then, inside the container (workdir is already `/workspace`, the repo mounted from the host):

```bash
cabal update
cabal build all
cabal run gen-blueprint -- ./plutus.json
```

Same verification as §4 applies — `v3` and a 12-character `compiledCode` means the toolchain works.

### 8.2 Gotchas specific to this path

- **The Compose *service* is `plinth`; the *project* is `devcontainer`.** `docker compose ls` shows
  the project name (taken from the `.devcontainer` folder name), not the service — running
  `docker compose exec devcontainer bash` fails with `service "devcontainer" is not running` because
  there is no service by that name. Use the service name, `plinth`.
- **Run Compose commands from `.devcontainer/`, or pass both `-f` files explicitly.** VS Code's Dev
  Containers extension reads `devcontainer.json` and does this for you; from a plain shell you either
  `cd .devcontainer` first or write:
  ```bash
  docker compose -f .devcontainer/docker-compose.yml -f .devcontainer/docker-compose.override.yml exec plinth bash
  ```
  Skipping the override file still works for building/running — it only matters for the
  HLS-over-Docker path below.
- **No IOG binary cache here.** Unlike `nix develop`, there's nothing to misconfigure (§2.1) — every
  build compiles Plutus from source the first time, by design. That's expected, not a sign something's
  wrong.
- **HLS for editors**: the image ships `haskell-language-server-9.6.6` for VS Code's Dev Containers
  extension (`devcontainer.json` sets `haskell.manageHLS: "PATH"` so the extension doesn't try to
  fetch its own). For other editors, [`hls-docker.sh`](hls-docker.sh) starts the service and pipes
  `haskell-language-server-wrapper --lsp` over `docker compose exec`; [`.nvim.lua`](.nvim.lua) wires
  that in as the `hls` LSP command for Neovim. Both files are path-portable: `hls-docker.sh` resolves
  its own directory at runtime and exports it as `HOST_REPO_PATH`, which
  [`docker-compose.override.yml`](.devcontainer/docker-compose.override.yml) mounts the workspace at —
  so an HLS diagnostic's file path matches what the host editor expects, on any machine or clone path,
  with nothing to edit by hand.

---

## 9. Next steps

- **[Plinth & Plutus Core docs](https://plutus.cardano.intersectmbo.org/docs/)** — the only fully
  current official source. Work through *Example: An Auction Smart Contract*.
- **[plinth-template](https://github.com/IntersectMBO/plinth-template)** — the upstream template
  this project's Nix layer comes from; a fuller starting point with example validators.
- **[CIP-57 blueprints](https://plutus.cardano.intersectmbo.org/docs/working-with-scripts/producing-a-blueprint)**
  — the JSON handoff between your on-chain Haskell and off-chain code (TypeScript, Java, Rust).

One API change to keep in mind while reading older material: since **V3 / CIP-69** a spending
validator takes **one** argument (datum and redeemer moved inside the `ScriptContext`) and signals
success by not failing, rather than the older `Datum -> Redeemer -> ScriptContext -> Bool`. Anything
built on `plutus-apps` — the `Contract` monad, `EmulatorTrace`, the Plutus Playground — is also
deprecated, and off-chain code is now written outside Haskell.
