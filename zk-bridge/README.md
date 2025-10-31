# Dev container for zk-bridge (Ubuntu 24.04)

This repository contains a Dockerfile and helper scripts to create a development container based on Ubuntu 24.04 with Rust, Solana CLI, Node.js (v24) and Yarn installed. The Solana installer is run according to Solana CLI documentation.

Files added:
- `Dockerfile` — builds the dev image (ubuntu:24.04) and runs the Solana installer.
- `scripts/verify_install.sh` — entrypoint that prints tool versions and drops to a shell.
- `scripts/docker-build.sh` — helper to build the Docker image.
- `scripts/run-verify.sh` — helper to run the container and validate installs.

How to build and run

1. Build the image:

```bash
./scripts/docker-build.sh
```

Quick build without installing Solana (faster, useful for iteration):

```bash
SKIP_SOLANA=1 ./scripts/docker-build.sh
```

Run the container and mount the current directory into `/work` inside the container:

```bash
./scripts/run-dev.sh
```

If you want the container process to run as your host user UID:GID (useful to avoid permission issues when creating files), pass `--as-host-user`:

```bash
./scripts/run-dev.sh --as-host-user
```

在后台（detached）运行容器并把当前目录挂载到 `/work`：

```bash
./scripts/run-dev.sh --detach
```

可选地为后台容器指定名称（便于停止/管理）：

```bash
./scripts/run-dev.sh --detach --name my-dev-container
```

停止后台容器（按容器名或 id）：

```bash
docker stop my-dev-container
```

2. Run the container and verify versions (this will run `verify_install.sh` and then drop you into an interactive shell inside the container):

```bash
./scripts/run-verify.sh
```

Notes
- The Solana installer installs user-local binaries into `$HOME/.local/share/solana/install/active_release/bin`. The Docker image updates `PATH` so those are available.
- Anchor CLI is installed via `cargo install` as a best-effort; the Solana installer may already provide Anchor depending on release. If Anchor is required and not installed, install it inside the container with `cargo install --git https://github.com/coral-xyz/anchor --tag v0.32.1 anchor-cli`.
- The verification script prints `rustc`, `solana`, `anchor`, `node`, and `yarn` versions. If any required tool (rustc, solana, node, yarn) is missing the script exits non-zero.

Troubleshooting
- If the image build fails due to network/timeouts while fetching NodeSource or Solana installer, rerun the build.
- For customization (different Node version, additional tools), edit the `Dockerfile`.
