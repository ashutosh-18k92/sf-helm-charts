# Helm Chart Repository

This repository contains the base **API Helm chart** used by all microservices in the Super Fortnight platform.

## Chart Release Workflow

https://helm.sh/docs/howto/chart_releaser_action/

## Chart: api

**Version**: 0.1.0  
**Description**: Production-ready Helm chart template for deploying API microservices on Kubernetes with Istio service mesh integration.

## Features

- ✅ Istio Integration with VirtualService
- ✅ Horizontal Pod Autoscaler
- ✅ Flexible Affinity (Node and Zone spreading)
- ✅ Configurable Health Checks
- ✅ Environment-specific values
- ✅ Schema Validation
- ✅ Standard Kubernetes labels

## Usage

Services reference this chart via Kustomize:

```yaml
# services/{service}/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

helmCharts:
  - name: api
    repo: https://github.com/ashutosh-18k92/sf-helm-registry.git
    releaseName: my-service
    namespace: super-fortnight
    valuesFile: values.yaml
    version: 0.1.0
```

## Chart Structure

```
sf-helm-registry/
├── README.md               # Repository documentation
├── SETUP_COMPLETE.md       # Setup instructions
└── api/                    # API chart directory
    ├── Chart.yaml          # Chart metadata (v0.1.0)
    ├── values.yaml         # Default values
    ├── values.dev.yaml     # Development overrides
    ├── values.stage.yaml   # Staging overrides
    ├── values.prod.yaml    # Production overrides
    ├── values.schema.json  # Values validation
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

| Version | Date       | Changes                                 |
| ------- | ---------- | --------------------------------------- |
| 0.1.0   | 2026-01-30 | Initial release with affinity templates |

## Service-Specific Configuration

Services override only what's unique to them:

```yaml
# Minimal service values
containerPort: 3000
image:
  repository: "my-service"
env:
  SERVICE_NAME: "my-service"
virtualService:
  hosts:
    - my-service
```

## Contributing

This chart is maintained by the **Platform Team**.

### Making Changes

1. Create a feature branch
2. Make changes to templates/values
3. Update `Chart.yaml` version
4. Test with real services
5. Create PR with changelog
6. Tag release after merge

### Testing

```bash
# Lint
helm lint .

# Template
helm template test . -f values.yaml

# Validate schema
helm lint . --strict
```

## Support

- **Issues**: [GitHub Issues](https://github.com/ashutosh-18k92/sf-helm-registry/issues)
- **Slack**: #platform-team
- **Docs**: [Helm + Kustomize Guide](../gitops-v3/helm-charts/HELM_KUSTOMIZE_HYBRID.md)

## License

Internal use only - Super Fortnight Platform
