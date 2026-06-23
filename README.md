# Estrutura de Ambientes Youse

Projeto de estratégia e implementação de **ambientes efêmeros por clone** (Golden Template) para a Youse Seguradora.

## Documentos

| Arquivo | Descrição |
|---------|-----------|
| [PROJETO-AMBIENTES-YOUSE-v2-CLONE.md](./PROJETO-AMBIENTES-YOUSE-v2-CLONE.md) | Proposta v2 — ambientes por clone (Golden Template) |
| [PROJETO-AMBIENTES-YOUSE.pdf](./PROJETO-AMBIENTES-YOUSE.pdf) | Proposta v1.3 — base original (Jun/2026) |

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
