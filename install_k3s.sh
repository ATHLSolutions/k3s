#!/usr/bin/env bash
# =============================================================================
# install_k3s.sh — k3s Single-Node Environment Setup
#
# What this script does:
#   1. Install missing system packages (curl, git, docker)
#   2. Install k3s (if not already installed)
#   3. Fix kubeconfig permissions for non-root access
#
# Usage:
#   chmod +x install_k3s.sh
#   ./install_k3s.sh
#
# Supported OS: Debian 11+ / Ubuntu 20.04+
# =============================================================================

set -euo pipefail

# ── colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── working directory ─────────────────────────────────────────────────────────
info "Working directory: $PWD"

# =============================================================================
# 1. SYSTEM PACKAGES
# =============================================================================
info "=== Step 1: System packages ==="

install_if_missing() {
  local cmd="$1" pkg="${2:-$1}"
  if ! command -v "$cmd" &>/dev/null; then
    info "Installing $pkg ..."
    sudo apt-get update -qq 2>/dev/null || true
    sudo apt-get install -y "$pkg"
    ok "$pkg installed"
  else
    ok "$cmd already installed ($(command -v "$cmd"))"
  fi
}

# Ensure apt is available (Debian/Ubuntu)
if ! command -v apt-get &>/dev/null; then
  error "This script requires apt-get (Debian/Ubuntu). Adapt for your distro."
fi

install_if_missing curl
install_if_missing git

# ── helper: disable broken APT sources so apt-get update doesn't fatal-error ──
_fix_broken_apt_sources() {
  local update_output
  update_output=$(sudo apt-get update 2>&1 || true)
  # Check for fatal "E:" errors (not just warnings)
  if ! echo "$update_output" | grep -q "^E:"; then
    return 0  # no fatal errors
  fi
  warn "Broken APT sources detected — disabling them temporarily ..."
  # Extract repo URLs from "E: The repository '...' ..." lines
  echo "$update_output" | grep "^E:.*Release\|^E:.*no longer" \
    | grep -oP "(?<=')[^']+(?=')" \
    | awk -F/ '{print $3}' | sort -u \
    | while read -r host; do
        [ -z "$host" ] && continue
        sudo find /etc/apt/sources.list.d/ -name "*.list" \
          -exec grep -lF "$host" {} \; 2>/dev/null \
          | while read -r f; do
              sudo mv "$f" "${f}.bak-k3s" \
                && warn "  Disabled broken repo file: $(basename "$f")"
            done
      done
  sudo apt-get update -qq 2>/dev/null || true
}

# Docker
if ! command -v docker &>/dev/null; then
  info "Installing Docker ..."
  _fix_broken_apt_sources

  # Try official Docker install script (preferred: installs docker-ce)
  if curl -fsSL https://get.docker.com | sudo sh; then
    ok "Docker installed via official script"
  else
    # Fallback: docker.io package from Debian/Ubuntu main repo
    warn "Official Docker script failed. Trying docker.io package ..."
    sudo apt-get install -y --fix-missing docker.io \
      || error "Docker installation failed. Fix apt repos manually or see https://docs.docker.com/engine/install/ubuntu/"
    ok "Docker installed (docker.io package)"
  fi

  sudo usermod -aG docker "$USER"
  warn "Added to 'docker' group — you may need to log out and back in for non-sudo access."
  warn "Continuing with sudo docker for this session ..."
  DOCKER_CMD="sudo docker"
else
  ok "docker already installed"
  # Check if current user can run docker without sudo
  if docker info &>/dev/null 2>&1; then
    DOCKER_CMD="docker"
  else
    warn "docker requires sudo for this session"
    DOCKER_CMD="sudo docker"
  fi
fi

# =============================================================================
# 2. INSTALL K3S
# =============================================================================
info "=== Step 2: k3s installation ==="

if ! command -v k3s &>/dev/null; then
  info "Installing k3s ..."
  curl -sfL https://get.k3s.io | sh -
  ok "k3s installed"
  # Wait for k3s to be ready
  info "Waiting for k3s to start ..."
  for i in $(seq 1 30); do
    if sudo k3s kubectl get nodes &>/dev/null 2>&1; then
      ok "k3s is running"
      break
    fi
    if [ "$i" -eq 30 ]; then
      error "k3s did not start within 60 seconds. Check: sudo journalctl -u k3s -n 50"
    fi
    sleep 2
  done
else
  ok "k3s already installed ($(k3s --version | head -1))"
fi

# =============================================================================
# 3. KUBECONFIG
# =============================================================================
info "=== Step 3: kubeconfig setup ==="

K3S_KUBECONFIG=/etc/rancher/k3s/k3s.yaml
if [ -f "$K3S_KUBECONFIG" ]; then
  sudo chmod 644 "$K3S_KUBECONFIG"
  export KUBECONFIG="$K3S_KUBECONFIG"
  ok "kubeconfig: $K3S_KUBECONFIG (mode 644)"
else
  error "k3s kubeconfig not found at $K3S_KUBECONFIG"
fi

# Persist KUBECONFIG in ~/.bashrc if not already there
if ! grep -q "KUBECONFIG.*k3s" ~/.bashrc 2>/dev/null; then
  echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> ~/.bashrc
  ok "Added KUBECONFIG to ~/.bashrc"
fi

# Verify kubectl works (k3s symlinks kubectl but may not be in PATH yet)
kubectl get nodes || sudo k3s kubectl get nodes || error "kubectl cannot connect to k3s"


