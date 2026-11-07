-- READ ONLY diagnostic. Run only after the #48 and #50 Flyway migrations.
-- No user e-mail, OAuth subject or Discord ID is returned.
-- IMPORTANT: No surviving schema field proves that historical users.email was
-- explicitly chosen and confirmed locally. Do NOT backfill verification from
-- OAuth verified_email, password_hash, user_discord, or token absence.
--
-- 1) Counts by recoverability/legacy classification.
SELECT
    CASE
        WHEN u.merged_into_user_id IS NOT NULL THEN 'MERGED_ALIAS'
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
