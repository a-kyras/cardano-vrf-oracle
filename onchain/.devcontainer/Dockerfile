# Docker counterpart of the Nix dev shell (flake.nix + nix/), for machines
# without Nix. Versions mirror the Nix pins — cross-check against flake.lock
# and README §1/§6 before bumping anything:
#
#   GHC        9.6.6      nix/project.nix: compiler-nix-name = "ghc966".
#                         Hard requirement — plutus-tx-plugin refuses to
#                         build outside GHC 9.6/9.12 (README §1).
#   cabal      3.16.1.0   The Nix shell pins "latest"; README: anything 3.8+.
#   HLS        2.9.0.1    Newest ghcup release with bindists built against
#                         GHC 9.6.6 (2.10+ ship 9.6.7 only). The Nix shell
#                         instead compiles HLS from source against 9.6.6;
#                         matching the GHC is the load-bearing part (README §5).
#   libsodium  dbb48cc…   IOG's VRF fork — flake.lock node "sodium".
#   secp256k1  acf5c55…   v0.3.2 with schnorrsig — flake.lock node "secp256k1".
#   blst       8c7db7f…   v0.3.14 — flake.lock node "blst". No `make install`
#                         upstream, so the .pc file is written by hand,
#                         exactly like iohk-nix does.
ARG UBUNTU_VERSION=22.04
FROM ubuntu:${UBUNTU_VERSION}

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# Build tools for the three C libraries + what GHC/ghcup need at runtime.
# python3 is only for README §4's plutus.json sanity check.
RUN apt-get update -y && apt-get install -y --no-install-recommends \
  autoconf \
  automake \
  autotools-dev \
  build-essential \
  ca-certificates \
  curl \
  git \
  libgmp-dev \
  libnuma-dev \
  libtinfo-dev \
  libtool \
  pkg-config \
  python3 \
  xz-utils \
  zlib1g-dev \
  && rm -rf /var/lib/apt/lists/*

# --- Native crypto libraries (README §1), pinned to flake.lock's revisions ---

ARG IOG_LIBSODIUM_GIT_REV=dbb48cce5429cb6585c9034f002568964f1ce567
ARG SECP256K1_GIT_REV=acf5c55ae6a94e5ca847e07def40427547876101
ARG BLST_GIT_REV=8c7db7fe8d2ce6e76dc398ebd4d475c0ec564355
ARG BLST_VERSION=0.3.14

# libsodium: IOG's VRF fork; plain libsodium lacks the VRF symbols.
RUN git clone https://github.com/input-output-hk/libsodium \
  && cd libsodium \
  && git checkout ${IOG_LIBSODIUM_GIT_REV} \
  && ./autogen.sh \
  # autogen.sh re-downloads config.{guess,sub} from savannah, which is flaky
  # and can serve junk — replace them with the system copies.
  && cp /usr/share/misc/config.guess /usr/share/misc/config.sub build-aux/ \
  && ./configure \
  && make -j"$(nproc)" \
  && make install \
  && ldconfig \
  && cd .. && rm -rf libsodium

# libsecp256k1: standard builds lack the schnorrsig module.
RUN git clone https://github.com/bitcoin-core/secp256k1 \
  && cd secp256k1 \
  && git checkout ${SECP256K1_GIT_REV} \
  && ./autogen.sh \
  && ./configure --enable-module-schnorrsig --enable-experimental \
  && make -j"$(nproc)" \
  && make install \
  && ldconfig \
  && cd .. && rm -rf secp256k1

# libblst: upstream has no install target and ships no .pc file.
RUN git clone https://github.com/supranational/blst \
  && cd blst \
  && git checkout ${BLST_GIT_REV} \
  && ./build.sh \
  && install -Dm644 libblst.a /usr/local/lib/libblst.a \
  && install -Dm644 -t /usr/local/include bindings/blst.h bindings/blst_aux.h \
  && mkdir -p /usr/local/lib/pkgconfig \
  && printf '%s\n' \
    'prefix=/usr/local' \
    'exec_prefix=${prefix}' \
    'libdir=${exec_prefix}/lib' \
    'includedir=${prefix}/include' \
    '' \
    'Name: libblst' \
    'Description: Multilingual BLS12-381 signature library' \
    'URL: https://github.com/supranational/blst' \
    "Version: ${BLST_VERSION}" \
    'Cflags: -I${includedir}' \
    'Libs: -L${libdir} -lblst' \
    > /usr/local/lib/pkgconfig/libblst.pc \
  && cd .. && rm -rf blst

# --- Haskell toolchain via ghcup ---

ARG GHC_VERSION=9.6.6
ARG CABAL_VERSION=3.16.1.0
ARG HLS_VERSION=2.9.0.1

# Modern cabal defaults to XDG dirs (~/.config, ~/.cache, ~/.local/state);
# force the classic single-directory layout so docker-compose.yml can persist
# the whole cabal state in one volume.
ENV CABAL_DIR=/root/.cabal
ENV PATH=/root/.ghcup/bin:/root/.cabal/bin:${PATH}

RUN mkdir -p /root/.ghcup/bin \
  && curl -fL "https://downloads.haskell.org/~ghcup/$(arch)-linux-ghcup" \
       -o /root/.ghcup/bin/ghcup \
  && chmod +x /root/.ghcup/bin/ghcup

RUN ghcup install ghc ${GHC_VERSION} --set \
  && ghcup install cabal ${CABAL_VERSION} --set \
  && ghcup install hls ${HLS_VERSION} --set

# Warm the Hackage index. CHaP (cabal.project's extra repository) is fetched
# by the first `cabal update` run inside the workspace.
RUN cabal update

WORKDIR /workspace
