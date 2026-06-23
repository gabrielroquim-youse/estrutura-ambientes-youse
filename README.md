# Estrutura de Ambientes Youse

Projeto de estratégia e implementação de **ambientes efêmeros por clone** (Golden Template) para a Youse Seguradora.

## Documentos

| Arquivo | Descrição |
|---------|-----------|
| [docs/apresentacao-cto.md](./docs/apresentacao-cto.md) | **Apresentação CTO** (~25 slides, formato Marp) |
| [docs/APRESENTACAO-NOTAS-PALESTRA.md](./docs/APRESENTACAO-NOTAS-PALESTRA.md) | Notas do apresentador + roteiro 45 min |
| [PROJETO-AMBIENTES-YOUSE-v2-CLONE.md](./PROJETO-AMBIENTES-YOUSE-v2-CLONE.md) | Proposta v2 — ambientes por clone (Golden Template) |
| [PROJETO-AMBIENTES-YOUSE.pdf](./PROJETO-AMBIENTES-YOUSE.pdf) | Proposta v1.3 — base original (Jun/2026) |

### Exportar apresentação

1. Instale a extensão **Marp for VS Code**
2. Abra `docs/apresentacao-cto.md`
3. `Ctrl+Shift+P` → **Marp: Export Slide Deck** → PDF ou PPTX

## Estrutura do projeto

```
environment-platform/     # Esqueleto da plataforma de ambientes
├── examples/               # YAMLs de solicitação (branch + automação)
├── golden-seed/            # Massa de dados versionada
└── README.md
```

## Contexto

- **Org Youse:** [youse-seguradora](https://github.com/youse-seguradora)
- **Auditoria:** 461 repos, 313 refs QA, 46 refs Stage
- **Modelo:** clone de ambiente padrão com massa de dados → branch / automação → destroy

## Próximos passos

Ver seção 15 do documento v2 e roadmap de 120 dias.

---

*Workspace pessoal — [gabrielroquim-youse](https://github.com/gabrielroquim-youse)*
