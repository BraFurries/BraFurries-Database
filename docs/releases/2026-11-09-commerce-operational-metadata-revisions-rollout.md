# BraFurries — revisões de lotes e metadados financeiros (09/11/2026)

**STATUS: NÃO EXECUTADO EM PRODUÇÃO.** Nenhum merge, deploy ou DDL é
autorizado por este runbook. Schema é responsabilidade de BraFurries-Database.

## O que muda

Migration canônica:
`flyway/sql/versioned/V20261109_005__commerce_operational_metadata_revisions.sql`
(Database PR #57). **Depende** de
`V20261109_004__commerce_payout_reversal_ledger.sql` (Database #56)
para assegurar que os pagamentos originais já são append-only.

São **três novas tabelas**, com chaves estrangeiras e auditoria permanente:

- `commerce_production_batch_revisions`: snapshots JSON antes/depois,
  justificativa e autor; o lote só admite alterar custos/quantidade/produto/
  fornecedor antes de existir qualquer venda histórica. Depois, só referência.
- `commerce_payment_metadata_revisions`: referência/observações antigas e
  novas do repasse, sem alterar valor, data, artista, fechamento ou pagamento.
- `commerce_cash_metadata_revisions`: descrição/referência/observações
  antigas e novas de despesas, entradas e aportes, sem alterar valor, tipo,
  pagamento, data, contraparte ou natureza.

Seis triggers (`trg_cpbr_*`, `trg_cpmr_*`, `trg_ccmr_*`)
proíbem UPDATE e DELETE da revisão. Não existe backfill nem alteração de
lançamento financeiro antigo. Banco não executa transferência/PIX.

## 1. Pré-flight — somente leitura, no schema real explicitamente selecionado

```sql
SELECT DATABASE() AS selected_schema, VERSION() AS mariadb_version;
SELECT table_name
FROM information_schema.tables
WHERE table_schema=DATABASE()
  AND table_name IN (
    'commerce_production_batches','commerce_payments',
    'commerce_cash_movements','commerce_catalog_audit',
    'commerce_finance_audit',
    'commerce_production_batch_revisions',
    'commerce_payment_metadata_revisions',
    'commerce_cash_metadata_revisions'
  ) ORDER BY table_name;
SELECT trigger_name,event_object_table,event_manipulation
FROM information_schema.triggers
WHERE trigger_schema=DATABASE()
  AND (trigger_name IN ('trg_cpay_no_update','trg_cpay_no_delete')
       OR trigger_name LIKE 'trg_cpbr_%'
       OR trigger_name LIKE 'trg_cpmr_%'
       OR trigger_name LIKE 'trg_ccmr_%')
ORDER BY trigger_name;
SELECT COUNT(*) AS catalog_lots FROM commerce_production_batches;
SELECT COUNT(*) AS payout_entries,COALESCE(SUM(amount),0) AS payout_sum
FROM commerce_payments;
SELECT COUNT(*) AS cash_entries,
       COALESCE(SUM(signed_amount),0) AS signed_cash_sum
FROM commerce_cash_movements;
SELECT COUNT(*) AS flyway_history_tables FROM information_schema.tables
WHERE table_schema=DATABASE() AND table_name='flyway_schema_history';
```

Esperado: cinco tabelas existentes; **zero** tabelas `*_revisions`;
nenhum dos seis triggers novos; os triggers `trg_cpay_no_update` e
`trg_cpay_no_delete` da migration 004 **já existem**. Pare se divergir.
Não usar DDL genérico de `IF NOT EXISTS` ou `DROP` para contornar conflito.

Salvar contagens e soma financeira antes do DDL. Verificar integridade do backup
com recuperação testável, checksum SHA-256 e commit do arquivo, espaço de disco,
janela para lock de metadados e ausência de deploy concorrente. Não copiar
credenciais ou dados pessoais para o GitHub.

## 2. Aplicação — só após autorização explícita

Aplicar exatamente o SQL versionado, após migration 004 aplicada e pós-flight
confirmado. Ele cria 3 tabelas + 6 triggers, sem DML.

O MariaDB aplica DDL com commit implícito. Caso uma instrução falhe, **PARAR**;
registrar quais objetos já foram criados e reconciliar o estado antes de qualquer
tentativa de continuar. Não executar `flyway migrate`, `flyway baseline`,
`baselineOnMigrate`, `flyway repair` nem o baseline `B20261020_001`
contra produção sem adoção formal.

## 3. Pós-flight — somente leitura

```sql
SELECT table_name,COUNT(*) AS columns_count
FROM information_schema.columns
WHERE table_schema=DATABASE()
  AND table_name IN ('commerce_production_batch_revisions',
    'commerce_payment_metadata_revisions','commerce_cash_metadata_revisions')
GROUP BY table_name ORDER BY table_name;

SELECT trigger_name,event_object_table,event_manipulation,action_timing
FROM information_schema.triggers
WHERE trigger_schema=DATABASE()
  AND trigger_name IN ('trg_cpbr_no_update','trg_cpbr_no_delete',
   'trg_cpmr_no_update','trg_cpmr_no_delete',
   'trg_ccmr_no_update','trg_ccmr_no_delete')
ORDER BY trigger_name;

SELECT table_name,constraint_name,constraint_type
FROM information_schema.table_constraints
WHERE constraint_schema=DATABASE()
  AND table_name IN ('commerce_production_batch_revisions',
    'commerce_payment_metadata_revisions','commerce_cash_metadata_revisions')
ORDER BY table_name,constraint_name;

SELECT
  (SELECT COUNT(*) FROM commerce_production_batch_revisions) AS lot_revisions,
  (SELECT COUNT(*) FROM commerce_payment_metadata_revisions) AS payout_revisions,
  (SELECT COUNT(*) FROM commerce_cash_metadata_revisions) AS cash_revisions;

SELECT COUNT(*) AS payout_entries,COALESCE(SUM(amount),0) AS payout_sum
FROM commerce_payments;
SELECT COUNT(*) AS cash_entries,COALESCE(SUM(signed_amount),0) AS signed_cash_sum
FROM commerce_cash_movements;
```

Esperado: 3 tabelas, 6 triggers BEFORE UPDATE/DELETE, 3 FKs para
documentos comerciais + 3 FKs para autor (6 no total), CHECKs de validade,
zero revisões iniciais. Contagens e somas financeiras devem coincidir com
pré-flight; nenhuma nova tabela possui `community_id`.

## 4. Dependências e homologação

Sequência de release:
Database #56 (004) → Database #57 (005) → API de estornos #79 →
API lotes #81 e metadados financeiros #82 → Front #64/#65, mais as PRs
de catálogo/encomendas pendentes. Validar integração combinada antes do merge.
Não mergear PRs temporárias de CI.

UAT com **dados de teste e duas identidades distintas**:
- Staff com PRODUCTS_MANAGE mas sem SUPPLIERS_MANAGE é recusada; com
  ambas, corrige lote sem vendas e vê auditoria antes/depois.
- Corrigir referência de lote com venda funciona; corrigir preço/quantidade/
  fornecedor/produto com venda histórica, inclusive cancelada, retorna 409.
- PAYMENTS_RECORD+FINANCE_VIEW pode corrigir referência/observação; usuário
  sem permissão falha; não duplica referências efetivas no mesmo fechamento.
- CASHFLOW_MANAGE+FINANCE_VIEW pode corrigir descrição/referência/observação;
  outros usuários só leem se autorizados. Nenhum valor ou saldo muda.
- Listagens mostram a última revisão, com histórico de anteriores;
  lançamentos originais permanecem iguais no banco.
- Triggers bloqueiam UPDATE/DELETE das revisões; triggers da 004 continuam
  protegendo repasses originais.
- Confirmar logs de auditoria, concorrência e campos nulos.

Não liberar operações reais sem backup, pré/pós-flight, CI do HEAD,
deploys sequenciais e UAT verificado.
