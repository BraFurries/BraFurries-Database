# Plano de rollout MANUAL — Gestão Comercial privada (PENDENTE)

Status: **NÃO EXECUTADO**. Nenhuma alteração de produção foi autorizada nesta PR.
Data da proposta: 2026-11-03. Responsável pelo banco: BraFurries-Database.

## Por que ainda é manual

Conforme README do Database, a adoção de baseline Flyway em produção **ainda não ocorreu**. O runner Flyway atual está autorizado apenas para bancos descartáveis na CI. Enquanto não houver baseline e wrapper de produção, DDL manual é um **caminho transitório excepcional**, com SQL idêntico ao arquivo versionado, pré-condições, backup, evidências e registro de execução.

**Nunca executar o baseline B20261020_001 numa base real existente.**
**Nunca executar simultaneamente SQL manual e `flyway migrate` contra produção.**
**DDL MariaDB faz commit implícito; não assumir rollback transacional.**

## Escopo aprovado (a validar no banco real)

Quatro scripts aditivos na ordem exata abaixo, sem DML de produção:

1. `flyway/sql/versioned/V20261103_001__create_commerce_access_foundation.sql` — 4 tabelas ACL privadas.
2. `flyway/sql/versioned/V20261103_002__create_commerce_catalog.sql` — 8 tabelas de artes, contratos, produtos, fornecedores e lotes.
3. `flyway/sql/versioned/V20261103_003__create_commerce_financial_ledger.sql` — 8 tabelas financeiras e coluna `sold_quantity` em `commerce_production_batches`.
4. `flyway/sql/versioned/V20261103_004__commerce_cash_movements_and_sale_fees.sql` — taxas de maquininha nas vendas; novo livro de lançamentos; nova ACL `CASHFLOW_MANAGE`.

Total esperado: **21 tabelas comerciais** (`4 + 8 + 8 + 1`). Não há `community_id` no domínio comercial. Todas as tabelas iniciam vazias.

## 1. Preflight SQL (somente leitura)

Executar com acesso **ao banco correto**, não com acesso à instância toda sem escopo; conferir nome do schema e parar se houver divergência.

```sql
SELECT DATABASE() AS selected_schema, VERSION() AS mariadb_version;
SELECT id, display_name FROM users WHERE id = 2;
SELECT id FROM communities WHERE id = 1;

SELECT table_name
FROM information_schema.tables
WHERE table_schema = DATABASE() AND table_name LIKE 'commerce\\_%' ESCAPE '\\'
ORDER BY table_name;

SELECT table_name, column_name, column_type, is_nullable
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND (
       (table_name='users' AND column_name='id')
    OR (table_name='communities' AND column_name='id')
    OR (table_name='community_team_roles' AND column_name IN ('id','community_id','active'))
    OR (table_name='community_team_role_assignments'
        AND column_name IN ('id','user_id','community_id','role_id'))
    OR (table_name='user_community_status'
        AND column_name IN ('user_id','community_id','is_present','banned','approval_required','approved'))
  )
ORDER BY table_name,column_name;

SELECT COUNT(*) AS production_flyway_history_tables
FROM information_schema.tables
WHERE table_schema=DATABASE() AND table_name='flyway_schema_history';
```

**Parar** se os IDs esperados não existirem, se algum `commerce_*` já existir sem histórico documentado, se os tipos/FKs não forem compatíveis ou se houver `flyway_schema_history` de produção não reconciliado.

Antes de DDL:
- Executar backup físico/lógico com procedimento de restauração definido (preferencialmente testado em ambiente separado).
- Conferir tamanho, janela de manutenção, migrations atuais, bloqueios e dependência API/Front.
- Registrar hash SHA-256 e commit exato dos quatro scripts. Não copiar versões antigas ou editar SQL no servidor sem commit de revisão.
- Confirmar como o banco será acessado sem expor credenciais em logs, chat ou scripts versionados.

## 2. Aplicação

**Somente após preflight e autorização explícita:** aplicar exatamente os quatro scripts na sequência 001→002→003→004.

Se executar no cliente `mariadb` ou `mysql`, abrir a base selecionada, validar `SELECT DATABASE()` e usar o arquivo completo por vez, sem editar DDL. Verificar o resultado e o conjunto de tabelas após **cada** script antes de prosseguir.

