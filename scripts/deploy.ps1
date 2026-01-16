# ===============================
# SonicWall NSv 270 Deployment Script
# Deploys from GitHub-hosted Bicep templates
# ===============================

$ErrorActionPreference = "Stop"

# ===============================
# Configuration
# ===============================
$githubUser = "YOUR-GITHUB-USERNAME"
$githubRepo = "YOUR-REPO-NAME"
$githubBranch = "main"
$templateBase = "https://raw.githubusercontent.com/$githubUser/$githubRepo/$githubBranch/templates"
$mainTemplate = "$templateBase/main.bicep"

Write-Host "`n=== SonicWall NSv 270 Azure Deployment ===" -ForegroundColor Cyan
Write-Host "Using templates from: $templateBase" -ForegroundColor Yellow

# ===============================
# Verify GitHub Template Access
# ===============================
Write-Host "`nVerifying GitHub template access..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri $mainTemplate -Method Head -UseBasicParsing -ErrorAction Stop
    Write-Host "✓ GitHub templates accessible" -ForegroundColor Green
}
catch {
    Write-Host "✗ Cannot access template at: $mainTemplate" -ForegroundColor Red
    Write-Host "Please verify:" -ForegroundColor Yellow
    Write-Host "  1. Repository exists and is public" -ForegroundColor Yellow
    Write-Host "  2. File path is correct" -ForegroundColor Yellow
    Write-Host "  3. Branch name is correct" -ForegroundColor Yellow
    exit 1
}

# ===============================
# Collect Parameters
# ===============================
$clientId = Read-Host "`nEnter Client ID (ALL CAPS)"
$tenantDomain = Read-Host "Enter tenant email domain"

Write-Host "`nSelect Azure Region:" -ForegroundColor Yellow
Write-Host "  1. WestUS2" -ForegroundColor Cyan
Write-Host "  2. WestUS3" -ForegroundColor Cyan
$regionChoice = Read-Host "Enter selection (1 or 2)"

switch ($regionChoice) {
    "1" { $location = "westus2" }
    "2" { $location = "westus3" }
    default {
        Write-Host "Invalid selection" -ForegroundColor Red
        exit 1
    }
}

$adminPassword = Read-Host -AsSecureString "Enter SonicWall management password"

# ===============================
# Resource Groups
# ===============================
$resourceGroup = "${clientId}-RG"
$fwResourceGroup = "${clientId}-FW-RG"

# ===============================
# Accept Marketplace Terms
# ===============================
Write-Host "`nAccepting Azure Marketplace terms..." -ForegroundColor Yellow
try {
    Set-AzMarketplaceTerms `
        -Publisher "sonicwall-inc" `
        -Product "sonicwall-nsz-azure" `
        -Name "snwl-nsv-scx" `
        -Accept `
        -ErrorAction SilentlyContinue | Out-Null
}
catch {
    Write-Warning "Terms already accepted or manual acceptance required"
}

# ===============================
# Create Resource Groups
# ===============================
Write-Host "`nCreating resource groups..." -ForegroundColor Yellow
New-AzResourceGroup -Name $resourceGroup -Location $location -Force | Out-Null
Write-Host "✓ Created: $resourceGroup" -ForegroundColor Green

New-AzResourceGroup -Name $fwResourceGroup -Location $location -Force | Out-Null
Write-Host "✓ Created: $fwResourceGroup" -ForegroundColor Green

# ===============================
# Deploy from GitHub
# ===============================
Write-Host "`nDeploying SonicWall from GitHub templates..." -ForegroundColor Yellow
Write-Host "Template URL: $mainTemplate" -ForegroundColor Cyan
Write-Host "This will take approximately 5-10 minutes...`n" -ForegroundColor Cyan

$deploymentName = "sonicwall-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

$deployment = New-AzResourceGroupDeployment `
    -Name $deploymentName `
    -ResourceGroupName $resourceGroup `
    -TemplateUri $mainTemplate `
    -clientId $clientId `
    -tenantDomain $tenantDomain `
    -location $location `
    -adminPassword $adminPassword `
    -githubRepoBase $templateBase `
    -Verbose

# ===============================
# Display Results
# ===============================
Write-Host "`n=== Deployment Complete ===" -ForegroundColor Cyan
Write-Host "`nSonicWall Details:" -ForegroundColor Yellow
Write-Host "  Public IP:      $($deployment.Outputs.publicIpAddress.Value)" -ForegroundColor White
Write-Host "  FQDN:           $($deployment.Outputs.fqdn.Value)" -ForegroundColor White
Write-Host "  Management URL: $($deployment.Outputs.managementUrl.Value)" -ForegroundColor Green

Write-Host "`n✓ Deployment successful!" -ForegroundColor Green