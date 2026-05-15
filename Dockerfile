# Base images with other frontends are available - simply replace "vscodium" with
# "jupyter" or "ttyd".
FROM ghcr.io/swissdatasciencecenter/renku/py-basic-vscodium:2.15.0

# Install OS-level build/runtime dependencies as root. These packages are
# required by ghcup/GHC and cannot be installed later in an unprivileged session.
USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        clang-15 \
        curl \
        libffi-dev \
        libgmp-dev \
        libncurses-dev \
        llvm-15 \
        xz-utils \
        zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

# Install the Haskell toolchain as the regular Renku user. ghcup is a user-space
# toolchain manager and installs into $HOME, which avoids root-owned files in the
# user's Haskell directories. This block is intentionally before requirements.txt
# is copied so the slow GHC install stays cached when Python dependencies change.
USER 1000
ENV HOME=/home/renku
ENV PATH="${HOME}/.ghcup/bin:${HOME}/.cabal/bin:${PATH}"

RUN export BOOTSTRAP_HASKELL_NONINTERACTIVE=1 \
        BOOTSTRAP_HASKELL_MINIMAL=1 \
        BOOTSTRAP_HASKELL_INSTALL_NO_STACK=1 && \
    curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh && \
    ghcup install ghc 9.10.1 && \
    ghcup set ghc 9.10.1 && \
    ghcup install cabal 3.12.1.0 && \
    ghc --version && \
    cabal --version

# Switch back to root for Python dependencies because the Paketo/Python layer
# under /layers is not writable by the regular user. Use the CNB launcher rather
# than a hard-coded layer path so this is resilient to base image changes.
USER root
COPY requirements.txt /tmp/requirements.txt
RUN /cnb/lifecycle/launcher python -m pip install --no-cache-dir -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

# Run the final image as the regular Renku user.
USER 1000
