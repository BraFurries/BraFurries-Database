# Creator Studio V1 — registro de implantação em produção (18/11/2026)

## Status e fontes de evidência

**Schema, API e Front publicados; canário funcional humano pendente.**

Este registro distingue a observação do operador sobre o MariaDB de evidências
automáticas de CI e deploy no GitHub. Não representa inspeção independente do
banco de produção, acesso às credenciais, comprovação de backup/restauração
ou validação completa do uso em navegador.

## Schema: autoridade Database

- Fonte oficial: Database PR #73 integrada por squash em commit
  `733b372fad4f16d29faf42c39155a6d528a59f73`.
- A base de produção ainda usa implantação **manual excepcional** de DDL; o
  baseline Flyway não foi adotado formalmente. Não inventar histórico Flyway.
- Após aplicar o schema, o operador enviou screenshots de pós-flight:
  - **13** tabelas `creator_studio_*`;
  - **8** colunas críticas com tipos e nulabilidade esperados;
  - **4** índices verificados (`idx_csc_retention`, `uq_csc_owner_id`,
    `uq_csrn_delivery_event`, `uq_csrn_epoch`);
  - **22** relações de FK listadas em `information_schema`;
  - **0** registros iniciais em assinaturas, commissions, avisos e holds.
- O teste de validação disposable do Database passou após endurecimento
  do critério: duas aceitações SMTP **não** liberam exclusão sem evidência
  independente do provedor.
- Não foram anexados resultados de pré-flight e de backup restaurável nesta
  conversa. Não transformar ausência de evidência em confirmação de realização.

## API: controle de acesso e operações

- API PR #120 integrada por squash em commit
  `3bb08db000c6b54766437b323d249d18a5f37123`.
- O tree do HEAD revisado era idêntico ao tree da `main` publicada;
  PRs intermediárias #109–#119 foram fechadas como incorporadas, preservando branches.
- [Workflow de produção #44296883227](https://github.com/BraFurries/BraFurries-API/actions/runs/44296883227)
  concluiu **success** em `deploy-secret-scan`, `build-image` e
  `deploy-production`, incluindo checks de saúde/readiness e API pública.
- API #120 também validou SQL real contra schema do Database em MariaDB
  Testcontainers descartável (isolamento entre artistas, status de retenção,
  holds, bounces, exigência D30+D7 e callbacks HMAC sintéticos).
- O padrão de configuração no código mantém envio de notices, CPaaS SMTP,
  webhook e purge **desativados**; valores efetivos de segredos e variáveis
  protegidas de produção não foram lidos nem expostos.

## Front: liberação de interface

- Front PR #118 integrada por squash em commit
  `e12e3a603de25205eb701d0e63d68b580f0ffe51`.
- O tree do HEAD revisado correspondia ao tree da `main`; PRs intermediárias
  #111–#117 foram fechadas como incorporadas, branches preservadas.
- [Workflow Firebase Hosting #44297819297](https://github.com/BraFurries/BraFurries-Front-End/actions/runs/44297819297)
  concluiu **success**, após instalação de dependências, build e deploy.
- O Firebase Preview das PRs não é um ambiente de staging: seu build aponta
  para `https://api.brafurries.com.br`.

## Limitações e próximos testes em produção

- Não houve geração de commissions sintéticas por automação nesta implantação.
  A liberação inicial permanece condicionada ao convite/assinatura;
  não ocorreu concessão automática de PRO a artistas.
- O operador ainda deve testar no navegador com conta piloto autorizada,
  conta sem acesso e idealmente dois artistas autorizados diferentes:
  criação/edição, fila, modelos, etapa, revisão, referência, exportação,
  histórico, responsividade e isolamento entre contas.
- Saúde e dry-run de retenção são consultas administrativas somente leitura;
  não autorizam exclusão nem comprovam entrega em caixa de entrada.
- Zoho CPaaS real, replay/bounce e limpeza automática não fazem parte desta
  homologação; exigem credenciais protegidas e autorização operacional específica.
- Em incidente, reverter API/Front por código, preservando migrations aditivas
  e dados. Nunca executar DROP ou rollback de DDL improvisado.

Plano original: [2026-11-18-creator-studio-prod-rollout-plan.md]
(2026-11-18-creator-studio-prod-rollout-plan.md).
