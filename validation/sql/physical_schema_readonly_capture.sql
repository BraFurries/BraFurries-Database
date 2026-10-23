-- BraFurries Database: read-only physical fingerprint export for HeidiSQL.
-- Open a connection to the intended schema first, verify SELECT DATABASE()
-- returns the expected schema, and export this SINGLE result grid to CSV.
-- CSV must include column headers, have two columns: section, metadata;
-- save it privately, outside Git, without user data or passwords.
-- READ-ONLY: accesses information_schema and server metadata ONLY.
-- Never run against an ambiguous default schema. Do NOT use production
-- connection info or credentials in repository files or GitHub Actions.
--
-- Note: each row is individually JSON-encoded (no JSON_ARRAYAGG), avoiding
-- group_concat_max_len truncation. No data rows or application tables queried.

SELECT 'tables' AS `section`,
  JSON_OBJECT('table',TABLE_NAME,'engine',ENGINE,
    'table_collation',TABLE_COLLATION,'row_format',ROW_FORMAT) AS `metadata`
FROM information_schema.TABLES
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_TYPE='BASE TABLE'
  AND TABLE_NAME<>'flyway_schema_history'
UNION ALL
SELECT 'columns',
  JSON_OBJECT('table',TABLE_NAME,'column',COLUMN_NAME,
    'position',ORDINAL_POSITION,'type',COLUMN_TYPE,
    'nullable',IS_NULLABLE,'default',COLUMN_DEFAULT,'extra',EXTRA,
    'expression',GENERATION_EXPRESSION,
    'charset',CHARACTER_SET_NAME,'collation',COLLATION_NAME)
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME<>'flyway_schema_history'
UNION ALL
SELECT 'indexes',
  JSON_OBJECT('table',TABLE_NAME,'index',INDEX_NAME,'sequence',SEQ_IN_INDEX,
    'column',COLUMN_NAME,'non_unique',NON_UNIQUE,'sub_part',SUB_PART,
    'index_type',INDEX_TYPE,'collation',COLLATION)
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME<>'flyway_schema_history'
UNION ALL
SELECT 'foreign_keys',
  JSON_OBJECT('table',k.TABLE_NAME,'constraint',k.CONSTRAINT_NAME,
    'position',k.ORDINAL_POSITION,'column',k.COLUMN_NAME,
    'referenced_table',k.REFERENCED_TABLE_NAME,
    'referenced_column',k.REFERENCED_COLUMN_NAME,
    'on_delete',r.DELETE_RULE,'on_update',r.UPDATE_RULE)
FROM information_schema.KEY_COLUMN_USAGE k
JOIN information_schema.REFERENTIAL_CONSTRAINTS r
  ON r.CONSTRAINT_SCHEMA=k.CONSTRAINT_SCHEMA
 AND r.CONSTRAINT_NAME=k.CONSTRAINT_NAME
 AND r.TABLE_NAME=k.TABLE_NAME
WHERE k.TABLE_SCHEMA=DATABASE()
  AND k.TABLE_NAME<>'flyway_schema_history'
  AND k.REFERENCED_TABLE_NAME IS NOT NULL
UNION ALL
SELECT 'checks',
  JSON_OBJECT('table',TABLE_NAME,'constraint',CONSTRAINT_NAME,
    'expression',CHECK_CLAUSE)
FROM information_schema.CHECK_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA=DATABASE()
  AND TABLE_NAME<>'flyway_schema_history'
UNION ALL
SELECT 'environment',
  JSON_OBJECT('mariadb_version',VERSION(),
    'schema_collation',
      (SELECT DEFAULT_COLLATION_NAME FROM information_schema.SCHEMATA
        WHERE SCHEMA_NAME=DATABASE()),
    'server_collation',@@collation_server);
