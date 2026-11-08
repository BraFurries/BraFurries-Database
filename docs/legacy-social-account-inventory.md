# Inventário do legado OAuth (somente leitura)

Este inventário não altera registros de usuários. Executar **apenas em ambiente controlado** após as migrations de identidade social e onboarding. Os resultados são agregados e não mostram e-mails, IDs do Discord ou subjects de OAuth.

**Atenção:** o banco legado não dispõe de evidência positiva confiável de que o e-mail antigo foi escolhido e confirmado localmente. A ausência de token de verificação **não comprova** verificação. A migration `V20261107_002` cria `users.email_verified_at` inicialmente nulo; apenas uma confirmação de e-mail realizada pela BraFurries após a migration preenche esse campo. Não promover migração/DML automática a partir desses resultados. Interpretar os grupos com revisão de regras e dados reais antes de habilitar o novo comportamento.

## Etapa 0 — inventário ANTES de qualquer migration em produção

Estas consultas usam apenas tabelas existentes no legado e são **somente SELECT**. Podem ser executadas antes de #47/#48/#50, por uma pessoa autorizada, sem coletar nem compartilhar dados pessoais. A contagem abaixo não comprova propriedade de e-mail nem autoriza merge automático.

~~~sql
-- Quantidade total de contas e capacidade de acesso local.
SELECT
  COUNT(*) AS total_users,
  SUM(CASE WHEN email IS NULL OR TRIM(email)='' THEN 1 ELSE 0 END) AS without_email,
  SUM(CASE WHEN password_hash IS NULL OR TRIM(password_hash)='' THEN 1 ELSE 0 END) AS without_local_password,
  SUM(CASE WHEN email IS NOT NULL AND TRIM(email)<>'' AND
                password_hash IS NOT NULL AND TRIM(password_hash)<>'' THEN 1 ELSE 0 END)
    AS local_credentials_email_proof_unknown
FROM users;

-- Registros Discord vinculados a contas que ainda não possuem senha local.
SELECT
  COUNT(*) AS discord_identity_records,
  SUM(CASE WHEN u.id IS NULL THEN 1 ELSE 0 END) AS broken_user_references,
  SUM(CASE WHEN u.id IS NOT NULL AND
           (u.password_hash IS NULL OR TRIM(u.password_hash)='') THEN 1 ELSE 0 END)
    AS discord_identity_without_local_password
FROM user_discord ud
LEFT JOIN users u ON u.id = ud.user_id;

-- Retorna só a quantidade de grupos, nunca os e-mails.
SELECT COUNT(*) AS duplicate_normalized_email_groups
FROM (
  SELECT LOWER(TRIM(email)) AS normalized_email
  FROM users
  WHERE email IS NOT NULL AND TRIM(email)<>''
  GROUP BY LOWER(TRIM(email))
  HAVING COUNT(*) > 1
) duplicate_groups;

-- Tokens pendentes e vencidos: vencimento não equivale a conta abandonada.
SELECT
  COUNT(*) AS pending_confirmation_tokens,
  SUM(CASE WHEN expires_at < UTC_TIMESTAMP() THEN 1 ELSE 0 END)
    AS expired_pending_confirmation_tokens,
  COUNT(DISTINCT user_id) AS affected_users
FROM user_tokens
WHERE type = 'EMAIL_VERIFICATION'
  AND used_at IS NULL
  AND revoked_at IS NULL;
~~~

**Procedimento:** registrar apenas as contagens e o snapshot/versão do banco; não executar UPDATE, DELETE, alteração de índice, backfill de e-mail verificado nem deduplicação de contas. Contas com histórico comunitário, permissões, restrições ou identidade social exigem reconciliação individual antes de qualquer mudança destrutiva.

## Etapa 1 — inventário APÓS as migrations, em ambiente controlado

```sql
-- READ ONLY diagnostic. Run only after the #48 and #50 Flyway migrations.
-- No user e-mail, OAuth subject or Discord ID is returned.
-- IMPORTANT: Pre-migration history does not prove that users.email was
-- explicitly chosen and confirmed locally. Do NOT backfill verification from
-- OAuth verified_email, password_hash, user_discord, or token absence.
--
-- 1) Counts by recoverability/legacy classification.
SELECT
    CASE
        WHEN u.merged_into_user_id IS NOT NULL THEN 'MERGED_ALIAS'
        WHEN u.email_verified_at IS NOT NULL THEN 'LOCALLY_CONFIRMED_EMAIL'
        WHEN u.email IS NULL OR TRIM(u.email) = '' THEN 'NO_LOCAL_EMAIL'
        WHEN u.password_hash IS NULL OR TRIM(u.password_hash) = '' THEN 'NO_LOCAL_PASSWORD'
        WHEN EXISTS (
            SELECT 1 FROM user_tokens t
            WHERE t.user_id = u.id AND t.type = 'EMAIL_VERIFICATION'
              AND t.used_at IS NULL AND t.revoked_at IS NULL
        ) THEN 'HAS_PENDING_LOCAL_EMAIL_VERIFICATION'
        WHEN EXISTS (SELECT 1 FROM user_discord d WHERE d.user_id = u.id)
          THEN 'DISCORD_HISTORY_WITH_LOCAL_CREDENTIALS_VERIFICATION_UNKNOWN'
        WHEN EXISTS (SELECT 1 FROM user_social_identities i WHERE i.user_id = u.id)
          THEN 'OAUTH_WITH_LOCAL_CREDENTIALS_VERIFICATION_UNKNOWN'
        ELSE 'LOCAL_CREDENTIALS_VERIFICATION_UNKNOWN'
    END AS account_group,
    COUNT(*) AS accounts
FROM users u
GROUP BY account_group
ORDER BY account_group;

-- 2) Discord history coverage by immutable OAuth subject.
-- Presence of a stored subject is NOT proof of local e-mail ownership.
SELECT
    COUNT(*) AS discord_links,
    SUM(CASE WHEN si.id IS NULL THEN 1 ELSE 0 END) AS discord_links_without_oauth_identity,
    SUM(CASE WHEN si.id IS NOT NULL AND si.user_id <> ud.user_id THEN 1 ELSE 0 END)
        AS conflicting_identity_owners,
    SUM(CASE WHEN si.login_enabled = 0 THEN 1 ELSE 0 END) AS disabled_discord_logins
FROM user_discord ud
LEFT JOIN user_social_identities si
    ON si.provider = 'discord'
   AND si.provider_subject = CAST(ud.discord_user_id AS CHAR);

-- 3) Expired local e-mail confirmations still blocking OAuth-backed accounts.
-- Negative authorization must be retained until a valid local confirmation
-- replaces it. Do NOT delete these rows as a cleanup shortcut.
SELECT
    COUNT(DISTINCT t.user_id) AS accounts_with_expired_pending_local_confirmation
FROM user_tokens t
WHERE t.type = 'EMAIL_VERIFICATION'
  AND t.used_at IS NULL
  AND t.revoked_at IS NULL
  AND t.expires_at < UTC_TIMESTAMP()
  AND EXISTS (SELECT 1 FROM user_social_identities si WHERE si.user_id = t.user_id);

-- 4) Number of provider subjects already blocked from OAuth login.
SELECT provider, login_enabled, COUNT(*) AS subjects
FROM user_social_identities
GROUP BY provider, login_enabled
ORDER BY provider, login_enabled;
```
