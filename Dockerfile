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
  autoconf
RUN apt-get clean

# Install cabal
RUN wget https://downloads.haskell.org/~cabal/cabal-install-3.2.0.0/cabal-install-3.2.0.0-x86_64-unknown-linux.tar.xz \
  && tar -xf cabal-install-3.2.0.0-x86_64-unknown-linux.tar.xz \
  && rm cabal-install-3.2.0.0-x86_64-unknown-linux.tar.xz cabal.sig \
  && mv cabal /usr/bin/ \
  && cabal update


# Install GHC
RUN wget https://downloads.haskell.org/ghc/8.10.2/ghc-8.10.2-x86_64-deb9-linux.tar.xz \
  && tar -xf ghc-8.10.2-x86_64-deb9-linux.tar.xz \
  && rm ghc-8.10.2-x86_64-deb9-linux.tar.xz \
  && cd ghc-8.10.2 \
  && ./configure \
  && make install \
  && cd ..


# Install libsodium
RUN git clone https://github.com/input-output-hk/libsodium \
  && cd libsodium \
  && git fetch --all --recurse-submodules --tags \
  && git tag \
  && echo git checkout 66f017f1 \
  && ./autogen.sh \
  && ./configure \
  && make \
  && make install

ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH" 
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"

# Install cardano-node
RUN echo "Building tags/1.26.0..." \
  && echo tags/1.26.0 > /CARDANO_BRANCH \
  && git clone https://github.com/input-output-hk/cardano-node.git \
  && cd cardano-node \
  && git fetch --all --recurse-submodules --tags \
  && git tag \
  && git checkout tags/1.26.0
WORKDIR /cardano-node/
RUN cabal configure --with-compiler=ghc-8.10.2 \
  && echo "package cardano-crypto-praos" >>  cabal.project.local \
  && echo "  flags: -external-libsodium-vrf" >>  cabal.project.local \
  && cabal build cardano-node cardano-cli
RUN mkdir -p /root/.local/bin/ \
  && cp -p dist-newstyle/build/x86_64-linux/ghc-8.10.2/cardano-node-1.26.0/x/cardano-node/build/cardano-node/cardano-node /root/.local/bin/ \
  && cp -p dist-newstyle/build/x86_64-linux/ghc-8.10.2/cardano-cli-1.26.0/x/cardano-cli/build/cardano-cli/cardano-cli /root/.local/bin/

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
