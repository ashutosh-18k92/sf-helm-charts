# Helm Chart Repository

> [!IMPORTANT]
> **Architecture Change: Service-Specific Charts**
>
> This repository now contains **TEMPLATE charts** for creating service-specific charts.
>
> - **DO NOT** reference these charts as runtime dependencies
> - **DO** copy charts to create service-specific charts in your service repository
> - See [Service-Specific Charts Pattern](../gitops-v3/gitops-docs/docs/gitops/guides/service-specific-charts.md)

This repository contains Helm chart **templates** maintained by the Platform Team for the Super Fortnight platform.

## Chart: api

**Version**: 0.1.8  
**Type**: Template Chart  
**Description**: Production-ready Helm chart template for deploying API microservices on Kubernetes with Istio service mesh integration.

### Purpose

The `api` chart is a **kickstart template** for creating new service-specific charts. It is **NOT** intended to be used as a shared runtime dependency.

### How to Use

1. **Create** your service chart using the starter (recommended):

   ```bash
   # Add the Helm repository
   helm repo add sf-charts https://ashutosh-18k92.github.io/sf-helm-charts

   # Create your service chart from the starter
   mkdir -p charts
   helm create charts/your-service --starter=sf-charts/api
   ```

   **Alternative**: Pull and rename manually:

   ```bash
   helm pull sf-charts/api --untar --untardir ./charts
   mv ./charts/api ./charts/your-service
   ```

2. **Customize** for your service:

   ```bash
   cd charts/your-service
   vim Chart.yaml   # Update name, version, description
   vim values.yaml  # Update app.name, app.component, etc.
   ```

3. **Publish** to GitHub Pages:

   ```bash
   helm package charts/your-service
   # ... publish to gh-pages branch
   ```

4. **Reference** from Kustomize overlays:
   ```yaml
   # deploy/overlays/development/kustomization.yaml
   helmCharts:
     - name: your-service
       repo: https://your-org.github.io/your-service/charts
       releaseName: your-service
       namespace: super-fortnight-dev
       valuesFile: values.yaml
       version: 0.1.0
   ```

See the [Adding a New Service Guide](../gitops-v3/gitops-docs/docs/gitops/guides/adding-new-service.md) for complete workflow.

## Features

- ✅ **Istio Integration**: Built-in VirtualService with retry policies and timeouts
- ✅ **Auto-scaling**: Horizontal Pod Autoscaler with CPU/memory targets
- ✅ **Health Checks**: Configurable liveness and readiness probes
- ✅ **Identity System**: Separation of business identity (`app.*`) from deployment identity
- ✅ **Environment Overrides**: Separate values files for dev/stage/prod
- ✅ **Schema Validation**: JSON schema for values validation
- ✅ **Flexible Affinity**: Default node and zone affinity templates with override capability
- ✅ **Standard Labels**: Kubernetes `app.kubernetes.io/*` labels with canary deployment support

## Architecture: Service-Specific Charts

### Why Service-Specific Charts?

✅ **Team Autonomy**: Feature teams own and control their service's base configuration  
✅ **No Kustomize Limitations**: Charts are first-class citizens in service repositories  
✅ **Independent Evolution**: Each service versions and evolves its chart independently  
✅ **Helm Dependencies**: Use Helm's dependency system for complex services (leader chart pattern)  
✅ **Quick Launchpad**: Copy template to start new service

### What Changed?

**Previous Approach** (Deprecated):

```yaml
# ❌ DO NOT DO THIS
helmCharts:
  - name: api
    repo: https://github.com/ashutosh-18k92/sf-helm-charts.git
    # This approach has Kustomize limitations
```

**Current Approach**:

```bash
# ✅ DO THIS
# 1. Copy chart to your service repo
cp -r sf-helm-charts/charts/api charts/your-service

# 2. Publish to GitHub Pages
# 3. Reference your service chart
```

## Chart Structure

```
sf-helm-charts/
├── README.md               # Repository documentation
└── charts/
    └── api/                # API chart template
        ├── Chart.yaml      # Chart metadata (v0.1.8)
        ├── values.yaml     # Default values with app.* identity
        ├── values.schema.json
        ├── README.md       # Chart documentation
        └── templates/
            ├── deployment.yaml
            ├── service.yaml
            ├── hpa.yaml
            ├── istioVirtualService.yaml
            ├── serviceAccount.yaml
            └── _helpers.tpl
```

## Versioning

This repository follows [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes requiring service updates
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

## Releases

| Version | Date       | Changes                                     |
| ------- | ---------- | ------------------------------------------- |
| 0.1.8   | 2026-02-02 | Identity system refactoring (app.\* fields) |
| 0.1.7   | 2026-02-01 | Updated to use Chart.AppVersion             |
| 0.1.0   | 2026-01-30 | Initial release with affinity templates     |

## Example: Aggregator Service

The aggregator service demonstrates the service-specific chart pattern:

```
aggregator-service/
├── charts/
│   └── aggregator/         # Service-specific chart (copied from api template)
│       ├── Chart.yaml
│       ├── values.yaml     # Aggregator's base configuration
│       └── templates/
└── deploy/
    └── overlays/           # Environment-specific customization
        ├── development/
        └── production/
```

Published to: `https://ashutosh-18k92.github.io/aggregator-service/charts`

## Contributing

This repository is maintained by the **Platform Team**.

### Making Changes to Templates

1. Create a feature branch
2. Make changes to `charts/api/` templates
3. Update `charts/api/Chart.yaml` version
4. Test with example services
5. Create PR with changelog
6. Tag release after merge

### Testing

```bash
# Lint the chart
helm lint charts/api

# Render templates
helm template test charts/api -f charts/api/values.yaml

# Validate schema
helm lint charts/api --strict

# Test with service-specific values
helm template aggregator charts/api \
  -f /path/to/aggregator-service/deploy/overlays/development/values.yaml
```

### Updating Services

When the template chart is updated, services can choose to:

1. **Manual Update**: Copy specific changes from the new template
2. **Full Refresh**: Re-copy the template and re-apply customizations
3. **Stay Current**: Continue using their current chart version

Services are **NOT** automatically updated when the template changes.

## Support

- **Issues**: [GitHub Issues](https://github.com/ashutosh-18k92/sf-helm-charts/issues)
- **Slack**: #platform-team
- **Documentation**:
  - [Service-Specific Charts Pattern](../gitops-v3/gitops-docs/docs/gitops/guides/service-specific-charts.md)
  - [Adding a New Service](../gitops-v3/gitops-docs/docs/gitops/guides/adding-new-service.md)
  - [Helm Chart Reference](../gitops-v3/gitops-docs/docs/gitops/reference/helm-chart-reference.md)

## License

Internal use only - Super Fortnight Platform
