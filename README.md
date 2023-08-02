<a name="readme-top"></a>

<!-- PROJECT LOGO -->
<br />
<div align="center">
  <a href="https://github.com/ayushgml/cardano-toolchain">
  </a>

  <h1 align="center">Build Toolchain for Cardano using Containerization</h1>

  <p align="center">
    <a href="https://github.com/ayushgml/cardano-toolchain"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/ayushgml/cardano-toolchain">View Demo</a>
    ·
    <a href="https://github.com/ayushgml/cardano-toolchain/issues">Report Bug</a>
    ·
    <a href="https://github.com/ayushgml/cardano-toolchain/issues">Request Feature</a>
  </p>
</div>

<!-- ABOUT THE PROJECT -->
## About The Project
a Containerfile that can be used as a build toolchain for cardano-node and cardano-cli (including libsodium).

Read the below section to know the details

<p align="right">(<a href="#readme-top">back to top</a>)</p>


<!-- GETTING STARTED -->
## Steps to build the containerfile
#### Setting the base image
```FROM debian:stable-slim AS builder``` : This line sets the base image to Debian's stable-slim version. We give it an alias as 'builder' using the "AS" keyword.


#### Set environment variables
```ENV DEBIAN_FRONTEND noninteractive```

This prevents any interactive prompts during package installations.

```
ENV LC_ALL C.UTF-8
ENV LANG C.UTF-8
```
These lines set the character encoding for the local and system language.


#### Install build dependencies
```
RUN apt-get update -y
```
Updating the package repository metadata.

```
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
```
Installing build dependencies required for GHC, Cabal, libsodium(dependencies for cardano-node and CLI) and cardano-node


#### Install cabal
```
RUN wget https://downloads.haskell.org/~cabal/cabal-install-3.2.0.0/cabal-install-3.2.0.0-x86_64-unknown-linux.tar.xz \
  && tar -xf cabal-install-3.2.0.0-x86_64-unknown-linux.tar.xz \
  && rm cabal-install-3.2.0.0-x86_64-unknown-linux.tar.xz cabal.sig \
  && mv cabal /usr/bin/ \
  && cabal update
```
Downloading the cabal version 3.2 tar file. Then after extracting the fo;der we remove the downloaded archive. Then we move cabal to /usr/bin/ so that we can run the cabal command then.


#### Install GHC
```
RUN wget https://downloads.haskell.org/ghc/8.10.2/ghc-8.10.2-x86_64-deb9-linux.tar.xz \
  && tar -xf ghc-8.10.2-x86_64-deb9-linux.tar.xz \
  && rm ghc-8.10.2-x86_64-deb9-linux.tar.xz \
  && cd ghc-8.10.2 \
  && ./configure \
  && make install \
  && cd ..
```
Downloading GHC (Glasgow Haskell Compiler) version 8.10.2, extracts it, removes the downloaded archive, configures, installs, and sets up GHC.

#### Install libsodium
```
RUN git clone https://github.com/input-output-hk/libsodium \
  && cd libsodium \
  && git fetch --all --recurse-submodules --tags \
  && git tag \
  && echo git checkout 66f017f1 \
  && ./autogen.sh \
  && ./configure \
  && make \
  && make install
```

Clones the libsodium repository, fetches tags, checks out a specific tag - 66f017f1. Then we run autogen.sh and configure, builds the library, and installs it.


```
ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH" 
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
```
Setting up the environment variable "LD_LIBRARY_PATH" to include the /usr/local/lib directory, allowing the system to find dynamically linked libraries at runtime. Also, the environment variable "PKG_CONFIG_PATH" to include the /usr/local/lib/pkgconfig directory, allowing the system to find pkg-config files for libraries at build time.

