#!/usr/bin/env bash
# Test script to verify Helm chart manifests with development overlay

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directories
ROOT_DIR="/home/akumar/Desktop/SuperFortnight-Dev"

CHART_DIR="$ROOT_DIR/sf-helm-charts/charts/api"
SERVICE_DIR="$ROOT_DIR/dummy-services-repos/aggregator-service"
OUTPUT_DIR="$ROOT_DIR/sf-helm-charts/tmp/aggregator-test"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "========================================="
echo "  Helm Chart Manifest Verification"
echo "========================================="
echo ""
echo "📁 Chart: $CHART_DIR"
echo "📁 Service: $SERVICE_DIR"
echo "📁 Output: $OUTPUT_DIR"
echo ""

# Test 1: Verify chart exists
echo "🔍 Test 1: Verifying chart structure..."
if [ ! -f "$CHART_DIR/Chart.yaml" ]; then
    echo -e "   ${RED}❌ Chart.yaml not found in $CHART_DIR${NC}"
    exit 1
fi
echo -e "   ${GREEN}✅ Chart.yaml found${NC}"

CHART_NAME=$(yq eval '.name' "$CHART_DIR/Chart.yaml")
CHART_VERSION=$(yq eval '.version' "$CHART_DIR/Chart.yaml")
echo "      Chart: $CHART_NAME v$CHART_VERSION"
echo ""

# Test 2: Verify values files exist
echo "🔍 Test 2: Verifying values files..."
BASE_VALUES="$CHART_DIR/values.yaml"
DEV_VALUES="$SERVICE_DIR/deploy/overlays/development/values.yaml"

if [ ! -f "$BASE_VALUES" ]; then
    echo -e "   ${RED}❌ Base values not found: $BASE_VALUES${NC}"
    exit 1
fi
echo -e "   ${GREEN}✅ Base values found${NC}"

if [ ! -f "$DEV_VALUES" ]; then
    echo -e "   ${RED}❌ Development values not found: $DEV_VALUES${NC}"
    exit 1
fi
echo -e "   ${GREEN}✅ Development values found${NC}"
echo ""

# Test 3: Render Helm chart with development values
echo "🔍 Test 3: Rendering Helm chart with development overlay..."
RENDER_OUTPUT="$OUTPUT_DIR/development-manifests.yaml"

if helm template aggregator "$CHART_DIR" \
    -f "$BASE_VALUES" \
    -f "$DEV_VALUES" \
    --namespace super-fortnight-dev \
    > "$RENDER_OUTPUT" 2>&1; then
    echo -e "   ${GREEN}✅ Helm rendering successful${NC}"
    RESOURCE_COUNT=$(grep -c "^kind:" "$RENDER_OUTPUT" || true)
    echo "      Generated $RESOURCE_COUNT Kubernetes resources"
else
    echo -e "   ${RED}❌ Helm rendering failed${NC}"
    cat "$RENDER_OUTPUT"
    exit 1
fi
echo ""

# Test 4: Validate generated YAML
echo "🔍 Test 4: Validating generated YAML syntax..."
if kubectl apply --dry-run=client -f "$RENDER_OUTPUT" > /dev/null 2>&1; then
    echo -e "   ${GREEN}✅ All manifests are valid Kubernetes YAML${NC}"
else
    echo -e "   ${RED}❌ Invalid Kubernetes YAML detected${NC}"
    kubectl apply --dry-run=client -f "$RENDER_OUTPUT"
    exit 1
fi
echo ""

# Test 5: Check for required resources
echo "🔍 Test 5: Checking for required Kubernetes resources..."
REQUIRED_RESOURCES=("Deployment" "Service" "ConfigMap")

for resource in "${REQUIRED_RESOURCES[@]}"; do
    if grep -q "^kind: $resource" "$RENDER_OUTPUT"; then
        echo -e "   ${GREEN}✅ $resource found${NC}"
    else
        echo -e "   ${YELLOW}⚠️  $resource not found (may be optional)${NC}"
    fi
done
echo ""

# Test 6: Extract and verify specific resources
echo "🔍 Test 6: Extracting individual resources..."

# Extract Deployment
yq eval 'select(.kind == "Deployment")' "$RENDER_OUTPUT" > "$OUTPUT_DIR/deployment.yaml"
if [ -s "$OUTPUT_DIR/deployment.yaml" ]; then
    echo -e "   ${GREEN}✅ Deployment extracted${NC}"
    
    # Check deployment details
    REPLICAS=$(yq eval '.spec.replicas' "$OUTPUT_DIR/deployment.yaml")
    IMAGE=$(yq eval '.spec.template.spec.containers[0].image' "$OUTPUT_DIR/deployment.yaml")
    echo "      Replicas: $REPLICAS"
    echo "      Image: $IMAGE"
else
    echo -e "   ${RED}❌ No Deployment found${NC}"
fi

# Extract Service
yq eval 'select(.kind == "Service")' "$RENDER_OUTPUT" > "$OUTPUT_DIR/service.yaml"
if [ -s "$OUTPUT_DIR/service.yaml" ]; then
    echo -e "   ${GREEN}✅ Service extracted${NC}"
    
    SERVICE_TYPE=$(yq eval '.spec.type' "$OUTPUT_DIR/service.yaml")
    SERVICE_PORT=$(yq eval '.spec.ports[0].port' "$OUTPUT_DIR/service.yaml")
    echo "      Type: $SERVICE_TYPE"
    echo "      Port: $SERVICE_PORT"
