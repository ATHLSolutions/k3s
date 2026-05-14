# k3s Single-Node Setup

Script to install and configure a single-node [k3s](https://k3s.io/) cluster on Debian/Ubuntu.

## Requirements

| Requirement | Notes |
|---|---|
| OS | Debian 11+ or Ubuntu 20.04+ |
| User | Sudo privileges required |
| Internet | Required to download k3s, Docker, and images |

## Quick Start

```bash
chmod +x install_k3s.sh
./install_k3s.sh
```

## What `install_k3s.sh` Does

1. **System packages** — installs `curl`, `git` via `apt-get`
2. **Docker** — installs via `https://get.docker.com`; falls back to `docker.io` package
3. **k3s** — installs via `https://get.k3s.io` and waits for the node to be ready
4. **kubeconfig** — sets `/etc/rancher/k3s/k3s.yaml` to mode `644` and exports `KUBECONFIG`

## Notes

- Re-running the script is safe — each step checks if the tool is already installed before proceeding.
- If Docker requires sudo for the current session, the script automatically uses `sudo docker`.
- Broken APT sources are automatically disabled to prevent `apt-get update` failures.
