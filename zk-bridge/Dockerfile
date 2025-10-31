FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install core packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates curl wget git build-essential pkg-config libssl-dev clang cmake lldb gnupg2 sudo \
       locales procps file \
    && rm -rf /var/lib/apt/lists/*

ENV HOME=/root
ENV USER=root
ENV NVM_DIR=/root/.nvm
ENV PATH=$HOME/.local/share/solana/install/active_release/bin:$HOME/.cargo/bin:$PATH

# Install Rust (rustup) as root
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Install nvm and Node.js (v24) as root, then yarn
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install 24 \
    && nvm alias default 24 \
    && npm install -g yarn@1.22.22 || true

# Allow skipping Solana installer at build time
ARG INSTALL_SOLANA=true
ENV INSTALL_SOLANA=${INSTALL_SOLANA}
RUN if [ "$INSTALL_SOLANA" = "true" ]; then \
      curl --proto '=https' --tlsv1.2 -sSfL https://solana-install.solana.workers.dev | bash; \
    else \
      echo "Skipping Solana installer (BUILD ARG INSTALL_SOLANA=false)"; \
    fi

# Best-effort install Anchor CLI via cargo
RUN . $HOME/.cargo/env && \
    cargo install --git https://github.com/coral-xyz/anchor --tag v0.32.1 anchor-cli || true

# Create a workspace mount point
RUN mkdir -p /workspace && chown root:root /workspace
WORKDIR /workspace

# Copy verification script and make it executable
COPY scripts/verify_install.sh /verify_install.sh
RUN chmod +x /verify_install.sh

# Default command keeps the container alive so it can be run in detached mode
CMD ["/bin/bash", "-c", "sleep infinity"]

# Optional: expose a shell entrypoint (commented out by default)
# ENTRYPOINT ["/verify_install.sh"]
