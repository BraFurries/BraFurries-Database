# Rollout — blacklist global e ferramentas de cargos (2026-11-16)

A base de produção **ainda não tem Flyway adotado**. Por isso, os scripts em
`flyway/sql/versioned/` são a autoridade versionada, mas a execução em produção
segue o procedimento manual excepcional do
[runbook de migrações](../runbooks/migration-release.md).
O CI usa **MariaDB descartável**; passar no CI **não** confirma que uma migration
tenha sido aplicada no banco real.

## Contratos e dependências

1. `V20261116_001__global_record_game_blacklist.sql`: nova blacklist
   **global**, preservando `blacklisted_games` e importando nomes legados de
   todas as guilds sem alterar a tabela antiga.
2. `V20261116_002__guild_role_tool_operations.sql`: operações
   **por Community e guild**, with FK composta para impedir vínculos cruzados,
   unique para apenas um job PENDING/RUNNING por guild e auditoria persistente.
3. Coddy muda para leitura global de jogos e hospeda ferramentas de cargos.
   API é autoridade das decisões, autorização e início de jobs; Front só UI.

## Pré-flight de produção — somente leitura

Exigir backup restaurável recente e operador responsável. Executar no banco
**correto** e registrar o resultado abaixo. **Não prosseguir** se o
`database()` for inesperado, se tabelas novas existirem parcialmente,
se houver migração concorrente ou se não puder conferir backup.

```sql
SELECT DATABASE() AS schema_ativo, VERSION() AS maria_version, NOW() AS clock_local;
SELECT table_name FROM information_schema.tables
 WHERE table_schema = DATABASE()
   AND table_name IN ('blacklisted_games','record_global_blacklisted_games',
                      'record_global_blacklist_audit','guild_role_tool_operations',
                      'guild_role_tool_audit');
SELECT COUNT(*) AS comunidades FROM communities;
SELECT COUNT(*) AS guilds FROM community_discord;
SELECT COUNT(*) AS candidatos_globais FROM (
  SELECT DISTINCT TRIM(game_name) AS name FROM blacklisted_games
   WHERE game_name IS NOT NULL AND TRIM(game_name) <> '' AND TRIM(game_name) <> '0'
) legacy;
SELECT MAX(CHAR_LENGTH(TRIM(game_name))) AS maior_nome_legado
  FROM blacklisted_games WHERE game_name IS NOT NULL;
SELECT game_name, COUNT(*) AS ocorrencias
  FROM blacklisted_games
 WHERE game_name IS NOT NULL AND TRIM(game_name) <> ''
 GROUP BY game_name HAVING COUNT(*) > 1 ORDER BY ocorrencias DESC LIMIT 20;
```

A tabela `blacklisted_games` pode não existir em ambientes novos.
Se não existir, omitir as consultas que a referenciam; a primeira migration
trata a ausência condicionalmente. Em produção que já possui esse legado,
`maior_nome_legado` precisa ser `<=50`; valores incompatíveis exigem
revisão, **nunca truncamento silencioso**.

## Aplicação controlada

Sem executar `flyway migrate` ou `baseline` na produção não adotada:

1. Aplicar o conteúdo **exato** de
   `V20261116_001__global_record_game_blacklist.sql`.
2. Confirmar que a estrutura e os dados passaram no pós-flight abaixo.
3. Aplicar o conteúdo **exato** de
   `V20261116_002__guild_role_tool_operations.sql`.
4. Confirmar o pós-flight completo e registrar que foi aplicação manual
   excepcional, **sem criar** `flyway_schema_history`.

**Não recriar, editar, corrigir ou reexecutar parcialmente tabelas** em caso
de falha. Como DDL não é totalmente transacional, parar e inventariar o estado
antes de qualquer tentativa seguinte.

## Pós-flight de produção — somente leitura

```sql
SELECT table_name FROM information_schema.tables
 WHERE table_schema = DATABASE()
   AND table_name IN ('record_global_blacklisted_games',
                      'record_global_blacklist_audit',
                      'guild_role_tool_operations',
                      'guild_role_tool_audit')
 ORDER BY table_name;
SELECT COUNT(*) AS nomes_globais FROM record_global_blacklisted_games;
SELECT COUNT(*) AS nomes_legados_ausentes
  FROM (SELECT DISTINCT TRIM(game_name) AS name FROM blacklisted_games
         WHERE game_name IS NOT NULL
           AND TRIM(game_name) <> '' AND TRIM(game_name) <> '0') legacy
 WHERE NOT EXISTS (
   SELECT 1 FROM record_global_blacklisted_games g
   WHERE g.game_name = legacy.name
 );
SELECT COUNT(*) AS total_jobs_iniciais FROM guild_role_tool_operations;
SELECT COUNT(*) AS total_auditorias_iniciais FROM guild_role_tool_audit;
SELECT constraint_name, table_name, referenced_table_name
  FROM information_schema.referential_constraints
 WHERE constraint_schema = DATABASE()
   AND table_name IN ('guild_role_tool_operations','guild_role_tool_audit')
 ORDER BY table_name, constraint_name;
SELECT index_name, non_unique, group_concat(column_name ORDER BY seq_in_index) AS columns
  FROM information_schema.statistics
 WHERE table_schema = DATABASE() AND table_name = 'guild_role_tool_operations'
 GROUP BY index_name, non_unique ORDER BY index_name;
```

Esperado: 4 tabelas novas, `nomes_legados_ausentes=0`,
`total_jobs_iniciais=0`, `total_auditorias_iniciais=0`; FKs compostas
presentes e índice único `uq_grto_active_guild`. No ambiente que não tinha
`blacklisted_games`, omitir somente a consulta de nomes legados ausentes.
O número final da blacklist precisa corresponder à cardinalidade distinta
da prévia (considerando a collation case-insensitive).

## Rollout dos aplicativos — **somente depois** do pós-flight

1. Coddy: disponibilizar leitura global e endpoint interno de preflight/
   execução. Validar readiness e ausência de falhas do cache novo.
2. API: ativar endpoints globais e jobs autorizados; confirmar status
   e erro apropriado para usuário sem ADMIN Discord.
3. Front: liberar Administração → Recordes, Ferramentas → Cargos para todos
   e Ferramentas → Recuperação.
4. Canários: conferir blacklist global em **duas comunidades distintas**;
   prévia de cargo sem executar; job de poucos membros em servidor controlado;
   análise de logs e recuperação de 1 cargo/membro autorizado;
   consultar auditorias e garantir que nenhuma operação duplicou.
5. **Remover comandos slash legados só em outra PR**, depois dos canários.
   A recuperação deve continuar disponível para o administrador mesmo em
   caso de falha do novo UI.

## Rollback

As migrations são aditivas: **não apagar** as tabelas nem os dados para
rollback. Manter as PRs reversíveis por código e observar a compatibilidade
N/N-1. Reverter API/Coddy/Front se um canário falhar; investigar sem inventar
edições diretas em produção. As configurações globais podem demandar
reconciliação antes de retornar aos leitores antigos por-guild.
