# CLAUDE.md

Guidance for AI assistants working in this repository.

## What this is

A verifiable-randomness oracle for Cardano: a pairing-based VRF over BLS12-381,
verified on-chain in Plinth, served by an off-chain publisher in Rust.

Consumers submit a request UTxO; the publisher computes a VRF proof over the
request's nonce and submits a fulfillment transaction; the validator verifies the
pairing check on-chain and emits the random output. One UTxO per request.

This is a short-horizon project. Prefer working, measured, honestly-documented
over feature-complete.

## Layout

```
.devcontainer/          Extension of the onchain/.devcontainer
artifacts/              Contains copy of generated blueprint
backend/                Rust: publisher service, tx building, CLI
onchain/                Plinth: validators (container-only)
  .devcontainer/        docker-compose.yml + Dockerfile (SHARED — see below)
  app/                  CIP-57 blueprint generator
  src/                  validators
  plutus.json           generated blueprint — committed, canonical
  cabal.project         CHaP pins
Cargo.toml              Rust workspace root
```

## Build split — read before running anything

**Rust builds on the host. Haskell builds in the container.** Do not cross these.

The container bind-mounts `onchain/` (not the repo root) at `/workspace`. So:

- `/workspace` *is* the Haskell project root — `cabal` commands need no `cd`
- PATH is set in the image — no `bash -lc` wrapper needed
- The container **cannot see** `backend/`, `Cargo.toml`, or the repo root

Never run `cargo build` inside the container — it writes host-incompatible
artifacts into the shared `target/`.

`onchain/.devcontainer/` is a **shared internal template used by other repos.**
Do not edit it. Repo-specific container changes go in a root-level
`docker-compose.override.yml` instead.

The created blueprint is always stored in `artifacts/vrf-validator.json`.
Regenerating it is a manual step after validator changes, not part of the Rust build.

## Architecture

**On-chain**

- VRF public key: fixed script parameter (single operator, no on-chain registration)
- Request validator: locks flat fee. Datum = nonce, requester PKH, deadline slot.
  Two spend paths — fulfill (valid proof, before deadline) or reclaim (after deadline)
- Fulfillment: redeemer carries compressed proof + output; validator recomputes
  hash-to-curve of the nonce and runs the pairing check
- Demo consumer: reads the result via reference input

**Off-chain (Rust)**

- VRF secret key + proof generation (`blst`)
- Chain watcher for new request UTxOs
- Fulfillment tx builder
- Requester-side CLI

**Nonce derivation:** hash of one of the requester's own spent inputs
(tx hash + index). Guarantees per-request uniqueness and anti-replay.

## Settled decisions

| Decision                                  | Why                                                                                                                                                            |
|-------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Pairing-based VRF on BLS12-381            | Plutus has no Curve25519 builtin; hand-rolled EC arithmetic blows the budget. This is a real VRF, not a workaround — just a different curve family than ECVRF. |
| Plinth first (Aiken later for comparison) | Deliberate. A same-verifier, two-language exUnits comparison is a wanted deliverable. Keep the verifier structured so it ports cleanly.                        |
| One UTxO per request                      | A shared feed UTxO creates transaction contention — every consumer races to spend the same output.                                                             |
| Flat fee                                  | See rejected: bid-ranked capacity.                                                                                                                             |
| Deadline + requester reclaim              | Guarantees funds are never stuck if the publisher goes offline.                                                                                                |
| Result as datum, not minted token         | Saves building minting policy logic. Revisit only if composability is needed.                                                                                  |
| Compressed points in datum/redeemer       | Builtin BLS types cannot be serialized directly. Uncompress on-chain.                                                                                          |

## Rejected — do not re-propose without new information

**Economic bonding / slashing for non-fulfillment.** Flood-drain attack: an
attacker submits more requests than the publisher's throughput can serve, so
requests time out through no fault of the operator. Each timeout returns the
attacker's fee *and* pays them from the bond — net cost is only network fees.
Any penalty mechanism that cannot distinguish "operator misbehaved" from
"operator was overwhelmed" inverts the incentive.

**Future-chain anchor (block hash / epoch nonce) as anti-grinding entropy.**
Plutus validators see only the current transaction's context. Whoever builds the
tx must *supply* the block value, so you'd be trusting the publisher to report it
honestly — the exact assumption being removed. A trustless version needs on-chain
block-header verification (a lightweight chain client), which is its own project.

**Bid-ranked capacity ("fulfill top N bids per block").** Makes non-fulfillment
*legitimate*, giving cherry-picking perfect cover — you can no longer distinguish
"below the cutoff" from "didn't like the output." Also creates publisher
self-dealing on declared capacity, and requires the selection rule to be enforced
on-chain to mean anything.

## Trust model — state this plainly, never soften it

Single operator. The publisher can compute the VRF output privately before
deciding whether to submit, and can silently withhold unfavorable outcomes
(grinding). There is no economic penalty for non-fulfillment.

The VRF math is sound — uniqueness, pseudorandomness, verifiability all hold.
The gap is *liveness*, which the formal VRF definition never covered.

Mitigations, in order of preference, both out of current scope:
1. Publisher-side commit-reveal (commit to a proof hash before revealing)
2. Threshold signing across multiple keys (removes the preview entirely)

Do not write documentation implying this is solved. "The operator is honest" is a
statement about a person, not a property of the system.

## Plinth conventions

- `PlutusTx.Prelude`, not `Prelude`. Plugin errors from accidental `Prelude` use
  point at the compilation pipeline, not the real mistake.
- `INLINABLE` on anything crossing into compiled code.
- `.cabal` keeps two option sets — `plinth-options` for the on-chain library,
  `ghc-only-options` for the blueprint executables. Do not merge them.
- Prefer the Template Haskell `$$(compile [|| ... ||])` form over the `-fplugin`
  flag — better error locations.
- Use `millerLoop` twice + one `finalVerify` (with `mulMlResult` where it helps)
  rather than two full pairings. This is the intended fast path.
- Uncompression dominates cost, not the pairings (G1 uncompress ~16.5M CPU units
  vs ~3.3M for compress; G2 worse). Optimize there first.

## Open questions

- **Which BLS variant is cheaper on-chain?** minimal-signature-size (sig in G1,
  hashToG1, pk in G2) vs minimal-pubkey-size (the reverse). Trade cheap
  hash-to-curve against cheap pubkey uncompress. Measure, don't reason.
- **Full-flow exUnits** — measure the complete fulfillment tx, not just an
  isolated verify script.
- **Cabal store persistence** — the compose file mounts `cabal-store` at
  `/root/.cabal`, but cabal 3.10+ follows XDG and may use `~/.local/state/cabal`
  instead, making the volume a no-op. Verify with `cabal path --store-dir`.

## Priority when time runs short

Verification correctness over demo polish. A working proof-verification loop with
a boring consumer beats a flashy demo on unverified randomness.