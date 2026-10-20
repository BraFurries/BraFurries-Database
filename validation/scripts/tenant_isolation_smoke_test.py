#!/usr/bin/env python3
"""Synthetic cross-guild schema/SQL contract smoke test; no production connections.

Database FK integrity is NOT application-level authorization. For unscoped
child identifiers and backup operation IDs, consumers must filter on guild.
"""
from __future__ import annotations

import sys
from smoke_test import (
    SmokeFailure, DATABASE_NAME, DATABASE_PASSWORD, DATABASE_USER,
    assert_no_resources_remain, compose, down, query, require_equal,
    safety_preflight, start_empty_database,
)

GUILD_A = 991001
GUILD_B = 991002


def execute(statement: str, *, check: bool = True):
    return compose(
        "exec", "--no-TTY", "mariadb", "mariadb",
        "--host=127.0.0.1", f"--user={DATABASE_USER}",
        f"--password={DATABASE_PASSWORD}", f"--database={DATABASE_NAME}",
        "--execute=" + statement, check=check,
    )


def expect_fk_rejection(statement: str, description: str) -> None:
    result = execute(statement, check=False)
    evidence = (result.stdout + "\n" + result.stderr).lower()
    if result.returncode == 0 or (
        "1452" not in evidence and "foreign key constraint fails" not in evidence
    ):
        raise SmokeFailure(
            f"{description}: expected cross-guild foreign-key rejection, "
            f"got exit code {result.returncode}"
        )
    print(f"PASS: {description} (FK rejects cross-guild reference)")


def require_count(statement: str, expected: int, description: str) -> None:
    require_equal(query(statement), str(expected), description)


def assert_theme_integrity() -> None:
    execute(
        "INSERT INTO discord_themes "
        "(id,guild_id,name,created_by_discord_user_id) VALUES "
        f"(93001,{GUILD_A},'Autumn',701),"
        f"(93002,{GUILD_B},'Winter',702)"
    )
    expect_fk_rejection(
        "INSERT INTO discord_theme_applications "
        "(id,theme_id,guild_id,actor_discord_user_id,frozen_definition_json) "
        f"VALUES (94003,93002,{GUILD_A},701,'{{}}')",
        "applications cannot attach a guild-B theme to guild A",
    )
    execute(
        "INSERT INTO discord_theme_applications "
        "(id,theme_id,guild_id,actor_discord_user_id,frozen_definition_json) VALUES "
        f"(94001,93001,{GUILD_A},701,'{{}}'),"
        f"(94002,93002,{GUILD_B},702,'{{}}')"
    )
    expect_fk_rejection(
        f"INSERT INTO discord_theme_active_guilds (guild_id,application_id) "
        f"VALUES ({GUILD_A},94002)",
        "active theme pointer cannot target another guild",
    )
    execute(
        "INSERT INTO discord_theme_active_guilds (guild_id,application_id) VALUES "
        f"({GUILD_A},94001),({GUILD_B},94002)"
    )
    expect_fk_rejection(
        "INSERT INTO discord_theme_operations "
        "(id,application_id,guild_id,operation_key,operation_type,actor_discord_user_id) "
        f"VALUES (95003,94002,{GUILD_A},'cross','APPLY',701)",
        "theme operations cannot reference another guild's application",
    )
    execute(
        "INSERT INTO discord_theme_operations "
        "(id,application_id,guild_id,operation_key,operation_type,actor_discord_user_id) VALUES "
        f"(95001,94001,{GUILD_A},'same-idempotency-key','APPLY',701),"
        f"(95002,94002,{GUILD_B},'same-idempotency-key','APPLY',702)"
    )
    require_count(
        "SELECT COUNT(*) FROM discord_theme_operations "
        "WHERE operation_key='same-idempotency-key'", 2,
        "theme idempotency keys are independent per guild",
    )
    expect_fk_rejection(
        "INSERT INTO discord_theme_operation_steps "
        "(guild_id,operation_id,step_code,step_status,message) "
        f"VALUES ({GUILD_A},95002,'stage','SUCCEEDED','synthetic')",
        "theme steps cannot claim another guild's operation",
    )
    execute(
        "INSERT INTO discord_theme_operation_steps "
        "(guild_id,operation_id,step_code,step_status,message) VALUES "
        f"({GUILD_A},95001,'stage','SUCCEEDED','synthetic'),"
        f"({GUILD_B},95002,'stage','SUCCEEDED','synthetic')"
    )
    expect_fk_rejection(
        "INSERT INTO discord_theme_guild_locks "
        "(guild_id,lock_token,operation_type,operation_id,application_id,expires_at) "
        f"VALUES ({GUILD_A},'cross','APPLY',95002,94002,UTC_TIMESTAMP()+INTERVAL 1 HOUR)",
        "theme mutex cannot lock another guild's operation",
    )
    execute(
        "INSERT INTO discord_theme_application_snapshots "
        "(application_id,resource_type,resource_discord_id) "
        "VALUES (94001,'ROLE',101),(94002,'ROLE',102)"
    )
    execute(
        "INSERT INTO discord_theme_resource_changes "
        "(theme_id,resource_type,resource_discord_id,target_name) "
        "VALUES (93001,'ROLE',101,'A'),(93002,'ROLE',102,'B')"
    )
    # These tables have NO guild_id: application authorization is on the parent.
    require_count(
        "SELECT COUNT(*) FROM discord_theme_application_snapshots s "
        "JOIN discord_theme_applications app ON app.id=s.application_id "
        f"WHERE app.guild_id={GUILD_A} AND s.application_id=94002",
        0, "snapshots require a guild-scoped parent join",
    )
    require_count(
        "SELECT COUNT(*) FROM discord_theme_application_snapshots s "
        "JOIN discord_theme_applications app ON app.id=s.application_id "
        f"WHERE app.guild_id={GUILD_A} AND s.application_id=94001",
        1, "authorized snapshot is visible for its guild",
    )
    require_count(
        "SELECT COUNT(*) FROM discord_theme_resource_changes rc "
        "JOIN discord_themes theme ON theme.id=rc.theme_id "
        f"WHERE theme.guild_id={GUILD_A} AND rc.theme_id=93002",
        0, "resource changes require guild-scoped theme authorization",
    )
    require_count(
        "SELECT COUNT(*) FROM discord_theme_resource_changes rc "
        "JOIN discord_themes theme ON theme.id=rc.theme_id "
        f"WHERE theme.guild_id={GUILD_A} AND rc.theme_id=93001",
        1, "authorized resource changes are visible for its guild",
    )
    require_count(
        "SELECT COUNT(*) FROM discord_theme_operation_steps "
        f"WHERE guild_id={GUILD_A} AND operation_id=95002",
        0, "theme progress query never returns steps from another guild",
    )


