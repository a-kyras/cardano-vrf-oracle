COMPOSE := bin/compose
DC      := $(COMPOSE) exec -T -w /workspace plinth

.PHONY: all up down cabal-update onchain onchain-blueprint backend clean

all: onchain-blueprint backend

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

cabal-update:
	$(DC) cabal update

onchain: up cabal-update
	$(DC) cabal build all

onchain-blueprint: up cabal-update
	$(DC) cabal run gen-blueprint -- plutus.json
	mkdir -p artifacts && cp onchain/plutus.json artifacts/vrf-validator.json

backend:
	cargo build --releasema

clean:
	cargo clean
	$(DC) cabal clean
