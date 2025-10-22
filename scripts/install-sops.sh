#!/bin/bash
# Quick installer for SOPS and age

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Installing age and SOPS...${NC}\n"

# Install age
if ! command -v age >/dev/null 2>&1; then
    echo "Installing age..."
    cd /tmp
    rm -f age-v1.1.1-linux-amd64.tar.gz* age-v1.1.1-linux-amd64.tar.gz
    wget -q https://github.com/FiloSottile/age/releases/download/v1.1.1/age-v1.1.1-linux-amd64.tar.gz
    tar xf age-v1.1.1-linux-amd64.tar.gz
    sudo mv age/age age/age-keygen /usr/local/bin/
    rm -rf age age-v1.1.1-linux-amd64.tar.gz*
    echo -e "${GREEN}✓ age installed${NC}"
else
    echo -e "${GREEN}✓ age already installed${NC}"
fi

# Install SOPS
if ! command -v sops >/dev/null 2>&1; then
    echo "Installing SOPS..."
    cd /tmp

    # Clean up any existing files first
    rm -f sops-v3.8.1.linux.amd64*

    # Download SOPS
    if ! wget -q https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64; then
        echo -e "${RED}✗ Failed to download SOPS${NC}"
        exit 1
    fi

    # Verify file exists
    if [ ! -f sops-v3.8.1.linux.amd64 ]; then
        echo -e "${RED}✗ SOPS download failed${NC}"
        exit 1
    fi

    chmod +x sops-v3.8.1.linux.amd64
    sudo mv sops-v3.8.1.linux.amd64 /usr/local/bin/sops
    echo -e "${GREEN}✓ SOPS installed${NC}"
else
    echo -e "${GREEN}✓ SOPS already installed${NC}"
fi

echo ""
echo -e "${GREEN}✅ Installation complete!${NC}"
echo ""
echo "Verify installation:"
echo "  age --version"
echo "  sops --version"
echo ""
echo "Run demo:"
echo "  make sops-demo"
