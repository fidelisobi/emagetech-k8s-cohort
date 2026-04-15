#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Kubernetes Cohort — Environment Setup Script
# Installs everything you need for the class on macOS or Linux (Ubuntu/Debian)
# Usage: curl -fsSL https://raw.githubusercontent.com/emage-tech/kubernetes-january-2026-cohort/main/setup.sh | bash
# ─────────────────────────────────────────────────────────────────────────────

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── Detect OS ────────────────────────────────────────────────
OS="$(uname -s)"
ARCH="$(uname -m)"
[[ "$ARCH" == "x86_64" ]] && ARCH_SUFFIX="amd64"
[[ "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]] && ARCH_SUFFIX="arm64"

info "Detected OS: $OS | Arch: $ARCH"
echo ""

# ── Helper: check if command exists ─────────────────────────
installed() { command -v "$1" &>/dev/null; }

# ── macOS: ensure Homebrew ────────────────────────────────────
if [[ "$OS" == "Darwin" ]]; then
  if ! installed brew; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    success "Homebrew already installed"
  fi
fi

install_tool() {
  local name="$1"; local brew_pkg="$2"; local apt_pkg="$3"; local check_cmd="${4:-$1}"
  if installed "$check_cmd"; then
    success "$name already installed: $($check_cmd version 2>/dev/null | head -1 || echo 'ok')"
    return
  fi
  info "Installing $name..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install "$brew_pkg"
  elif [[ "$OS" == "Linux" ]]; then
    sudo apt-get update -qq && sudo apt-get install -y "$apt_pkg"
  fi
  success "$name installed"
}

echo "════════════════════════════════════════"
echo "  Installing Kubernetes Toolchain"
echo "════════════════════════════════════════"
echo ""

# ── kubectl ──────────────────────────────────────────────────
if ! installed kubectl; then
  info "Installing kubectl..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install kubectl
  else
    KUBECTL_VER=$(curl -sL https://dl.k8s.io/release/stable.txt)
    curl -sLO "https://dl.k8s.io/release/${KUBECTL_VER}/bin/linux/${ARCH_SUFFIX}/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
  fi
  success "kubectl installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
else
  success "kubectl already installed"
fi

# ── Helm ─────────────────────────────────────────────────────
if ! installed helm; then
  info "Installing Helm..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  success "Helm installed: $(helm version --short)"
else
  success "Helm already installed"
fi

# ── ArgoCD CLI ───────────────────────────────────────────────
if ! installed argocd; then
  info "Installing ArgoCD CLI..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install argocd
  else
    ARGOCD_VER=$(curl -sI https://github.com/argoproj/argo-cd/releases/latest | grep -i location | awk -F'/' '{print $NF}' | tr -d '\r')
    curl -sLO "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VER}/argocd-linux-${ARCH_SUFFIX}"
    sudo install -m 555 "argocd-linux-${ARCH_SUFFIX}" /usr/local/bin/argocd
    rm "argocd-linux-${ARCH_SUFFIX}"
  fi
  success "ArgoCD CLI installed"
else
  success "ArgoCD CLI already installed"
fi

# ── k9s ──────────────────────────────────────────────────────
if ! installed k9s; then
  info "Installing k9s (terminal UI for Kubernetes)..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install k9s
  else
    K9S_VER=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d'"' -f4)
    curl -sLO "https://github.com/derailed/k9s/releases/download/${K9S_VER}/k9s_Linux_${ARCH_SUFFIX}.tar.gz"
    tar xzf "k9s_Linux_${ARCH_SUFFIX}.tar.gz" k9s
    sudo mv k9s /usr/local/bin/
    rm "k9s_Linux_${ARCH_SUFFIX}.tar.gz"
  fi
  success "k9s installed"
else
  success "k9s already installed"
fi

# ── kubectx / kubens ─────────────────────────────────────────
if ! installed kubectx; then
  info "Installing kubectx + kubens..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install kubectx
  else
    sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx 2>/dev/null || true
    sudo ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx
    sudo ln -sf /opt/kubectx/kubens /usr/local/bin/kubens
  fi
  success "kubectx + kubens installed"
else
  success "kubectx already installed"
fi

# ── Stern (multi-pod log tailing) ────────────────────────────
if ! installed stern; then
  info "Installing stern (multi-pod log viewer)..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install stern
  else
    STERN_VER=$(curl -s https://api.github.com/repos/stern/stern/releases/latest | grep tag_name | cut -d'"' -f4)
    curl -sLO "https://github.com/stern/stern/releases/download/${STERN_VER}/stern_${STERN_VER#v}_linux_${ARCH_SUFFIX}.tar.gz"
    tar xzf "stern_${STERN_VER#v}_linux_${ARCH_SUFFIX}.tar.gz" stern
    sudo mv stern /usr/local/bin/
    rm "stern_${STERN_VER#v}_linux_${ARCH_SUFFIX}.tar.gz"
  fi
  success "stern installed"
else
  success "stern already installed"
fi

# ── kubeconform (YAML validator) ─────────────────────────────
if ! installed kubeconform; then
  info "Installing kubeconform..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install kubeconform
  else
    curl -sL https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-linux-${ARCH_SUFFIX}.tar.gz \
      | sudo tar xz -C /usr/local/bin
  fi
  success "kubeconform installed"
else
  success "kubeconform already installed"
fi

# ── Docker ───────────────────────────────────────────────────
if ! installed docker; then
  warn "Docker not found."
  if [[ "$OS" == "Darwin" ]]; then
    echo "  → Download Docker Desktop: https://www.docker.com/products/docker-desktop/"
  else
    echo "  → Install Docker Engine: https://docs.docker.com/engine/install/ubuntu/"
    echo "  → Or run: curl -fsSL https://get.docker.com | sh"
  fi
else
  success "Docker already installed"
fi

# ── Git ───────────────────────────────────────────────────────
if ! installed git; then
  info "Installing git..."
  if [[ "$OS" == "Darwin" ]]; then
    brew install git
  else
    sudo apt-get install -y git
  fi
fi
success "git installed: $(git --version)"

# ── Final check ──────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo "  Setup Complete! Version Summary:"
echo "════════════════════════════════════════"
for cmd in kubectl helm argocd k9s kubectx stern kubeconform git docker; do
  if installed "$cmd"; then
    VER=$($cmd version 2>/dev/null | head -1 || $cmd --version 2>/dev/null | head -1 || echo "installed")
    printf "  %-15s %s\n" "$cmd" "$VER"
  else
    printf "  %-15s %s\n" "$cmd" "⚠️  not installed"
  fi
done

echo ""
echo "Next steps:"
echo "  1. Make sure your KUBECONFIG is set: export KUBECONFIG=~/.kube/config"
echo "  2. Verify cluster access: kubectl get nodes"
echo "  3. Clone the class repo (if not already):"
echo "     git clone https://github.com/emage-tech/kubernetes-january-2026-cohort.git"
echo ""
success "You're ready for the Kubernetes cohort! 🚀"