def assert_backup_contracts() -> None:
    execute(
        "INSERT INTO backup_discord (id,guild_id,backup_type) VALUES "
        f"(96001,{GUILD_A},'normal'),(96002,{GUILD_B},'normal')"
    )
    # There is intentionally no physical FK on backup_restore_operations.backup_id.
    # The API uses INSERT ... SELECT FROM backup_discord WHERE id=? AND guild_id=?.
    execute(
        "INSERT INTO backup_restore_operations "
        "(guild_id,backup_id,operation_key,scope,actor_discord_user_id) "
        "SELECT guild_id,id,'wrong-guild','full',701 FROM backup_discord "
        f"WHERE id=96002 AND guild_id={GUILD_A}"
    )
    require_count(
        "SELECT COUNT(*) FROM backup_restore_operations WHERE operation_key='wrong-guild'",
        0, "API-style guarded restore insert rejects cross-guild backup ID",
    )
    execute(
        "INSERT INTO backup_restore_operations "
        "(guild_id,backup_id,operation_key,scope,actor_discord_user_id) VALUES "
        f"({GUILD_A},96001,'same-restore-key','full',701),"
        f"({GUILD_B},96002,'same-restore-key','full',702)"
    )
    require_count(
        "SELECT COUNT(*) FROM backup_restore_operations "
        "WHERE operation_key='same-restore-key'", 2,
        "backup restore idempotency keys are independent per guild",
    )
    execute(
        "INSERT INTO backup_operation_steps "
        "(guild_id,operation_kind,operation_id,step_code,step_status,message) VALUES "
        f"({GUILD_A},'RESTORE',1,'restoring','RUNNING','synthetic'),"
        f"({GUILD_B},'RESTORE',2,'restoring','RUNNING','synthetic')"
    )
    # Polymorphic backup_operation_steps.operation_id has no FK. Guild filtering
    # is a required API/Coddy contract, not a database-enforced association.
    require_count(
        "SELECT COUNT(*) FROM backup_operation_steps "
        f"WHERE guild_id={GUILD_A} AND operation_kind='RESTORE' AND operation_id=2",
        0, "backup progress query filters by guild plus kind plus operation",
    )
    require_count(
        "SELECT COUNT(*) FROM backup_discord "
        f"WHERE guild_id={GUILD_A} AND id=96002",
        0, "backup listing never returns another guild's snapshot",
    )


def run() -> None:
    down()
    start_empty_database()
    compose(
        "run", "--rm", "--no-deps", "flyway",
        "-locations=filesystem:/flyway/baseline,filesystem:/flyway/official",
        "migrate",
    )
    require_count(
        "SELECT COUNT(*) FROM information_schema.TABLES "
        "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME<>'flyway_schema_history'",
        107, "tenant tests start from all 107 canonical schema tables",
    )
    assert_theme_integrity()
    assert_backup_contracts()


def main() -> int:
    result = 0
    preflight_accepted = False
    try:
        safety_preflight()
        preflight_accepted = True
        run()
    except SmokeFailure as error:
        print(f"Tenant isolation smoke failed: {error}", file=sys.stderr)
        result = 1
    finally:
        if preflight_accepted:
            down()
            try:
                assert_no_resources_remain()
            except SmokeFailure as error:
                print(f"Cleanup failed: {error}", file=sys.stderr)
                result = 1
    if not result:
        print("PASS: synthetic cross-guild schema and scoped-SQL contracts")
    return result


if __name__ == "__main__":
    raise SystemExit(main())
