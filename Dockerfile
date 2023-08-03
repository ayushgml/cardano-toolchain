FROM debian:stable-slim AS builder

# Set environment variables
ENV DEBIAN_FRONTEND noninteractive
ENV LC_ALL C.UTF-8
ENV LANG C.UTF-8

# Install build dependencies
RUN apt-get update -y
RUN apt-get install -y \
  python3 \
  python3-pip \
  automake \
  build-essential \
  pkg-config \
  libffi-dev \
  libgmp-dev \
  libssl-dev \
  libtinfo-dev \
  systemd \
  libsystemd-dev \
  libsodium-dev \
  libsodium23 \
  zlib1g-dev \
  npm \
  yarn \
  make \
  g++ \
  tmux \
  git \
  jq \
  wget \
  libncursesw5 \
  gnupg \
  libtool \
  autoconf \
  curl
RUN apt-get clean

# Install GHC
RUN wget https://downloads.haskell.org/ghc/8.10.7/ghc-8.10.7-x86_64-deb10-linux.tar.xz \
  && tar -xf ghc-8.10.7-x86_64-deb10-linux.tar.xz \
  && rm ghc-8.10.7-x86_64-deb10-linux.tar.xz \
  && cd ghc-* \
  && ./configure \
  && make install \
  && cd ..


# Install cabal
RUN wget https://downloads.haskell.org/~cabal/cabal-install-3.8.1.0/cabal-install-3.8.1.0-x86_64-linux-deb10.tar.xz
RUN tar -xf cabal-install-3.8.1.0-x86_64-linux-deb10.tar.xz
RUN rm cabal-install-3.8.1.0-x86_64-linux-deb10.tar.xz
RUN mv cabal /usr/bin/
RUN cabal update





# Install libsodium
RUN git clone https://github.com/input-output-hk/libsodium \
  && cd libsodium \
  && git fetch --all --recurse-submodules --tags \
  && git tag \
  && echo git checkout dbb48cc \
  && ./autogen.sh \
  && ./configure \
  && make \
  && make install

ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH" 
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"

RUN git clone https://github.com/bitcoin-core/secp256k1 \
  && cd secp256k1 \
  && git checkout ac83be33 \
  && ./autogen.sh \
  && ./configure --enable-module-schnorrsig --enable-experimental \
  && make \
  && make check \
  && make install

# Install cardano-node

RUN echo "Building tags/8.2.0-pre..." 
RUN echo tags/8.2.0-pre > /CARDANO_BRANCH 
RUN git clone https://github.com/input-output-hk/cardano-node.git \
  && cd cardano-node \
  && git fetch --all --recurse-submodules --tags \
  && git tag \
  && git checkout 8.2.0-pre \
  && cabal configure --with-compiler=ghc-8.10.7 \
  && echo -e "package cardano-crypto-praos\n flags: -external-libsodium-vrf" >>  cabal.project.local \
  && cabal update \
  && cabal build all
RUN mkdir -p /root/.local/bin/ \
  && cp -p dist-newstyle/build/x86_64-linux/ghc-8.10.2/cardano-node-8.2.0-pre/x/cardano-node/build/cardano-node/cardano-node /root/.local/bin/ \
  && cp -p dist-newstyle/build/x86_64-linux/ghc-8.10.2/cardano-cli-8.2.0-pre/x/cardano-cli/build/cardano-cli/cardano-cli /root/.local/bin/


FROM debian:stable-slim

# Copy the binaries/libraries we've just built in the builder stage
COPY --from=builder /root/.local/bin/cardano-* /usr/local/bin/
COPY --from=builder /usr/local/lib/libsodium* /usr/local/lib/

# Install tools
RUN apt-get update && \
  apt-get install -y \
  curl        \
  dnsutils    \
  jq          \
  net-tools   \ 
  procps      \ 
  python3     \
  python3-pip \ 
  telnet      \
  tmux        \
  vim         \
  wget        \
  bc          \
  curl

# Remove uneccesary packages
RUN rm -rf /var/lib/apt/lists/*

# Set the working directory to /app
WORKDIR /app
