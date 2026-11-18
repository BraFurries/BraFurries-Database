# Creator Studio Pro — produção: plano de ativação controlada (18/11/2026)

**Estado: NÃO EXECUTADO.** Este arquivo registra pré-condições e operações necessárias, mas **não** demonstra qualquer DDL aplicada, backup ou deploy em produção. O usuário autorizou testar a V1 na produção; isso não equivale a uma autorização para habilitar expurgo, notificações automáticas ou envio real de e-mails.

## Autoridade e dependências

- Database é a única autoridade do schema. Não criar DDL por API, Coddy ou Front.
- O banco produtivo da BraFurries **ainda não tem baseline Flyway adotado**; nunca executar o baseline de 107 tabelas na produção, nunca inicializar \`flyway_schema_history\` de maneira ad hoc e nunca rodar \`flyway migrate\` sem a reconciliação formal.
- A excepcional transição manual usa **exatamente** os SQLs de \`flyway/sql/versioned/\`, sem alterar arquivos nem aplicar trechos parcialmente. Qualquer falha interrompe a execução para inventário e investigação; DDL MariaDB não tem rollback transacional geral.
- O domínio de commissions pertence a \`users.id\`, independentemente do tenant \`Community\`. Não copiar dados entre artistas, nem grants de produção.
- Pré-requisitos já documentados para identidade: \`users.merged_into_user_id\` e \`users.email_verified_at\` (rollout social de 08/11). Se ausentes no banco atual, **PARAR**.
- Confirmar backup restituível recente, acesso ao schema de produção correto, ausência de migração concorrente e a janela operacional com o operador antes de qualquer DDL.

## 1. Preflight SOMENTE LEITURA

Executar com conta autorizada no banco correto e registrar resultados sem credenciais, e-mails, dados de cliente ou nomes privados em logs públicos:

\`\`\`sql
SELECT DATABASE() AS schema_ativo, VERSION() AS maria_version, UTC_TIMESTAMP(6) AS agora_utc;

SELECT table_name FROM information_schema.tables
 WHERE table_schema = DATABASE()
   AND table_name LIKE 'creator_studio\_%' ESCAPE '\\'
 ORDER BY table_name;

SELECT table_name,column_name,column_type,is_nullable
  FROM information_schema.columns
 WHERE table_schema=DATABASE()
   AND (table_name='users' AND column_name IN ('id','merged_into_user_id','email_verified_at'))
 ORDER BY column_name;

SELECT COUNT(*) AS existe_flyway_history
  FROM information_schema.tables
 WHERE table_schema=DATABASE() AND table_name='flyway_schema_history';

SELECT COUNT(*) AS user_rows FROM users;
\`\`\`

**Esperado:** zero tabelas \`creator_studio_*\` antes desta implantação; \`users.id\`, \`users.merged_into_user_id\`, \`users.email_verified_at\` presentes e compatíveis; nenhuma adoção Flyway surpreendente. Se houver qualquer tabela parcial, migração já aplicada, coluna ausente, concorrência, backup sem comprovação ou schema inesperado, **parar** — não executar por cima.

Conferir tamanho do banco, bloqueios/longas transações e capacidade de executar os SQLs na ordem. Conferir o SHA Git revisado, hash dos cinco arquivos e a aprovação registrada do operador.

## 2. Migrations oficiais (execução MANUAL excepcional)

Abrir os cinco arquivos inteiros na ordem abaixo, sem recriar ou truncar tabelas e sem \`IF NOT EXISTS\` improvisado:

1. \`V20261117_001__creator_studio_subscription_and_commissions.sql\` — 9 tabelas de assinaturas, modelos, tipos e commissions.
2. \`V20261117_002__creator_studio_activity.sql\` — histórico privado da commission (10ª tabela).
3. \`V20261117_003__creator_studio_retention_index.sql\` — índice de seleção conservadora de retenção.
4. \`V20261117_004__creator_studio_retention_notices_holds.sql\` — ledger de avisos, holds e auditoria (3 tabelas).
5. \`V20261118_001__creator_studio_retention_delivery_evidence.sql\` — evidência independente do provedor, sem backfill ou disparos.

Verificar o resultado de **cada** migration antes de avançar. Nunca assumir que execução parcial de DDL foi revertida automaticamente.

## 3. Postflight SOMENTE LEITURA

\`\`\`sql
SELECT COUNT(*) AS creator_studio_tables
  FROM information_schema.tables
 WHERE table_schema=DATABASE()
   AND table_name LIKE 'creator_studio\_%' ESCAPE '\\';

SELECT table_name,column_name,column_type,is_nullable,column_default
  FROM information_schema.columns
 WHERE table_schema=DATABASE()
   AND ((table_name='creator_studio_commissions' AND column_name IN ('owner_user_id','completed_at','status'))
     OR (table_name='creator_studio_retention_notices' AND column_name IN
           ('recipient_email','delivery_state','delivery_provider','delivery_event_ref','delivery_evidence_at')))
 ORDER BY table_name,column_name;

SELECT table_name,index_name,non_unique,
       GROUP_CONCAT(column_name ORDER BY seq_in_index) AS columns
  FROM information_schema.statistics
 WHERE table_schema=DATABASE()
   AND ((table_name='creator_studio_commissions' AND index_name IN ('uq_csc_owner_id','idx_csc_retention'))
     OR (table_name='creator_studio_retention_notices' AND index_name IN ('uq_csrn_epoch','uq_csrn_delivery_event')))
 GROUP BY table_name,index_name,non_unique
 ORDER BY table_name,index_name;

SELECT table_name,constraint_name,referenced_table_name
  FROM information_schema.referential_constraints
 WHERE constraint_schema=DATABASE()
   AND table_name LIKE 'creator_studio\_%' ESCAPE '\\'
 ORDER BY table_name,constraint_name;

SELECT
 (SELECT COUNT(*) FROM creator_studio_subscriptions) AS subscriptions,
 (SELECT COUNT(*) FROM creator_studio_commissions) AS commissions,
 (SELECT COUNT(*) FROM creator_studio_retention_notices) AS notices,
 (SELECT COUNT(*) FROM creator_studio_retention_holds) AS holds;
\`\`\`

Esperado: **13 tabelas** novas; índices \`uq_csc_owner_id\`, \`idx_csc_retention\`, \`uq_csrn_epoch\`, \`uq_csrn_delivery_event\` presentes; FKs de artista+commission em tabelas filhas; colunas novas do ledger; as quatro contagens iniciais iguais a **zero**. Verificar igualmente constraints, CHECKs e charset/collation com o schema revisado. O pós-flight precisa ser evidenciado antes de habilitar a API.

## 4. Aplicação e ensaio em produção

1. **Somente após pós-flight real**, revisar HEAD, checks, aprovações e merge da API #120 (inclui API #109–#119). Executar deploy habitual, respeitando suas flags de habilitação. Não alterar a configuração produtiva para apontar à base de teste.
2. Confirmar readiness da API, que GET autenticado de acesso ao Studio não gera erro de schema, que conta sem convite recebe 403 no acesso Pro e que proprietário consegue gerir convites; revogar convidados apenas se explicitamente autorizado.
3. Após API funcional, merge/deploy Front #118 (inclui Front #111–#117); validar UI no navegador com usuário **autorizado** e registros de teste identificáveis e removíveis somente mediante decisão do operador. Não usar Firebase Preview como staging: o build preview atual aponta para \`https://api.brafurries.com.br\`.
4. Exercitar separação entre contas de dois artistas e todas as operações do MVP (pedido, edição, status/etapa, revisão manual, histórico, exportação). Não criar commissions com dados de clientes reais só para teste. Não alterar assinaturas de usuários terceiros sem consentimento.
5. Inspecionar painel owner-only de saúde e dry-run. O relatório é somente leitura e não autoriza expurgo.
6. **Permanecer desativados**: \`CREATOR_STUDIO_RETENTION_NOTICES_ENABLED=false\`, \`CREATOR_STUDIO_RETENTION_CPAAS_SMTP=false\`, \`CREATOR_STUDIO_RETENTION_CPAAS_WEBHOOK_ENABLED=false\`, \`CREATOR_STUDIO_RETENTION_PURGE_ENABLED=false\`, \`CREATOR_STUDIO_RETENTION_NOTICES_READY=false\` (e qualquer flag equivalente do control plane). Conferir valores reais no ambiente protegido, sem copiar segredos para logs.
7. Zoho real, replay, bounce e corrida com purge ficam como fase operacional separada **sem habilitação automática de limpeza**. Um e-mail entregue ao servidor não significa que chegou à caixa do destinatário.

## 5. Rollback e evidências

As migrations são **aditivas**; não deletar tabelas, inventar down migration nem resetar dados. Se API/Front falharem, reverter os binários/UI com segurança, preservar o schema e os registros para investigação. Registrar: commit e hash SQL, backup e procedimento de restauração, pré/post-flight, horário e operador, merge SHAs, logs redigidos, checks, canários e incidentes.

**Não declarar este rollout concluído até haver evidência da aplicação manual do Database, da API e do Front em produção e do teste autenticado.**