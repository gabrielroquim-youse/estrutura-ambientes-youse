# environment-platform

Plataforma de ambientes efêmeros por clone para a Youse Seguradora.

## Visão geral

- **Golden Templates** — ambientes padrão com massa de dados
- **Control Plane** — criação/destruição de clones (Infra, fase 2)
- **golden-seed** — dados de teste versionados
- **poc-simulador** — valida conceito **sem Infra**

Documentação: [GUIA-PRATICO-AMBIENTES-FERRAMENTAS.md](../docs/GUIA-PRATICO-AMBIENTES-FERRAMENTAS.md)

## Começar sem Infra (Qualidade)

```bash
# Validar massa de dados
./golden-seed/scripts/validate-seed.sh

# Simular clone de ambiente
./poc-simulador/simulate-clone.sh examples/branch-preview-request.yaml

# Simular destroy
./poc-simulador/simulate-destroy.sh you-123
```

## Começar com Infra (futuro)

1. Refresh do golden template (`golden-qa`)
2. Push em branch `feature/YOU-*`
3. CircleCI clona ambiente → `you-XXX.preview.youse.io`
4. Merge ou TTL → destroy automático

## Estrutura

```
environment-platform/
├── examples/           # YAMLs EphemeralEnvironment
├── golden-seed/        # Massa de dados + scripts
│   ├── manifests/
│   └── scripts/
├── poc-simulador/      # POC sem EKS (simulate-clone/destroy)
├── golden-templates/   # (Infra) configs dos templates fixos
├── control-plane/      # (Infra) API/Operator
├── terraform/          # (Infra) DNS, RDS
└── charts/             # (Infra) Helm umbrella
```

## Ferramentas (resumo)

| Camada | Ferramenta |
|--------|------------|
| Infra | EKS, Helm, Terraform, Route53 |
| CI/CD | CircleCI, `deployment-orb`, GitHub Actions |
| Dados | golden-seed (YAML/JSON) |
| Automação | Playwright (`qa-e2e-tests-automation`) |
| Mocks | WireMock, MSW (opcional, local) |

## Repositórios Youse relacionados

- `deployment-orb` — jobs CircleCI
- `gitops-kubernetes-addons` — namespaces EKS
- `terraform-platform` — Route53
- `qa-e2e-tests-automation` — suites Playwright
