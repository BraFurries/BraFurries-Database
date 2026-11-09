# BraFurries — convite de artista e consolidação comercial

**Status:** PRs draft ainda sem merge ou rollout. Não é evidência de aplicação em produção.
**Schema authoritative:** `flyway/sql/versioned/V20261109_003__commerce_artist_invitations_and_consolidation.sql`.
**Sequência controlada:** revisar PRs DB #55 → API #76 → Front #59; agendar janela de migração manual; publicar API imediatamente após DDL; publicar Front depois de verificar API. Nenhum deploy automático com migração pendente.

## Contrato funcional

- O administrador cadastra a artista externa em `users.id` sem credenciais, roles, Discord ou Community; o contato em `commerce_artist_profiles` é administrativo, nunca prova de login.
- O proprietário emite convite individual de 48h, de uso único. Apenas hashes SHA-256 do token e do código são guardados no banco; link e código são entregues separadamente ao contato previamente conhecido. Cinco falhas bloqueiam o convite.
- Sem conta: convite + código + e-mail/senha escolhidos ativam o MESMO `users.id`; o login permanece bloqueado até a confirmação local do e-mail.
- Com conta existente: convite + código + autenticação e confirmação recente da senha consolidam os registros comerciais no `users.id` principal. Refreshtokens e sessão são invalidados; exige novo login.
- Contratos assinados preservam a parte signatária histórica em `commerce_artwork_contracts.signed_artist_user_id` e bytes/hash do PDF. O campo `artist_user_id` é o dono comercial atual.
- Aborta a transação antes de modificar dados se encontrar referências legadas desconhecidas ou a mesma competência financeira ocupada nas duas contas. Nunca copia roles, permissões ou vínculos Discord.
- O antigo usuário mínimo vira um alias técnico `merged_into_user_id`, sem login. Não existe segundo perfil operacional nem link de consulta permanente.
- `/painel/minhas-artes` usa exclusivamente o usuário autenticado. Sem botão de auto-reivindicação, sem exposição do ID do artista, sem consulta de dados de terceiros.

## Atenção ao contrato legado

A migration adiciona `signed_artist_user_id NOT NULL` e substitui `fk_cac_artwork_artist` pela FK por `artwork_id`. Isso exige que a versão nova da API grave a coluna ao assinar contratos. **O app antigo não consegue criar novos contratos após o DDL**.

Agendar uma janela curta de manutenção para **suspender a assinatura de contratos** entre o SQL e a publicação/healthcheck da API #76. Se a API não puder ser publicada, não iniciar o DDL. Todos os passos DDL são commits implícitos em MariaDB; rollback não é automático. Não usar `SET FOREIGN_KEY_CHECKS=0`.

## Pré-flight: somente leitura, em produção

Confirmar backup testado, horário de manutenção, conexão e schema alvo antes de qualquer DDL.

```sql
SELECT DATABASE() AS schema_ativo, VERSION() AS versao_mariadb;
SELECT TABLE_NAME
  FROM information_schema.TABLES
 WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN (
   'users','commerce_artworks','commerce_artwork_contracts',
   'commerce_royalty_accruals','commerce_settlements',
   'commerce_period_locks','commerce_artist_profiles',
   'commerce_artist_invitations','commerce_artist_consolidations')
 ORDER BY TABLE_NAME;

SELECT CONSTRAINT_NAME
  FROM information_schema.REFERENTIAL_CONSTRAINTS
 WHERE CONSTRAINT_SCHEMA=DATABASE()
   AND TABLE_NAME='commerce_artwork_contracts'
 ORDER BY CONSTRAINT_NAME;

SELECT COUNT(*) AS contratos_anteriores FROM commerce_artwork_contracts;
SELECT COUNT(*) AS artes_anteriores FROM commerce_artworks;
SELECT COUNT(*) AS royalties_anteriores FROM commerce_royalty_accruals;
SELECT COUNT(*) AS fechamentos_anteriores FROM commerce_settlements;

SELECT COLUMN_NAME,DATA_TYPE,IS_NULLABLE
  FROM information_schema.COLUMNS
 WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users'
   AND COLUMN_NAME IN ('id','email','password_hash',
                       'email_verified_at','merged_into_user_id','auth_version')
 ORDER BY COLUMN_NAME;
```

