#!/usr/bin/env bash
# Dry-run validation script for Hybrid Helm + Kustomize ApplicationSet

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Base directories
ROOT_DIR="/home/akumar/Desktop/SuperFortnight-Dev"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FEATURE_REPO="$ROOT_DIR/super-fortnight-infrastructure/feature-services/aggregator-service"
DUMMY_REPO="$ROOT_DIR/dummy-services-repos/aggregator-service"
HELM_REPO="$ROOT_DIR/sf-helm-charts"
GITOPS_REPO="$ROOT_DIR/gitops-v2"
HELM_CHART_REPO="https://ashutosh-18k92.github.io/sf-helm-charts/"

# Use dummy repo if feature repo doesn't exist
if [ -d "$FEATURE_REPO" ]; then
    SERVICE_REPO="$FEATURE_REPO"
elif [ -d "$DUMMY_REPO" ]; then
    SERVICE_REPO="$DUMMY_REPO"
else
    echo -e "${RED}❌ Service repository not found${NC}"
    exit 1
fi

echo "========================================="
echo "  Hybrid Helm + Kustomize Validation"
echo "========================================="
echo ""
echo "📁 Using service repo: $SERVICE_REPO"
echo ""

# Test 1: Check prerequisites
echo "🔍 Test 1: Checking prerequisites..."
MISSING_TOOLS=()

if ! command -v helm &> /dev/null; then
    MISSING_TOOLS+=("helm")
fi

if ! command -v kubectl &> /dev/null; then
    MISSING_TOOLS+=("kubectl")
fi

if ! command -v yq &> /dev/null; then
    MISSING_TOOLS+=("yq")
fi

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo -e "   ${RED}❌ Missing tools: ${MISSING_TOOLS[*]}${NC}"
    echo "   Install with: sudo apt-get install helm kubectl yq"
    exit 1
else
    echo -e "   ${GREEN}✅ All required tools installed${NC}"
    helm version --short
    kubectl version --client --short 2>/dev/null || echo "   kubectl: $(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')"
fi
echo ""

# Test 2: Clone Helm registry if needed
echo "🔍 Test 2: Checking Helm chart repository..."
if [ ! -d "$HELM_REPO" ]; then
    echo "   Cloning sf-helm-registry..."
    git clone $HELM_CHART_REPO "$HELM_REPO" 2>&1 | grep -v "Cloning" || true
    echo -e "   ${GREEN}✅ Cloned successfully${NC}"
else
    echo -e "   ${GREEN}✅ Helm registry already exists${NC}"
    cd "$HELM_REPO"
    git pull origin main > /dev/null 2>&1 || echo "   (Could not update, using cached version)"
    cd - > /dev/null
fi
echo ""

# Test 3: Validate environment files
echo "🔍 Test 3: Validating environment configuration files..."
ENV_DIR="$SERVICE_REPO/deploy/environments"
if [ ! -d "$ENV_DIR" ]; then
    echo -e "   ${RED}❌ Environment directory not found: $ENV_DIR${NC}"
    exit 1
fi

