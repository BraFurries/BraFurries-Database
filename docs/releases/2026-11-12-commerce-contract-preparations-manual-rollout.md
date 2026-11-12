# BraFurries — rollout manual da geração de minutas contratuais (12/11/2026)

**STATUS: PREPARADO / NÃO EXECUTADO EM PRODUÇÃO.** Este documento não autoriza DDL, merge ou deploy. Autoridade de schema: BraFurries-Database.

## Escopo, compatibilidade e dependências

- Migration: `flyway/sql/versioned/V20261112_001__commerce_contract_document_preparations.sql` (Database PR #64).
- Adição de `commerce_contract_templates.full_text` como `LONGTEXT NULL`: os modelos preexistentes ficam válidos e **sem texto integral** até serem atualizados.
- Nova tabela `commerce_contract_preparations`: minutas PDF imutáveis geradas em bucket R2 privado, com snapshot das cláusulas, das condições financeiras e das qualificações informadas das duas partes. Estados PENDING/SIGNED/CANCELLED e UNIQUE de minuta pendente por arte.
- Nenhum histórico de `commerce_artwork_contracts` é convertido, sobrescrito ou excluído. O contrato só entra em vigor após envio humano de PDF assinado.
- Comercial é um recurso exclusivamente BraFurries (não há `community_id`). Permissão `CONTRACTS_MANAGE` é sempre validada pela API, não pelo Front.
- **N/N-1:** API antiga ignora a coluna e tabela novas. API nova depende delas. Ordem: **Database → API PR #98 → Front PR #84**. Coddy não participa.

A produção ainda não possui baseline Flyway autorizado: se esse estado persistir, usar somente o procedimento manual/one-time do runbook de migrations. Não executar `flyway baseline/migrate/repair` em produção sem autorização específica.

## Preflight de leitura e autorização humana

Antes de qualquer alteração, confirmar banco selecionado, versão do MariaDB, backup restaurável, SHA do SQL revisado e disponibilidade de janela de manutenção. **STOP** se a estrutura do banco diferir, houver um artefato parcialmente aplicado ou backup não verificado.

```sql
SELECT DATABASE() AS selected_schema, VERSION() AS mariadb_version;

SELECT table_name
  FROM information_schema.tables
 WHERE table_schema=DATABASE()
   AND table_name IN ('commerce_contract_templates',
                      'commerce_artworks','commerce_artwork_contracts',
                      'commerce_contract_preparations')
 ORDER BY table_name;

SELECT column_name, column_type, is_nullable
  FROM information_schema.columns
 WHERE table_schema=DATABASE()
   AND table_name='commerce_contract_templates'
   AND column_name IN ('id','full_text');

SELECT COUNT(*) AS template_count FROM commerce_contract_templates;
SELECT COUNT(*) AS signed_agreement_count FROM commerce_artwork_contracts;
SELECT COUNT(*) AS flyway_history_present
  FROM information_schema.tables
 WHERE table_schema=DATABASE() AND table_name='flyway_schema_history';
```

Esperado: três tabelas legadas, **sem** `commerce_contract_preparations`, **sem** `full_text`, contagens de templates/contratos documentadas. Qualquer resultado diferente exige investigação antes de aplicar.

## Aplicação (não executar automaticamente)

Somente depois de aprovação explícita, backup e preflight: executar o arquivo canônico, integral e revisado `V20261112_001`, uma única vez, por operador autorizado. MariaDB DDL realiza commits implícitos: **parar na primeira falha** e reconciliar estrutura; nunca tentar rollback assumido, reaplicar arquivo inteiro ou usar DROP para consertar.

## Postflight somente leitura

```sql
SELECT column_name, column_type, is_nullable
  FROM information_schema.columns
 WHERE table_schema=DATABASE() AND table_name='commerce_contract_templates'
   AND column_name='full_text';

SELECT table_name
  FROM information_schema.tables
 WHERE table_schema=DATABASE() AND table_name='commerce_contract_preparations';

SELECT constraint_name, constraint_type
  FROM information_schema.table_constraints
 WHERE constraint_schema=DATABASE()
   AND table_name='commerce_contract_preparations';

SELECT index_name, non_unique
  FROM information_schema.statistics
 WHERE table_schema=DATABASE() AND table_name='commerce_contract_preparations'
 GROUP BY index_name, non_unique ORDER BY index_name;

SELECT COUNT(*) AS pending_documents FROM commerce_contract_preparations;
SELECT COUNT(*) AS template_count FROM commerce_contract_templates;
SELECT COUNT(*) AS signed_agreement_count FROM commerce_artwork_contracts;

SELECT COUNT(*) AS tenant_column_count
  FROM information_schema.columns
 WHERE table_schema=DATABASE()
   AND table_name='commerce_contract_preparations' AND column_name='community_id';
```

Esperado: `full_text LONGTEXT NULL`, nova tabela com PK/UNIQUE de `pending_artwork_id` e FKs, zero minutas iniciais, zero tenant columns, contagens legadas **iguais às do preflight**.

## API, UI, riscos e homologação

- Implantar API apenas depois da migration; validar acesso negado sem `CONTRACTS_MANAGE`, PDF privado (sem URL público/R2 key na API), PDF legível com cláusulas completas e duas assinaturas, dados reais somente em ambiente homologado autorizado.
- Fluxo: modelo completo → minuta pronta → download → assinatura fora da plataforma → confirmação humana e upload PDF de até 8 MiB → contrato ativo. Exigir que não nasçam royalties/contratos ativos na etapa PENDING.
- Testar edição de modelo após preparação: minuta antiga continua igual e usa regras comerciais de snapshot; conferir que contratos históricos mantêm os mesmos dados. Testar duas minutas concorrentes na mesma arte e impedimento de segundo contrato ativo.
- Identificações legais preenchidas manualmente são dados pessoais confidenciais; limitar acesso e não colocá-las em logs, exceções, URLs ou respostas de listagem. O sistema não autentica criptograficamente assinaturas.
- Monitorar eventuais objetos R2 órfãos após falha entre upload e commit. Registrar data, operador, backups e hashes das evidências sem dados pessoais.

**Nenhuma migration, API ou Front desta feature foi autorizada para produção nesta rodada.**
