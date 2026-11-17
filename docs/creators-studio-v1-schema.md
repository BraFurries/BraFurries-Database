# Creator Studio — schema V1 e acesso por assinatura

## Escopo

Produto de organização de commissions para artistas com conta BraFurries.
**Não** é o cadastro de artistas da Gestão Comercial nem um tenant Community.
Toda linha privada referencia o usuário proprietário (`users.id`). Não há
`community_id`, contrato comercial, associação automática com Patreon ou
processamento de pagamentos nesta migration.

Migration: `V20261117_001__creator_studio_subscription_and_commissions.sql`.

## Acesso por assinatura

`creator_studio_subscriptions` registra **um período de acesso atual por usuário**.
A API deve exigir, em *toda operação de dados*:

```sql
SELECT 1
  FROM creator_studio_subscriptions
 WHERE user_id = ?
   AND status = 'ACTIVE'
   AND starts_at <= UTC_TIMESTAMP(6)
   AND expires_at > UTC_TIMESTAMP(6);
```

Ausência de registro, suspensão, revogação e expiração **negam acesso**.
Não conceder privilégio automático a administrador, usuário que tenha Patreon,
membro de Community nem artista cadastrado no módulo comercial.

- `source_kind=PAID`: alimentado futuramente por integração de cobrança
  verificada no servidor (sem confiar em retorno do browser).
- `source_kind=PILOT`: assinatura de cortesia, com validade finita, emitida
  apenas por um fluxo administrativo autorizado e auditado.
- `status=ACTIVE`: acesso vigente apenas dentro do intervalo temporal;
  **cobrança cancelada sem perda imediata do período pago** pode continuar ativa
  até `expires_at`; a renovação da cobrança não está neste escopo.
- `creator_studio_subscription_events`: histórico append-only de concessões,
  renovações e revogações. A escrita da assinatura e do evento deve ocorrer
  na mesma transação; não provisionar por DML manual em produção.
- Não armazenar token de cobrança, dados bancários, identificadores de cartão
  nem segredos nesta tabela. O provedor/checkout será uma decisão futura.
- Para piloto, a API deve fornecer mecanismo **owner-only** de concessão com
  expiração e auditoria, antes de convidar usuários; esta migration não concede
  assinaturas a ninguém.

Nota: o termo *assinatura ativa* aqui se refere à autorização efetiva de
uso do produto; cobranças recorrentes e catálogo de planos são domínios
distintos ainda não implementados.

## Estrutura do Studio

- `creator_studio_stage_definitions`: nomes de etapas reutilizáveis para
  agrupamento entre diferentes processos do mesmo artista.
- `creator_studio_workflows`/`creator_studio_workflow_steps`: modelos de
  etapas. Cada artista pode ter até um padrão.
- `creator_studio_art_types`: tipos de trabalho, com associação **opcional**
  ao fluxo específico.
- `creator_studio_commissions`: pedido privado e estado operacional
  independente da etapa, com `requested_on` (data real do pedido) distinto
  de `created_at` (registro no sistema). Índice para fila cronológica.
- `creator_studio_commission_steps`: **cópia** das etapas escolhidas na
  criação do pedido; edição do modelo não retroage. `stage_definition_id`
  é opcional e pode conectar semanticamente a etapa a outras commissions.
- `creator_studio_reference_links`: apenas URLs. Sem upload no R2.

FKs compostas por `(owner_user_id, id)` previnem associações entre
objetos de **artistas diferentes** (tipo de arte, fluxo e etapas). A API
precisa ainda aplicar ownership em todas as consultas, operações e alterações,
com parâmetros derivados do usuário autenticado — nunca de `user_id` enviado
pelo cliente.

## Notas de implementação

- Validar tamanho, URLs e dados recebidos na API antes de gravar. Evitar
  HTML/JavaScript em URLs de referência; preferir HTTPS.
- Concluir uma commission remove-a da fila **ativa**, mas não apaga a
  informação; exclusão definitiva deve ser explícita e respeitar privacidade.
- Registrar aprovação/correção como **nota manual do artista**, nunca como
  confirmação autenticada do cliente.
- A API deve negar leitura e escrita a assinantes expirados; futura política
  de exportação de dados após expiração precisa de decisão específica.
- Cuidado com a migração de contas consolidadas: rejeitar login de
  `users.merged_into_user_id IS NOT NULL`.
- Cliente, links e notas devem permanecer privados; recursos públicos de
  vitrine ou fila pública requerem autorização e contratos separados.
- Não iniciar a API com `ddl-auto=create/update` e não executar Flyway
  nela; migrações somente aqui.

## Ordem de rollout (ainda não autorizada)

1. Revisar diff e executar CI / validação em MariaDB descartável.
2. Backup e preflight manual de schema MariaDB de produção.
3. Aplicar migration **somente após autorização explícita**.
4. Publicar API com validação de assinatura em todos os endpoints.
5. Publicar Front sem habilitar acesso indiscriminado.
6. Conceder assinaturas PILOT temporárias, com auditoria, a usuários
   específicos após consentimento.
7. Observar erros, isolamento e uso real do MVP.

Não houve execução de SQL nem deploy de produção ao criar esta PR.