#### Install cardano-node
```
RUN echo "Building tags/1.26.0..." \
  && echo tags/1.26.0 > /CARDANO_BRANCH \
  && git clone https://github.com/input-output-hk/cardano-node.git \
  && cd cardano-node \
  && git fetch --all --recurse-submodules --tags \
  && git tag \
  && git checkout tags/1.26.0
```
Clones the cardano-node repository, fetches tags, checks out a specific tag - 1.26.0. Note: This is a stable version! (You can change the tag to another stable version if you want to build the another version of cardano-node.)


```
WORKDIR /cardano-node/
RUN cabal configure --with-compiler=ghc-8.10.2 \
  && echo "package cardano-crypto-praos" >>  cabal.project.local \
  && echo "  flags: -external-libsodium-vrf" >>  cabal.project.local \
  && cabal build cardano-node cardano-cli
RUN mkdir -p /root/.local/bin/ \
  && cp -p dist-newstyle/build/x86_64-linux/ghc-8.10.2/cardano-node-1.26.0/x/cardano-node/build/cardano-node/cardano-node /root/.local/bin/ \
  && cp -p dist-newstyle/build/x86_64-linux/ghc-8.10.2/cardano-cli-1.26.0/x/cardano-cli/build/cardano-cli/cardano-cli /root/.local/bin/
```
We change the work directory to /cardano-node/ and then we configure cabal to use the GHC version 8.10.2. Then we add the cardano-crypto-praos package to the cabal.project.local file. Then we build the cardano-node and cardano-cli. Then we create a directory /root/.local/bin/ and copy the cardano-node and cardano-cli binaries to the directory. 


#### Starting a new build stage
```
FROM debian:stable-slim
```
From here we start a new stage build. We use multi stage build to reduce the size of the final image.(Otherwise the final image will be around 9GB)


#### Copy the binaries/libraries we've just built in the builder stage
```
COPY --from=builder /root/.local/bin/cardano-* /usr/local/bin/
COPY --from=builder /usr/local/lib/libsodium* /usr/local/lib/
```
Copies the binaries and libraries built in the previous "builder" stage to the corresponding locations in the new stage.

#### Install tools
```
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
```
Updating and installing some necessary tools that may be needed when running the final container.

#### Remove uneccesary packages
```
RUN rm -rf /var/lib/apt/lists/*
```
Removing uneccesary libraries and files that we we installed in the builder stage that we dont need anymore. 

#### Set the working directory to /app
```
WORKDIR /app
```
Changing the work directory to /app

The containerfile is ready now!

## Usage
#### Building the image from Dockerfile

```
git clone https://github.com/ayushgml/cardano-toolchain
cd cardano-toolchain
docker build -t cardano-toolchain .
docker run -it cardano-toolchain
```

#### Pulling the image from Docker Hub

```
docker run -it ayushgml/cardano-toolchain
```

Then you can use the cardano-node and cardano-cli commands inside container.


### Dependency Hierarchy
![Dependencies](https://github.com/ayushgml/cardano-toolchain/assets/72748253/b42aa73b-854a-4cf9-b73d-c5cb6421f513)

### Flow of the Containerfile
![Flow](https://github.com/ayushgml/cardano-toolchain/assets/72748253/c03d7914-675f-4b1e-a150-7d23d2d29c46)


### Continuous Integration
I added Github Actions to the repository to build the image and push it to Docker Hub whenever a push/PR is made to the main branch. The workflow file is located at .github/workflows/docker-image.yml

### Docker Hub
The image is available on Docker Hub at [https://hub.docker.com/repository/docker/ayushgml/cardano-toolchain/general](https://hub.docker.com/repository/docker/ayushgml/cardano-toolchain/general)



<!-- CONTACT -->
## Contact

Ayush Gupta - [@itsayush__](https://twitter.com/itsayush__) - ayushgml@gmail.com

Project Link: [https://github.com/ayushgml/cardano-toolchain](https://github.com/ayushgml/cardano-toolchain)

<p align="right">(<a href="#readme-top">back to top</a>)</p>



