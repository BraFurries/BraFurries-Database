# BraFurries — pré-rollout manual: arquivos de artes e encomendas (09/11/2026)

**STATUS: PENDENTE / NÃO EXECUTADO EM PRODUÇÃO.** Este documento prepara a janela; não autoriza aplicação, merge nem deploy. Autoridade DDL: BraFurries-Database. O GitHub Actions valida em MariaDB *descartável*, não no banco de produção.

## Motivo do procedimento manual

A produção **ainda não adotou o baseline Flyway** (ver `docs/runbooks/baseline-adoption.md` e `docs/runbooks/migration-release.md`). Como transição excepcional, executar o SQL canônico revisado **uma única vez**, manualmente, somente com autorização do operador, backup e evidências. **Não executar** `flyway migrate`, `flyway baseline`, `baselineOnMigrate`, `flyway repair` ou o baseline `B20261020_001` na base real. Não inserir registros artificiais em `flyway_schema_history`.

## Escopo exato (nenhum DML de produção)

Na sequência, com a versão fixada pelo HEAD aprovado de cada PR:

1. [Database #52](https://github.com/BraFurries/BraFurries-Database/pull/52): `flyway/sql/versioned/V20261109_001__commerce_artwork_private_files.sql` — cria **uma** tabela `commerce_artwork_files` vinculada a `commerce_artworks`, com metadados de arquivos privados R2 e trilha de arquivamento.
2. [Database #53](https://github.com/BraFurries/BraFurries-Database/pull/53): `flyway/sql/versioned/V20261109_002__commerce_physical_orders.sql` — cria **três** tabelas (`commerce_orders`, `commerce_order_items`, `commerce_order_payment_events`) e **dois** triggers de imutabilidade sobre eventos de pagamento.

São **4 tabelas novas e 2 triggers**. Sem `community_id`, sem apagar/alterar tabelas legadas, sem decremento de estoque nem lançamento automático de venda/royalty. Community é tenant das demais funcionalidades; este domínio comercial é exclusivamente BraFurries.

## 1. Preflight (consultas somente leitura)

Executar no banco **explicitamente selecionado** e conferir identidade antes de qualquer DDL:

```sql
SELECT DATABASE() AS selected_schema, VERSION() AS mariadb_version;
SELECT table_name
  FROM information_schema.tables
 WHERE table_schema = DATABASE()
   AND table_name IN (
     'commerce_artworks', 'commerce_products',
     'commerce_finance_audit', 'commerce_catalog_audit'
   ) ORDER BY table_name;
SELECT table_name
  FROM information_schema.tables
 WHERE table_schema = DATABASE()
   AND table_name IN (
     'commerce_artwork_files','commerce_orders',
     'commerce_order_items','commerce_order_payment_events'
   ) ORDER BY table_name;
SELECT trigger_name
  FROM information_schema.triggers
 WHERE trigger_schema = DATABASE()
   AND trigger_name IN ('trg_cope_no_update','trg_cope_no_delete')
 ORDER BY trigger_name;
SELECT COUNT(*) AS production_flyway_history_tables
  FROM information_schema.tables
 WHERE table_schema = DATABASE() AND table_name = 'flyway_schema_history';
```

Esperado: quatro tabelas pré-requisito presentes; **zero** das quatro tabelas novas; **zero** dos dois triggers novos. O resultado do Flyway history deve ser compatível com o processo manual já registrado; histórico inesperado é **STOP**, não ignorar. Verificar que `users.id` é `INT` e que `commerce_artworks.id`, `commerce_products.id` são `BIGINT UNSIGNED`. Caso difiram, interromper. Confirmar o backup restaurável, o acesso à base pretendida e a versão SHA-256 de cada SQL.

Se alguma tabela nova ou trigger já existir: **PARAR** e identificar execução anterior. Não reaplicar ou alterar scripts com `IF NOT EXISTS`.

## 2. Aplicação (somente após autorização explícita)

- Pausar escritores/deploys concorrentes quando necessário; escolher janela operacional.
- Abrir e revisar **o conteúdo integral** dos dois arquivos canônicos dos HEADs aprovados; registrar commit e checksum de cada arquivo.
- Executar `V20261109_001__commerce_artwork_private_files.sql` por completo e conferir criação da tabela, FKs e CHECKs.
- Executar `V20261109_002__commerce_physical_orders.sql` por completo, incluindo **ambos** `CREATE TRIGGER`. Se o cliente SQL exigir configuração própria para separar statements, executar o `CREATE TRIGGER` como uma única instrução cada; não editar as definições.
- Interromper na **primeira** falha: MariaDB faz commit implícito em DDL. Não presumir rollback, não reexecutar arquivo inteiro, não usar `DROP` para reiniciar. Reconciliar o estado real com as migrations revisadas.

## 3. Postflight (somente leitura)

```sql
SELECT table_name
  FROM information_schema.tables
 WHERE table_schema = DATABASE()
   AND table_name IN (
     'commerce_artwork_files','commerce_orders',
     'commerce_order_items','commerce_order_payment_events'
   ) ORDER BY table_name;

SELECT trigger_name, event_manipulation, action_timing
  FROM information_schema.triggers
 WHERE trigger_schema = DATABASE()
   AND event_object_table = 'commerce_order_payment_events'
 ORDER BY trigger_name;

SELECT table_name, constraint_name, constraint_type
  FROM information_schema.table_constraints
 WHERE constraint_schema = DATABASE()
   AND table_name IN (
     'commerce_artwork_files','commerce_orders',
     'commerce_order_items','commerce_order_payment_events'
   ) ORDER BY table_name, constraint_name;

SELECT table_name, column_name
  FROM information_schema.columns
 WHERE table_schema = DATABASE()
   AND table_name IN (
     'commerce_artwork_files','commerce_orders',
     'commerce_order_items','commerce_order_payment_events'
   ) AND column_name = 'community_id';

SELECT
  (SELECT COUNT(*) FROM commerce_artwork_files) AS artwork_files,
  (SELECT COUNT(*) FROM commerce_orders) AS orders_count,
  (SELECT COUNT(*) FROM commerce_order_items) AS order_items,
  (SELECT COUNT(*) FROM commerce_order_payment_events) AS order_payment_events;
```

**Aprovar somente se**: quatro novas tabelas; dois triggers `BEFORE UPDATE` e `BEFORE DELETE`; CHECKs e FKs presentes; nenhuma coluna `community_id`; quatro contagens inicialmente zero. O total de tabelas `commerce_*` cresce em 4 em relação ao preflight. Arquivar evidências sem senhas, hashes de credenciais ou dados pessoais de compradores.

## 4. Após o schema, antes de liberar UI

- [API #74](https://github.com/BraFurries/BraFurries-API/pull/74) e [API #75](https://github.com/BraFurries/BraFurries-API/pull/75): revisar HEAD, mergeability, reviews, checks, o **diff real** e execução conjunta. A API tem de entrar **antes** do Front. Nenhuma autorização de merge/deploy foi dada.
- [Front #57](https://github.com/BraFurries/BraFurries-Front-End/pull/57) e [Front #58](https://github.com/BraFurries/BraFurries-Front-End/pull/58): conferir que a condição `draft == false` no workflow bloqueia Firebase Preview enquanto PR permanecer draft.
- Validar `PROD_ENV_FILE` com segredo privado R2 existente (`R2_ENDPOINT`, `R2_PRIVATE_BUCKET`, `R2_PRIVATE_ACCESS_KEY`, `R2_PRIVATE_SECRET_KEY`) sem exibi-los. Não criar outro bucket. Upload de arte até **25 MiB**, multipart máximo configurado em **30 MB**; validar limites reais do proxy/ingress.
- Homologar arte no bucket privado (upload, GET autenticado, checksum, arquivamento e resposta negada para usuário sem `ARTWORKS_MANAGE`). Não expor chave R2 ou URL pública.
- Homologar encomenda e itens; `SALES_MANAGE` para listagem, cadastro, recebimento parcial, estorno, conclusão/cancelamento e tentativas repetidas. Conferir logs/auditoria. Entrega não pode ter data anterior à encomenda. Não é permitido cancelar com saldo recebido positivo.
- Confirmar que encomendas **não** geram venda financeira, taxa de maquininha, decréscimo de estoque, caixa, repasse ou royalties. A vinculação/reconciliação ordem→venda permanece fora desta V1; impedir dupla contabilização manual.

Registrar usuário operador, janela, backup, nomes e SHAs dos SQLs, preflight, resultados de cada script, postflight e versão implantada. Não marcar esta release como executada sem essas evidências.

## Riscos residuais aceitos para homologação, não omitir em produção

- Exceção após upload para R2 provoca compensação na reversão da transação; falha de processo entre upload e commit ainda pode deixar **objeto órfão**. `STATUS_UNKNOWN` preserva objeto para não causar perda de arquivo confirmado. Monitorar/reconciliar objetos não registrados.
- Validação de formato e entrega `application/octet-stream` como attachment são controles defensivos, não antivírus nem garantia de conteúdo inofensivo (PDF/SVG/ZIP).
- Uploads de originais superiores a 25 MiB não são suportados nesta versão.
- Regras de acesso comercial pertencem à autorização da API, não às permissões de Community ou a controles do Front.
