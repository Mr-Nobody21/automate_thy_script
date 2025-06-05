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

read -p "Enter your GitHub username: " GIT_USER

KEY_PATH="$HOME/.ssh/id_ed25519_github"
if [ ! -f "$KEY_PATH" ]; then
  ssh-keygen -t ed25519 -C "$GIT_USER@github" -f "$KEY_PATH" -N ""
else
  echo "SSH key already exists at $KEY_PATH"
fi

PUB_KEY=$(cat "$KEY_PATH.pub")

echo ""
echo "✅ SSH key generated!"
echo ""
echo "========== COPY BELOW =========="
echo "$PUB_KEY"
echo "================================="
echo ""
echo "👉 Now:"
echo "1️⃣ Login to GitHub → Settings → SSH and GPG keys → New SSH Key"
echo "2️⃣ Paste the key."
echo ""

# Ask to configure Git user.name and user.email
echo ""
read -p "Do you want to configure Git user.name and user.email now? (y/n): " CONFIG_GIT

if [[ "$CONFIG_GIT" =~ ^[Yy]$ ]]; then
  read -p "Enter your full name for Git commits: " GIT_NAME
  read -p "Enter your email for Git commits: " GIT_EMAIL
  git config --global user.name "$GIT_NAME"
  git config --global user.email "$GIT_EMAIL"
  echo "✅ Git user.name and user.email configured globally."
else
  echo "Skipping Git global config."
fi

# Test SSH
read -p "Test SSH connection now? (y/n): " TEST
if [[ "$TEST" =~ ^[Yy]$ ]]; then
  ssh -T git@github.com
fi
