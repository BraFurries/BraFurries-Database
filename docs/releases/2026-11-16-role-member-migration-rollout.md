# Rollout — migração de membros entre cargos (V20261116_003)

A estrutura de jobs já foi criada por `V20261116_002`. Esta release é
**aditiva e específica**: adiciona `source_role_id` e `removed_count` a
`guild_role_tool_operations` e habilita o tipo `ROLE_MIGRATE` nas
constraints. Nenhuma tabela nova ou cargo Discord é criado/removido pelo SQL.

**Atenção:** produção não tem Flyway adotado. Seguir
[runbook de migration release](../runbooks/migration-release.md):
execução manual excepcional do **arquivo versionado exato**, após backup e
pré-flight, sem executar `flyway migrate` nem inventar
`flyway_schema_history`.

## Pré-flight — somente SELECT

```sql
SELECT DATABASE() AS schema_ativo, VERSION() AS maria_version;
SELECT COUNT(*) AS jobs_ativos
  FROM guild_role_tool_operations WHERE status IN ('PENDING','RUNNING');
SELECT COUNT(*) AS jobs_existentes FROM guild_role_tool_operations;
SELECT column_name, column_type, is_nullable
  FROM information_schema.columns
 WHERE table_schema = DATABASE() AND table_name='guild_role_tool_operations'
   AND column_name IN ('role_id','source_role_id','added_count','removed_count')
 ORDER BY column_name;
SELECT constraint_name, check_clause
  FROM information_schema.check_constraints
 WHERE constraint_schema=DATABASE()
   AND constraint_name IN ('ck_grto_type','ck_grto_role_migrate');
```

Parar se o schema não for o esperado, se houver outro release de migration,
se faltarem backups verificáveis ou se `source_role_id`/`removed_count`
já estiverem aplicadas parcialmente. Registrar cardinalidade de jobs antigos.
Recomenda-se `jobs_ativos=0` no momento da aplicação.

## Aplicação

Executar, uma única vez, o SQL revisado em
[`V20261116_003__role_member_migration.sql`](../../flyway/sql/versioned/V20261116_003__role_member_migration.sql)
com o operador credenciado. Não executar SQL paralelo na API/Coddy.

## Pós-flight — somente SELECT

```sql
SELECT column_name, column_type, is_nullable, column_default
  FROM information_schema.columns
 WHERE table_schema = DATABASE() AND table_name='guild_role_tool_operations'
   AND column_name IN ('source_role_id','removed_count');
SELECT constraint_name, check_clause
  FROM information_schema.check_constraints
 WHERE constraint_schema = DATABASE()
   AND constraint_name IN ('ck_grto_type','ck_grto_role_migrate');
SELECT COUNT(*) AS jobs_legados FROM guild_role_tool_operations;
SELECT COUNT(*) AS migrations_iniciais FROM guild_role_tool_operations
 WHERE operation_type='ROLE_MIGRATE';
SELECT COUNT(*) AS counters_antigos_inconsistentes FROM guild_role_tool_operations
 WHERE removed_count <> 0;
```

Esperado: `source_role_id` nullable, `removed_count` INT UNSIGNED default
zero, dois CHECKs válidos, mesmo total de jobs do pré-flight,
`migrations_iniciais=0` e `counters_antigos_inconsistentes=0`.
Se houver divergência, interromper rollout de aplicativos e preservar
os dados para diagnóstico.

## Ordem de rollout

1. Database aplicado + pós-flight verificado.
2. Coddy: novo endpoint de prévia e worker `ROLE_MIGRATE` com acesso
   administrador, hierarquia de origem/destino, fingerprint e métricas.
3. API: endpoints por Community para prévia e dispatch idempotente.
4. Front: dropdown Ferramentas → Cargos e opção Migrar membros.
5. Canário em servidor controlado: teste com dois cargos e poucos membros;
   conferir casos com/sem destino, bots ignorados, add falhando preserva
   origem e histórico de operações. Não testar removendo cargo de staff
   importante nem repetir operação parcialmente concluída sem nova prévia.

## Rollback e limites

Não apagar as colunas, constraints nem dados em rollback. Se falhar um
canário, reverter aplicações em ordem inversa, sem recriar as tabelas.
A transferência é deliberadamente em duas chamadas Discord (adicionar
destino, depois remover origem). Em falha entre elas, o membro mantém
o cargo antigo e pode receber também o novo: o job é parcial, com
contadores persistidos. Uma execução interrompida não é repetida
automaticamente; refazer a prévia antes de reexecutar.