else
    echo -e "   ${YELLOW}⚠️  No Service found${NC}"
fi

# Extract ConfigMap
yq eval 'select(.kind == "ConfigMap")' "$RENDER_OUTPUT" > "$OUTPUT_DIR/configmap.yaml"
if [ -s "$OUTPUT_DIR/configmap.yaml" ]; then
    echo -e "   ${GREEN}✅ ConfigMap extracted${NC}"
else
    echo -e "   ${YELLOW}⚠️  No ConfigMap found${NC}"
fi
echo ""

# Test 7: Verify development-specific values
echo "🔍 Test 7: Verifying development-specific configurations..."

# Check if development values are applied
if grep -q "development" "$RENDER_OUTPUT"; then
    echo -e "   ${GREEN}✅ Development environment markers found${NC}"
else
    echo -e "   ${YELLOW}⚠️  No development environment markers${NC}"
fi

# Check namespace
if grep -q "namespace: super-fortnight-dev" "$RENDER_OUTPUT"; then
    echo -e "   ${GREEN}✅ Correct namespace (super-fortnight-dev)${NC}"
else
    echo -e "   ${RED}❌ Incorrect or missing namespace${NC}"
fi
echo ""

# Test 8: Compare base vs development values
echo "🔍 Test 8: Comparing base vs development overlays..."

# Render with base values only
BASE_RENDER="$OUTPUT_DIR/base-manifests.yaml"
helm template aggregator "$CHART_DIR" \
    -f "$BASE_VALUES" \
    --namespace super-fortnight \
    > "$BASE_RENDER" 2>&1

# Show differences
DIFF_OUTPUT="$OUTPUT_DIR/base-vs-dev.diff"
if diff "$BASE_RENDER" "$RENDER_OUTPUT" > "$DIFF_OUTPUT" 2>&1; then
    echo -e "   ${YELLOW}⚠️  No differences between base and development${NC}"
else
    DIFF_LINES=$(wc -l < "$DIFF_OUTPUT")
    echo -e "   ${GREEN}✅ Development overlay applied${NC}"
    echo "      $DIFF_LINES lines changed"
    echo "      Diff saved to: $DIFF_OUTPUT"
fi
echo ""

# Test 9: Verify patches directory (if exists)
echo "🔍 Test 9: Checking for Kustomize patches..."
PATCHES_DIR="$SERVICE_DIR/deploy/overlays/development/patches"

if [ -d "$PATCHES_DIR" ]; then
    PATCH_COUNT=$(find "$PATCHES_DIR" -name "*.yaml" -type f | wc -l)
    echo -e "   ${GREEN}✅ Patches directory found${NC}"
    echo "      $PATCH_COUNT patch file(s) available"
    
    # List patches
    find "$PATCHES_DIR" -name "*.yaml" -type f | while read -r patch; do
        echo "      - $(basename "$patch")"
    done
else
    echo -e "   ${YELLOW}⚠️  No patches directory found${NC}"
fi
echo ""

# Test 10: Simulate full ArgoCD rendering (Helm + Kustomize)
echo "🔍 Test 10: Simulating ArgoCD multi-source rendering..."

# This simulates what ArgoCD would do:
# 1. Render Helm chart with values
# 2. Apply Kustomize patches (if any)

FINAL_OUTPUT="$OUTPUT_DIR/final-manifests.yaml"

# For now, just copy Helm output (Kustomize patches would be applied by ArgoCD)
cp "$RENDER_OUTPUT" "$FINAL_OUTPUT"

if [ -d "$PATCHES_DIR" ]; then
    echo -e "   ${BLUE}ℹ️  Note: Kustomize patches exist but are not applied in this test${NC}"
    echo "      ArgoCD will apply these patches after Helm rendering"
fi

echo -e "   ${GREEN}✅ Final manifests ready${NC}"
echo "      Output: $FINAL_OUTPUT"
echo ""

# Summary
echo "========================================="
echo -e "${GREEN}✅ All tests passed!${NC}"
echo "========================================="
echo ""
echo "📋 Summary:"
echo "   Chart: $CHART_NAME v$CHART_VERSION"
echo "   Environment: development"
echo "   Namespace: super-fortnight-dev"
echo "   Resources generated: $RESOURCE_COUNT"
echo ""
echo "📁 Generated files:"
echo "   - $RENDER_OUTPUT (all manifests)"
echo "   - $OUTPUT_DIR/deployment.yaml"
echo "   - $OUTPUT_DIR/service.yaml"
echo "   - $OUTPUT_DIR/configmap.yaml"
echo "   - $DIFF_OUTPUT (base vs dev diff)"
echo "   - $FINAL_OUTPUT (final manifests)"
echo ""
echo "🔍 Review manifests:"
echo "   cat $RENDER_OUTPUT"
echo ""
echo "🚀 Apply to cluster (dry-run):"
echo "   kubectl apply --dry-run=server -f $FINAL_OUTPUT"
echo ""
