# Windows Universal Git SSH Multi-Account Setup

if (!(Get-Command choco.exe -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey not found. Installing..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

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

$PLATFORMS = @{
    "github.com"   = "id_ed25519_github"
    "gitlab.com"   = "id_ed25519_gitlab"
    "bitbucket.org"= "id_ed25519_bitbucket"
}

Write-Host "--------------------------------------------"
Write-Host "🚀 Git SSH Multi-Account Setup Utility"
Write-Host "--------------------------------------------"

foreach ($host in $PLATFORMS.Keys) {
    $keyName = $PLATFORMS[$host]
    $keyPath = "$env:USERPROFILE\.ssh\$keyName"

    if (Test-Path $keyPath) {
        Write-Host "✅ $host key found: $keyPath"
    } else {
        Write-Host "❌ $host key NOT found."
    }
}

foreach ($host in $PLATFORMS.Keys) {
    $resp = Read-Host "Setup SSH for $host? (y/n)"
    $keyName = $PLATFORMS[$host]
    $keyPath = "$env:USERPROFILE\.ssh\$keyName"

    if ($resp -eq "y" -or $resp -eq "Y") {
        if (Test-Path $keyPath) {
            Write-Host "🔑 Key already exists for $host: $keyPath"
        } else {
            ssh-keygen -t ed25519 -C "$host" -f $keyPath -N ""
        }
    }
}

$configPath = "$env:USERPROFILE\.ssh\config"

foreach ($host in $PLATFORMS.Keys) {
    $keyName = $PLATFORMS[$host]
    $keyPath = "$env:USERPROFILE\.ssh\$keyName"

    if (Test-Path $keyPath) {
        (Get-Content $configPath | Select-String -NotMatch "Host $host") | Set-Content $configPath
        Add-Content $configPath "Host $host"
        Add-Content $configPath "  HostName $host"
        Add-Content $configPath "  User git"
        Add-Content $configPath "  IdentityFile $keyPath"
        Add-Content $configPath "  IdentitiesOnly yes"
        Add-Content $configPath ""
    }
}

foreach ($host in $PLATFORMS.Keys) {
    $keyName = $PLATFORMS[$host]
    $keyPath = "$env:USERPROFILE\.ssh\$keyName.pub"
    if (Test-Path $keyPath) {
        Write-Host ""
        Write-Host "🔑 Public key for $host:"
        Write-Host "========== COPY BELOW =========="
        Get-Content $keyPath
        Write-Host "================================="
        Write-Host "👉 Paste this key into $host SSH keys settings."
    }
}

$userChoice = Read-Host "Do you want to configure Git user.name and user.email? (y/n)"
if ($userChoice -eq "y" -or $userChoice -eq "Y") {
    $GIT_NAME = Read-Host "Enter your full name"
    $GIT_EMAIL = Read-Host "Enter your email"
    git config --global user.name "$GIT_NAME"
    git config --global user.email "$GIT_EMAIL"
}