Esperado: as seis tabelas comerciais preexistentes e `users` presentes; as três novas tabelas ausentes; FK `fk_cac_artwork_artist` presente; `signed_artist_user_id` ausente; credenciais em `users` opcionais e coluna `merged_into_user_id` existente. Se o schema divergir ou as novas estruturas já existirem, **parar** e reconciliar o estado sem reaplicar.

## Execução manual

Após aprovação expressa, executar **exatamente** o SQL da migration versionada na Database PR #55. Ele cria três tabelas, adiciona e preenche a nova coluna de signatário histórico e troca a FK composta. Preserva todos os documentos, valores e IDs existentes. Registrar checksum, executor e resultado; não executar `flyway migrate`, `baseline` ou `repair` em produção porque não houve adoção formal.

## Pós-flight: somente leitura

```sql
SELECT TABLE_NAME
  FROM information_schema.TABLES
 WHERE TABLE_SCHEMA=DATABASE()
   AND TABLE_NAME IN ('commerce_artist_profiles',
                      'commerce_artist_invitations',
                      'commerce_artist_consolidations')
 ORDER BY TABLE_NAME;

SELECT COUNT(*) AS contratos_sem_signatario
  FROM commerce_artwork_contracts
 WHERE signed_artist_user_id IS NULL;

SELECT COUNT(*) AS contratos_com_signatario_distinto
  FROM commerce_artwork_contracts
 WHERE artist_user_id<>signed_artist_user_id;

SELECT CONSTRAINT_NAME
  FROM information_schema.REFERENTIAL_CONSTRAINTS
 WHERE CONSTRAINT_SCHEMA=DATABASE()
   AND TABLE_NAME='commerce_artwork_contracts'
   AND CONSTRAINT_NAME IN ('fk_cac_artwork_only',
                            'fk_cac_signed_artist',
                            'fk_cac_artwork_artist');

SELECT COUNT(*) AS perfis FROM commerce_artist_profiles;
SELECT COUNT(*) AS convites FROM commerce_artist_invitations;
SELECT COUNT(*) AS consolidacoes FROM commerce_artist_consolidations;
```

Esperado: três tabelas presentes e inicialmente vazias; nenhum contrato sem signatário; `fk_cac_artwork_only` e `fk_cac_signed_artist` presentes e `fk_cac_artwork_artist` ausente. Antes das primeiras consolidações, os contratos devem ter `signed_artist_user_id = artist_user_id`.

Comparar contagens de artes, contratos, royalties e fechamentos com o pré-flight; não devem diminuir.

## Homologação após API e Front

- Administrador autorizado cadastra artista externa sem OAuth/Discord; somente proprietário pode emitir ou revogar convite.
- Link vazado sem código separado não ativa nada; cinco códigos errados bloqueiam. Convite expirado, revogado ou usado não pode ser reutilizado.
- Ativação local mantém ID original e exige confirmação do e-mail antes do primeiro login.
- Conta existente validada pela senha recebe obras, royalties, contratos e fechamentos transacionalmente; alias antigo deixa de autenticar; login novo é necessário.
- Contrato assinado retém `signed_artist_user_id`, PDF, SHA-256, valores; o titular atual é o ID canônico. Verificar estornos, pagamento por competência e totais.
- Abortar sem transferir metade dos registros em caso de duas competências financeiras conflitantes, permissões/identidades legadas na conta mínima ou novo domínio desconhecido.
- A área pessoal é restrita ao titular, sem perfis de outras Communities, contatos privados de terceiros ou funções administrativas.
- OAuth/Discord de login continua separado da titularidade comercial. Se alguém tentar uma fusão social posterior a esta consolidação e houver propriedade financeira, o reconciliador deve bloquear com revisão em vez de apagar dados.

Somente fechar as issues relacionadas após evidência real de produção, inclusive homologação com uma artista.
