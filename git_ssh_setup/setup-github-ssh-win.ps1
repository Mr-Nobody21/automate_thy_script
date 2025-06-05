# Windows GitHub SSH Setup

# Install Chocolatey if missing
if (!(Get-Command choco.exe -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey not found. Installing..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

# Dependency Install Function
function Install-PackageIfMissing($name, $chocoName) {
    if (!(Get-Command $name -ErrorAction SilentlyContinue)) {
        Write-Host "$name not found. Installing..."
        choco install $chocoName -y
    } else {
        Write-Host "$name found."
    }
}

Install-PackageIfMissing "ssh-keygen" "openssh"
Install-PackageIfMissing "curl" "curl"
Install-PackageIfMissing "git" "git"

# Get GitHub username
$GIT_USER = Read-Host "Enter your GitHub username"

# Generate SSH key
$KEY_PATH = "$env:USERPROFILE\.ssh\id_ed25519_github"
if (!(Test-Path $KEY_PATH)) {
    ssh-keygen -t ed25519 -C "$GIT_USER@github" -f $KEY_PATH -N ""
} else {
    Write-Host "SSH key already exists at $KEY_PATH"
}

# Display public key
$PUB_KEY = Get-Content "$KEY_PATH.pub"
Write-Host ""
Write-Host "✅ SSH key generated!"
Write-Host ""
Write-Host "========== COPY BELOW =========="
Write-Host $PUB_KEY
Write-Host "================================="
Write-Host ""
Write-Host "👉 Now:"
Write-Host "1️⃣ Login to GitHub → Settings → SSH and GPG keys → New SSH Key"
Write-Host "2️⃣ Paste the key."
Write-Host ""

# Ask Git user config
$userChoice = Read-Host "Do you want to configure Git user.name and user.email now? (y/n)"
if ($userChoice -eq "y" -or $userChoice -eq "Y") {
    $GIT_NAME = Read-Host "Enter your full name for Git commits"
    $GIT_EMAIL = Read-Host "Enter your email for Git commits"
    git config --global user.name "$GIT_NAME"
    git config --global user.email "$GIT_EMAIL"
    Write-Host "✅ Git user.name and user.email configured globally."
} else {
    Write-Host "Skipping Git global config."
}

# Test SSH
$test = Read-Host "Test SSH connection now? (y/n)"
if ($test -eq "y" -or $test -eq "Y") {
    ssh -T git@github.com
}
