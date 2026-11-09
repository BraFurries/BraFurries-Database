# BraFurries — release evidence: arquivos de artes e encomendas V1

Data: **09/11/2026**. Autoridade do schema: BraFurries-Database. Esta evidência é um registro pós-rollout, não um script de produção e não uma autorização para reaplicar migrations.

## Banco de produção — evidência informada pelo operador

O operador informou nesta conversa que **aplicou as migrations e que o pós-flight estava correto**, e posteriormente autorizou seguir com a integração/deploy.

Scripts canônicos (ambos com conteúdo versionado na `main`):

1. `V20261109_001__commerce_artwork_private_files.sql` — Database #52.
2. `V20261109_002__commerce_physical_orders.sql` — Database #53 (incluindo os dois triggers append-only).

**Limites da evidência:** o assistente **não** executou SQL contra produção nem inspecionou o resultado real das consultas, prints, backup, credenciais, identidade de schema ou os dados do banco. O pós-flight está **confirmado pelo operador**, não verificado independentemente nesta sessão. O checksum e o inventário observado das quatro tabelas/dois triggers em produção não foram fornecidos aqui; não inventá-los. O ambiente de produção ainda opera sob procedimento transitório de DDL manual, **sem adoção oficial do baseline Flyway**. Não reaplicar scripts manualmente nem rodar `flyway migrate` sobre a base existente sem nova análise.

Runbook com preflight, execução e postflight: [2026-11-09-commerce-artwork-files-and-orders-manual-rollout.md](2026-11-09-commerce-artwork-files-and-orders-manual-rollout.md).

## Integração GitHub — verificada nos repositórios

| Camada | Escopo | PRs e resultado |
| --- | --- | --- |
| Database | Metadados de originais de artes, encomendas, itens, recebimentos e estornos | [#52](https://github.com/BraFurries/BraFurries-Database/pull/52) merge commit `53e31ebd6ffb3b142e3ff87e67245350e3d3ed4c`; [#53](https://github.com/BraFurries/BraFurries-Database/pull/53) merge commit `f92f516c5687cf102cd2a060598ef03a0ad09d44` |
| API | Armazenamento privado R2, API de encomendas e concorrência/idempotência | [#75](https://github.com/BraFurries/BraFurries-API/pull/75) squash commit `ec1476980682421e45caa308b8d834095ab3e631`, incluindo integralmente [#74](https://github.com/BraFurries/BraFurries-API/pull/74), encerrada como incorporada |
| Front | Interface de arquivos privados e operações de encomendas | [#58](https://github.com/BraFurries/BraFurries-Front-End/pull/58) squash commit `88432319e94690e1db88d35d0e322aaf413bb893`, incluindo integralmente [#57](https://github.com/BraFurries/BraFurries-Front-End/pull/57), encerrada como incorporada |

As branches intermediárias de API/Front foram **preservadas**. Comparações de blob SHA confirmaram identidade dos arquivos da PR intermediária em `main`, além das alterações da PR final. As PRs integradas tinham CIs verdes e nenhuma review thread pendente. Nenhuma alteração no Coddy.

## Evidência dos deployments automáticos

- **API:** [workflow de produção 42610391810](https://github.com/BraFurries/BraFurries-API/actions/runs/42610391810), commit `ec147698`: **success** em `deploy-secret-scan`, `build-image` e `deploy-production`, incluindo `/actuator/health/readiness`, endpoint local, CORS local e API pública/CORS. O deploy usou imagem GHCR imutável.
- **Front:** [workflow Firebase Hosting 42611138574](https://github.com/BraFurries/BraFurries-Front-End/actions/runs/42611138574), commit `88432319`: **success** no `build_and_deploy`.
- **Preview:** prevenção de Firebase Preview em PRs draft integrada ao Front, com execução anterior `skipped`. Após merge, produção usa o workflow separado.

## Comportamentos preservados e pendências de homologação

- O comércio permanece **privado e exclusivo da BraFurries**. `ARTWORKS_MANAGE` e `SALES_MANAGE` são verificados na API por autorização de plataforma; Community Admin de outra Community não recebe autorização por padrão.
- Arquivos das artes usam o **bucket privado R2 já existente**, prefixo `commerce/artworks/{artworkId}/`, até 25 MiB, validação básica de formato, SHA-256, download autenticado como attachment e trilha de arquivamento. A API usa multipart 30 MB como padrão, sujeito a variáveis de produção e proxy.
- Encomendas e estornos operacionais têm histórico e auditoria, sem gerar automaticamente `commerce_sales`, receitas financeiras, baixa de estoque, royalties ou repasse a artistas. **Evitar contabilização em duplicidade** quando uma encomenda também for registrada como venda.
- **Não foi realizado teste end-to-end autenticado pelo assistente em produção**, upload/download real para o R2, teste negativo com outra conta, cadastro real de pedido/estorno ou conferência direta do banco. O sucesso de CI/health check **não prova** esses fluxos.
- Restam como evolução: conciliação de possíveis objetos R2 órfãos após queda de processo; proteção operacional contra arquivos potencialmente maliciosos; suporte a originais maiores que 25 MiB; conversão rastreável de encomenda para venda/caixa/royalty sem dupla contagem.

## Registro de acompanhamento

Manter as issues amplas abertas até a homologação funcional e as fases além da V1. Eventuais erros de acesso ou de upload em produção exigem conferência segura de `R2_PRIVATE_BUCKET`, `R2_PRIVATE_ACCESS_KEY`, `R2_PRIVATE_SECRET_KEY`, `R2_ENDPOINT`, e das configurações de upload no `PROD_ENV_FILE` **sem copiar valores secretos para issues ou chats**.
