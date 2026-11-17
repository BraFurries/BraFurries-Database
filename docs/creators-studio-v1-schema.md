# Creator Studio — modelo de dados e acesso autorizado (V1)

## Produto e isolamento

Creator Studio é um produto de **organização de commissions**, pertencente à conta canônica `users.id`.
Não é parte da Gestão Comercial da BraFurries, do sistema de permissões de Community nem do Patreon.
Todo registro privado usa `owner_user_id`, com chaves compostas que impedem vincular
objetos de artistas diferentes. A API deve exigir ownership em toda leitura e escrita.

Migration da PR: `V20261117_001__creator_studio_subscription_and_commissions.sql`.
Somente o repositório Database pode executar migrations Flyway. Não há DML de assinatura
nem acesso concedido automaticamente.

## Política de produto (17/11/2026)

- **Fase piloto (acesso fechado):** somente contas **explicitamente autorizadas** podem entrar.
- **Free:** plano gratuito básico, reservado a contas autorizadas no momento. A futura
  abertura de autoinscrição é decisão separada, não implementada agora.
- **Pro:** plano completo pago futuramente, sem provedor de cobrança escolhido.
- **Artistas do piloto:** **Pro vitalício**, como reconhecimento pela colaboração;
  período sem expiração, sem cobrança futura e sem downgrade automático.
- O acesso por assinatura/entitlement **não deve depender** de identidade no Patreon,
  membro de Community, Artista Parceiro ou admin da Gestão Comercial.

O conceito de `creator_studio_subscriptions` reúne autorização de entrada,
`tier` e situação da assinatura. **Sem registro = sem acesso**, mesmo que
exista plano Free no catálogo conceitual.

| Origem | Plano | Vencimento | Como pode surgir |
| --- | --- | --- | --- |
| `INVITE` | `FREE` | Opcional: NULL para acesso gratuito sem vencimento | Concessão explícita por owner |
| `PILOT` | `PRO` | Obrigatoriamente NULL (vitalício) | Concessão explícita por owner |
| `BILLING` | `PRO` | Obrigatoriamente preenchido | Integração de cobrança server-side *futura* |

A permissão efetiva é:

```sql
SELECT 1
  FROM creator_studio_subscriptions
 WHERE user_id = ?
   AND status = 'ACTIVE'
   AND starts_at <= UTC_TIMESTAMP(6)
   AND (expires_at IS NULL OR expires_at > UTC_TIMESTAMP(6));
```

O valor `expires_at=NULL` em PILOT significa Pro vitalício, **não** uma
assinatura temporária sem prazo conhecido. A administração pode revogar
explicitamente o acesso por motivos legítimos, com auditoria, mas o sistema
não expira nem rebaixa esse plano automaticamente.

`creator_studio_subscription_events` é a trilha append-only; concessão,
revogação ou alteração de plano e evento devem ser persistidos na **mesma transação**.
Não confiar em dados de cobrança informados pelo navegador; integração futura
precisa validar webhook e idempotência antes de alterar uma assinatura.

**Ainda não há preços, checkout, cobrança recorrente ou mapeamento definitivo de
funcionalidades Free/Pro.** Não criar cortes artificiais sem validar o MVP. A
API pode exigir `tier=PRO` em endpoints premium futuros, mas todos os
endpoints privados exigem ao menos `ACTIVE` e entrada autorizada.

## Domínio de commissions

- `creator_studio_stage_definitions`: rótulos reutilizáveis de etapas,
  permitindo agrupar “Sketch” entre fluxos distintos do mesmo artista.
- `creator_studio_workflows` / `creator_studio_workflow_steps`: modelos
  reutilizáveis de etapas. Até um padrão por artista.
- `creator_studio_art_types`: tipo de arte opcional, associado ou não a workflow.
- `creator_studio_commissions`: cliente, pedido, descrição, anotações, data
  **real** de solicitação `requested_on`, diferente de `created_at` de
  cadastro, prazo opcional e status separado da etapa atual.
- `creator_studio_commission_steps`: cópia das etapas no momento da criação
  da commission; editar o modelo não altera trabalhos iniciados.
- `creator_studio_reference_links`: URLs e rótulos, sem R2 e sem anexos no MVP.

Status operacional e etapa de produção são distintos: pausar uma arte não
faz com que o artista perca a informação de qual etapa estava executando.
Concluídos saem da fila ativa, mas isso não equivale a excluir seus dados.

## Segurança e critérios para implementação

- Identidade canônica derivada do token autenticado, **não** de `user_id` enviado
  pelo cliente. Rejeitar contas mescladas (`merged_into_user_id IS NOT NULL`).
- Não expor clientes, notas, URLs e etapas por endpoints públicos ou de Community.
- Toda operação de Studio checa autorização e tier na API, não somente no Front.
- Concessão Free / Pro vitalício apenas pelo responsável autorizado; nunca
  tornar endpoint de concessão público ou conceder automaticamente.
- Datas no banco em UTC; tratar data civil de pedido como `DATE`, independente
  de timezone. Testar intervalo de início/vencimento com limites exatos.
- Sem arquivos no R2 inicialmente. Referências por link com esquema
  `https://`, validações e limites de tamanho na API.
- Não reaproveitar `commerce_artist_profiles`; esse dado pertence à
  operação comercial exclusiva da BraFurries.
- A política de exportação dos próprios dados em situação de vencimento /
  revogação precisa ser definida antes da cobrança real.

## Validação/rollout

1. Revisar diff de DDL, índices e restrições contra legado real.
2. CI estática, Flyway e MariaDB descartável, smoke de isolamento/planos.
3. API: testes focados para negação sem autorização, Free vs Pro, Pro
   vitalício, expiração de BILLING, cross-user, revogação e auditoria.
4. Front: estado de acesso e Studio para aprovados; nada de controle
   de segurança baseado apenas em menu.
5. Depois de aprovação: backup + preflight, migration manual no Database,
   deploy API, deploy Front e concessões auditadas para piloto.
6. Sem merge, DDL/DML em produção, checkout ou deploy automático nesta PR.

Relacionadas: BraFurries/BraFurries-API#12 e BraFurries/BraFurries-Front-End#3.
