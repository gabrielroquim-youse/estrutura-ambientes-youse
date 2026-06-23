# environment-platform

Plataforma de ambientes efêmeros por clone para a Youse Seguradora.

## Visão geral

Este repositório (proposto) centraliza:

- **Golden Templates** — ambientes padrão com massa de dados
- **Control Plane** — criação/destruição de clones
- **golden-seed** — dados de teste versionados
- **Terraform/Helm** — infraestrutura de preview

Documentação completa: [PROJETO-AMBIENTES-YOUSE-v2-CLONE.md](../PROJETO-AMBIENTES-YOUSE-v2-CLONE.md)

## Quick start (piloto)

1. Refresh do golden template (`golden-qa`)
2. Push em branch `feature/YOU-*`
3. Pipeline clona ambiente → URL `you-XXX.preview.youse.io`
4. Merge ou TTL → destroy automático

## Estrutura

```
environment-platform/
├── examples/           # YAMLs de solicitação de ambiente
├── golden-seed/        # Massa de dados versionada
├── golden-templates/   # Config dos templates fixos (a criar)
├── control-plane/      # API/Operator (a criar)
├── terraform/          # DNS, RDS clone (a criar)
└── charts/             # Helm umbrella (a criar)
```

## Repositórios Youse relacionados

- `deployment-orb` — jobs CircleCI
- `gitops-kubernetes-addons` — namespaces EKS
- `terraform-platform` — Route53
- `qa-e2e-tests-automation` — suites Playwright
