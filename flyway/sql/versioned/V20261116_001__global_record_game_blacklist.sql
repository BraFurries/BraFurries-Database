-- Coddy record games blacklist becomes a single platform-wide policy.
-- The existing per-guild blacklisted_games table is kept as immutable legacy data
-- for rollback/forensics; no guild-specific records are deleted or rewritten.
-- Legacy names from all guilds are intentionally consolidated into one policy.
-- Rollout: Database -> Coddy global reads/slash fallback -> API -> Front -> retire slash.
CREATE TABLE record_global_blacklisted_games (
    id INT(11) NOT NULL AUTO_INCREMENT,
    game_name VARCHAR(50) NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uq_rgbg_game_name (game_name),
    CONSTRAINT ck_rgbg_name_nonempty CHECK (CHAR_LENGTH(TRIM(game_name)) > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Preserve prior exclusions: all distinct legacy values become globally excluded,
-- under case-insensitive utf8mb4_general_ci collation. Avoid placeholder/empty names.
INSERT IGNORE INTO record_global_blacklisted_games (game_name)
SELECT DISTINCT TRIM(game_name)
FROM blacklisted_games
WHERE game_name IS NOT NULL
  AND CHAR_LENGTH(TRIM(game_name)) > 0
  AND TRIM(game_name) <> '0';
