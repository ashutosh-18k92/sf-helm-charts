#!/usr/bin/env bash
# Test script for Git Files Generator ApplicationSet

set -euo pipefail

echo "=== Testing Git Files Generator ApplicationSet ==="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Base directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FEATURE_REPO="$SCRIPT_DIR/super-fortnight-infrastructure/feature-services/aggregator-service"
HELM_REPO="$SCRIPT_DIR/sf-helm-registry"
GITOPS_REPO="$SCRIPT_DIR/gitops-v2"

echo "📁 Directories:"
echo "   Feature Repo: $FEATURE_REPO"
echo "   Helm Repo: $HELM_REPO"
echo "   GitOps Repo: $GITOPS_REPO"
echo ""

# Test 1: Check Helm version
echo "🔍 Test 1: Checking Helm version..."
HELM_VERSION=$(helm version --short)
echo "   Helm version: $HELM_VERSION"
if [[ "$HELM_VERSION" == *"v4."* ]]; then
    echo -e "   ${GREEN}✅ Helm 4.x detected${NC}"
else
    echo -e "   ${YELLOW}⚠️  Not Helm 4.x, but continuing...${NC}"
fi
echo ""

# Test 2: Clone Helm registry if needed
echo "🔍 Test 2: Checking Helm chart repository..."
if [ ! -d "$HELM_REPO" ]; then
    echo "   Cloning sf-helm-registry..."
    git clone https://github.com/ashutosh-18k92/sf-helm-registry.git "$HELM_REPO"
    echo -e "   ${GREEN}✅ Cloned successfully${NC}"
else
    echo -e "   ${GREEN}✅ Helm registry already exists${NC}"
fi
echo ""

# Test 3: Validate environment files
echo "🔍 Test 3: Validating environment configuration files..."
ENV_DIR="$FEATURE_REPO/deploy/environments"
if [ -d "$ENV_DIR" ]; then
    for env_file in "$ENV_DIR"/*.yaml; do
        if [ -f "$env_file" ]; then
            echo "   Checking $(basename $env_file)..."
            if yq eval '.' "$env_file" > /dev/null 2>&1; then
                echo -e "   ${GREEN}✅ Valid YAML${NC}"
                # Show key fields
                ENV_NAME=$(yq eval '.env' "$env_file")
                CHART_VERSION=$(yq eval '.chartVersion' "$env_file")
                echo "      env: $ENV_NAME, chartVersion: $CHART_VERSION"
            else
                echo -e "   ${RED}❌ Invalid YAML${NC}"
                exit 1
            fi
        fi
    done
else
    echo -e "   ${RED}❌ Environment directory not found: $ENV_DIR${NC}"
    exit 1
fi
echo ""

# Test 4: Test Helm template rendering for dev
echo "🔍 Test 4: Testing Helm template rendering (dev)..."
if helm template aggregator "$HELM_REPO/api" \
    -f "$FEATURE_REPO/deploy/base/values.yaml" \
    -f "$FEATURE_REPO/deploy/overlays/dev/values.yaml" \
    --namespace super-fortnight-dev \
    > /tmp/aggregator-dev-render.yaml 2>&1; then
    echo -e "   ${GREEN}✅ Dev environment renders successfully${NC}"
    RESOURCE_COUNT=$(grep -c "^kind:" /tmp/aggregator-dev-render.yaml || true)
    echo "      Generated $RESOURCE_COUNT Kubernetes resources"
else
    echo -e "   ${RED}❌ Dev environment rendering failed${NC}"
    cat /tmp/aggregator-dev-render.yaml
    exit 1
fi
echo ""

# Test 5: Test Helm template rendering for production
echo "🔍 Test 5: Testing Helm template rendering (production)..."
if helm template aggregator "$HELM_REPO/api" \
    -f "$FEATURE_REPO/deploy/base/values.yaml" \
    -f "$FEATURE_REPO/deploy/overlays/production/values.yaml" \
    --namespace super-fortnight \
    > /tmp/aggregator-prod-render.yaml 2>&1; then
    echo -e "   ${GREEN}✅ Production environment renders successfully${NC}"
    RESOURCE_COUNT=$(grep -c "^kind:" /tmp/aggregator-prod-render.yaml || true)
    echo "      Generated $RESOURCE_COUNT Kubernetes resources"
else
    echo -e "   ${RED}❌ Production environment rendering failed${NC}"
    cat /tmp/aggregator-prod-render.yaml
    exit 1
fi
echo ""

# Test 6: Validate ApplicationSet YAML
echo "🔍 Test 6: Validating ApplicationSet YAML..."
APPSET_FILE="$GITOPS_REPO/argocd/apps/aggregator-appset.yaml"
if [ -f "$APPSET_FILE" ]; then
    if kubectl apply --dry-run=client -f "$APPSET_FILE" > /dev/null 2>&1; then
        echo -e "   ${GREEN}✅ ApplicationSet YAML is valid${NC}"
    else
        echo -e "   ${RED}❌ ApplicationSet YAML is invalid${NC}"
        kubectl apply --dry-run=client -f "$APPSET_FILE"
        exit 1
    fi
else
    echo -e "   ${RED}❌ ApplicationSet file not found: $APPSET_FILE${NC}"
    exit 1
fi
echo ""

# Test 7: Check for Git Files Generator
echo "🔍 Test 7: Checking Git Files Generator configuration..."
if grep -q "git:" "$APPSET_FILE" && grep -q "files:" "$APPSET_FILE"; then
    echo -e "   ${GREEN}✅ Git Files Generator configured${NC}"
    GENERATOR_PATH=$(yq eval '.spec.generators[0].git.files[0].path' "$APPSET_FILE")
    echo "      Generator path: $GENERATOR_PATH"
else
    echo -e "   ${YELLOW}⚠️  Git Files Generator not found (might be using List Generator)${NC}"
fi
echo ""

# Test 8: Check for multi-source configuration
echo "🔍 Test 8: Checking multi-source configuration..."
if grep -q "sources:" "$APPSET_FILE"; then
    echo -e "   ${GREEN}✅ Multi-source configuration detected${NC}"
    SOURCE_COUNT=$(yq eval '.spec.template.spec.sources | length' "$APPSET_FILE")
    echo "      Number of sources: $SOURCE_COUNT"
    if [ "$SOURCE_COUNT" -eq 2 ]; then
        echo -e "   ${GREEN}✅ Correct number of sources (2)${NC}"
    else
        echo -e "   ${YELLOW}⚠️  Expected 2 sources, found $SOURCE_COUNT${NC}"
    fi
else
    echo -e "   ${RED}❌ Multi-source configuration not found${NC}"
    exit 1
fi
echo ""

# Summary
echo "========================================="
echo -e "${GREEN}✅ All tests passed!${NC}"
echo "========================================="
echo ""
echo "📋 Generated manifests saved to:"
echo "   - /tmp/aggregator-dev-render.yaml"
echo "   - /tmp/aggregator-prod-render.yaml"
echo ""
echo "🚀 Next steps:"
echo "   1. Review the generated manifests"
echo "   2. Apply ApplicationSet to ArgoCD:"
echo "      kubectl apply -f $APPSET_FILE"
echo "   3. Check generated Applications:"
echo "      argocd app list | grep aggregator-service"
echo ""