**Se qualquer passo falhar, PARE.** MariaDB não garante desfazer DDL já aplicada. Não rode novamente o mesmo arquivo, não crie `IF NOT EXISTS` genéricos, não use `DROP TABLE` para tentar reiniciar. Registrar erro e reconciliar o estado real com o versionado antes de corrigir.

O procedimento transitório **não** cria entradas no `flyway_schema_history`. Para adoção do Flyway em produção no futuro será preciso reconciliar formalmente o baseline e as quatro migrations manuais.

## 3. Postflight SQL (somente leitura)

```sql
SELECT COUNT(*) AS commerce_tables
FROM information_schema.tables
WHERE table_schema=DATABASE() AND table_name LIKE 'commerce\\_%' ESCAPE '\\';

SELECT table_name, column_name, column_type, extra
FROM information_schema.columns
WHERE table_schema=DATABASE()
  AND (
       (table_name='commerce_sales' AND column_name IN (
           'payment_method','processing_fee_percent','processing_fee_fixed',
           'processing_fee_amount','net_receipt_amount'))
    OR (table_name='commerce_production_batches' AND column_name='sold_quantity')
    OR (table_name='commerce_cash_movements' AND column_name IN (
           'movement_type','signed_amount','contribution_nature','event_kind'))
  )
ORDER BY table_name,column_name;

SELECT table_name,column_name
FROM information_schema.columns
WHERE table_schema=DATABASE() AND table_name LIKE 'commerce\\_%' ESCAPE '\\'
  AND column_name='community_id';

SELECT table_name,check_clause
FROM information_schema.check_constraints
WHERE constraint_schema=DATABASE()
  AND constraint_name IN (
      'ck_ccm_contribution','ck_ccm_kind','ck_cs_fee_amount',
      'ck_cup_permission','ck_crp_permission'
  )
ORDER BY table_name;

SELECT (SELECT COUNT(*) FROM commerce_cash_movements) AS cash_movements,
       (SELECT COUNT(*) FROM commerce_sales) AS sales,
       (SELECT COUNT(*) FROM commerce_payments) AS payouts;
```

Expectativas para instalação nova: **21 tabelas comerciais**; nenhum `community_id`; todas as 9 colunas verificadas presentes; `CASHFLOW_MANAGE` permitido nas duas tabelas ACL; contagens iniciais **zero**. Se diferir, bloquear a API e investigar.

## 4. Depois do schema

Na API, após validar merges/testes e com bucket R2 privado verificado, ajustar **somente no ambiente seguro**:

```dotenv
COMMERCE_OWNER_USER_ID=2
COMMERCE_OFFICIAL_COMMUNITY_ID=1
R2_PRIVATE_BUCKET=<NOME_REAL_DO_BUCKET_PRIVADO>
R2_PRIVATE_ACCESS_KEY=<TOKEN_ACESSO_PRIVADO>
R2_PRIVATE_SECRET_KEY=<SEGREDO_PRIVADO>
```

Preservar demais variáveis de `PROD_ENV_FILE`. Não colocar segredo em GitHub issue, commit ou chat. A API depende de scripts 001–004; Front só pode entrar depois de schema e API prontos. Não dar deploy automático nem alterar dados operacionais sem aprovação.

## 5. Verificações funcionais obrigatórias

- Conta `users.id=2` acessa; outra Community Admin sem autorização pessoal não acessa.
- Staff sem `CASHFLOW_MANAGE` não pode registrar/estornar entradas e saídas.
- Taxa 3,5% + R$1 sobre venda R$100: líquido R$95,50; royalty PERCENT_GROSS continua sobre R$100.
- Compra de fornecedor real registrada como despesa somente quando paga; não duplicar custo de lote/maquininha.
- Aporte reembolsável de membro da staff entra em financiamento, não receita; estorno compensa sem apagar original.
- UUID repetido com payload idêntico não duplica lançamento; payload diferente gera conflito.
- Vendas concorrentes no mesmo lote não passam do saldo disponível.
- Fechamento mensal/pagamento a artista não convertem obrigações em fluxo automaticamente antes de pagamento externo real.
- Bucket privado não possui domínio público nem `r2.dev`; PDF privado só baixa com autorização.

## Evidência a registrar após aplicação real

Momento de início/término, operador (sem senha), backup verificável, resultado do preflight, hash/commit dos scripts, retorno de cada SQL, postflight, versão API/Front liberada, teste de acesso com duas identidades, incidentes e rollback operacional. **Não marcar como concluído sem evidência.**
