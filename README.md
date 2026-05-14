# VoiceAI — k3s Single-Node Setup

Scripts to prepare and deploy the **VoiceAI** stack on a single-node [k3s](https://k3s.io/) cluster.

## Requirements

| Requirement | Notes |
|---|---|
| OS | Debian 11+ or Ubuntu 20.04+ |
| User | Sudo privileges required |
| Internet | Required to download k3s, Docker, and images |

## Quick Start

```bash
cd ~/voiceai
chmod +x k3s/scripts/01-prepare.sh

# Default: build images locally and import into k3s containerd
./k3s/scripts/01-prepare.sh
```

After the script completes, fill in your API keys in `.env.k3s`, then deploy:

```bash
./k3s/scripts/02-deploy.sh
```

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `REGISTRY` | *(empty)* | Container registry URL. Empty = local import mode |
| `IMAGE_TAG` | `latest` | Tag applied to all built images |
| `GHCR_USERNAME` | *(empty)* | GitHub username for GHCR login |
| `GHCR_TOKEN` | *(empty)* | GitHub PAT with `packages:write` scope |

### Push to GitHub Container Registry (GHCR)

```bash
GHCR_USERNAME=<github-username> \
GHCR_TOKEN=<github-pat> \
REGISTRY=ghcr.io/<github-owner> \
IMAGE_TAG=v1 \
./k3s/scripts/01-prepare.sh
```

## What `install_k3s.sh` Does

1. **System packages** — installs `curl`, `git`, `python3`, `pip3` via `apt-get`
2. **Docker** — installs via `https://get.docker.com`; falls back to `docker.io` package
3. **k3s** — installs via `https://get.k3s.io` and waits for the node to be ready
4. **kubeconfig** — sets `/etc/rancher/k3s/k3s.yaml` to mode `644` and exports `KUBECONFIG`
5. **Python venv** — creates `.venv` and installs `asyncpg`, `redis`, `nats-py`

## Notes

- Re-running the script is safe — each step checks if the tool is already installed before proceeding.
- If Docker requires sudo for the current session, the script automatically uses `sudo docker`.
- Broken APT sources are automatically disabled to prevent `apt-get update` failures.
