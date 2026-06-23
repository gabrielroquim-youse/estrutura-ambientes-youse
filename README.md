# Estrutura de Ambientes Youse

Projeto **em construção** — estratégia e implementação de **ambientes efêmeros por clone** (Golden Template) para a Youse Seguradora.

## Sequência de validação

| Fase | Público | Status |
|------|---------|--------|
| 1 | **Time de Qualidade** | Em andamento |
| 2 | Time de Infra / DevOps | Após feedback QA |
| 3 | Liderança | Futuro — proposta madura |

## Documentos

| Arquivo | Descrição |
|---------|-----------|
| [docs/apresentacao-time-qualidade.md](./docs/apresentacao-time-qualidade.md) | **Apresentação Qualidade** (~20 slides, Marp) |
| [docs/APRESENTACAO-NOTAS-TIME-QUALIDADE.md](./docs/APRESENTACAO-NOTAS-TIME-QUALIDADE.md) | Notas do apresentador + roteiro 40 min |
| [docs/apresentacao-time-infra.md](./docs/apresentacao-time-infra.md) | Apresentação Infra — placeholder (fase 2) |
| [PROJETO-AMBIENTES-YOUSE-v2-CLONE.md](./PROJETO-AMBIENTES-YOUSE-v2-CLONE.md) | Proposta v2 — ambientes por clone (Golden Template) |
| [PROJETO-AMBIENTES-YOUSE.pdf](./PROJETO-AMBIENTES-YOUSE.pdf) | Proposta v1.3 — base original (Jun/2026) |

### Exportar apresentação

1. Instale a extensão **Marp for VS Code**
2. Abra `docs/apresentacao-time-qualidade.md`
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

1. Validar proposta com **Time de Qualidade** (workshop golden-seed)
2. Ajustar documentação com feedback
3. Apresentar para **Infra / DevOps** e iniciar spike técnico

Ver seção 15 do documento v2.

---

*Workspace pessoal — [gabrielroquim-youse](https://github.com/gabrielroquim-youse)*
