#!/bin/bash
# ===============================
# SonicWall NSv 270 Deployment Script
# Deploys from GitHub-hosted Bicep templates
# ===============================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ===============================
# Configuration
# ===============================
GITHUB_USER="YOUR-GITHUB-USERNAME"
GITHUB_REPO="YOUR-REPO-NAME"
GITHUB_BRANCH="main"
TEMPLATE_BASE="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}/templates"
MAIN_TEMPLATE="${TEMPLATE_BASE}/main.bicep"

echo -e "${CYAN}=== SonicWall NSv 270 Azure Deployment ===${NC}"
echo -e "${YELLOW}Using templates from: ${TEMPLATE_BASE}${NC}\n"

# ===============================
# Verify GitHub Template Accessibility
# ===============================
echo -e "${YELLOW}Verifying GitHub template access...${NC}"
if ! curl --output /dev/null --silent --head --fail "$MAIN_TEMPLATE"; then
    echo -e "${RED}✗ Cannot access template at: $MAIN_TEMPLATE${NC}"
    echo -e "${YELLOW}Please verify:${NC}"
    echo -e "  1. Repository exists and is public"
    echo -e "  2. File path is correct"
    echo -e "  3. Branch name is correct"
    exit 1
fi
echo -e "${GREEN}✓ GitHub templates accessible${NC}\n"

# ===============================
# Collect Parameters
# ===============================
read -p "Enter Client ID (ALL CAPS): " CLIENT_ID
read -p "Enter tenant email domain: " TENANT_DOMAIN

echo -e "\n${YELLOW}Select Azure Region:${NC}"
echo "  1. WestUS2"
echo "  2. WestUS3"
read -p "Enter selection (1 or 2): " REGION_CHOICE

case $REGION_CHOICE in
  1) LOCATION="westus2" ;;
  2) LOCATION="westus3" ;;
  *)
    echo -e "${RED}Invalid selection${NC}"
    exit 1
    ;;
esac

read -sp "Enter SonicWall management password: " ADMIN_PASSWORD
echo ""

if [ ${#ADMIN_PASSWORD} -lt 12 ]; then
    echo -e "${RED}Password must be at least 12 characters${NC}"
    exit 1
fi

# ===============================
# Resource Group Names
# ===============================
RESOURCE_GROUP="${CLIENT_ID}-RG"
FW_RESOURCE_GROUP="${CLIENT_ID}-FW-RG"

# ===============================
# Accept Marketplace Terms
# ===============================
echo -e "\n${YELLOW}Accepting Azure Marketplace terms...${NC}"
az vm image terms accept \
  --publisher sonicwall-inc \
  --offer sonicwall-nsz-azure \
  --plan snwl-nsv-scx \
  --output none 2>/dev/null || echo -e "${YELLOW}Terms already accepted${NC}"

# ===============================
# Create Resource Groups
# ===============================
echo -e "\n${YELLOW}Creating resource groups...${NC}"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
echo -e "${GREEN}✓ Created: $RESOURCE_GROUP${NC}"

az group create --name "$FW_RESOURCE_GROUP" --location "$LOCATION" --output none
echo -e "${GREEN}✓ Created: $FW_RESOURCE_GROUP${NC}"

# ===============================
# Deploy from GitHub
# ===============================
echo -e "\n${YELLOW}Deploying SonicWall from GitHub templates...${NC}"
echo -e "${CYAN}Template URL: $MAIN_TEMPLATE${NC}"
echo -e "${CYAN}This will take approximately 5-10 minutes...${NC}\n"

DEPLOYMENT_NAME="sonicwall-deployment-$(date +%Y%m%d-%H%M%S)"

az deployment group create \
  --name "$DEPLOYMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --template-uri "$MAIN_TEMPLATE" \
  --parameters \
    clientId="$CLIENT_ID" \
    tenantDomain="$TENANT_DOMAIN" \
    location="$LOCATION" \
    adminPassword="$ADMIN_PASSWORD" \
    githubRepoBase="$TEMPLATE_BASE" \
  --output table

# ===============================
# Get Outputs
# ===============================
echo -e "\n${YELLOW}Retrieving deployment information...${NC}"

PUBLIC_IP=$(az deployment group show \
  --name "$DEPLOYMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query 'properties.outputs.publicIpAddress.value' \
  --output tsv)

FQDN=$(az deployment group show \
  --name "$DEPLOYMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query 'properties.outputs.fqdn.value' \
  --output tsv)

# ===============================
# Final Output
# ===============================
echo -e "\n${CYAN}=== Deployment Complete ===${NC}\n"
echo -e "${YELLOW}SonicWall Details:${NC}"
echo -e "  Public IP:      $PUBLIC_IP"
echo -e "  FQDN:           $FQDN"
echo -e "  Management URL: ${GREEN}https://$PUBLIC_IP${NC}"
echo -e "\n${GREEN}✓ Deployment successful!${NC}\n"