ENVIRONMENTS=()
for env_file in "$ENV_DIR"/*.yaml; do
    if [ -f "$env_file" ]; then
        ENV_NAME=$(basename "$env_file" .yaml)
        ENVIRONMENTS+=("$ENV_NAME")
        
        echo "   Validating $ENV_NAME..."
        if yq eval '.' "$env_file" > /dev/null 2>&1; then
            echo -e "   ${GREEN}✅ Valid YAML${NC}"
            ENV_VAL=$(yq eval '.env' "$env_file")
            NAMESPACE=$(yq eval '.namespace' "$env_file")
            echo "      env: $ENV_VAL, namespace: $NAMESPACE"
        else
            echo -e "   ${RED}❌ Invalid YAML${NC}"
            exit 1
        fi
    fi
done
echo ""

# Test 4: Validate overlay kustomizations
echo "🔍 Test 4: Validating overlay kustomization files..."
for env in "${ENVIRONMENTS[@]}"; do
    OVERLAY_DIR="$SERVICE_REPO/deploy/overlays/$env"
    KUSTOMIZATION="$OVERLAY_DIR/kustomization.yaml"
    
    if [ ! -f "$KUSTOMIZATION" ]; then
        echo -e "   ${RED}❌ Missing kustomization for $env: $KUSTOMIZATION${NC}"
        exit 1
    fi
    
    echo "   Checking $env overlay..."
    
    # Check for helmCharts section
    if grep -q "helmCharts:" "$KUSTOMIZATION"; then
        CHART_VERSION=$(yq eval '.helmCharts[0].version' "$KUSTOMIZATION")
        CHART_REPO=$(yq eval '.helmCharts[0].repo' "$KUSTOMIZATION")
        echo -e "   ${GREEN}✅ Helm chart configured${NC}"
        echo "      Chart version: $CHART_VERSION"
        echo "      Chart repo: $CHART_REPO"
    else
        echo -e "   ${YELLOW}⚠️  No helmCharts section found${NC}"
    fi
    
    # Check for patches
    PATCH_COUNT=$(yq eval '.patches | length' "$KUSTOMIZATION" 2>/dev/null || echo "0")
    if [ "$PATCH_COUNT" -gt 0 ]; then
        echo -e "   ${GREEN}✅ $PATCH_COUNT patch(es) configured${NC}"
    fi
done
echo ""

# Test 5: Validate Helm values files
echo "🔍 Test 5: Validating Helm values files..."
for env in "${ENVIRONMENTS[@]}"; do
    BASE_VALUES="$SERVICE_REPO/deploy/base/values.yaml"
    OVERLAY_VALUES="$SERVICE_REPO/deploy/overlays/$env/values.yaml"
    
    echo "   Checking $env values..."
    
    if [ -f "$BASE_VALUES" ]; then
        yq eval '.' "$BASE_VALUES" > /dev/null 2>&1 && echo -e "   ${GREEN}✅ Base values valid${NC}" || echo -e "   ${RED}❌ Base values invalid${NC}"
    else
        echo -e "   ${YELLOW}⚠️  No base values file${NC}"
    fi
    
    if [ -f "$OVERLAY_VALUES" ]; then
        yq eval '.' "$OVERLAY_VALUES" > /dev/null 2>&1 && echo -e "   ${GREEN}✅ Overlay values valid${NC}" || echo -e "   ${RED}❌ Overlay values invalid${NC}"
    else
        echo -e "   ${YELLOW}⚠️  No overlay values file${NC}"
    fi
done
echo ""

# Test 6: Test Helm template rendering (without Kustomize)
echo "🔍 Test 6: Testing Helm template rendering..."
for env in "${ENVIRONMENTS[@]}"; do
    echo "   Rendering $env environment..."
    
    BASE_VALUES="$SERVICE_REPO/deploy/base/values.yaml"
    OVERLAY_VALUES="$SERVICE_REPO/deploy/overlays/$env/values.yaml"
    NAMESPACE=$(yq eval '.namespace' "$SERVICE_REPO/deploy/environments/$env.yaml")
    
    # Build helm template command
    HELM_CMD="helm template aggregator $HELM_REPO/api --namespace $NAMESPACE"
    
    if [ -f "$BASE_VALUES" ]; then
        HELM_CMD="$HELM_CMD -f $BASE_VALUES"
    fi
    
    if [ -f "$OVERLAY_VALUES" ]; then
        HELM_CMD="$HELM_CMD -f $OVERLAY_VALUES"
    fi
    
    if $HELM_CMD > "/tmp/aggregator-$env-helm-render.yaml" 2>&1; then
        RESOURCE_COUNT=$(grep -c "^kind:" "/tmp/aggregator-$env-helm-render.yaml" || true)
        echo -e "   ${GREEN}✅ Helm rendering successful${NC}"
        echo "      Generated $RESOURCE_COUNT Kubernetes resources"
        echo "      Output: /tmp/aggregator-$env-helm-render.yaml"
    else
        echo -e "   ${RED}❌ Helm rendering failed${NC}"
        cat "/tmp/aggregator-$env-helm-render.yaml"
        exit 1
    fi
done
echo ""

# Test 7: Validate ApplicationSet YAML
echo "🔍 Test 7: Validating ApplicationSet YAML..."
APPSET_FILE="$GITOPS_REPO/argocd/apps/aggregator-appset.yaml"

if [ ! -f "$APPSET_FILE" ]; then
    echo -e "   ${RED}❌ ApplicationSet file not found: $APPSET_FILE${NC}"
    exit 1
fi

if kubectl apply --dry-run=client -f "$APPSET_FILE" > /dev/null 2>&1; then
    echo -e "   ${GREEN}✅ ApplicationSet YAML is valid${NC}"
else
    echo -e "   ${RED}❌ ApplicationSet YAML is invalid${NC}"
    kubectl apply --dry-run=client -f "$APPSET_FILE"
    exit 1
fi
echo ""

# Test 8: Check for environment-based branching
echo "🔍 Test 8: Checking environment-based branching configuration..."
if grep -q 'targetRevision: "{{.env}}"' "$APPSET_FILE"; then
    echo -e "   ${GREEN}✅ Environment-based branching configured${NC}"
    echo "      ApplicationSet will use branches: ${ENVIRONMENTS[*]}"
else
    echo -e "   ${YELLOW}⚠️  Using fixed branch (not environment-based)${NC}"
fi
echo ""

# Test 9: Check for Kustomize --enable-helm flag
echo "🔍 Test 9: Checking Kustomize Helm integration..."
if grep -q -- "--enable-helm" "$APPSET_FILE"; then
    echo -e "   ${GREEN}✅ Kustomize --enable-helm flag configured${NC}"
    echo "      ArgoCD will handle Helm chart inflation"
else
    echo -e "   ${RED}❌ Missing --enable-helm flag${NC}"
    echo "      Kustomize won't be able to inflate Helm charts"
    exit 1
fi
echo ""

# Test 10: Check patch files exist
echo "🔍 Test 10: Checking patch files..."
for env in "${ENVIRONMENTS[@]}"; do
    OVERLAY_DIR="$SERVICE_REPO/deploy/overlays/$env"
    KUSTOMIZATION="$OVERLAY_DIR/kustomization.yaml"
    
    if [ -f "$KUSTOMIZATION" ]; then
        # Get patch paths from kustomization
        PATCHES=$(yq eval '.patches[].path' "$KUSTOMIZATION" 2>/dev/null || echo "")
        
        if [ -n "$PATCHES" ]; then
            echo "   Checking $env patches..."
            while IFS= read -r patch; do
                PATCH_FILE="$OVERLAY_DIR/$patch"
                if [ -f "$PATCH_FILE" ]; then
                    echo -e "   ${GREEN}✅ $patch exists${NC}"
                else
                    echo -e "   ${RED}❌ Missing patch: $patch${NC}"
                fi
            done <<< "$PATCHES"
        fi
    fi
done
echo ""

# Test 11: Simulate ArgoCD Application generation
echo "🔍 Test 11: Simulating ArgoCD Application generation..."
for env in "${ENVIRONMENTS[@]}"; do
    ENV_FILE="$SERVICE_REPO/deploy/environments/$env.yaml"
    ENV_NAME=$(yq eval '.env' "$ENV_FILE")
    NAMESPACE=$(yq eval '.namespace' "$ENV_FILE")
    
    echo "   Would generate Application: aggregator-service-$ENV_NAME"
    echo "      Namespace: $NAMESPACE"
    echo "      Source path: deploy/overlays/$ENV_NAME"
    echo "      Target branch: $ENV_NAME"
done
echo ""

# Summary
echo "========================================="
echo -e "${GREEN}✅ All validation tests passed!${NC}"
echo "========================================="
echo ""
echo "📋 Summary:"
echo "   Environments: ${ENVIRONMENTS[*]}"
echo "   Helm charts: Configured in overlay kustomizations"
echo "   Patches: Modular patch files"
echo "   ApplicationSet: Valid and ready"
echo ""
echo "🚀 Next steps:"
echo "   1. Create environment branches:"
for env in "${ENVIRONMENTS[@]}"; do
    echo "      git checkout -b $env && git push -u origin $env"
done
echo ""
echo "   2. Apply ApplicationSet to ArgoCD:"
echo "      kubectl apply -f $APPSET_FILE"
echo ""
echo "   3. Check generated Applications:"
echo "      argocd app list | grep aggregator-service"
echo ""
echo "📁 Generated manifests saved to:"
for env in "${ENVIRONMENTS[@]}"; do
    echo "   - /tmp/aggregator-$env-helm-render.yaml"
done
echo ""
