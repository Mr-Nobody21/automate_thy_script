#!/bin/bash

set -e

OS=$(uname -s)

# Package manager detection
if [ -f /etc/debian_version ]; then
  PM="apt-get"
elif [ -f /etc/redhat-release ]; then
  PM="yum"
elif [ "$OS" == "Darwin" ]; then
  PM="brew"
else
  PM="unknown"
fi

install_package() {
  if ! command -v $1 &>/dev/null; then
    echo "Installing $1..."
    if [ "$PM" == "apt-get" ]; then
      sudo apt-get update && sudo apt-get install -y "$1"
    elif [ "$PM" == "yum" ]; then
      sudo yum install -y "$1"
    elif [ "$PM" == "brew" ]; then
      brew install "$1"
    else
      echo "Unsupported OS: please install $1 manually."
      exit 1
    fi
  fi
}

install_package curl
install_package ssh-keygen
install_package git

echo "--------------------------------------------"
echo "🚀 Git SSH Multi-Account Setup Utility"
echo "--------------------------------------------"

declare -A PLATFORMS
PLATFORMS=(
  ["github.com"]="id_ed25519_github"
  ["gitlab.com"]="id_ed25519_gitlab"
  ["bitbucket.org"]="id_ed25519_bitbucket"
)

echo "🔍 Checking existing SSH keys:"
for HOST in "${!PLATFORMS[@]}"; do
  KEY_NAME="${PLATFORMS[$HOST]}"
  KEY_PATH="$HOME/.ssh/$KEY_NAME"
  if [ -f "$KEY_PATH" ]; then
    echo "✅ $HOST key found: $KEY_PATH"
  else
    echo "❌ $HOST key NOT found."
  fi
done

echo ""
echo "Which platforms do you want to setup?"
for HOST in "${!PLATFORMS[@]}"; do
  read -p "Setup SSH for $HOST? (y/n): " RESP
  if [[ "$RESP" =~ ^[Yy]$ ]]; then
    KEY_NAME="${PLATFORMS[$HOST]}"
    KEY_PATH="$HOME/.ssh/$KEY_NAME"
    if [ -f "$KEY_PATH" ]; then
      echo "🔑 Key already exists for $HOST: $KEY_PATH"
    else
      echo "Generating SSH key for $HOST..."
      ssh-keygen -t ed25519 -C "$HOST" -f "$KEY_PATH" -N ""
    fi
  fi
done

echo ""
echo "⚙️ Updating ~/.ssh/config file"
SSH_CONFIG="$HOME/.ssh/config"

for HOST in "${!PLATFORMS[@]}"; do
  KEY_NAME="${PLATFORMS[$HOST]}"
  KEY_PATH="$HOME/.ssh/$KEY_NAME"

  if [ -f "$KEY_PATH" ]; then
    sed -i "/Host $HOST/,+3d" $SSH_CONFIG 2>/dev/null || true

    {
      echo "Host $HOST"
      echo "  HostName $HOST"
      echo "  User git"
      echo "  IdentityFile $KEY_PATH"
      echo "  IdentitiesOnly yes"
      echo ""
    } >> $SSH_CONFIG
  fi
done

chmod 600 $SSH_CONFIG

echo ""
echo "✅ SSH config updated."

for HOST in "${!PLATFORMS[@]}"; do
  KEY_NAME="${PLATFORMS[$HOST]}"
  KEY_PATH="$HOME/.ssh/$KEY_NAME"
  if [ -f "$KEY_PATH" ]; then
    PUB_KEY=$(cat "$KEY_PATH.pub")
    echo ""
    echo "🔑 Public key for $HOST:"
    echo "========== COPY BELOW =========="
    echo "$PUB_KEY"
    echo "================================="
    echo "👉 Paste this key into $HOST SSH keys settings."
  fi
done

read -p "Do you want to configure Git user.name and user.email globally? (y/n): " CONFIG_GIT
if [[ "$CONFIG_GIT" =~ ^[Yy]$ ]]; then
  read -p "Enter your full name for Git commits: " GIT_NAME
  read -p "Enter your email for Git commits: " GIT_EMAIL
  git config --global user.name "$GIT_NAME"
  git config --global user.email "$GIT_EMAIL"
  echo "✅ Git user.name and user.email configured globally."
fi

echo ""
echo "🚀 All done. You are fully configured!"
