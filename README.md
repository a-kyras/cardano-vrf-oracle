# Cardano VRF Oracle

A verifiable-randomness oracle for Cardano: a pairing-based VRF over BLS12-381,
verified on-chain in Plinth, served by an off-chain publisher in Rust.

## What's a VRF, and why this one

A **Verifiable Random Function** takes a secret key and an input, and produces
an output plus a proof. Anyone holding the public key can check the proof —
confirming the output really was derived from that input under that key —
without being able to predict the output in advance or produce a different
valid output for the same input. That's what makes it usable as an on-chain
randomness source: the result is unpredictable *and* checkable.

Cardano's Plutus has no elliptic-curve builtins for Curve25519, which is what
most VRF implementations (e.g. ECVRF) use, and hand-rolling that arithmetic in
Plutus blows the transaction budget. Plutus *does* have builtins for
BLS12-381 pairing operations, so this project uses a pairing-based VRF
construction over that curve instead. It's a different curve family from the
usual ECVRF.

**Flow:** a consumer submits a request UTxO (locking a flat fee, with a nonce
derived from one of the requester's own spent inputs). The off-chain publisher
picks it up, computes a VRF proof over that nonce, and submits a fulfillment
transaction. The on-chain validator recomputes the hash-to-curve of the nonce
and runs the pairing check; if it holds, the random output is emitted. One
UTxO per request, so consumers never contend over a shared feed output. If the
publisher never fulfills, the requester can reclaim their fee after a
deadline.

### Trust model — read this before relying on it

Single operator, no on-chain key registration. The publisher can compute the
VRF output privately before deciding whether to submit a fulfillment, and can
silently withhold outcomes it doesn't like (grinding). There's currently no
economic penalty for non-fulfillment. The VRF math itself is sound; what's
missing is *liveness*, which the formal VRF definition never covered in the
first place.

## Layout

```
backend/     Rust: publisher service, tx building, CLI (builds on the host)
onchain/     Plinth: validators (builds only inside the container)
artifacts/   Committed copy of the generated CIP-57 blueprint
utils/       Rust: libraries and utilities to generate and deploy on-chain part (builds on the host)
```

The Rust and Haskell halves are built completely separately — see below.

## Setup and build

### Prerequisites

- **Rust** (stable, edition 2024 - 1.85+) built directly on the host.
- **Docker**, for the Plinth/Haskell toolchain. See `onchain/README.md` if you'd
  rather use Nix instead of Docker.
- **Script Configuration**, for deployment. Run `make config` to generate random one
- 
### Commands

```bash
make up                  # start the Plinth container
make onchain             # cabal build all, inside the container
make onchain-blueprint   # regenerate artifacts/vrf-validator.json from the validator
make backend             # build the Rust publisher/CLI (release)
make                     # same as `make backend`
make config              # generate new config file in ./artifacts/config.json
make down                # stop the container
make clean               # cargo clean + cabal clean
```

`artifacts/vrf-validator.json` is the canonical, committed CIP-57 blueprint.
Regenerate it with `make onchain-blueprint` after changing anything under
`onchain/src`.

### Utilities
#### Generate Configuration
Script for generating new configuration written in Rust.
Intended for new script setup.

To see command help, run:
```sh
$ cargo run --bin gen_config -- --help
```

#### Generate proof
Script for generating proofs, using existing script configuration.
This is intended for testing and debugging.

To see command help, run:
```sh
$ cargo run --bin gen_proof -- --help
```
