# BraFurries — Gestão Comercial: catálogo, encomendas e estorno de repasses

**Estado: NÃO EXECUTADO EM PRODUÇÃO.** Este documento não autoriza merge, SQL nem deploy.
Autoridade do schema: `BraFurries-Database`. O banco de produção não adotou o baseline
Flyway; a via excepcional atual é SQL manual aprovado, com evidências verificáveis.

## Objetivo e dependências

- Database [#56](https://github.com/BraFurries/BraFurries-Database/pull/56):
  `flyway/sql/versioned/V20261109_004__commerce_payout_reversal_ledger.sql`.
  **ÚNICO DDL desta rodada**, restrito a `commerce_payments`.
- API [#77](https://github.com/BraFurries/BraFurries-API/pull/77): correções e
  arquivamento do catálogo; [#78](https://github.com/BraFurries/BraFurries-API/pull/78):
  correção de encomendas sem evento de recebimento; [#79](https://github.com/BraFurries/BraFurries-API/pull/79):
  estorno auditável de repasses.
- Front [#60](https://github.com/BraFurries/BraFurries-Front-End/pull/60),
  [#61](https://github.com/BraFurries/BraFurries-Front-End/pull/61) e
  [#62](https://github.com/BraFurries/BraFurries-Front-End/pull/62), respectivamente.
  #61 e #62 alteram arquivos em comum: verificar integração após merge, nunca
  presumir que os dois builds isolados validam o conjunto.
- Coddy não é alterado. Gestão Comercial é **exclusiva BraFurries**, não
  herdada de Community selecionada. O controle de autorização é da API.

A migration converte o registro de repasses em ledger com `event_kind`
(`PAYMENT` padrão para dados antigos, `REVERSAL` novo),
`original_payment_id` (FK composta de origem no mesmo fechamento),
`reversal_reason`, `reversed_by_user_id`, `reversed_at`. Mantém
todas as linhas e valores anteriores; somente compensações negativas são novas.
Uma UNIQUE impede estornar o mesmo pagamento duas vezes. Dois triggers proíbem UPDATE/DELETE de lançamentos originais ou compensatórios. A operação **não**
faz PIX/transferência/reembolso; trata somente do registro contábil interno.

## 1. Preflight SQL: SOMENTE LEITURA

Selecionar explicitamente a base **real correta** antes de executar. Não assumir
que as migrations anteriores foram aplicadas porque a API está publicada.

```sql
SELECT DATABASE() AS selected_schema, VERSION() AS mariadb_version;
SELECT table_name
  FROM information_schema.tables
 WHERE table_schema = DATABASE()
   AND table_name IN
       ('commerce_payments','commerce_settlements','commerce_finance_audit')
 ORDER BY table_name;
SELECT column_name,column_type,is_nullable,column_default
  FROM information_schema.columns
 WHERE table_schema = DATABASE() AND table_name='commerce_payments'
 ORDER BY ordinal_position;
SELECT constraint_name,constraint_type
  FROM information_schema.table_constraints
 WHERE constraint_schema=DATABASE() AND table_name='commerce_payments'
 ORDER BY constraint_name;
SELECT COUNT(*) AS total_payments,
       COALESCE(SUM(amount),0) AS sum_payments,
       COALESCE(MIN(amount),0) AS min_amount,
       COALESCE(MAX(amount),0) AS max_amount
  FROM commerce_payments;
SELECT COUNT(*) AS rows_invalid_by_legacy_rules
  FROM commerce_payments
 WHERE amount<=0 OR request_key IS NULL
    OR settlement_id IS NULL OR paid_on IS NULL;
SELECT trigger_name,event_manipulation
  FROM information_schema.triggers
 WHERE trigger_schema=DATABASE() AND event_object_table='commerce_payments';
SELECT COUNT(*) AS flyway_history_tables
  FROM information_schema.tables
 WHERE table_schema=DATABASE() AND table_name='flyway_schema_history';
```

**Parar** se tabela anterior estiver ausente, estrutura prévia divergir,
`event_kind` ou `original_payment_id` já existir, houver algum valor
de pagamento não positivo, ou o histórico Flyway indicar outro procedimento
sem reconciliação. Esperado antes do SQL: constraint `ck_cpay_amount`
(`amount > 0`), sem `ck_cpay_signed_amount`, sem índice de origem e sem os triggers `trg_cpay_no_update` e `trg_cpay_no_delete`.

Registrar snapshot dos totais (contagem e soma), distribuição por fechamento,
versão MariaDB, SHA do HEAD aprovado, SHA-256 do arquivo e backup restaurável.
Verificar janela de manutenção/lock DDL, espaço, grants de ALTER e integridade
de FKs. Nenhuma credencial ou dado de clientes deve ser colado em PR/chat.

## 2. Aplicação — SÓ APÓS AUTORIZAÇÃO EXPRESSA

1. Confirmar backup íntegro e plano de recuperação; impedir deploys concorrentes.
2. Conferir que a versão EXATA e integral do SQL está no HEAD final aprovado.
3. Executar **uma vez** o arquivo
   `flyway/sql/versioned/V20261109_004__commerce_payout_reversal_ledger.sql`
   com o schema selecionado. Ele contém **três ALTER TABLE** (índices,
   foreign keys e substituição da CHECK antiga) e **dois CREATE TRIGGER** que tornam o ledger append-only.
4. Conferir cada resultado e parar diante da primeira falha.

MariaDB faz **commit implícito** em DDL. Se o ALTER #2 falhar após o #1,
**não** reaplicar cegamente tudo; coletar o estado real e planejar reconciliação.
Nunca usar `flyway baseline`, `baselineOnMigrate`, `flyway repair`
ou inserir histórico Flyway artificial na base de produção. Migração aplicada
manualmente requer evidência própria até a adoção formal do baseline.

## 3. Postflight SQL: SOMENTE LEITURA

```sql
SELECT column_name,column_type,is_nullable,column_default
  FROM information_schema.columns
 WHERE table_schema=DATABASE() AND table_name='commerce_payments'
   AND column_name IN ('event_kind','original_payment_id','reversal_reason',
                       'reversed_by_user_id','reversed_at')
 ORDER BY ordinal_position;

SELECT constraint_name,constraint_type
  FROM information_schema.table_constraints
 WHERE constraint_schema=DATABASE() AND table_name='commerce_payments'
   AND constraint_name IN
       ('fk_cpay_reversal_origin','fk_cpay_reverser',
        'ck_cpay_signed_amount','ck_cpay_amount');

SELECT trigger_name,event_manipulation,action_timing
  FROM information_schema.triggers
 WHERE trigger_schema=DATABASE() AND event_object_table='commerce_payments'
 ORDER BY trigger_name;

SELECT index_name,group_concat(column_name ORDER BY seq_in_index) AS index_columns
  FROM information_schema.statistics
 WHERE table_schema=DATABASE() AND table_name='commerce_payments'
   AND index_name IN ('uq_cpay_reversal_origin','uq_cpay_id_settlement',
                      'idx_cpay_payment_event')
 GROUP BY index_name ORDER BY index_name;

SELECT event_kind,COUNT(*) AS quantity,COALESCE(SUM(amount),0) AS total
  FROM commerce_payments GROUP BY event_kind;

SELECT COUNT(*) AS invalid_payment_rows
  FROM commerce_payments
 WHERE (event_kind='PAYMENT'
        AND (amount<=0 OR original_payment_id IS NOT NULL
             OR reversal_reason IS NOT NULL OR reversed_by_user_id IS NOT NULL
             OR reversed_at IS NOT NULL))
    OR (event_kind='REVERSAL'
        AND (amount>=0 OR original_payment_id IS NULL OR reversal_reason IS NULL
             OR reversed_by_user_id IS NULL OR reversed_at IS NULL))
    OR event_kind NOT IN ('PAYMENT','REVERSAL');

SELECT COUNT(*) AS invalid_reversal_links
  FROM commerce_payments reversal
  LEFT JOIN commerce_payments original ON original.id=reversal.original_payment_id
 WHERE reversal.event_kind='REVERSAL'
   AND (original.id IS NULL OR original.settlement_id<>reversal.settlement_id
        OR original.event_kind<>'PAYMENT'
        OR reversal.amount<>-original.amount);
```

Esperado imediatamente após migração **sem estorno lançado**: cinco colunas
novas, `ck_cpay_signed_amount` presente, `ck_cpay_amount` ausente,
duas FKs, três índices e dois triggers (BEFORE UPDATE e BEFORE DELETE) presentes, contagem e soma de registros iguais ao
preflight, todas as linhas existentes marcadas `PAYMENT`,
`invalid_payment_rows=0`, `invalid_reversal_links=0`. O `community_id`
não aparece. Se não houver pagamentos ainda, a contagem continuará zero;
isso não invalida a migration.

## 4. Integração e UAT antes de operação

- Checks/HEAD/diffs reais e reviews de cada PR; testar branch com **alterações
  de todos os Fronts** (e todas as APIs) antes de publicar.
- Sequência de disponibilidade: SQL validado → API com funcionalidades
  operacionais → Front com botões habilitados. DDL não exige alteração no Coddy.
- Testar como owner, staff autorizado e staff sem grants: acesso ao catálogo,
  edição segura de obra sem contrato, bloqueio quando obra possui contrato,
  arquivamento/reativação, exclusão sem FKs e rejeição com FKs, mudança de
  produto/SKU, correção de artista sem tocar login, vínculo arte/produto.
- Encomenda aberta sem qualquer recebimento: alterar itens/total e excluir;
  com evento de recebimento **mesmo revertido**: impedir edição/exclusão.
- Após mês fechado: pagamento externo registrado (simulado) e estorno contábil
  com motivo; valor original mantido; saldo reaberto; segunda tentativa
  idempotente; estorno de outro fechamento ou do próprio estorno proibido;
  usuário não-owner sem acesso. **Não iniciar dinheiro real no teste**.
- Reconciliar relatórios e visão da artista após estorno, auditar operador;
  observar respostas MariaDB, encoding, locks, status e incidentes.

Sem aprovação dos resultados e autorização específica, **não fazer merge,
deploy, migration nem DML de produção**.
