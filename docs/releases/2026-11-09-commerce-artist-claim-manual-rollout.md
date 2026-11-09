# BraFurries — preparação de rollout de artistas externos e reivindicação pessoal

**Status:** candidato em PR draft #55. Não é evidência de aplicação em produção.
**Schema authority:** `BraFurries-Database` / `flyway/sql/versioned/V20261109_003__commerce_artist_profiles_and_claim_requests.sql`.
**Sequência:** Database manual (após aprovação) → API #76 → Front #59 → homologação autenticada.

## Contrato arquitetural

- Artista externo: criar `users.id` **sem** e-mail de login, senha, OAuth, Discord ou Community, e `commerce_artist_profiles` com contato administrativo separado.
- Quando a artista cria uma conta real com um ID diferente, ela solicita reivindicação. A aprovação é exclusiva do responsável da plataforma, mediante verificação independente e registrada do contato **preexistente**; uma solicitação, nome artístico ou e-mail declarado não prova titularidade.
- A aprovação cria um vínculo de **visualização privada** (`claimed_by_user_id`). Não faz merge destrutivo de `users`, não transfere permissões, não modifica os FKs de artes, contratos e royalties. A revogação deve retirar a visualização imediatamente em chamadas seguintes.
- Os pagamentos são lançados por artista/competência e **não** por obra. Nunca inventar rateios de transferências entre artes.
- Dados administrativos de contato e comprovação não podem aparecer no portal pessoal. A própria pessoa deve ver apenas seus trabalhos, sua apuração e os pagamentos referentes a si.

## Pré-flight de produção (consultas somente leitura)

Efetuar backup verificado, conferir o schema selecionado, registrar a versão MariaDB e confirmar que as migrations anteriores foram instaladas e estão íntegras. **Não** usar `flyway migrate`, `baseline` ou `repair` em produção; a adoção Flyway oficial ainda não ocorreu.

```sql
SELECT DATABASE() AS schema_ativo, VERSION() AS versao_mariadb;
SELECT TABLE_NAME
  FROM information_schema.TABLES
 WHERE TABLE_SCHEMA=DATABASE()
   AND TABLE_NAME IN ('users','commerce_artworks','commerce_artwork_contracts',
    'commerce_royalty_accruals','commerce_settlements','commerce_payments',
    'commerce_artist_profiles','commerce_artist_claim_requests')
 ORDER BY TABLE_NAME;
SELECT TABLE_NAME,COLUMN_NAME,DATA_TYPE,IS_NULLABLE
  FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA=DATABASE()
   AND ((TABLE_NAME='users' AND COLUMN_NAME IN
         ('id','email','password_hash','email_verified_at','merged_into_user_id'))
      OR (TABLE_NAME='commerce_artworks' AND COLUMN_NAME='artist_user_id')
      OR (TABLE_NAME='commerce_royalty_accruals' AND COLUMN_NAME='artist_user_id'))
 ORDER BY TABLE_NAME,COLUMN_NAME;
SELECT TABLE_NAME,CONSTRAINT_NAME
  FROM information_schema.TABLE_CONSTRAINTS
 WHERE CONSTRAINT_SCHEMA=DATABASE()
   AND TABLE_NAME IN ('commerce_artworks','commerce_royalty_accruals')
 ORDER BY TABLE_NAME,CONSTRAINT_NAME;
```

Precondições: seis tabelas base presentes, ambas as novas **ausentes**; `users.id` INT e `email`/`password_hash` nullable; migrações anteriores em produção confirmadas; credencial DDL autoriza dois CREATE TABLE com FK e CHECK; backup disponível. Caso as novas tabelas já existam ou o schema divirja, **parar**, sem reaplicar.

## Execução posterior e autorizada

Somente o operador, após revisão e autorização expressa, executará **uma única vez** o SQL exato `V20261109_003__commerce_artist_profiles_and_claim_requests.sql`, vindo da PR aprovada e com checksum registrado. O arquivo cria somente duas novas tabelas. Nenhuma alteração destrutiva ou recálculo de royalties.

Diferentemente do ambiente descartável/CI, **a produção não possui baseline Flyway oficialmente adotado**. A aplicação excepcional manual deve ter a execução e as evidências anotadas no registro deste release.

## Pós-flight somente leitura

```sql
SELECT TABLE_NAME
  FROM information_schema.TABLES
 WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN
    ('commerce_artist_profiles','commerce_artist_claim_requests')
 ORDER BY TABLE_NAME;
SELECT TABLE_NAME,CONSTRAINT_NAME,CONSTRAINT_TYPE
  FROM information_schema.TABLE_CONSTRAINTS
 WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME IN
    ('commerce_artist_profiles','commerce_artist_claim_requests')
 ORDER BY TABLE_NAME,CONSTRAINT_NAME;
SELECT TABLE_NAME,INDEX_NAME,COLUMN_NAME
  FROM information_schema.STATISTICS
 WHERE TABLE_SCHEMA=DATABASE()
   AND TABLE_NAME IN ('commerce_artist_profiles','commerce_artist_claim_requests')
 ORDER BY TABLE_NAME,INDEX_NAME,SEQ_IN_INDEX;
SELECT 'commerce_artist_profiles' AS tabela,COUNT(*) AS registros FROM commerce_artist_profiles
UNION ALL
SELECT 'commerce_artist_claim_requests',COUNT(*) FROM commerce_artist_claim_requests;
SELECT TABLE_NAME,COUNT(*) AS colunas_community
  FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA=DATABASE() AND COLUMN_NAME='community_id'
   AND TABLE_NAME IN ('commerce_artist_profiles','commerce_artist_claim_requests')
 GROUP BY TABLE_NAME;
```

Esperado: duas tabelas criadas, CHECKs e FKs, chaves únicas das reivindicações pendentes, ambas vazias; nenhum campo `community_id` adicionado. Um resultado sem linhas na última query indica zero colunas de Community.

## Liberação por etapas e verificação

1. **API:** merge depois do pós-flight, build/testes, deploy Health, validação autorização das rotas. Não habilitar Front antes de API.
2. **Front:** merge/deploy com CI verde; conferir que artista externa é cadastrada durante criação da obra sem perder o formulário; nenhum cadastro fictício recebe login.
3. **Autenticação:** artista cria ou usa conta própria, com e-mail verificado. Sujeito autenticado solicita reivindicação de um ID conhecido, responsável confirma pelo contato preexistente e aprova. Antes da aprovação, o portal não deve mostrar obras/royalties de outra pessoa; depois da aprovação, mostra apenas do titular.
4. **Financeiro:** conferir total por obra e mês, estorno, valores totais, competência do pagamento vs. data do pagamento; nenhuma transferência por obra inventada.
5. **Negativos:** não permitir aprovação por `ARTWORKS_MANAGE` sem owner, conta não verificada, username/e-mail coincidente sem prova; impedir dois pedidos PENDING sobre o mesmo artista, bloquear identidades/roles legados; revogação deve retirar acesso sem apagar auditoria; outra Community não confere permissão.
6. **Reconciliação:** fusão OAuth existente deve continuar **fail-closed** quando encontrar FKs operacionais ou claims aprovadas, até existir política separada de migração verificável.

Limites: CI usa MariaDB descartável; não valida por si só dados reais de produção nem comprovação humana de identidade. Não fechar issues comerciais amplas por esta V1.
