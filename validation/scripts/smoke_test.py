#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
COMPOSE_FILE = REPOSITORY_ROOT / "validation" / "compose.yaml"
COMPOSE_ENV_FILE = REPOSITORY_ROOT / "validation" / "disposable-compose.env"
PROJECT_NAME = "brafurries_flyway_phase2"

MARIADB_IMAGE = "mariadb:10.6.28"
FLYWAY_IMAGE = "flyway/flyway:13.4.0"
DATABASE_NAME = "brf_flyway_smoke_test"
DATABASE_HOST = "mariadb"
DATABASE_USER = "brf_flyway_smoke"
DATABASE_PASSWORD = "brf_disposable_smoke_only"
FLYWAY_URL = f"jdbc:mariadb://{DATABASE_HOST}:3306/{DATABASE_NAME}"
SMOKE_SCRIPT = "V00000000_001__create_brf_flyway_smoke_test.sql"
IDENTITY_SCRIPT = "V20260924_001__create_user_identity_links.sql"
BUMP_SCRIPT = "V20260929_001__formalize_bump_configuration.sql"
LEDGER_SCRIPT = "V20260929_002__create_bump_monthly_reward_ledger.sql"
MEMBERSHIP_UNIQUE_SCRIPT = "V20260930_001__enforce_unique_user_community_status.sql"
TEAM_ASSIGNMENT_SCRIPT = "V20260930_002__create_community_team_role_assignments.sql"
IDENTITY_UNDIRECTED_SCRIPT = "V20260930_003__make_user_identity_links_undirected.sql"
BAN_EFFECT_SCRIPT = "V20261001_001__create_user_ban_discord_effects.sql"
COMMUNITY_AUTH_SCRIPT = "V20261001_002__create_community_authorization_foundation.sql"
COMMUNITY_MEMBER_NOTES_SCRIPT = "V20261001_003__create_community_member_notes.sql"
COMMUNITY_LIFECYCLE_SYNC_SCRIPT = "V20261002_001__add_community_lifecycle_and_network_sync.sql"
NETWORK_MEMBERSHIP_SCRIPT = "V20261002_002__add_network_member_state_and_events.sql"
XP_LEVELING_SCRIPT = "V20261004_001__formalize_xp_leveling_schema.sql"
SMOKE_TABLE = "__brf_flyway_smoke_test"

BUMP_SERVER_COLUMNS = {
    "bump_warn_enabled": ("tinyint(1)", "NO", "0"),
    "bump_warn_disboard_channel_id": ("bigint(20)", "YES", "NULL"),
    "bump_warn_target_channel_id": ("bigint(20)", "YES", "NULL"),
    "bump_warn_messages": ("text", "YES", "NULL"),
    "bump_warn_next_at": ("datetime", "YES", "NULL"),
    "bump_warn_last_bump_at": ("datetime", "YES", "NULL"),
    "bump_reward_enabled": ("tinyint(1)", "NO", "0"),
    "bump_reward_temp_role_id": ("bigint(20)", "YES", "NULL"),
    "bump_reward_role_minutes": ("int(11)", "NO", "0"),
    "bump_reward_coins": ("int(11)", "NO", "0"),
    "bump_reward_message": ("text", "YES", "NULL"),
    "bump_monthly_enabled": ("tinyint(1)", "NO", "0"),
    "bump_monthly_disboard_channel_id": ("bigint(20)", "YES", "NULL"),
    "bump_monthly_reward_role_id": ("bigint(20)", "YES", "NULL"),
    "bump_monthly_reward_days_1": ("int(11)", "NO", "21"),
    "bump_monthly_reward_days_2": ("int(11)", "NO", "14"),
    "bump_monthly_reward_days_3": ("int(11)", "NO", "7"),
    "bump_monthly_reward_coins_1": ("int(11)", "NO", "0"),
    "bump_monthly_reward_coins_2": ("int(11)", "NO", "0"),
    "bump_monthly_reward_coins_3": ("int(11)", "NO", "0"),
}

BUMP_ECONOMY_COLUMNS = {
    "bump_points": ("int(11)", "YES", "NULL"),
    "bump_reward_enabled": ("tinyint(1)", "NO", "0"),
}

MONTHLY_REWARD_RUN_COLUMNS = {
    "id": ("bigint(20)", "NO", "<NULL>"),
    "server_guild_id": ("bigint(20)", "NO", "<NULL>"),
    "period_start": ("date", "NO", "<NULL>"),
    "period_end": ("date", "NO", "<NULL>"),
    "source_channel_id": ("bigint(20)", "NO", "<NULL>"),
    "reward_role_id": ("bigint(20)", "YES", "NULL"),
    "reward_days_1": ("int(11)", "NO", "0"),
    "reward_days_2": ("int(11)", "NO", "0"),
    "reward_days_3": ("int(11)", "NO", "0"),
    "reward_coins_1": ("int(11)", "NO", "0"),
    "reward_coins_2": ("int(11)", "NO", "0"),
    "reward_coins_3": ("int(11)", "NO", "0"),
    "ranking_prepared_at": ("datetime", "YES", "NULL"),
    "attempt_count": ("int(11)", "NO", "0"),
    "last_attempt_at": ("datetime", "YES", "NULL"),
    "completed_at": ("datetime", "YES", "NULL"),
    "last_error": ("varchar(512)", "YES", "NULL"),
    "created_at": ("datetime", "NO", "current_timestamp()"),
    "updated_at": ("datetime", "NO", "current_timestamp()"),
}

MONTHLY_REWARD_GRANT_COLUMNS = {
    "id": ("bigint(20)", "NO", "<NULL>"),
    "run_id": ("bigint(20)", "NO", "<NULL>"),
    "discord_user_id": ("bigint(20)", "NO", "<NULL>"),
    "rank_position": ("tinyint(3) unsigned", "NO", "<NULL>"),
    "bump_count": ("int(10) unsigned", "NO", "<NULL>"),
    "first_bump_at": ("datetime", "YES", "NULL"),
    "coins_amount": ("int(10) unsigned", "NO", "0"),
    "role_id": ("bigint(20)", "YES", "NULL"),
    "role_days": ("int(10) unsigned", "NO", "0"),
    "role_expires_at": ("datetime", "YES", "NULL"),
    "coins_applied_at": ("datetime", "YES", "NULL"),
    "role_applied_at": ("datetime", "YES", "NULL"),
    "role_skipped_at": ("datetime", "YES", "NULL"),
    "notification_attempted_at": ("datetime", "YES", "NULL"),
    "notification_sent_at": ("datetime", "YES", "NULL"),
    "last_error": ("varchar(512)", "YES", "NULL"),
    "created_at": ("datetime", "NO", "current_timestamp()"),
    "updated_at": ("datetime", "NO", "current_timestamp()"),
}

FORBIDDEN_DATABASE_NAMES = {"coddy", "brafurries", "production", "prod"}
FORBIDDEN_ENVIRONMENT_KEYS = {
    "COMPOSE_FILE",
    "COMPOSE_PROJECT_NAME",
    "COMPOSE_PROFILES",
    "DATABASE_URL",
    "DB_HOST",
    "DB_NAME",
    "DOCKER_CONTEXT",
    "DOCKER_HOST",
    "FLYWAY_URL",
    "FLYWAY_USER",
    "FLYWAY_PASSWORD",
    "JDBC_URL",
    "MARIADB_DATABASE",
    "MARIADB_HOST",
    "MARIADB_USER",
    "MARIADB_PASSWORD",
    "MYSQL_DATABASE",
    "MYSQL_HOST",
    "MYSQL_USER",
    "MYSQL_PASSWORD",
}

COMPOSE_COMMAND = [
    "docker",
    "compose",
    "--env-file",
    str(COMPOSE_ENV_FILE),
    "--project-name",
    PROJECT_NAME,
    "--file",
    str(COMPOSE_FILE),
]


class SmokeFailure(RuntimeError):
    pass


def run_command(
    command: Sequence[str], *, check: bool = True, show_output: bool = True
) -> subprocess.CompletedProcess[str]:
    printable = " ".join(
        "--password=<synthetic>" if argument.startswith("--password=") else argument
        for argument in command
    )
    print(f"$ {printable}")
    try:
        result = subprocess.run(
            list(command),
            cwd=REPOSITORY_ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
    except FileNotFoundError as exc:
        raise SmokeFailure(f"required command is unavailable: {command[0]}") from exc

    if show_output:
        if result.stdout.strip():
            print(result.stdout.rstrip())
        if result.stderr.strip():
            print(result.stderr.rstrip(), file=sys.stderr)
    if check and result.returncode != 0:
        raise SmokeFailure(
            f"command failed with exit code {result.returncode}: {printable}"
        )
    return result


def compose(*arguments: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return run_command([*COMPOSE_COMMAND, *arguments], check=check)


def reject_environment_overrides() -> None:
    forbidden = sorted(
        key
        for key in os.environ
        if key.upper() in FORBIDDEN_ENVIRONMENT_KEYS or key.upper().startswith("PROD_")
    )
    if forbidden:
        names = ", ".join(forbidden)
        raise SmokeFailure(
            "refusing to run with connection/production-like environment variables set: "
            f"{names}. Values were not read or printed."
        )


def validate_local_docker_context() -> None:
    result = run_command(
        [
            "docker",
            "context",
            "inspect",
            "--format",
            "{{json .Endpoints.docker.Host}}",
        ],
        show_output=False,
    )
    try:
        endpoint = json.loads(result.stdout.strip())
    except json.JSONDecodeError as exc:
        raise SmokeFailure("unable to determine the active Docker endpoint") from exc
    if not isinstance(endpoint, str) or not endpoint.startswith(("unix://", "npipe://")):
        raise SmokeFailure(
            "active Docker context is not a local Unix socket or Windows named pipe"
        )
    print(f"Safety preflight accepted local Docker endpoint scheme: {endpoint.split(':', 1)[0]}")


def _environment(service: dict[str, Any]) -> dict[str, str]:
    environment = service.get("environment", {})
    if not isinstance(environment, dict):
        raise SmokeFailure("rendered Compose service environment is not a mapping")
    return {str(key): str(value) for key, value in environment.items()}


def validate_rendered_compose(config: dict[str, Any]) -> None:
    services = config.get("services")
    if not isinstance(services, dict) or set(services) != {"mariadb", "flyway"}:
        raise SmokeFailure("Compose must contain exactly the mariadb and flyway services")

    mariadb = services["mariadb"]
    flyway = services["flyway"]
    if mariadb.get("image") != MARIADB_IMAGE:
        raise SmokeFailure(f"MariaDB image must be pinned to {MARIADB_IMAGE}")
    if flyway.get("image") != FLYWAY_IMAGE:
        raise SmokeFailure(f"Flyway image must be pinned to {FLYWAY_IMAGE}")

    for service_name, service in services.items():
        if service.get("build"):
            raise SmokeFailure(f"{service_name}: local image builds are not allowed")
        if service.get("ports"):
            raise SmokeFailure(f"{service_name}: host port publication is forbidden")
        if service.get("network_mode") == "host":
            raise SmokeFailure(f"{service_name}: host networking is forbidden")
        if service.get("extra_hosts"):
            raise SmokeFailure(f"{service_name}: extra_hosts is forbidden")

    mariadb_environment = _environment(mariadb)
    expected_mariadb = {
        "MARIADB_DATABASE": DATABASE_NAME,
        "MARIADB_USER": DATABASE_USER,
        "MARIADB_PASSWORD": DATABASE_PASSWORD,
        "MARIADB_ROOT_PASSWORD": "brf_disposable_root_only",
    }
    if set(mariadb_environment) != set(expected_mariadb):
        raise SmokeFailure("mariadb: unexpected environment keys are forbidden")
    for key, expected in expected_mariadb.items():
        if mariadb_environment.get(key) != expected:
            raise SmokeFailure(f"mariadb: {key} must equal the disposable fixed value")

    flyway_environment = _environment(flyway)
    expected_flyway = {
        "FLYWAY_URL": FLYWAY_URL,
        "FLYWAY_USER": DATABASE_USER,
        "FLYWAY_PASSWORD": DATABASE_PASSWORD,
        "FLYWAY_DRIVER": "org.mariadb.jdbc.Driver",
        "FLYWAY_COLOR": "never",
    }
    if set(flyway_environment) != set(expected_flyway):
        raise SmokeFailure("flyway: unexpected environment keys are forbidden")
    for key, expected in expected_flyway.items():
        if flyway_environment.get(key) != expected:
            raise SmokeFailure(f"flyway: {key} must equal the disposable fixed value")

    if DATABASE_NAME.lower() in FORBIDDEN_DATABASE_NAMES:
        raise SmokeFailure("configured database name is forbidden")
    if not DATABASE_NAME.startswith("brf_") or not DATABASE_NAME.endswith("_test"):
        raise SmokeFailure("database name is not unambiguously test-only")
    if "coddy" in FLYWAY_URL.lower():
        raise SmokeFailure("production-like database name detected in Flyway URL")
    if not re.fullmatch(
        r"jdbc:mariadb://mariadb:3306/brf_flyway_smoke_test", FLYWAY_URL
    ):
        raise SmokeFailure("Flyway host/database target is not the fixed Compose service")

    networks = config.get("networks", {})
    if not isinstance(networks, dict) or not networks:
        raise SmokeFailure("Compose must define a private network")
    if not all(network.get("internal") is True for network in networks.values()):
        raise SmokeFailure("all Compose networks must be internal")

    tmpfs = mariadb.get("tmpfs", [])
    if not any(str(item).split(":", maxsplit=1)[0] == "/var/lib/mysql" for item in tmpfs):
        raise SmokeFailure("MariaDB data directory must use disposable tmpfs storage")


def safety_preflight() -> None:
    reject_environment_overrides()
    validate_local_docker_context()
    result = run_command(
        [*COMPOSE_COMMAND, "config", "--format", "json"], show_output=False
    )
    try:
        rendered = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise SmokeFailure("Docker Compose did not return valid JSON configuration") from exc
    validate_rendered_compose(rendered)
    print("Safety preflight passed: fixed internal host, test database, no published ports.")


def query(statement: str) -> str:
    result = compose(
        "exec",
        "--no-TTY",
        "mariadb",
        "mariadb",
        "--host=127.0.0.1",
        f"--user={DATABASE_USER}",
        f"--password={DATABASE_PASSWORD}",
        f"--database={DATABASE_NAME}",
        "--batch",
        "--skip-column-names",
        f"--execute={statement}",
    )
    return result.stdout.strip()


def require_equal(actual: str, expected: str, description: str) -> None:
    if actual != expected:
        raise SmokeFailure(f"{description}: expected {expected!r}, got {actual!r}")
    print(f"PASS: {description}")


def start_empty_database() -> None:
    compose("up", "--detach", "--wait", "--wait-timeout", "120", "mariadb")
    version = query("SELECT VERSION();")
    if not version.startswith("10.6.28-MariaDB"):
        raise SmokeFailure(f"expected MariaDB 10.6.28, got {version!r}")
    print(f"PASS: MariaDB version is {version}")
    require_equal(
        query(
            "SELECT COUNT(*) FROM information_schema.tables "
            "WHERE table_schema = DATABASE();"
        ),
        "0",
        "disposable application database starts empty",
    )


def assert_column(table: str, column: str, expected: tuple[str, str, str]) -> None:
    actual = query(
        "SELECT CONCAT(COLUMN_TYPE, '|', IS_NULLABLE, '|', "
        "COALESCE(COLUMN_DEFAULT, '<NULL>')) "
        "FROM information_schema.columns "
        f"WHERE table_schema = DATABASE() AND table_name = '{table}' "
        f"AND column_name = '{column}'"
    )
    require_equal(actual, "|".join(expected), f"{table}.{column} definition")


def assert_index(table: str, index: str, expected_non_unique: str, expected_columns: str) -> None:
    actual = query(
        "SELECT CONCAT(MIN(NON_UNIQUE), '|', "
        "GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX SEPARATOR ',')) "
        "FROM information_schema.statistics "
        f"WHERE table_schema = DATABASE() AND table_name = '{table}' "
        f"AND index_name = '{index}'"
    )
    require_equal(actual, f"{expected_non_unique}|{expected_columns}", f"{table}.{index} index")


def assert_table_exists(table: str) -> None:
    require_equal(
        query(
            "SELECT COUNT(*) FROM information_schema.tables "
            f"WHERE table_schema = DATABASE() AND table_name = '{table}'"
        ),
        "1",
        f"{table} exists",
    )


def assert_column_extra(table: str, column: str, expected: str) -> None:
    actual = query(
        "SELECT EXTRA FROM information_schema.columns "
        f"WHERE table_schema = DATABASE() AND table_name = '{table}' "
        f"AND column_name = '{column}'"
    )
    require_equal(actual, expected, f"{table}.{column} extra")


def assert_foreign_key(
    table: str,
    constraint: str,
    referenced_table: str,
    referenced_column: str,
    delete_rule: str,
    update_rule: str,
) -> None:
    actual = query(
        "SELECT CONCAT(kcu.REFERENCED_TABLE_NAME, '|', kcu.REFERENCED_COLUMN_NAME, "
        "'|', rc.DELETE_RULE, '|', rc.UPDATE_RULE) "
        "FROM information_schema.key_column_usage AS kcu "
        "JOIN information_schema.referential_constraints AS rc "
        "ON rc.constraint_schema = kcu.constraint_schema "
        "AND rc.constraint_name = kcu.constraint_name "
        "AND rc.table_name = kcu.table_name "
        f"WHERE kcu.constraint_schema = DATABASE() AND kcu.table_name = '{table}' "
        f"AND kcu.constraint_name = '{constraint}'"
    )
    require_equal(
        actual,
        f"{referenced_table}|{referenced_column}|{delete_rule}|{update_rule}",
        f"{table}.{constraint} foreign key",
    )


def assert_membership_uniqueness() -> None:
    assert_table_exists("user_community_status")
    assert_index(
        "user_community_status",
        "uk_user_community_status_community_user",
        "0",
        "community_id,user_id",
    )


def assert_identity_link_schema() -> None:
    assert_column("user_identity_links", "user_a_id", ("int(11)", "NO", "<NULL>"))
    assert_column("user_identity_links", "user_b_id", ("int(11)", "NO", "<NULL>"))
    assert_column("user_identity_links", "active_user_low_id", ("int(11)", "YES", "NULL"))
    assert_column("user_identity_links", "active_user_high_id", ("int(11)", "YES", "NULL"))
    assert_column_extra("user_identity_links", "active_user_low_id", "STORED GENERATED")
    assert_column_extra("user_identity_links", "active_user_high_id", "STORED GENERATED")
    require_equal(
        query(
            "SELECT COUNT(*) FROM information_schema.columns "
            "WHERE table_schema = DATABASE() AND table_name = 'user_identity_links' "
            "AND column_name IN ('primary_user_id', 'linked_user_id', 'active_linked_user_id')"
        ),
        "0",
        "retired identity hierarchy columns are absent",
    )
    assert_index(
        "user_identity_links",
        "uk_user_identity_links_active_pair",
        "0",
        "active_user_low_id,active_user_high_id",
    )
    assert_index(
        "user_identity_links",
        "idx_user_identity_links_user_a_active",
        "1",
        "user_a_id,revoked_at",
    )
    assert_index(
        "user_identity_links",
        "idx_user_identity_links_user_b_active",
        "1",
        "user_b_id,revoked_at",
    )
    assert_check_constraint("user_identity_links", "chk_user_identity_links_distinct_users")
    assert_check_constraint("user_identity_links", "chk_user_identity_links_status")
    assert_check_constraint("user_identity_links", "chk_user_identity_links_source")
    assert_foreign_key(
        "user_identity_links",
        "fk_user_identity_links_user_a",
        "users",
        "id",
        "RESTRICT",
        "RESTRICT",
    )
    assert_foreign_key(
        "user_identity_links",
        "fk_user_identity_links_user_b",
        "users",
        "id",
        "RESTRICT",
        "RESTRICT",
    )


def assert_user_ban_effect_schema() -> None:
    table = "user_ban_discord_effects"
    assert_table_exists(table)
    for column, expected in {
        "id": ("bigint(20) unsigned", "NO", "<NULL>"),
        "ban_id": ("int(11)", "NO", "<NULL>"),
        "identity_user_id": ("int(11)", "NO", "<NULL>"),
        "discord_user_id": ("bigint(20)", "NO", "<NULL>"),
        "is_origin": ("tinyint(1)", "NO", "0"),
        "outcome": ("varchar(32)", "NO", "<NULL>"),
        "error_code": ("varchar(64)", "YES", "NULL"),
        "attempted_at": ("datetime(6)", "NO", "current_timestamp(6)"),
        "reverted_at": ("datetime(6)", "YES", "NULL"),
        "revert_outcome": ("varchar(32)", "YES", "NULL"),
    }.items():
        assert_column(table, column, expected)
    assert_column_extra(table, "id", "auto_increment")
    assert_index(table, "uq_user_ban_effect_ban_discord", "0", "ban_id,discord_user_id")
    assert_foreign_key(table, "fk_user_ban_effect_ban", "user_bans", "id", "CASCADE", "RESTRICT")
    assert_foreign_key(table, "fk_user_ban_effect_identity_user", "users", "id", "RESTRICT", "RESTRICT")
    assert_check_constraint(table, "ck_user_ban_effect_outcome")
    assert_check_constraint(table, "ck_user_ban_effect_revert_outcome")



def assert_community_authorization_schema() -> None:
    assert_column("communities", "owner_user_id", ("int(11)", "YES", "NULL"))
    assert_index("communities", "idx_communities_owner_user", "1", "owner_user_id")
    assert_foreign_key(
        "communities",
        "fk_communities_owner_user",
        "users",
        "id",
        "RESTRICT",
        "RESTRICT",
    )

    for table in (
        "community_team_role_capabilities",
        "community_user_capability_grants",
        "community_audit_log",
    ):
        assert_table_exists(table)

    for column, expected in {
        "community_id": ("int(11)", "NO", "<NULL>"),
        "role_id": ("int(11)", "NO", "<NULL>"),
        "capability": ("varchar(64)", "NO", "<NULL>"),
        "granted_by_user_id": ("int(11)", "NO", "<NULL>"),
        "created_at": ("datetime(6)", "NO", "current_timestamp(6)"),
    }.items():
        assert_column("community_team_role_capabilities", column, expected)
    assert_index(
        "community_team_role_capabilities",
        "PRIMARY",
        "0",
        "community_id,role_id,capability",
    )
    assert_index(
        "community_team_role_capabilities",
        "idx_ctrc_grantor",
        "1",
        "granted_by_user_id,created_at",
    )
    role_cap_fk_columns = query(
        "SELECT GROUP_CONCAT(CONCAT(kcu.COLUMN_NAME, '->', kcu.REFERENCED_COLUMN_NAME) "
        "ORDER BY kcu.ORDINAL_POSITION SEPARATOR ',') "
        "FROM information_schema.key_column_usage AS kcu "
        "WHERE kcu.constraint_schema = DATABASE() "
        "AND kcu.table_name = 'community_team_role_capabilities' "
        "AND kcu.constraint_name = 'fk_ctrc_role_same_community'"
    )
    require_equal(
        role_cap_fk_columns,
        "community_id->community_id,role_id->id",
        "role capability FK is tenant-aware",
    )
    assert_foreign_key(
        "community_team_role_capabilities",
        "fk_ctrc_grantor",
        "users",
        "id",
        "RESTRICT",
        "RESTRICT",
    )

    for column, expected in {
        "community_id": ("int(11)", "NO", "<NULL>"),
        "user_id": ("int(11)", "NO", "<NULL>"),
        "capability": ("varchar(64)", "NO", "<NULL>"),
        "granted_by_user_id": ("int(11)", "NO", "<NULL>"),
        "created_at": ("datetime(6)", "NO", "current_timestamp(6)"),
    }.items():
        assert_column("community_user_capability_grants", column, expected)
    assert_index(
        "community_user_capability_grants",
        "PRIMARY",
        "0",
        "community_id,user_id,capability",
    )
    direct_fk_columns = query(
        "SELECT GROUP_CONCAT(CONCAT(kcu.COLUMN_NAME, '->', kcu.REFERENCED_COLUMN_NAME) "
        "ORDER BY kcu.ORDINAL_POSITION SEPARATOR ',') "
        "FROM information_schema.key_column_usage AS kcu "
        "WHERE kcu.constraint_schema = DATABASE() "
        "AND kcu.table_name = 'community_user_capability_grants' "
        "AND kcu.constraint_name = 'fk_cucg_member_same_community'"
    )
    require_equal(
        direct_fk_columns,
        "community_id->community_id,user_id->user_id",
        "direct capability grant FK is tenant-aware",
    )
    assert_foreign_key(
        "community_user_capability_grants",
        "fk_cucg_grantor",
        "users",
        "id",
        "RESTRICT",
        "RESTRICT",
    )

    for column, expected in {
        "id": ("bigint(20) unsigned", "NO", "<NULL>"),
        "community_id": ("int(11)", "NO", "<NULL>"),
        "actor_user_id": ("int(11)", "NO", "<NULL>"),
        "action": ("varchar(64)", "NO", "<NULL>"),
        "target_type": ("varchar(64)", "YES", "NULL"),
        "target_id": ("varchar(128)", "YES", "NULL"),
        "metadata": ("longtext", "YES", "NULL"),
        "created_at": ("datetime(6)", "NO", "current_timestamp(6)"),
    }.items():
        assert_column("community_audit_log", column, expected)
    assert_column_extra("community_audit_log", "id", "auto_increment")
    assert_index(
        "community_audit_log",
        "idx_cal_community_created",
        "1",
        "community_id,created_at,id",
    )
    assert_index(
        "community_audit_log",
        "idx_cal_actor_created",
        "1",
        "actor_user_id,created_at",
    )
    assert_foreign_key(
        "community_audit_log",
        "fk_cal_community",
        "communities",
        "id",
        "RESTRICT",
        "RESTRICT",
    )
    assert_foreign_key(
        "community_audit_log",
        "fk_cal_actor",
        "users",
        "id",
        "RESTRICT",
        "RESTRICT",
    )




def assert_community_member_notes_schema() -> None:
    table = "community_member_notes"
    assert_table_exists(table)
    for column, expected in {
        "id": ("bigint(20) unsigned", "NO", "<NULL>"),
        "community_id": ("int(11)", "NO", "<NULL>"),
        "user_id": ("int(11)", "NO", "<NULL>"),
        "author_user_id": ("int(11)", "NO", "<NULL>"),
        "updated_by_user_id": ("int(11)", "NO", "<NULL>"),
        "content": ("text", "NO", "<NULL>"),
        "created_at": ("datetime(6)", "NO", "current_timestamp(6)"),
        "updated_at": ("datetime(6)", "NO", "current_timestamp(6)"),
        "archived_at": ("datetime(6)", "YES", "NULL"),
    }.items():
        assert_column(table, column, expected)
    assert_column_extra(table, "id", "auto_increment")
    assert_index(
        table,
        "idx_cmn_member_archive_created",
        "1",
        "community_id,user_id,archived_at,created_at,id",
    )
    assert_index(table, "idx_cmn_author_created", "1", "author_user_id,created_at")
    assert_index(table, "idx_cmn_updated_by", "1", "updated_by_user_id")

    member_fk_columns = query(
        "SELECT GROUP_CONCAT(CONCAT(kcu.COLUMN_NAME, '->', kcu.REFERENCED_COLUMN_NAME) "
        "ORDER BY kcu.ORDINAL_POSITION SEPARATOR ',') "
        "FROM information_schema.key_column_usage AS kcu "
        "WHERE kcu.constraint_schema = DATABASE() "
        "AND kcu.table_name = 'community_member_notes' "
        "AND kcu.constraint_name = 'fk_cmn_member_same_community'"
    )
    require_equal(
        member_fk_columns,
        "community_id->community_id,user_id->user_id",
        "Community member note FK is tenant-aware",
    )
    assert_foreign_key(
        table,
        "fk_cmn_author",
        "users",
        "id",
        "RESTRICT",
        "RESTRICT",
    )
    assert_foreign_key(
        table,
        "fk_cmn_updated_by",
        "users",
        "id",
        "RESTRICT",
        "RESTRICT",
    )

def assert_community_lifecycle_sync_schema() -> None:
    assert_column("portaria_base_config", "portaria_enabled", ("tinyint(1)", "NO", "0"))
    require_equal(
        query(
            "SELECT CONCAT(formulario_portaria_ativo, '|', portaria_enabled) "
            "FROM portaria_base_config WHERE id = 77"
        ),
        "0|0",
        "unconfigured legacy base row remains disabled regardless of form flag",
    )
    require_equal(
        query(
            "SELECT CONCAT(formulario_portaria_ativo, '|', portaria_enabled) "
            "FROM portaria_base_config WHERE id = 78"
        ),
        "1|1",
        "legacy Community with a Portaria flow is preserved as enabled",
    )
    assert_column("user_community_status", "approval_required", ("tinyint(1)", "YES", "NULL"))
    assert_column("user_community_status", "display_name", ("varchar(100)", "YES", "NULL"))
    require_equal(
        query(
            "SELECT CONCAT_WS('|', DATE_FORMAT(member_since, '%Y-%m-%d %H:%i:%s'), "
            "IF(approval_required IS NULL, 'NULL', approval_required), "
            "IF(display_name IS NULL, 'NULL', display_name)) "
            "FROM user_community_status WHERE id = 77"
        ),
        "2026-01-01 00:00:00|NULL|NULL",
        "legacy membership history and unknown approval applicability remain unchanged",
    )

    table = "community_network_sync_runs"
    assert_table_exists(table)
    for column, expected in {
        "id": ("bigint(20) unsigned", "NO", "<NULL>"),
        "community_id": ("int(11)", "NO", "<NULL>"),
        "network_type": ("varchar(32)", "NO", "<NULL>"),
        "external_network_id": ("bigint(20)", "NO", "<NULL>"),
        "trigger": ("varchar(32)", "NO", "<NULL>"),
        "status": ("varchar(16)", "NO", "'QUEUED'"),
        "started_at": ("datetime(6)", "YES", "NULL"),
        "completed_at": ("datetime(6)", "YES", "NULL"),
        "observed_members": ("int(10) unsigned", "YES", "NULL"),
        "updated_members": ("int(10) unsigned", "YES", "NULL"),
        "error_code": ("varchar(64)", "YES", "NULL"),
    }.items():
        assert_column(table, column, expected)
    assert_column_extra(table, "id", "auto_increment")
    assert_index(table, "idx_cnsr_community_network", "1", "community_id,network_type,external_network_id")
    assert_index(table, "idx_cnsr_community_status_started", "1", "community_id,status,started_at")
    assert_index(table, "idx_cnsr_network_status_id", "1", "network_type,status,id")
    assert_foreign_key(table, "fk_cnsr_community", "communities", "id", "RESTRICT", "RESTRICT")
    assert_check_constraint(table, "ck_cnsr_trigger")
    assert_check_constraint(table, "ck_cnsr_status")
    assert_check_constraint(table, "ck_cnsr_observed_members")
    assert_check_constraint(table, "ck_cnsr_updated_members")


def assert_network_membership_schema() -> None:
    assert_column(
        "community_discord",
        "membership_sync_state",
        ("varchar(32)", "NO", "'RECONCILIATION_REQUIRED'"),
    )
    assert_column(
        "community_discord",
        "last_full_reconciliation_at",
        ("datetime(6)", "YES", "NULL"),
    )
    assert_column(
        "community_discord",
        "last_membership_event_at",
        ("datetime(6)", "YES", "NULL"),
    )
    assert_check_constraint(
        "community_discord",
        "ck_community_discord_membership_sync_state",
    )

    state = "community_network_member_status"
    assert_table_exists(state)
    for column, expected in {
        "id": ("bigint(20) unsigned", "NO", "<NULL>"),
        "community_id": ("int(11)", "NO", "<NULL>"),
        "network_type": ("varchar(32)", "NO", "<NULL>"),
        "external_network_id": ("bigint(20)", "NO", "<NULL>"),
        "user_id": ("int(11)", "NO", "<NULL>"),
        "is_present": ("tinyint(1)", "NO", "0"),
        "first_known_join_at": ("datetime(6)", "YES", "NULL"),
        "first_known_join_source": ("varchar(32)", "YES", "NULL"),
        "last_join_at": ("datetime(6)", "YES", "NULL"),
        "last_join_source": ("varchar(32)", "YES", "NULL"),
        "current_presence_since": ("datetime(6)", "YES", "NULL"),
        "left_at": ("datetime(6)", "YES", "NULL"),
        "last_observed_at": ("datetime(6)", "NO", "current_timestamp(6)"),
        "last_sync_run_id": ("bigint(20) unsigned", "YES", "NULL"),
        "approval_required": ("tinyint(1)", "YES", "NULL"),
        "approved": ("tinyint(1)", "YES", "NULL"),
        "approved_at": ("datetime(6)", "YES", "NULL"),
        "display_name": ("varchar(100)", "YES", "NULL"),
        "created_at": ("datetime(6)", "NO", "current_timestamp(6)"),
        "updated_at": ("datetime(6)", "NO", "current_timestamp(6)"),
    }.items():
        assert_column(state, column, expected)
    assert_column_extra(state, "id", "auto_increment")
    assert_index(
        state,
        "uk_cnms_network_user",
        "0",
        "network_type,external_network_id,user_id",
    )
    assert_index(
        state,
        "idx_cnms_community_user_present",
        "1",
        "community_id,user_id,is_present",
    )
    assert_index(
        state,
        "idx_cnms_network_present_user",
        "1",
        "network_type,external_network_id,is_present,user_id",
    )
    assert_index(
        state,
        "idx_cnms_network_sync",
        "1",
        "network_type,external_network_id,last_sync_run_id,is_present",
    )
    assert_foreign_key(
        state, "fk_cnms_community", "communities", "id", "RESTRICT", "RESTRICT"
    )
    assert_foreign_key(
        state, "fk_cnms_user", "users", "id", "RESTRICT", "RESTRICT"
    )
    assert_foreign_key(
        state,
        "fk_cnms_last_sync_run",
        "community_network_sync_runs",
        "id",
        "SET NULL",
        "RESTRICT",
    )

    events = "community_network_member_events"
    assert_table_exists(events)
    assert_column(events, "event_type", ("varchar(32)", "NO", "<NULL>"))
    assert_column(events, "occurred_at", ("datetime(6)", "NO", "<NULL>"))
    assert_column(events, "observed_at", ("datetime(6)", "NO", "current_timestamp(6)"))
    assert_column(events, "source", ("varchar(32)", "NO", "<NULL>"))
    assert_column(events, "sync_run_id", ("bigint(20) unsigned", "YES", "NULL"))
    assert_index(
        events,
        "idx_cnme_network_user_time",
        "1",
        "network_type,external_network_id,user_id,occurred_at,id",
    )
    assert_index(
        events,
        "idx_cnme_community_user_time",
        "1",
        "community_id,user_id,occurred_at,id",
    )
    assert_foreign_key(
        events, "fk_cnme_community", "communities", "id", "RESTRICT", "RESTRICT"
    )
    assert_foreign_key(
        events, "fk_cnme_user", "users", "id", "RESTRICT", "RESTRICT"
    )
    assert_foreign_key(
        events,
        "fk_cnme_sync_run",
        "community_network_sync_runs",
        "id",
        "SET NULL",
        "RESTRICT",
    )


def assert_team_role_assignment_schema() -> None:
    assert_table_exists("community_team_role_assignments")
    for column, expected in {
        "community_id": ("int(11)", "NO", "<NULL>"),
        "role_id": ("int(11)", "NO", "<NULL>"),
        "user_id": ("int(11)", "NO", "<NULL>"),
        "created_at": ("datetime(6)", "NO", "current_timestamp(6)"),
    }.items():
        assert_column("community_team_role_assignments", column, expected)

    assert_index(
        "community_team_role_assignments",
        "PRIMARY",
        "0",
        "community_id,role_id,user_id",
    )
    assert_index(
        "community_team_role_assignments",
        "idx_ctra_community_user",
        "1",
        "community_id,user_id",
    )
    role_fk_columns = query(
        "SELECT GROUP_CONCAT(CONCAT(kcu.COLUMN_NAME, '->', kcu.REFERENCED_COLUMN_NAME) "
        "ORDER BY kcu.ORDINAL_POSITION SEPARATOR ',') "
        "FROM information_schema.key_column_usage AS kcu "
        "WHERE kcu.constraint_schema = DATABASE() "
        "AND kcu.table_name = 'community_team_role_assignments' "
        "AND kcu.constraint_name = 'fk_ctra_role_same_community'"
    )
    require_equal(
        role_fk_columns,
        "community_id->community_id,role_id->id",
        "team assignment role FK is tenant-aware",
    )
    role_fk_rules = query(
        "SELECT CONCAT(kcu.REFERENCED_TABLE_NAME, '|', rc.DELETE_RULE, '|', rc.UPDATE_RULE) "
        "FROM information_schema.key_column_usage AS kcu "
        "JOIN information_schema.referential_constraints AS rc "
        "ON rc.constraint_schema = kcu.constraint_schema "
        "AND rc.constraint_name = kcu.constraint_name "
        "AND rc.table_name = kcu.table_name "
        "WHERE kcu.constraint_schema = DATABASE() "
        "AND kcu.table_name = 'community_team_role_assignments' "
        "AND kcu.constraint_name = 'fk_ctra_role_same_community' "
        "LIMIT 1"
    )
    require_equal(
        role_fk_rules,
        "community_team_roles|RESTRICT|RESTRICT",
        "team assignment role FK blocks implicit deletion",
    )
    member_fk_columns = query(
        "SELECT GROUP_CONCAT(CONCAT(kcu.COLUMN_NAME, '->', kcu.REFERENCED_COLUMN_NAME) "
        "ORDER BY kcu.ORDINAL_POSITION SEPARATOR ',') "
        "FROM information_schema.key_column_usage AS kcu "
        "WHERE kcu.constraint_schema = DATABASE() "
        "AND kcu.table_name = 'community_team_role_assignments' "
        "AND kcu.constraint_name = 'fk_ctra_member_same_community'"
    )
    require_equal(
        member_fk_columns,
        "community_id->community_id,user_id->user_id",
        "team assignment member FK is tenant-aware",
    )
    member_fk_rules = query(
        "SELECT CONCAT(kcu.REFERENCED_TABLE_NAME, '|', rc.DELETE_RULE, '|', rc.UPDATE_RULE) "
        "FROM information_schema.key_column_usage AS kcu "
        "JOIN information_schema.referential_constraints AS rc "
        "ON rc.constraint_schema = kcu.constraint_schema "
        "AND rc.constraint_name = kcu.constraint_name "
        "AND rc.table_name = kcu.table_name "
        "WHERE kcu.constraint_schema = DATABASE() "
        "AND kcu.table_name = 'community_team_role_assignments' "
        "AND kcu.constraint_name = 'fk_ctra_member_same_community' "
        "LIMIT 1"
    )
    require_equal(
        member_fk_rules,
        "user_community_status|RESTRICT|RESTRICT",
        "team assignment member FK blocks cross-tenant/non-member links",
    )

def assert_check_constraint(table: str, constraint: str) -> None:
    actual = query(
        "SELECT CONSTRAINT_TYPE FROM information_schema.table_constraints "
        f"WHERE constraint_schema = DATABASE() AND table_name = '{table}' "
        f"AND constraint_name = '{constraint}'"
    )
    require_equal(actual, "CHECK", f"{table}.{constraint} check constraint")


def assert_bump_schema() -> None:
    require_equal(
        query(
            "SELECT COUNT(*) FROM information_schema.tables "
            "WHERE table_schema = DATABASE() AND table_name = 'allowed_feature_channels'"
        ),
        "1",
        "allowed_feature_channels exists",
    )
    for column, expected in {
        "server_guild_id": ("bigint(20)", "NO", "<NULL>"),
        "feature_key": ("varchar(100)", "NO", "<NULL>"),
        "channel_id": ("bigint(20)", "NO", "<NULL>"),
        "created_at": ("timestamp", "NO", "current_timestamp()"),
    }.items():
        assert_column("allowed_feature_channels", column, expected)
    require_equal(
        query(
            "SELECT EXTRA FROM information_schema.columns "
            "WHERE table_schema = DATABASE() AND table_name = 'allowed_feature_channels' "
            "AND column_name = 'id'"
        ),
        "auto_increment",
        "allowed_feature_channels.id is AUTO_INCREMENT",
    )
    assert_index("allowed_feature_channels", "PRIMARY", "0", "id")
    assert_index("allowed_feature_channels", "uq_allowed_feature_channels", "0", "server_guild_id,feature_key,channel_id")
    assert_index("allowed_feature_channels", "idx_allowed_feature_channels_lookup", "1", "server_guild_id,feature_key")

    for column, expected in BUMP_SERVER_COLUMNS.items():
        assert_column("config_server_settings", column, expected)
    for column, expected in BUMP_ECONOMY_COLUMNS.items():
        assert_column("config_economy", column, expected)


def assert_bump_monthly_reward_ledger_schema() -> None:
    assert_table_exists("bump_monthly_reward_runs")
    assert_table_exists("bump_monthly_reward_grants")

    for column, expected in MONTHLY_REWARD_RUN_COLUMNS.items():
        assert_column("bump_monthly_reward_runs", column, expected)
    for column, expected in MONTHLY_REWARD_GRANT_COLUMNS.items():
        assert_column("bump_monthly_reward_grants", column, expected)

    assert_column_extra("bump_monthly_reward_runs", "id", "auto_increment")
    assert_column_extra("bump_monthly_reward_grants", "id", "auto_increment")
    assert_column_extra(
        "bump_monthly_reward_runs", "updated_at", "on update current_timestamp()"
    )
    assert_column_extra(
        "bump_monthly_reward_grants", "updated_at", "on update current_timestamp()"
    )

    assert_index("bump_monthly_reward_runs", "PRIMARY", "0", "id")
    assert_index(
        "bump_monthly_reward_runs",
        "uq_bump_monthly_reward_runs_guild_period",
        "0",
        "server_guild_id,period_start",
    )
    assert_index(
        "bump_monthly_reward_runs",
        "idx_bump_monthly_reward_runs_guild_completed",
        "1",
        "server_guild_id,completed_at",
    )
    assert_index(
        "bump_monthly_reward_runs",
        "idx_bump_monthly_reward_runs_period_start",
        "1",
        "period_start",
    )
    assert_index("bump_monthly_reward_grants", "PRIMARY", "0", "id")
    assert_index(
        "bump_monthly_reward_grants",
        "uq_bump_monthly_reward_grants_run_rank",
        "0",
        "run_id,rank_position",
    )
    assert_index(
        "bump_monthly_reward_grants",
        "uq_bump_monthly_reward_grants_run_user",
        "0",
        "run_id,discord_user_id",
    )
    assert_index(
        "bump_monthly_reward_grants",
        "idx_bump_monthly_reward_grants_run",
        "1",
        "run_id",
    )

    assert_foreign_key(
        "bump_monthly_reward_runs",
        "fk_bump_monthly_reward_runs_guild",
        "community_discord",
        "guild_id",
        "NO ACTION",
        "NO ACTION",
    )
    assert_check_constraint(
        "bump_monthly_reward_runs",
        "ck_bump_monthly_reward_runs_calendar_period",
    )
    assert_check_constraint(
        "bump_monthly_reward_grants",
        "ck_bump_monthly_reward_grants_rank_position",
    )
    assert_foreign_key(
        "bump_monthly_reward_grants",
        "fk_bump_monthly_reward_grants_run",
        "bump_monthly_reward_runs",
        "id",
        "CASCADE",
        "NO ACTION",
    )


def migrate_pre_bump_history() -> None:
    """Apply the real pre-Bump history in an otherwise empty disposable database."""
    shell_command = (
        "set -eu; "
        "mkdir -p /tmp/brf-pre-bump; "
        f"cp /flyway/sql/{SMOKE_SCRIPT} /tmp/brf-pre-bump/{SMOKE_SCRIPT}; "
        f"cp /flyway/official/{IDENTITY_SCRIPT} /tmp/brf-pre-bump/{IDENTITY_SCRIPT}; "
        "/flyway/flyway -configFiles=/flyway/conf/flyway.conf "
        "-locations=filesystem:/tmp/brf-pre-bump migrate"
    )
    compose(
        "run",
        "--rm",
        "--no-deps",
        "--entrypoint",
        "/bin/sh",
        "flyway",
        "-c",
        shell_command,
    )


def assert_pre_bump_history() -> None:
    require_equal(
        query(
            "SELECT COUNT(*) FROM information_schema.tables "
            "WHERE table_schema = DATABASE() AND table_name = 'flyway_schema_history';"
        ),
        "1",
        "pre-Bump flyway_schema_history exists",
    )
    for script, expected, description in (
        (SMOKE_SCRIPT, "1", "one successful pre-Bump fixture history row exists"),
        (IDENTITY_SCRIPT, "1", "one successful pre-Bump identity history row exists"),
        (BUMP_SCRIPT, "0", "no successful Bump migration history row exists yet"),
        (LEDGER_SCRIPT, "0", "no successful monthly reward ledger history row exists yet"),
        (MEMBERSHIP_UNIQUE_SCRIPT, "0", "no successful membership uniqueness history row exists yet"),
        (TEAM_ASSIGNMENT_SCRIPT, "0", "no successful team assignment migration history row exists yet"),
        (IDENTITY_UNDIRECTED_SCRIPT, "0", "no successful undirected identity migration history row exists yet"),
        (BAN_EFFECT_SCRIPT, "0", "no successful ban-effect migration history row exists yet"),
        (COMMUNITY_AUTH_SCRIPT, "0", "no successful Community authorization migration history row exists yet"),
        (COMMUNITY_MEMBER_NOTES_SCRIPT, "0", "no successful Community member notes migration history row exists yet"),
        (COMMUNITY_LIFECYCLE_SYNC_SCRIPT, "0", "no successful Community lifecycle migration history row exists yet"),
        (NETWORK_MEMBERSHIP_SCRIPT, "0", "no successful network membership migration history row exists yet"),
        (XP_LEVELING_SCRIPT, "0", "no successful XP/leveling migration history row exists yet"),
    ):
        require_equal(
            query(
                "SELECT COUNT(*) FROM flyway_schema_history "
                f"WHERE success = 1 AND script = '{script}';"
            ),
            expected,
            description,
        )


def prepare_existing_bump_schema() -> None:
    """Add observed Bump legacy structures after the pre-Bump Flyway history."""
    query(
        "CREATE TABLE allowed_feature_channels ("
        "id INT(11) NOT NULL AUTO_INCREMENT, "
        "server_guild_id BIGINT(20) NOT NULL, "
        "feature_key VARCHAR(100) NOT NULL, "
        "channel_id BIGINT(20) NOT NULL, "
        "created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, "
        "PRIMARY KEY (id), "
        "UNIQUE KEY uq_allowed_feature_channels (server_guild_id, feature_key, channel_id), "
        "KEY idx_allowed_feature_channels_lookup (server_guild_id, feature_key)"
        ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci"
    )
    server_columns = ", ".join(
        f"ADD COLUMN {name} {definition}"
        for name, definition in (
            ("bump_warn_enabled", "TINYINT(1) NOT NULL DEFAULT 0"),
            ("bump_warn_disboard_channel_id", "BIGINT(20) NULL DEFAULT NULL"),
            ("bump_warn_target_channel_id", "BIGINT(20) NULL DEFAULT NULL"),
            ("bump_warn_messages", "TEXT NULL DEFAULT NULL"),
            ("bump_warn_next_at", "DATETIME NULL DEFAULT NULL"),
            ("bump_warn_last_bump_at", "DATETIME NULL DEFAULT NULL"),
            ("bump_reward_enabled", "TINYINT(1) NOT NULL DEFAULT 0"),
            ("bump_reward_temp_role_id", "BIGINT(20) NULL DEFAULT NULL"),
            ("bump_reward_role_minutes", "INT(11) NOT NULL DEFAULT 0"),
            ("bump_reward_coins", "INT(11) NOT NULL DEFAULT 0"),
            ("bump_reward_message", "TEXT NULL DEFAULT NULL"),
            ("bump_monthly_enabled", "TINYINT(1) NOT NULL DEFAULT 0"),
            ("bump_monthly_disboard_channel_id", "BIGINT(20) NULL DEFAULT NULL"),
            ("bump_monthly_reward_role_id", "BIGINT(20) NULL DEFAULT NULL"),
            ("bump_monthly_reward_days_1", "INT(11) NOT NULL DEFAULT 21"),
            ("bump_monthly_reward_days_2", "INT(11) NOT NULL DEFAULT 14"),
            ("bump_monthly_reward_days_3", "INT(11) NOT NULL DEFAULT 7"),
            ("bump_monthly_reward_coins_1", "INT(11) NOT NULL DEFAULT 0"),
            ("bump_monthly_reward_coins_2", "INT(11) NOT NULL DEFAULT 0"),
            ("bump_monthly_reward_coins_3", "INT(11) NOT NULL DEFAULT 0"),
        )
    )
    query(f"ALTER TABLE config_server_settings {server_columns}")
    query(
        "ALTER TABLE config_economy "
        "ADD COLUMN bump_points INT(11) NULL DEFAULT NULL, "
        "ADD COLUMN bump_reward_enabled TINYINT(1) NOT NULL DEFAULT 0"
    )
    query(
        "INSERT INTO config_server_settings "
        "(server_guild_id, bump_warn_enabled, bump_reward_coins) VALUES (101, 1, 37)"
    )
    query(
        "INSERT INTO config_economy "
        "(server_guild_id, currency_name, currency_prefix, bump_points, bump_reward_enabled) "
        "VALUES (101, 'coins', 'C', NULL, 1)"
    )
    query(
        "INSERT INTO allowed_feature_channels "
        "(server_guild_id, feature_key, channel_id) "
        "VALUES (101, 'disboard_bump_processing', 202)"
    )


def assert_existing_bump_sentinels() -> None:
    require_equal(
        query("SELECT CONCAT(bump_warn_enabled, '|', bump_reward_coins) FROM config_server_settings WHERE server_guild_id = 101"),
        "1|37",
        "existing config_server_settings Bump values remain unchanged",
    )
    require_equal(
        query("SELECT CONCAT(IF(bump_points IS NULL, 'NULL', bump_points), '|', bump_reward_enabled) FROM config_economy WHERE server_guild_id = 101"),
        "NULL|1",
        "existing nullable bump_points and reward flag remain unchanged",
    )
    require_equal(
        query("SELECT COUNT(*) FROM allowed_feature_channels WHERE server_guild_id = 101 AND feature_key = 'disboard_bump_processing' AND channel_id = 202"),
        "1",
        "existing processing-channel row remains unchanged",
    )


def prepare_existing_xp_schema() -> None:
    """Model observed runtime-managed XP objects before the Flyway formalization."""
    query(
        "CREATE TABLE config_levels ("
        "id INT(11) NOT NULL AUTO_INCREMENT, "
        "server_guild_id BIGINT(20) NOT NULL, "
        "clear_on_exit TINYINT(1) NOT NULL DEFAULT 0, "
        "levelup_warning TINYINT(1) NOT NULL DEFAULT 0, "
        "levelup_warning_channel BIGINT(20) NULL, "
        "level_up_message TEXT NULL, "
        "multiplier DECIMAL(20,3) NULL, "
        "phase1_k DECIMAL(20,3) NOT NULL DEFAULT 45.000, "
        "phase1_p DECIMAL(20,3) NOT NULL DEFAULT 2.000, "
        "phase1_b DECIMAL(20,3) NOT NULL DEFAULT 0.000, "
        "daily_combo INT(11) NULL, "
        "combo_multiplier DECIMAL(20,3) NULL, "
        "xp_base_per_min INT(11) NOT NULL DEFAULT 2, "
        "voice_social_bonus_pct DECIMAL(8,4) NOT NULL DEFAULT 0.0000, "
        "voice_social_bonus_min_humans INT(11) NOT NULL DEFAULT 2, "
        "voice_diminishing_window1_minutes INT(11) NOT NULL DEFAULT 60, "
        "voice_diminishing_window2_minutes INT(11) NOT NULL DEFAULT 120, "
        "voice_diminishing_factor2 DECIMAL(8,4) NOT NULL DEFAULT 0.6000, "
        "voice_diminishing_factor3 DECIMAL(8,4) NOT NULL DEFAULT 0.3000, "
        "voice_daily_cap_xp INT(11) NOT NULL DEFAULT 600, "
        "text_daily_cap_xp INT(11) NOT NULL DEFAULT 300, "
        "global_daily_cap_xp INT(11) NOT NULL DEFAULT 900, "
        "pivot_level INT(11) NULL, "
        "phase2_c DECIMAL(20,3) NULL, "
        "PRIMARY KEY (id), "
        "UNIQUE KEY server_guild_id (server_guild_id)"
        ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci"
    )
    query(
        "INSERT INTO config_levels "
        "(server_guild_id, clear_on_exit, levelup_warning, multiplier, "
        "phase1_k, phase1_p, phase1_b, xp_base_per_min, text_daily_cap_xp, "
        "voice_daily_cap_xp, global_daily_cap_xp, pivot_level, phase2_c) VALUES "
        "(7700, 1, 1, 1.500, 45.000, 2.000, 3.000, 0, 321, 654, 777, 25, 8.000)"
    )
    query(
        "INSERT INTO user_level "
        "(user_id, server_guild_id, total_xp, current_level, daily_recs_count, weekly_bump_xp) "
        "VALUES (77, 7700, 4321, 9, 4, 12)"
    )
    query(
        "CREATE TABLE voice_xp_sessions ("
        "server_guild_id BIGINT(20) NOT NULL, "
        "discord_user_id BIGINT(20) NOT NULL, "
        "voice_channel_id BIGINT(20) NOT NULL, "
        "started_at DATETIME NOT NULL, "
        "last_tick_at DATETIME NOT NULL, "
        "is_eligible TINYINT(1) NOT NULL DEFAULT 0, "
        "is_self_muted TINYINT(1) NOT NULL DEFAULT 0, "
        "is_self_deafened TINYINT(1) NOT NULL DEFAULT 0, "
        "is_server_muted TINYINT(1) NOT NULL DEFAULT 0, "
        "is_server_deafened TINYINT(1) NOT NULL DEFAULT 0, "
        "PRIMARY KEY (server_guild_id, discord_user_id)"
        ") ENGINE=InnoDB"
    )
    query(
        "INSERT INTO voice_xp_sessions "
        "(server_guild_id, discord_user_id, voice_channel_id, started_at, last_tick_at, is_eligible) "
        "VALUES (7700, 77001, 77002, '2026-10-04 12:00:00', '2026-10-04 12:05:00', 1)"
    )
    query(
        "CREATE TABLE voice_xp_audit_log ("
        "id BIGINT(20) NOT NULL AUTO_INCREMENT, "
        "server_guild_id BIGINT(20) NOT NULL, discord_user_id BIGINT(20) NOT NULL, "
        "voice_channel_id BIGINT(20) NULL, event_type VARCHAR(64) NOT NULL, "
        "xp_amount INT(11) NOT NULL DEFAULT 0, eligible_seconds INT(11) NOT NULL DEFAULT 0, "
        "ineligible_seconds INT(11) NOT NULL DEFAULT 0, meta_json JSON NULL, "
        "created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (id), "
        "KEY idx_voice_xp_audit_guild_day (server_guild_id, created_at), "
        "KEY idx_voice_xp_audit_user_day (server_guild_id, discord_user_id, created_at)"
        ") ENGINE=InnoDB"
    )
    query(
        "INSERT INTO voice_xp_audit_log "
        "(server_guild_id, discord_user_id, voice_channel_id, event_type, xp_amount) "
        "VALUES (7700, 77001, 77002, 'AWARD', 7)"
    )
    query(
        "CREATE TABLE voice_xp_daily_metrics ("
        "id BIGINT(20) NOT NULL AUTO_INCREMENT, metric_day DATE NOT NULL, "
        "server_guild_id BIGINT(20) NOT NULL, modality VARCHAR(32) NOT NULL, "
        "voice_channel_id BIGINT(20) NULL, total_xp BIGINT(20) NOT NULL DEFAULT 0, "
        "grants_count BIGINT(20) NOT NULL DEFAULT 0, blocks_count BIGINT(20) NOT NULL DEFAULT 0, "
        "eligible_seconds BIGINT(20) NOT NULL DEFAULT 0, ineligible_seconds BIGINT(20) NOT NULL DEFAULT 0, "
        "PRIMARY KEY (id), "
        "UNIQUE KEY uniq_voice_xp_daily_metrics "
        "(metric_day, server_guild_id, modality, voice_channel_id)"
        ") ENGINE=InnoDB"
    )
    query(
        "INSERT INTO voice_xp_daily_metrics "
        "(metric_day, server_guild_id, modality, voice_channel_id, total_xp, grants_count) "
        "VALUES ('2026-10-04', 7700, 'VOICE', 77002, 7, 1)"
    )


def assert_existing_xp_sentinels() -> None:
    require_equal(
        query(
            "SELECT CONCAT(clear_on_exit, '|', levelup_warning, '|', multiplier, '|', "
            "phase1_k, '|', phase1_p, '|', phase1_b, '|', xp_base_per_min, '|', "
            "text_daily_cap_xp, '|', voice_daily_cap_xp, '|', global_daily_cap_xp, '|', "
            "pivot_level, '|', phase2_c) "
            "FROM config_levels WHERE server_guild_id = 7700"
        ),
        "1|1|1.500|45.000|2.000|3.000|0|321|654|777|25|8.000",
        "existing XP configuration and legacy columns remain unchanged",
    )
    require_equal(
        query(
            "SELECT CONCAT(text_xp_enabled, '|', voice_xp_enabled, '|', "
            "text_xp_base_min, '|', text_xp_base_max, '|', "
            "text_xp_cooldown_min_seconds, '|', text_xp_cooldown_max_seconds) "
            "FROM config_levels WHERE server_guild_id = 7700"
        ),
        "1|0|8|16|30|60",
        "new XP controls preserve legacy text behavior and zero-rate voice disablement",
    )
    require_equal(
        query(
            "SELECT CONCAT(total_xp, '|', current_level, '|', daily_recs_count, '|', weekly_bump_xp) "
            "FROM user_level WHERE user_id = 77 AND server_guild_id = 7700"
        ),
        "4321|9|4|12",
        "existing XP totals and levels are not rewritten",
    )
    require_equal(
        query(
            "SELECT CONCAT(voice_channel_id, '|', is_eligible) "
            "FROM voice_sessions WHERE server_guild_id = 7700 AND discord_user_id = 77001"
        ),
        "77002|1",
        "legacy voice session survives canonical table rename",
    )
    require_equal(
        query(
            "SELECT CONCAT(event_type, '|', xp_amount) FROM voice_xp_audit_log "
            "WHERE server_guild_id = 7700 AND discord_user_id = 77001"
        ),
        "AWARD|7",
        "existing voice XP audit row survives formalization",
    )
    require_equal(
        query(
            "SELECT CONCAT(total_xp, '|', grants_count) FROM voice_xp_daily_metrics "
            "WHERE metric_day = '2026-10-04' AND server_guild_id = 7700"
        ),
        "7|1",
        "existing voice XP daily metric survives formalization",
    )


def prepare_existing_identity_link() -> None:
    """Insert a fully audited row through the immutable pre-rename schema."""
    query(
        "INSERT INTO users (id, display_name) VALUES "
        "(101, 'legacy-a'), (102, 'legacy-b'), (103, 'legacy-actor'), "
        "(104, 'active-b'), (105, 'active-a')"
    )
    query(
        "INSERT INTO user_identity_links "
        "(id, primary_user_id, linked_user_id, status, link_source, reason, "
        "linked_by_user_id, created_at, revoked_at, revoked_by_user_id, revocation_reason) "
        "VALUES (901, 101, 102, 'CONFIRMED', 'LEGACY_SPLIT', 'preserve reason', "
        "103, '2026-09-24 12:34:56.123456', '2026-09-25 01:02:03.654321', "
        "103, 'preserve revocation')"
    )
    query(
        "INSERT INTO user_identity_links "
        "(id, primary_user_id, linked_user_id, status, link_source, reason, linked_by_user_id) "
        "VALUES (902, 105, 104, 'SUSPECTED', 'ADMIN', 'preserve active edge', 103)"
    )


def prepare_existing_warning_schema() -> None:
    """Add the canonical legacy warnings table for partial pre-Bump adoption."""
    query(
        "CREATE TABLE user_warnings ("
        "id INT(11) NOT NULL AUTO_INCREMENT,"
        "user_id INT(11) NOT NULL,"
        "community_id INT(11) NOT NULL,"
        "date DATE NOT NULL,"
        "reason VARCHAR(1024) NOT NULL,"
        "expired BIT(1) NOT NULL DEFAULT b'0',"
        "applied_by INT(11) NOT NULL,"
        "PRIMARY KEY (id),"
        "UNIQUE KEY unique_warning (user_id,community_id,date,reason) USING HASH,"
        "KEY warns_user_id_users_id (user_id),"
        "KEY FK_warns_communities (community_id),"
        "KEY FK_user_warnings_users (applied_by),"
        "CONSTRAINT FK_user_warnings_users FOREIGN KEY (applied_by) "
        "REFERENCES users(id) ON DELETE NO ACTION ON UPDATE NO ACTION,"
        "CONSTRAINT FK_warns_communities FOREIGN KEY (community_id) "
        "REFERENCES communities(id) ON DELETE NO ACTION ON UPDATE NO ACTION,"
        "CONSTRAINT warns_user_id_users_id FOREIGN KEY (user_id) "
        "REFERENCES users(id)"
        ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci"
    )


def assert_existing_identity_link_sentinel() -> None:
    require_equal(
        query(
            "SELECT CONCAT_WS('|', id, user_a_id, user_b_id, status, link_source, reason, "
            "linked_by_user_id, DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s.%f'), "
            "DATE_FORMAT(revoked_at, '%Y-%m-%d %H:%i:%s.%f'), revoked_by_user_id, "
            "revocation_reason) FROM user_identity_links WHERE id = 901"
        ),
        "901|101|102|CONFIRMED|LEGACY_SPLIT|preserve reason|103|"
        "2026-09-24 12:34:56.123456|2026-09-25 01:02:03.654321|103|preserve revocation",
        "existing identity row and complete audit history survive the endpoint rename",
    )
    require_equal(
        query(
            "SELECT CONCAT_WS('|', id, user_a_id, user_b_id, status, link_source, reason, "
            "linked_by_user_id, active_user_low_id, active_user_high_id) "
            "FROM user_identity_links WHERE id = 902"
        ),
        "902|105|104|SUSPECTED|ADMIN|preserve active edge|103|104|105",
        "existing active edge survives and is canonicalized without reordering its endpoints",
    )


def assert_migrated_state() -> tuple[str, str]:
    require_equal(
        query(
            "SELECT COUNT(*) FROM information_schema.tables "
            "WHERE table_schema = DATABASE() AND table_name = 'user_identity_links';"
        ),
        "1",
        "user_identity_links exists",
    )
    require_equal(
        query(
            "SELECT COUNT(*) FROM information_schema.tables "
            f"WHERE table_schema = DATABASE() AND table_name = '{SMOKE_TABLE}';"
        ),
        "1",
        "synthetic smoke table exists",
    )
    require_equal(
        query(
            "SELECT COUNT(*) FROM information_schema.tables "
            "WHERE table_schema = DATABASE() AND table_name = 'flyway_schema_history';"
        ),
        "1",
        "flyway_schema_history exists",
    )
    require_equal(
        query(f"SELECT COUNT(*) FROM `{SMOKE_TABLE}` WHERE id = 1;"),
        "1",
        "smoke fixture data exists exactly once",
    )
    history_count = query(
        "SELECT COUNT(*) FROM flyway_schema_history "
        f"WHERE success = 1 AND script = '{SMOKE_SCRIPT}';"
    )
    require_equal(history_count, "1", "one successful fixture history row exists")
    require_equal(
        query(
            "SELECT COUNT(*) FROM flyway_schema_history "
            f"WHERE success = 1 AND script = '{IDENTITY_SCRIPT}';"
        ),
        "1",
        "one successful identity migration history row exists",
    )
    require_equal(
        query(
            "SELECT COUNT(*) FROM flyway_schema_history "
            f"WHERE success = 1 AND script = '{BUMP_SCRIPT}';"
        ),
        "1",
        "one successful Bump migration history row exists",
    )
    require_equal(
        query(
            "SELECT COUNT(*) FROM flyway_schema_history "
            f"WHERE success = 1 AND script = '{LEDGER_SCRIPT}';"
        ),
        "1",
        "one successful monthly reward ledger migration history row exists",
    )
    require_equal(
        query(
            "SELECT COUNT(*) FROM flyway_schema_history "
            f"WHERE success = 1 AND script = '{MEMBERSHIP_UNIQUE_SCRIPT}';"
        ),
        "1",
        "one successful membership uniqueness migration history row exists",
    )
    require_equal(
        query(
            "SELECT COUNT(*) FROM flyway_schema_history "
            f"WHERE success = 1 AND script = '{TEAM_ASSIGNMENT_SCRIPT}';"
        ),
        "1",
        "one successful team assignment migration history row exists",
    )
    require_equal(
        query(
            "SELECT COUNT(*) FROM flyway_schema_history "
            f"WHERE success = 1 AND script = '{IDENTITY_UNDIRECTED_SCRIPT}';"
        ),
        "1",
        "one successful undirected identity migration history row exists",
    )
    require_equal(
        query(
            "SELECT COUNT(*) FROM flyway_schema_history "
            f"WHERE success = 1 AND script = '{BAN_EFFECT_SCRIPT}';"
        ),
        "1",
        "one successful ban-effect migration history row exists",
    )
    require_equal(
        query(
            "SELECT COUNT(*) FROM flyway_schema_history "
            f"WHERE success = 1 AND script = '{COMMUNITY_AUTH_SCRIPT}';"
        ),
        "1",
        "one successful Community authorization migration history row exists",
    )
    require_equal(
        query(
            "SELECT COUNT(*) FROM flyway_schema_history "
            f"WHERE success = 1 AND script = '{COMMUNITY_MEMBER_NOTES_SCRIPT}';"
        ),
        "1",
        "one successful Community member notes migration history row exists",
    )
    require_equal(
        query(
            "SELECT COUNT(*) FROM flyway_schema_history "
            f"WHERE success = 1 AND script = '{COMMUNITY_LIFECYCLE_SYNC_SCRIPT}';"
        ),
        "1",
        "one successful Community lifecycle migration history row exists",
    )
    require_equal(
        query(
            "SELECT COUNT(*) FROM flyway_schema_history "
            f"WHERE success = 1 AND script = '{NETWORK_MEMBERSHIP_SCRIPT}';"
        ),
        "1",
        "one successful network membership migration history row exists",
    )
    require_equal(
        query(
            "SELECT COUNT(*) FROM flyway_schema_history "
            f"WHERE success = 1 AND script = '{XP_LEVELING_SCRIPT}';"
        ),
        "1",
        "one successful XP/leveling migration history row exists",
    )
    assert_identity_link_schema()
    assert_user_ban_effect_schema()
    assert_community_authorization_schema()
    assert_community_member_notes_schema()
    assert_community_lifecycle_sync_schema()
    assert_network_membership_schema()
    assert_membership_uniqueness()
    assert_team_role_assignment_schema()
    assert_bump_schema()
    assert_bump_monthly_reward_ledger_schema()
    assert_xp_leveling_schema()
    checksum = query(
        "SELECT checksum FROM flyway_schema_history "
        f"WHERE success = 1 AND script = '{SMOKE_SCRIPT}';"
    )
    if not re.fullmatch(r"-?\d+", checksum):
        raise SmokeFailure(f"Flyway checksum was not persisted: {checksum!r}")
    print(f"PASS: Flyway persisted checksum {checksum}")
    return history_count, checksum


def assert_xp_leveling_schema() -> None:
    assert_table_exists("config_levels")
    for column, expected in {
        "text_xp_enabled": ("tinyint(1)", "NO", "1"),
        "voice_xp_enabled": ("tinyint(1)", "NO", "1"),
        "text_xp_base_min": ("int(11)", "NO", "8"),
        "text_xp_base_max": ("int(11)", "NO", "16"),
        "text_xp_cooldown_min_seconds": ("int(11)", "NO", "30"),
        "text_xp_cooldown_max_seconds": ("int(11)", "NO", "60"),
        "level_reconcile_required": ("tinyint(1)", "NO", "0"),
        "level_reconcile_requested_at": ("datetime(6)", "YES", "NULL"),
        "level_reconciled_at": ("datetime(6)", "YES", "NULL"),
    }.items():
        assert_column("config_levels", column, expected)

    config_unique = query(
        "SELECT COUNT(*) FROM ("
        "SELECT INDEX_NAME FROM information_schema.statistics "
        "WHERE table_schema = DATABASE() AND table_name = 'config_levels' "
        "AND non_unique = 0 AND index_name <> 'PRIMARY' "
        "GROUP BY INDEX_NAME "
        "HAVING GROUP_CONCAT(column_name ORDER BY seq_in_index) = 'server_guild_id'"
        ") AS x"
    )
    require_equal(config_unique, "1", "config_levels has one guild-scoped unique index")

    for column, expected in {
        "xp_awarded_voice_today": ("int(11)", "NO", "0"),
        "xp_awarded_voice_day": ("date", "YES", "NULL"),
        "xp_awarded_text_today": ("int(11)", "NO", "0"),
        "xp_awarded_text_day": ("date", "YES", "NULL"),
        "xp_awarded_today": ("int(11)", "NO", "0"),
        "xp_awarded_day": ("date", "YES", "NULL"),
    }.items():
        assert_column("user_level", column, expected)

    composite_unique = query(
        "SELECT COUNT(*) FROM ("
        "SELECT INDEX_NAME FROM information_schema.statistics "
        "WHERE table_schema = DATABASE() AND table_name = 'user_level' "
        "AND non_unique = 0 AND index_name <> 'PRIMARY' "
        "GROUP BY INDEX_NAME "
        "HAVING GROUP_CONCAT(column_name ORDER BY seq_in_index) = 'user_id,server_guild_id'"
        ") AS x"
    )
    require_equal(composite_unique, "1", "user_level is unique by user and guild")

    legacy_user_unique = query(
        "SELECT COUNT(*) FROM ("
        "SELECT INDEX_NAME FROM information_schema.statistics "
        "WHERE table_schema = DATABASE() AND table_name = 'user_level' "
        "AND non_unique = 0 AND index_name <> 'PRIMARY' "
        "GROUP BY INDEX_NAME "
        "HAVING GROUP_CONCAT(column_name ORDER BY seq_in_index) = 'user_id'"
        ") AS x"
    )
    require_equal(legacy_user_unique, "0", "legacy user-only XP uniqueness is retired")

    assert_table_exists("voice_sessions")
    assert_index(
        "voice_sessions",
        "PRIMARY",
        "0",
        "server_guild_id,discord_user_id",
    )
    assert_table_exists("voice_xp_audit_log")
    assert_index(
        "voice_xp_audit_log",
        "idx_voice_xp_audit_guild_day",
        "1",
        "server_guild_id,created_at",
    )
    assert_table_exists("voice_xp_daily_metrics")
    assert_index(
        "voice_xp_daily_metrics",
        "uniq_voice_xp_daily_metrics",
        "0",
        "metric_day,server_guild_id,modality,voice_channel_id",
    )


def prove_user_level_guild_isolation() -> None:
    query("INSERT INTO users (id, display_name) VALUES (501, 'XP tenant proof')")
    query(
        "INSERT INTO user_level "
        "(user_id, server_guild_id, total_xp, current_level) VALUES "
        "(501, 50101, 100, 1), (501, 50102, 200, 2)"
    )
    require_equal(
        query("SELECT COUNT(*) FROM user_level WHERE user_id = 501"),
        "2",
        "the same User may have independent XP rows in two guilds",
    )
    expect_sql_failure(
        "INSERT INTO user_level "
        "(user_id, server_guild_id, total_xp, current_level) "
        "VALUES (501, 50101, 999, 9)",
        "duplicate XP row for the same user and guild is rejected",
    )
    query("DELETE FROM user_level WHERE user_id = 501")
    query("DELETE FROM users WHERE id = 501")


def prove_checksum_mismatch_detection() -> None:
    shell_command = (
        "set -eu; "
        "mkdir -p /tmp/brf-checksum; "
        f"cp /flyway/sql/{SMOKE_SCRIPT} /tmp/brf-checksum/{SMOKE_SCRIPT}; "
        "cp /flyway/official/*.sql /tmp/brf-checksum/; "
        f"printf '\\n-- disposable checksum mismatch probe\\n' >> /tmp/brf-checksum/{SMOKE_SCRIPT}; "
        "/flyway/flyway -configFiles=/flyway/conf/flyway.conf "
        "-locations=filesystem:/tmp/brf-checksum validate"
    )
    result = compose(
        "run",
        "--rm",
        "--no-deps",
        "--entrypoint",
        "/bin/sh",
        "flyway",
        "-c",
        shell_command,
        check=False,
    )
    combined_output = f"{result.stdout}\n{result.stderr}".lower()
    if result.returncode == 0 or "checksum mismatch" not in combined_output:
        raise SmokeFailure("modified temporary fixture did not trigger checksum mismatch")
    print("PASS: validate rejected a temporary checksum mismatch without changing repository files")


def expect_sql_failure(statement: str, description: str) -> None:
    result = compose(
        "exec", "--no-TTY", "mariadb", "mariadb", "--host=127.0.0.1",
        f"--user={DATABASE_USER}", f"--password={DATABASE_PASSWORD}",
        f"--database={DATABASE_NAME}", "--batch", "--skip-column-names",
        f"--execute={statement}", check=False,
    )
    if result.returncode == 0:
        raise SmokeFailure(f"{description}: SQL unexpectedly succeeded")
    print(f"PASS: {description}")



def prove_membership_uniqueness_constraint() -> None:
    query("INSERT INTO communities (id, name) VALUES (301, 'Community A'), (302, 'Community B')")
    query("INSERT INTO users (id, display_name) VALUES (301, 'Member A')")
    query(
        "INSERT INTO user_community_status "
        "(id, user_id, community_id, member_since) "
        "VALUES (301, 301, 301, '2026-01-01 00:00:00')"
    )
    expect_sql_failure(
        "INSERT INTO user_community_status "
        "(user_id, community_id, member_since) "
        "VALUES (301, 301, '2026-02-01 00:00:00')",
        "duplicate current membership for one user/community is rejected",
    )
    query(
        "INSERT INTO user_community_status "
        "(user_id, community_id, member_since) "
        "VALUES (301, 302, '2026-02-01 00:00:00')"
    )
    require_equal(
        query("SELECT COUNT(*) FROM user_community_status WHERE user_id = 301"),
        "2",
        "same user may have one current membership in multiple Communities",
    )
    query("DELETE FROM user_community_status WHERE user_id = 301")
    query("DELETE FROM users WHERE id = 301")
    query("DELETE FROM communities WHERE id IN (301, 302)")


def prove_team_role_assignment_constraints() -> None:
    query(
        "INSERT INTO communities (id, name) VALUES "
        "(201, 'Community A'), (202, 'Community B')"
    )
    query(
        "INSERT INTO users (id, display_name) VALUES "
        "(201, 'Member A'), (202, 'Member B')"
    )
    query(
        "INSERT INTO community_team_roles "
        "(id, community_id, name, active) VALUES "
        "(201, 201, 'Role A1', 1), "
        "(202, 202, 'Role B1', 1), "
        "(203, 201, 'Role A2', 1)"
    )
    query(
        "INSERT INTO user_community_status "
        "(id, user_id, community_id, member_since) VALUES "
        "(201, 201, 201, '2026-01-01'), "
        "(202, 202, 202, '2026-01-01')"
    )

    query(
        "INSERT INTO community_team_role_assignments "
        "(community_id, role_id, user_id) VALUES (201, 201, 201)"
    )
    expect_sql_failure(
        "INSERT INTO community_team_role_assignments "
        "(community_id, role_id, user_id) VALUES (201, 201, 201)",
        "duplicate team role assignment is rejected",
    )
    expect_sql_failure(
        "INSERT INTO community_team_role_assignments "
        "(community_id, role_id, user_id) VALUES (202, 201, 201)",
        "cross-tenant role assignment is rejected by the composite FK",
    )
    expect_sql_failure(
        "INSERT INTO community_team_role_assignments "
        "(community_id, role_id, user_id) VALUES (201, 203, 202)",
        "team role assignment rejects a user whose membership belongs to another Community",
    )

    query(
        "INSERT INTO community_team_role_assignments "
        "(community_id, role_id, user_id) VALUES (201, 203, 201)"
    )
    require_equal(
        query(
            "SELECT COUNT(*) FROM community_team_role_assignments "
            "WHERE community_id = 201 AND user_id = 201"
        ),
        "2",
        "one member may occupy multiple roles in the same Community",
    )

    expect_sql_failure(
        "DELETE FROM community_team_roles WHERE id = 201",
        "role deletion is blocked while assignments exist",
    )
    expect_sql_failure(
        "DELETE FROM user_community_status WHERE community_id = 201 AND user_id = 201",
        "membership deletion is blocked while assignments exist",
    )

    query(
        "DELETE FROM community_team_role_assignments "
        "WHERE community_id IN (201, 202)"
    )
    query("DELETE FROM community_team_roles WHERE id IN (201, 202, 203)")
    query("DELETE FROM user_community_status WHERE id IN (201, 202)")
    query("DELETE FROM communities WHERE id IN (201, 202)")
    query("DELETE FROM users WHERE id IN (201, 202)")


def prove_community_authorization_constraints() -> None:
    query(
        "INSERT INTO users (id, display_name) VALUES "
        "(501, 'Owner and grantor'), (502, 'Community member'), (503, 'Other user')"
    )
    query(
        "INSERT INTO communities (id, name) VALUES "
        "(501, 'Authorization A'), (502, 'Authorization B')"
    )
    require_equal(
        query("SELECT COUNT(*) FROM communities WHERE id IN (501, 502) AND owner_user_id IS NULL"),
        "2",
        "Communities may exist without an Owner before API claim",
    )
    query("UPDATE communities SET owner_user_id = 501 WHERE id IN (501, 502)")
    require_equal(
        query("SELECT COUNT(*) FROM communities WHERE owner_user_id = 501 AND id IN (501, 502)"),
        "2",
        "one User may own multiple Communities",
    )
    expect_sql_failure(
        "UPDATE communities SET owner_user_id = 999999 WHERE id = 501",
        "Community Owner must reference an existing User",
    )

    query(
        "INSERT INTO community_team_roles "
        "(id, community_id, name, active) VALUES "
        "(501, 501, 'Coordination A', 1), "
        "(502, 502, 'Coordination B', 1)"
    )
    query(
        "INSERT INTO user_community_status "
        "(id, user_id, community_id, member_since) VALUES "
        "(501, 502, 501, '2026-10-01 00:00:00')"
    )

    query(
        "INSERT INTO community_team_role_capabilities "
        "(community_id, role_id, capability, granted_by_user_id) "
        "VALUES (501, 501, 'TEAM_MANAGE_STRUCTURE', 501)"
    )
    query(
        "INSERT INTO community_team_role_capabilities "
        "(community_id, role_id, capability, granted_by_user_id) "
        "VALUES (501, 501, 'MEMBERS_VIEW', 501)"
    )
    require_equal(
        query(
            "SELECT COUNT(*) FROM community_team_role_capabilities "
            "WHERE community_id = 501 AND role_id = 501"
        ),
        "2",
        "one role may hold multiple capabilities",
    )
    expect_sql_failure(
        "INSERT INTO community_team_role_capabilities "
        "(community_id, role_id, capability, granted_by_user_id) "
        "VALUES (501, 501, 'TEAM_MANAGE_STRUCTURE', 501)",
        "duplicate role capability is rejected",
    )
    expect_sql_failure(
        "INSERT INTO community_team_role_capabilities "
        "(community_id, role_id, capability, granted_by_user_id) "
        "VALUES (501, 502, 'TEAM_VIEW', 501)",
        "role capability cannot reference a role from another Community",
    )
    expect_sql_failure(
        "INSERT INTO community_team_role_capabilities "
        "(community_id, role_id, capability, granted_by_user_id) "
        "VALUES (501, 501, 'TEAM_VIEW', 999999)",
        "role capability grantor must exist",
    )

    query(
        "INSERT INTO community_user_capability_grants "
        "(community_id, user_id, capability, granted_by_user_id) "
        "VALUES (501, 502, 'MEMBER_DETAILS_VIEW', 501)"
    )
    expect_sql_failure(
        "INSERT INTO community_user_capability_grants "
        "(community_id, user_id, capability, granted_by_user_id) "
        "VALUES (501, 502, 'MEMBER_DETAILS_VIEW', 501)",
        "duplicate direct capability grant is rejected",
    )
    expect_sql_failure(
        "INSERT INTO community_user_capability_grants "
        "(community_id, user_id, capability, granted_by_user_id) "
        "VALUES (502, 502, 'MEMBERS_VIEW', 501)",
        "direct grant requires membership in the same Community",
    )
    expect_sql_failure(
        "INSERT INTO community_user_capability_grants "
        "(community_id, user_id, capability, granted_by_user_id) "
        "VALUES (501, 503, 'MEMBERS_VIEW', 501)",
        "direct grant cannot target a User without Community membership",
    )
    expect_sql_failure(
        "INSERT INTO community_user_capability_grants "
        "(community_id, user_id, capability, granted_by_user_id) "
        "VALUES (501, 502, 'MEMBER_NOTES_VIEW', 999999)",
        "direct grantor must exist",
    )

    query(
        "INSERT INTO community_audit_log "
        "(community_id, actor_user_id, action, target_type, target_id, metadata) "
        "VALUES (501, 501, 'COMMUNITY_CAPABILITY_GRANTED', 'USER', '502', '{\"source\":\"smoke\"}'), "
        "(502, 501, 'COMMUNITY_OWNER_ASSIGNED', 'COMMUNITY', '502', NULL)"
    )
    require_equal(
        query("SELECT COUNT(*) FROM community_audit_log WHERE community_id = 501"),
        "1",
        "audit entries remain scoped to their Community",
    )
    require_equal(
        query("SELECT COUNT(*) FROM community_audit_log WHERE community_id = 502"),
        "1",
        "another Community stores its audit entry independently",
    )
    expect_sql_failure(
        "INSERT INTO community_audit_log "
        "(community_id, actor_user_id, action) VALUES (999999, 501, 'INVALID')",
        "audit log rejects an unknown Community",
    )
    expect_sql_failure(
        "INSERT INTO community_audit_log "
        "(community_id, actor_user_id, action) VALUES (501, 999999, 'INVALID')",
        "audit log rejects an unknown actor",
    )

    query("DELETE FROM community_audit_log WHERE community_id IN (501, 502)")
    query("DELETE FROM community_user_capability_grants WHERE community_id IN (501, 502)")
    query("DELETE FROM community_team_role_capabilities WHERE community_id IN (501, 502)")
    query("DELETE FROM community_team_roles WHERE id IN (501, 502)")
    query("DELETE FROM user_community_status WHERE id = 501")
    query("DELETE FROM communities WHERE id IN (501, 502)")
    query("DELETE FROM users WHERE id IN (501, 502, 503)")




def prove_community_member_note_constraints() -> None:
    query(
        "INSERT INTO users (id, display_name) VALUES "
        "(601, 'Note author'), (602, 'Note target'), (603, 'Note editor')"
    )
    query(
        "INSERT INTO communities (id, name) VALUES "
        "(601, 'Notes A'), (602, 'Notes B')"
    )
    query(
        "INSERT INTO user_community_status "
        "(id, user_id, community_id, member_since) "
        "VALUES (601, 602, 601, '2026-10-01 00:00:00')"
    )

    query(
        "INSERT INTO community_member_notes "
        "(community_id, user_id, author_user_id, updated_by_user_id, content) "
        "VALUES (601, 602, 601, 601, 'community scoped note')"
    )
    require_equal(
        query(
            "SELECT COUNT(*) FROM community_member_notes "
            "WHERE community_id = 601 AND user_id = 602 AND archived_at IS NULL"
        ),
        "1",
        "Community member note is stored in its tenant",
    )
    expect_sql_failure(
        "INSERT INTO community_member_notes "
        "(community_id, user_id, author_user_id, updated_by_user_id, content) "
        "VALUES (602, 602, 601, 601, 'cross tenant')",
        "Community member note cannot target a membership from another tenant",
    )
    expect_sql_failure(
        "INSERT INTO community_member_notes "
        "(community_id, user_id, author_user_id, updated_by_user_id, content) "
        "VALUES (601, 602, 999999, 601, 'unknown author')",
        "Community member note author must exist",
    )
    expect_sql_failure(
        "INSERT INTO community_member_notes "
        "(community_id, user_id, author_user_id, updated_by_user_id, content) "
        "VALUES (601, 602, 601, 999999, 'unknown editor')",
        "Community member note editor must exist",
    )

    query(
        "UPDATE community_member_notes "
        "SET content = 'updated note', updated_by_user_id = 603 "
        "WHERE community_id = 601 AND user_id = 602"
    )
    require_equal(
        query(
            "SELECT updated_by_user_id FROM community_member_notes "
            "WHERE community_id = 601 AND user_id = 602"
        ),
        "603",
        "Community member note records its last editor",
    )
    query(
        "UPDATE community_member_notes "
        "SET archived_at = CURRENT_TIMESTAMP(6), updated_by_user_id = 603 "
        "WHERE community_id = 601 AND user_id = 602"
    )
    require_equal(
        query(
            "SELECT COUNT(*) FROM community_member_notes "
            "WHERE community_id = 601 AND user_id = 602 AND archived_at IS NOT NULL"
        ),
        "1",
        "Community member note supports archival without deletion",
    )
    expect_sql_failure(
        "DELETE FROM user_community_status "
        "WHERE community_id = 601 AND user_id = 602",
        "membership deletion is blocked while Community member notes exist",
    )

    query("DELETE FROM community_member_notes WHERE community_id = 601")
    query("DELETE FROM user_community_status WHERE id = 601")
    query("DELETE FROM communities WHERE id IN (601, 602)")
    query("DELETE FROM users WHERE id IN (601, 602, 603)")

def prove_community_network_sync_constraints() -> None:
    query("INSERT INTO communities (id, name) VALUES (701, 'Network Sync Community')")
    query(
        "INSERT INTO community_network_sync_runs "
        "(community_id, network_type, external_network_id, `trigger`, status, started_at, observed_members, updated_members) "
        "VALUES (701, 'DISCORD', 70101, 'MANUAL', 'RUNNING', '2026-10-02 10:00:00.000000', 12, 8)"
    )
    require_equal(
        query(
            "SELECT CONCAT(network_type, '|', external_network_id, '|', `trigger`, '|', status, '|', observed_members, '|', updated_members) "
            "FROM community_network_sync_runs WHERE community_id = 701"
        ),
        "DISCORD|70101|MANUAL|RUNNING|12|8",
        "network sync run retains tenant, network, trigger and lifecycle state",
    )
    query(
        "INSERT INTO community_network_sync_runs "
        "(community_id, network_type, external_network_id, `trigger`, status) "
        "VALUES (701, 'DISCORD', 70104, 'RECOVERY', 'RUNNING')"
    )
    require_equal(
        query(
            "SELECT `trigger` FROM community_network_sync_runs "
            "WHERE community_id = 701 AND external_network_id = 70104"
        ),
        "RECOVERY",
        "recovery sync trigger is accepted",
    )
    expect_sql_failure(
        "INSERT INTO community_network_sync_runs "
        "(community_id, network_type, external_network_id, `trigger`) "
        "VALUES (701, 'DISCORD', 70102, 'UNSUPPORTED')",
        "unsupported network sync trigger is rejected",
    )
    expect_sql_failure(
        "INSERT INTO community_network_sync_runs "
        "(community_id, network_type, external_network_id, `trigger`, status) "
        "VALUES (701, 'DISCORD', 70103, 'MANUAL', 'UNKNOWN')",
        "unsupported network sync status is rejected",
    )
    expect_sql_failure(
        "INSERT INTO community_network_sync_runs "
        "(community_id, network_type, external_network_id, `trigger`) "
        "VALUES (702, 'DISCORD', 70201, 'MANUAL')",
        "network sync run cannot reference a missing Community",
    )
    query("DELETE FROM community_network_sync_runs WHERE community_id = 701")
    query("DELETE FROM communities WHERE id = 701")


def prove_network_membership_constraints() -> None:
    query("INSERT INTO communities (id, name) VALUES (801, 'Network Membership Community')")
    query("INSERT INTO users (id, display_name) VALUES (801, 'Network Member')")
    query(
        "INSERT INTO community_network_member_status "
        "(community_id, network_type, external_network_id, user_id, is_present, "
        "first_known_join_at, first_known_join_source, last_join_at, last_join_source, "
        "current_presence_since, approval_required, approved, display_name) VALUES "
        "(801, 'DISCORD', 80101, 801, 1, "
        "'2024-01-02 03:04:05.000000', 'DISCORD_REPORTED', "
        "'2026-10-02 09:00:00.000000', 'BOT_EVENT', "
        "'2026-10-02 09:00:00.000000', 1, 1, 'Guild Member')"
    )
    require_equal(
        query(
            "SELECT CONCAT(community_id, '|', network_type, '|', external_network_id, '|', "
            "user_id, '|', is_present, '|', first_known_join_source, '|', last_join_source) "
            "FROM community_network_member_status WHERE community_id = 801"
        ),
        "801|DISCORD|80101|801|1|DISCORD_REPORTED|BOT_EVENT",
        "network membership keeps tenant, network and provenance",
    )
    expect_sql_failure(
        "INSERT INTO community_network_member_status "
        "(community_id, network_type, external_network_id, user_id) "
        "VALUES (801, 'DISCORD', 80101, 801)",
        "one current state row exists per network and User",
    )
    expect_sql_failure(
        "INSERT INTO community_network_member_status "
        "(community_id, network_type, external_network_id, user_id) "
        "VALUES (999999, 'DISCORD', 80102, 801)",
        "network membership cannot cross to a missing Community",
    )
    query(
        "INSERT INTO community_network_sync_runs "
        "(community_id, network_type, external_network_id, `trigger`, status) "
        "VALUES (801, 'DISCORD', 80101, 'MANUAL', 'SUCCESS')"
    )
    sync_run_id = query(
        "SELECT MAX(id) FROM community_network_sync_runs WHERE community_id = 801"
    )
    query(
        "INSERT INTO community_network_member_events "
        "(community_id, network_type, external_network_id, user_id, event_type, "
        "occurred_at, source, sync_run_id) VALUES "
        f"(801, 'DISCORD', 80101, 801, 'JOIN', "
        f"'2026-10-02 09:00:00.000000', 'BOT_EVENT', {sync_run_id})"
    )
    require_equal(
        query(
            "SELECT CONCAT(event_type, '|', source) "
            "FROM community_network_member_events WHERE community_id = 801"
        ),
        "JOIN|BOT_EVENT",
        "transition history retains event type and observation source",
    )
    query("DELETE FROM community_network_member_events WHERE community_id = 801")
    query("DELETE FROM community_network_member_status WHERE community_id = 801")
    query("DELETE FROM community_network_sync_runs WHERE community_id = 801")
    query("DELETE FROM communities WHERE id = 801")
    query("DELETE FROM users WHERE id = 801")


def prove_user_ban_reason_capacity() -> None:
    # A moderation reason is not a uniqueness key; repeated rationale must
    # be accepted for different users in the same tenant and calendar day.
    require_equal(
        query(
            "SELECT CHARACTER_MAXIMUM_LENGTH FROM information_schema.COLUMNS "
            "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='user_bans' "
            "AND COLUMN_NAME='reason'"
        ),
        "2048",
        "user_bans reason retains detailed moderation rationale",
    )
    require_equal(
        query(
            "SELECT COUNT(*) FROM information_schema.statistics "
            "WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='user_bans' "
            "AND INDEX_NAME='unique_ban'"
        ),
        "0",
        "obsolete community/date/reason uniqueness was removed",
    )
    assert_index("user_bans", "idx_user_bans_community_date", "1", "community_id,date")

    detailed_reason = "x" * 386
    query(
        "INSERT INTO communities (id, name) VALUES "
        "(9440, 'Ban smoke tenant A'), (9441, 'Ban smoke tenant B')"
    )
    query(
        "INSERT INTO users (id, display_name) VALUES "
        "(9440, 'Member A'), (9441, 'Member B'), (9442, 'Member C')"
    )
    query(
        "INSERT INTO user_bans (id, user_id, community_id, date, reason) VALUES "
        f"(9440, 9440, 9440, '2026-10-27', '{detailed_reason}'), "
        f"(9441, 9441, 9440, '2026-10-27', '{detailed_reason}'), "
        f"(9442, 9442, 9441, '2026-10-27', '{detailed_reason}')"
    )
    require_equal(
        query("SELECT COUNT(*) FROM user_bans WHERE community_id=9440"),
        "2",
        "two distinct users can be banned for the same reason in one tenant",
    )
    require_equal(
        query("SELECT COUNT(*) FROM user_bans WHERE community_id=9441"),
        "1",
        "independent tenant accepts the same reason without collisions",
    )
    query("DELETE FROM user_bans WHERE id IN (9440, 9441, 9442)")
    query("DELETE FROM users WHERE id IN (9440, 9441, 9442)")
    query("DELETE FROM communities WHERE id IN (9440, 9441)")


def prove_user_warning_repetition() -> None:
    # A same-day same-reason warning is a separate moderation action.
    require_equal(
        query(
            "SELECT COUNT(*) FROM information_schema.statistics "
            "WHERE table_schema=DATABASE() AND table_name='user_warnings' "
            "AND index_name='unique_warning'"
        ),
        "0",
        "legacy uniqueness on warning reason has been removed",
    )
    assert_index(
        "user_warnings", "idx_user_warnings_community_user_date",
        "1", "community_id,user_id,date",
    )
    require_equal(
        query(
            "SELECT CHARACTER_MAXIMUM_LENGTH FROM information_schema.columns "
            "WHERE table_schema=DATABASE() AND table_name='user_warnings' "
            "AND column_name='reason'"
        ),
        "1024",
        "warn reason retains API and Discord embed capacity",
    )
    query(
        "INSERT INTO communities (id,name) VALUES "
        "(9450,'Warnings tenant A'),(9451,'Warnings tenant B')"
    )
    query(
        "INSERT INTO users (id,display_name) VALUES "
        "(9450,'Warn user'),(9451,'Warn author')"
    )
    query(
        "INSERT INTO user_warnings "
        "(id,user_id,community_id,date,reason,expired,applied_by) VALUES "
        "(9450,9450,9450,'2026-10-29','same reason',0,9451),"
        "(9451,9450,9450,'2026-10-29','same reason',0,9451),"
        "(9452,9450,9451,'2026-10-29','same reason',0,9451)"
    )
    require_equal(
        query("SELECT COUNT(*) FROM user_warnings WHERE community_id=9450 "
              "AND user_id=9450 AND reason='same reason'"),
        "2",
        "same user may receive two independent repeated warnings in one tenant",
    )
    require_equal(
        query("SELECT COUNT(*) FROM user_warnings WHERE community_id=9451"),
        "1",
        "warnings in another tenant remain independent",
    )
    query("DELETE FROM user_warnings WHERE id IN (9450,9451,9452)")
    query("DELETE FROM users WHERE id IN (9450,9451)")
    query("DELETE FROM communities WHERE id IN (9450,9451)")


def prove_user_ban_effect_constraints() -> None:
    query("INSERT INTO communities (id, name) VALUES (401, 'Moderation Community')")
    query(
        "INSERT INTO users (id, display_name) VALUES "
        "(401, 'Origin'), (402, 'Confirmed account')"
    )
    query(
        "INSERT INTO user_bans (id, user_id, community_id, date, reason) "
        "VALUES (401, 401, 401, '2026-10-01', 'disposable test')"
    )
    query(
        "INSERT INTO user_ban_discord_effects "
        "(ban_id, identity_user_id, discord_user_id, is_origin, outcome) VALUES "
        "(401, 401, 4001, 1, 'APPLIED'), "
        "(401, 402, 4002, 0, 'ALREADY_BANNED')"
    )
    expect_sql_failure(
        "INSERT INTO user_ban_discord_effects "
        "(ban_id, identity_user_id, discord_user_id, outcome) "
        "VALUES (401, 402, 4001, 'APPLIED')",
        "one Discord account has one idempotent outcome per ban action",
    )
    expect_sql_failure(
        "INSERT INTO user_ban_discord_effects "
        "(ban_id, identity_user_id, discord_user_id, outcome) "
        "VALUES (401, 402, 4003, 'SUSPECTED')",
        "identity-link status cannot be stored as a Discord effect outcome",
    )
    query("DELETE FROM user_bans WHERE id = 401")
    require_equal(
        query("SELECT COUNT(*) FROM user_ban_discord_effects WHERE ban_id = 401"),
        "0",
        "legacy deletion of a parent action cascades to its effects",
    )
    query("DELETE FROM users WHERE id IN (401, 402)")
    query("DELETE FROM communities WHERE id = 401")


def prove_bump_monthly_reward_ledger_constraints() -> None:
    require_equal(
        query(
            "SELECT COUNT(*) FROM information_schema.statistics "
            "WHERE table_schema=DATABASE() AND table_name='community_discord' "
            "AND index_name='name' AND non_unique=0"
        ),
        "0",
        "legacy unique Discord guild-name index is removed",
    )
    assert_index("community_discord", "community_id", "0", "community_id")
    assert_index("community_discord", "guild_id", "0", "guild_id")

    query(
        "INSERT INTO communities (id, name) VALUES "
        "(6101, 'Discord tenant A'), (6102, 'Discord tenant B')"
    )
    query(
        "INSERT INTO community_discord "
        "(id, community_id, name, guild_id) VALUES "
        "(101, 6101, 'Repeated Discord Name', 101), "
        "(102, 6102, 'Repeated Discord Name', 102)"
    )
    require_equal(
        query(
            "SELECT COUNT(*) FROM community_discord "
            "WHERE name='Repeated Discord Name' AND guild_id IN (101,102)"
        ),
        "2",
        "two different Discord guilds may share the same display name",
    )
    query(
        "INSERT INTO bump_monthly_reward_runs "
        "(server_guild_id, period_start, period_end, source_channel_id) "
        "VALUES (101, '2026-09-01', '2026-10-01', 202)"
    )
    run_id = query(
        "SELECT id FROM bump_monthly_reward_runs "
        "WHERE server_guild_id = 101 AND period_start = '2026-09-01'"
    )
    expect_sql_failure(
        "INSERT INTO bump_monthly_reward_runs "
        "(server_guild_id, period_start, period_end, source_channel_id) "
        "VALUES (101, '2026-09-01', '2026-10-01', 203)",
        "one monthly reward run per guild and period",
    )
    expect_sql_failure(
        "INSERT INTO bump_monthly_reward_runs "
        "(server_guild_id, period_start, period_end, source_channel_id) "
        "VALUES (102, '2026-09-02', '2026-10-02', 203)",
        "monthly reward period must start on the first day of a month",
    )
    expect_sql_failure(
        "INSERT INTO bump_monthly_reward_runs "
        "(server_guild_id, period_start, period_end, source_channel_id) "
        "VALUES (102, '2026-09-01', '2026-09-30', 203)",
        "monthly reward period must end on the first day of the following month",
    )
    query(
        "INSERT INTO bump_monthly_reward_runs "
        "(server_guild_id, period_start, period_end, source_channel_id) "
        "VALUES (102, '2026-09-01', '2026-10-01', 203)"
    )
    other_run_id = query(
        "SELECT id FROM bump_monthly_reward_runs "
        "WHERE server_guild_id = 102 AND period_start = '2026-09-01'"
    )
    require_equal(
        query(
            "SELECT COUNT(*) FROM bump_monthly_reward_runs "
            "WHERE server_guild_id = 102 AND period_start = '2026-09-01'"
        ),
        "1",
        "another guild monthly reward run is permitted",
    )

    query(
        "INSERT INTO bump_monthly_reward_grants "
        "(run_id, discord_user_id, rank_position, bump_count) VALUES "
        f"({run_id}, 1001, 1, 30), ({run_id}, 1002, 2, 20)"
    )
    expect_sql_failure(
        "INSERT INTO bump_monthly_reward_grants "
        f"(run_id, discord_user_id, rank_position, bump_count) VALUES ({run_id}, 1001, 3, 1)",
        "duplicate monthly reward user is rejected within one run",
    )
    query(
        "INSERT INTO bump_monthly_reward_grants "
        f"(run_id, discord_user_id, rank_position, bump_count) VALUES ({run_id}, 1003, 3, 10)"
    )
    require_equal(
        query(f"SELECT COUNT(*) FROM bump_monthly_reward_grants WHERE run_id = {run_id}"),
        "3",
        "three monthly reward grants are permitted per run",
    )
    expect_sql_failure(
        "INSERT INTO bump_monthly_reward_grants "
        f"(run_id, discord_user_id, rank_position, bump_count) VALUES ({run_id}, 1004, 1, 1)",
        "duplicate monthly reward rank is rejected",
    )
    expect_sql_failure(
        "INSERT INTO bump_monthly_reward_grants "
        f"(run_id, discord_user_id, rank_position, bump_count) VALUES ({run_id}, 1004, 4, 1)",
        "monthly reward rank must stay within top three",
    )
    query(
        "INSERT INTO bump_monthly_reward_grants "
        f"(run_id, discord_user_id, rank_position, bump_count) VALUES ({other_run_id}, 1001, 1, 8)"
    )
    require_equal(
        query(
            "SELECT COUNT(*) FROM bump_monthly_reward_grants "
            f"WHERE run_id = {other_run_id} AND discord_user_id = 1001"
        ),
        "1",
        "the same Discord user is permitted in another monthly reward run",
    )
    query(f"DELETE FROM bump_monthly_reward_runs WHERE id = {run_id}")
    require_equal(
        query(f"SELECT COUNT(*) FROM bump_monthly_reward_grants WHERE run_id = {run_id}"),
        "0",
        "deleting a monthly reward run cascades to its grants",
    )
    query(f"DELETE FROM bump_monthly_reward_runs WHERE id = {other_run_id}")
    query("DELETE FROM community_discord WHERE guild_id IN (101, 102)")
    query("DELETE FROM communities WHERE id IN (6101, 6102)")


def prove_identity_link_constraints() -> None:
    query("INSERT INTO users (id, display_name) VALUES (1, 'user-a'), (2, 'user-b'), (3, 'user-c'), (4, 'actor');")
    query("INSERT INTO user_identity_links (user_a_id, user_b_id, status, link_source, reason, linked_by_user_id) VALUES (1, 2, 'CONFIRMED', 'ADMIN', 'disposable test', 4);")
    expect_sql_failure(
        "INSERT INTO user_identity_links (user_a_id, user_b_id, status, link_source) VALUES (2, 2, 'CONFIRMED', 'ADMIN');",
        "identity edge endpoints must differ",
    )
    expect_sql_failure(
        "INSERT INTO user_identity_links (user_a_id, user_b_id, status, link_source) VALUES (2, 1, 'SUSPECTED', 'ADMIN');",
        "reverse direction cannot duplicate an active unordered pair",
    )
    query("INSERT INTO user_identity_links (user_a_id, user_b_id, status, link_source, linked_by_user_id) VALUES (2, 3, 'CONFIRMED', 'ADMIN', 4);")
    require_equal(
        query("SELECT COUNT(*) FROM user_identity_links WHERE status = 'CONFIRMED' AND revoked_at IS NULL;"),
        "2",
        "confirmed edges may form a transitive cluster",
    )
    expect_sql_failure(
        "INSERT INTO user_identity_links (user_a_id, user_b_id, status, link_source) VALUES (1, 999, 'CONFIRMED', 'ADMIN');",
        "endpoint foreign key is enforced",
    )
    query("UPDATE user_identity_links SET revoked_at = CURRENT_TIMESTAMP(6), revoked_by_user_id = 4, revocation_reason = 'test' WHERE user_a_id = 1 AND user_b_id = 2;")
    query("INSERT INTO user_identity_links (user_a_id, user_b_id, status, link_source, linked_by_user_id) VALUES (2, 1, 'SUSPECTED', 'ADMIN', 4);")
    require_equal(
        query("SELECT COUNT(*) FROM user_identity_links WHERE active_user_low_id = 1 AND active_user_high_id = 2;"),
        "1",
        "only the replacement direction is active after revocation",
    )
    require_equal(
        query("SELECT COUNT(*) FROM user_identity_links WHERE (user_a_id = 1 AND user_b_id = 2) OR (user_a_id = 2 AND user_b_id = 1);"),
        "2",
        "revoked edge history is preserved when the pair is linked again",
    )
    query("DELETE FROM user_identity_links; DELETE FROM users WHERE id IN (1, 2, 3, 4);")



def assert_theme_schema() -> None:
    for table in (
        "discord_themes",
        "discord_theme_assets",
        "discord_theme_resource_changes",
        "discord_theme_applications",
        "discord_theme_application_snapshots",
        "discord_theme_operations",
        "discord_theme_operation_steps",
        "discord_theme_active_guilds",
        "discord_theme_guild_locks",
    ):
        assert_table_exists(table)

    assert_index(
        "discord_themes",
        "uq_discord_themes_guild_active_name",
        "0",
        "guild_id,active_name",
    )
    assert_index(
        "discord_theme_assets",
        "uq_discord_theme_asset_key",
        "0",
        "storage_key",
    )
    assert_index(
        "discord_theme_resource_changes",
        "uq_discord_theme_resource",
        "0",
        "theme_id,resource_type,resource_discord_id",
    )
    assert_index(
        "discord_theme_application_snapshots",
        "uq_discord_theme_snapshot_resource",
        "0",
        "application_id,resource_type,resource_discord_id",
    )
    assert_index(
        "discord_theme_operations",
        "uq_discord_theme_operation_key",
        "0",
        "guild_id,operation_key",
    )
    assert_index(
        "discord_theme_operations",
        "uq_discord_theme_operation_guild_id_app",
        "0",
        "guild_id,id,application_id",
    )
    assert_index(
        "discord_theme_active_guilds",
        "PRIMARY",
        "0",
        "guild_id",
    )
    assert_index(
        "discord_theme_guild_locks",
        "PRIMARY",
        "0",
        "guild_id",
    )
    assert_foreign_key(
        "discord_theme_resource_changes",
        "fk_discord_theme_resource_theme",
        "discord_themes",
        "id",
        "CASCADE",
        "RESTRICT",
    )
    require_equal(
        query(
            "SELECT CHARACTER_SET_NAME FROM information_schema.columns "
            "WHERE table_schema=DATABASE() "
            "AND table_name='discord_theme_resource_changes' "
            "AND column_name='target_name'"
        ),
        "utf8mb4",
        "Theme target names support full Discord Unicode/emoji",
    )
    assert_foreign_key(
        "discord_theme_application_snapshots",
        "fk_discord_theme_snapshot_application",
        "discord_theme_applications",
        "id",
        "CASCADE",
        "RESTRICT",
    )
    require_equal(
        query(
            "SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY ORDINAL_POSITION SEPARATOR ',') "
            "FROM information_schema.KEY_COLUMN_USAGE "
            "WHERE CONSTRAINT_SCHEMA=DATABASE() "
            "AND TABLE_NAME='discord_theme_operation_steps' "
            "AND CONSTRAINT_NAME='fk_discord_theme_operation_step_operation'"
        ),
        "guild_id,operation_id",
        "Theme operation steps are tenant-bound to operation guild",
    )

    require_equal(
        query(
            "SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY ORDINAL_POSITION SEPARATOR ',') "
            "FROM information_schema.KEY_COLUMN_USAGE "
            "WHERE CONSTRAINT_SCHEMA=DATABASE() "
            "AND TABLE_NAME='discord_theme_assets' "
            "AND CONSTRAINT_NAME='fk_discord_theme_asset_theme'"
        ),
        "guild_id,theme_id",
        "Theme assets are tenant-bound by composite FK",
    )
    require_equal(
        query(
            "SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY ORDINAL_POSITION SEPARATOR ',') "
            "FROM information_schema.KEY_COLUMN_USAGE "
            "WHERE CONSTRAINT_SCHEMA=DATABASE() "
            "AND TABLE_NAME='discord_theme_applications' "
            "AND CONSTRAINT_NAME='fk_discord_theme_app_theme'"
        ),
        "guild_id,theme_id",
        "Theme applications are tenant-bound to Theme guild",
    )
    require_equal(
        query(
            "SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY ORDINAL_POSITION SEPARATOR ',') "
            "FROM information_schema.KEY_COLUMN_USAGE "
            "WHERE CONSTRAINT_SCHEMA=DATABASE() "
            "AND TABLE_NAME='discord_theme_operations' "
            "AND CONSTRAINT_NAME='fk_discord_theme_operation_application'"
        ),
        "guild_id,application_id",
        "Theme operations are tenant-bound to application guild",
    )
    require_equal(
        query(
            "SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY ORDINAL_POSITION SEPARATOR ',') "
            "FROM information_schema.KEY_COLUMN_USAGE "
            "WHERE CONSTRAINT_SCHEMA=DATABASE() "
            "AND TABLE_NAME='discord_theme_active_guilds' "
            "AND CONSTRAINT_NAME='fk_discord_theme_active_application'"
        ),
        "guild_id,application_id",
        "Active Theme pointer cannot cross guilds",
    )
    require_equal(
        query(
            "SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY ORDINAL_POSITION SEPARATOR ',') "
            "FROM information_schema.KEY_COLUMN_USAGE "
            "WHERE CONSTRAINT_SCHEMA=DATABASE() "
            "AND TABLE_NAME='discord_theme_guild_locks' "
            "AND CONSTRAINT_NAME='fk_discord_theme_lock_operation'"
        ),
        "guild_id,operation_id,application_id",
        "Theme lock must match the exact guild operation application",
    )

    assert_column(
        "discord_theme_applications",
        "rollback_assets_cleaned_at",
        ("datetime(6)", "YES", "NULL"),
    )
    assert_column(
        "discord_theme_operations",
        "requested_audited_at",
        ("datetime(6)", "YES", "NULL"),
    )
    assert_column(
        "discord_theme_operations",
        "completion_audited_at",
        ("datetime(6)", "YES", "NULL"),
    )


def prove_theme_schema_constraints() -> None:
    query(
        "INSERT INTO discord_themes "
        "(id,guild_id,name,icon_action,banner_action,created_by_discord_user_id) "
        "VALUES "
        "(70001,7001,'Halloween','UNCHANGED','UNCHANGED',9001),"
        "(70002,7002,'Halloween','UNCHANGED','UNCHANGED',9002)"
    )
    require_equal(
        query("SELECT COUNT(*) FROM discord_themes WHERE name='Halloween'"),
        "2",
        "the same Theme name is isolated by guild",
    )
    expect_sql_failure(
        "INSERT INTO discord_themes "
        "(guild_id,name,icon_action,banner_action,created_by_discord_user_id) "
        "VALUES (7001,'Halloween','UNCHANGED','UNCHANGED',9003)",
        "duplicate Theme name in the same guild is rejected",
    )

    query(
        "INSERT INTO discord_theme_assets "
        "(id,theme_id,guild_id,asset_type,storage_key,content_type,sha256,size_bytes) "
        "VALUES "
        "(70501,70001,7001,'ICON','themes/7001/70001/icon/v1.png',"
        "'image/png',REPEAT('a',64),128),"
        "(70502,70001,7001,'ICON','themes/7001/70001/icon/v2.png',"
        "'image/png',REPEAT('b',64),256)"
    )
    require_equal(
        query("SELECT COUNT(*) FROM discord_theme_assets WHERE theme_id=70001 AND asset_type='ICON'"),
        "2",
        "Theme keeps versioned permanent assets while the Theme exists",
    )

    expect_sql_failure(
        "INSERT INTO discord_theme_assets "
        "(theme_id,guild_id,asset_type,storage_key,content_type,sha256,size_bytes) "
        "VALUES (70001,7002,'ICON','themes/cross-guild.png','image/png',REPEAT('c',64),64)",
        "Theme asset cannot claim a Theme from another guild",
    )

    query(
        "INSERT INTO discord_theme_resource_changes "
        "(theme_id,resource_type,resource_discord_id,target_name) VALUES "
        "(70001,'CHANNEL',71001,'halloween-geral'),"
        "(70001,'CATEGORY',71002,'Halloween'),"
        "(70001,'ROLE',71003,'Guardiao da Noite')"
    )
    expect_sql_failure(
        "INSERT INTO discord_theme_resource_changes "
        "(theme_id,resource_type,resource_discord_id,target_name) "
        "VALUES (70001,'ROLE',71003,'Outro nome')",
        "a Theme cannot target the same Discord resource twice",
    )

    expect_sql_failure(
        "INSERT INTO discord_theme_applications "
        "(theme_id,guild_id,actor_discord_user_id,status,frozen_definition_json) "
        "VALUES (70001,7002,9002,'APPLYING','{}')",
        "Theme application cannot point to another guild Theme",
    )
    query(
        "INSERT INTO discord_theme_applications "
        "(id,theme_id,guild_id,actor_discord_user_id,status,frozen_definition_json) "
        "VALUES "
        "(72001,70001,7001,9001,'APPLYING','{}'),"
        "(72002,70002,7002,9002,'APPLYING','{}')"
    )
    query(
        "INSERT INTO discord_theme_active_guilds (guild_id,application_id) VALUES "
        "(7001,72001),(7002,72002)"
    )
    expect_sql_failure(
        "INSERT INTO discord_theme_active_guilds (guild_id,application_id) "
        "VALUES (7001,72002)",
        "only one ThemeApplication can be active for a guild",
    )
    expect_sql_failure(
        "INSERT INTO discord_theme_active_guilds (guild_id,application_id) "
        "VALUES (7003,72002)",
        "active Theme pointer cannot reference an application from another guild",
    )

    query(
        "INSERT INTO discord_theme_application_snapshots "
        "(application_id,resource_type,resource_discord_id,before_value,applied_value) "
        "VALUES (72001,'CHANNEL',71001,'geral','halloween-geral')"
    )
    expect_sql_failure(
        "INSERT INTO discord_theme_application_snapshots "
        "(application_id,resource_type,resource_discord_id,before_value,applied_value) "
        "VALUES (72001,'CHANNEL',71001,'outro','duplicado')",
        "rollback snapshot is unique per application resource",
    )

    expect_sql_failure(
        "INSERT INTO discord_theme_operations "
        "(application_id,guild_id,operation_key,operation_type,actor_discord_user_id,status) "
        "VALUES (72001,7002,'cross-guild-op','APPLY',9002,'PENDING')",
        "Theme operation cannot point to another guild application",
    )
    query(
        "INSERT INTO discord_theme_operations "
        "(id,application_id,guild_id,operation_key,operation_type,"
        "actor_discord_user_id,status) VALUES "
        "(73001,72001,7001,'apply-7001','APPLY',9001,'PENDING')"
    )
    expect_sql_failure(
        "INSERT INTO discord_theme_guild_locks "
        "(guild_id,lock_token,operation_type,operation_id,application_id,expires_at) "
        "VALUES (7002,'cross-lock','APPLY',73001,72001,DATE_ADD(UTC_TIMESTAMP(6),INTERVAL 5 MINUTE))",
        "Theme lock cannot reference another guild operation",
    )
    expect_sql_failure(
        "INSERT INTO discord_theme_operations "
        "(application_id,guild_id,operation_key,operation_type,"
        "actor_discord_user_id,status) VALUES "
        "(72001,7001,'apply-7001','APPLY',9001,'PENDING')",
        "Theme operation idempotency key is unique inside a guild",
    )
    query(
        "INSERT INTO discord_theme_operations "
        "(application_id,guild_id,operation_key,operation_type,"
        "actor_discord_user_id,status) VALUES "
        "(72002,7002,'apply-7001','APPLY',9002,'PENDING')"
    )

    require_equal(
        query(
            "SELECT COUNT(*) FROM information_schema.tables "
            "WHERE table_schema=DATABASE() AND table_name LIKE 'backup_%' "
            "AND table_name IN ("
            "'discord_themes','discord_theme_resource_changes',"
            "'discord_theme_applications','discord_theme_application_snapshots')"
        ),
        "0",
        "Theme schema has no Backup table dependency",
    )

    query("DELETE FROM discord_theme_active_guilds WHERE guild_id IN (7001,7002)")
    query("DELETE FROM discord_theme_operations WHERE guild_id IN (7001,7002)")
    query("DELETE FROM discord_theme_application_snapshots WHERE application_id IN (72001,72002)")
    query("DELETE FROM discord_theme_applications WHERE id IN (72001,72002)")
    query("UPDATE discord_themes SET deleted_at=UTC_TIMESTAMP(6) WHERE id=70001")
    query(
        "INSERT INTO discord_themes "
        "(id,guild_id,name,icon_action,banner_action,created_by_discord_user_id) "
        "VALUES (70003,7001,'Halloween','UNCHANGED','UNCHANGED',9003)"
    )
    require_equal(
        query("SELECT COUNT(*) FROM discord_themes WHERE guild_id=7001 AND name='Halloween'"),
        "2",
        "deleted Theme name can be reused by a new active Theme",
    )
    query("DELETE FROM discord_themes WHERE id IN (70001,70002,70003)")
    require_equal(
        query("SELECT COUNT(*) FROM discord_theme_assets WHERE theme_id=70001"),
        "0",
        "Theme asset versions cascade when the Theme is deleted",
    )


def assert_backup_schema() -> None:
    for table in (
        "backup_discord",
        "backup_roles",
        "backup_channels",
        "backup_overwrites",
        "backup_server_settings",
        "backup_restore_operations",
        "backup_snapshot_operations",
        "backup_operation_steps",
        "backup_guild_locks",
    ):
        assert_table_exists(table)

    assert_column("backup_discord", "backup_type", ("varchar(20)", "NO", "'normal'"))
    assert_column("backup_discord", "created_by_discord_user_id", ("bigint(20)", "YES", "NULL"))
    assert_column("backup_discord", "idempotency_key", ("varchar(96)", "YES", "NULL"))
    assert_column("backup_discord", "creation_audited_at", ("datetime(6)", "YES", "NULL"))
    assert_index("backup_discord", "idx_backup_discord_guild_type", "1", "guild_id,backup_type,id")
    assert_index(
        "backup_discord",
        "uq_backup_discord_guild_idempotency",
        "0",
        "guild_id,idempotency_key",
    )

    assert_index("backup_roles", "idx_backup_roles_backup", "1", "backup_id")
    assert_index("backup_channels", "idx_backup_channels_backup", "1", "backup_id")
    assert_index("backup_overwrites", "idx_backup_overwrites_channel", "1", "channel_id")
    assert_index("backup_overwrites", "idx_backup_overwrites_role", "1", "role_id")
    assert_index(
        "backup_overwrites",
        "idx_backup_overwrites_target_discord",
        "1",
        "target_discord_id",
    )
    assert_column(
        "backup_overwrites",
        "target_type",
        ("varchar(24)", "NO", "'ROLE'"),
    )
    assert_column(
        "backup_overwrites",
        "target_discord_id",
        ("bigint(20)", "YES", "NULL"),
    )
    assert_column(
        "backup_overwrites",
        "role_id",
        ("int(11)", "YES", "NULL"),
    )

    assert_foreign_key(
        "backup_roles",
        "fk_backup_roles_backup",
        "backup_discord",
        "id",
        "CASCADE",
        "RESTRICT",
    )
    assert_foreign_key(
        "backup_channels",
        "fk_backup_channels_backup",
        "backup_discord",
        "id",
        "CASCADE",
        "RESTRICT",
    )
    assert_foreign_key(
        "backup_overwrites",
        "fk_backup_overwrites_channel",
        "backup_channels",
        "id",
        "CASCADE",
        "RESTRICT",
    )
    assert_foreign_key(
        "backup_overwrites",
        "fk_backup_overwrites_role",
        "backup_roles",
        "id",
        "CASCADE",
        "RESTRICT",
    )

    assert_column(
        "backup_server_settings",
        "periodicity_frequency",
        ("varchar(10)", "NO", "'weekly'"),
    )
    assert_column("backup_server_settings", "bot_removed_at", ("datetime(6)", "YES", "NULL"))
    assert_column("backup_server_settings", "purge_after", ("datetime(6)", "YES", "NULL"))
    assert_index(
        "backup_server_settings",
        "idx_backup_server_settings_purge_after",
        "1",
        "purge_after",
    )
    assert_index(
        "backup_server_settings",
        "uq_backup_server_settings_guild",
        "0",
        "guild_id",
    )
    assert_column(
        "backup_restore_operations",
        "requested_audited_at",
        ("datetime(6)", "YES", "NULL"),
    )
    assert_column(
        "backup_restore_operations",
        "completion_audited_at",
        ("datetime(6)", "YES", "NULL"),
    )
    assert_column("backup_restore_operations", "progress_current", ("int(11)", "NO", "0"))
    assert_column("backup_restore_operations", "progress_total", ("int(11)", "NO", "0"))
    assert_column("backup_restore_operations", "current_step", ("varchar(96)", "YES", "NULL"))
    assert_index(
        "backup_restore_operations",
        "uq_backup_restore_guild_operation_key",
        "0",
        "guild_id,operation_key",
    )
    assert_index(
        "backup_restore_operations",
        "idx_backup_restore_guild_status",
        "1",
        "guild_id,status,id",
    )
    assert_foreign_key(
        "backup_restore_operations",
        "fk_backup_restore_actor",
        "users",
        "id",
        "SET NULL",
        "RESTRICT",
    )
    assert_index(
        "backup_snapshot_operations",
        "uq_backup_snapshot_guild_operation_key",
        "0",
        "guild_id,operation_key",
    )
    assert_index(
        "backup_snapshot_operations",
        "idx_backup_snapshot_guild_status",
        "1",
        "guild_id,status,id",
    )
    assert_foreign_key(
        "backup_snapshot_operations",
        "fk_backup_snapshot_actor",
        "users",
        "id",
        "SET NULL",
        "RESTRICT",
    )
    assert_index(
        "backup_operation_steps",
        "idx_backup_operation_steps_operation",
        "1",
        "guild_id,operation_kind,operation_id,id",
    )
    assert_index(
        "backup_guild_locks",
        "PRIMARY",
        "0",
        "guild_id",
    )


def prove_backup_schema_constraints() -> None:
    # The disposable fixture represents an actually-populated legacy runtime schema.
    require_equal(
        query(
            "SELECT CONCAT(original_name, '|', backup_type, '|', "
            "COALESCE(created_by_discord_user_id, 'NULL'), '|', "
            "COALESCE(idempotency_key, 'NULL')) "
            "FROM backup_discord WHERE id = 9001"
        ),
        "Legacy populated backup|normal|NULL|NULL",
        "legacy Backup master row survives formalization",
    )
    require_equal(
        query(
            "SELECT COUNT(*) FROM backup_roles WHERE id = 9101 AND backup_id = 9001"
        ),
        "1",
        "legacy Backup role survives formalization",
    )
    require_equal(
        query(
            "SELECT COUNT(*) FROM backup_roles WHERE id = 9100 AND backup_id = 9001"
        ),
        "0",
        "legacy @everyone row is removed from restorable Backup roles",
    )
    require_equal(
        query(
            "SELECT COUNT(*) FROM backup_channels WHERE id = 9201 AND backup_id = 9001"
        ),
        "1",
        "legacy Backup channel survives formalization",
    )
    require_equal(
        query(
            "SELECT CONCAT(target_type, '|', target_discord_id, '|', role_id) "
            "FROM backup_overwrites WHERE id = 9301 AND channel_id = 9201"
        ),
        "ROLE|99101|9101",
        "legacy normal-role Backup overwrite survives target classification",
    )
    require_equal(
        query(
            "SELECT CONCAT(target_type, '|', target_discord_id, '|', "
            "COALESCE(role_id, 'NULL')) "
            "FROM backup_overwrites WHERE id = 9300 AND channel_id = 9201"
        ),
        "EVERYONE|99001|NULL",
        "legacy @everyone Backup overwrite is detached from backup_roles",
    )
    require_equal(
        query(
            "SELECT CONCAT(max_normal_backups, '|', max_periodic_backups, '|', "
            "periodic_backups_enabled, '|', periodicity_minutes, '|', periodicity_frequency) "
            "FROM backup_server_settings WHERE guild_id = 99001"
        ),
        "1|1|1|1440|daily",
        "legacy Backup settings keep frequency/enabled state while policy is canonicalized to one snapshot per type",
    )

    query(
        "INSERT INTO backup_server_settings (guild_id) VALUES (99002)"
    )
    require_equal(
        query(
            "SELECT CONCAT(max_normal_backups, '|', max_periodic_backups, '|', "
            "periodic_backups_enabled, '|', periodicity_minutes, '|', periodicity_frequency) "
            "FROM backup_server_settings WHERE guild_id = 99002"
        ),
        "1|1|0|10080|weekly",
        "Backup settings default to one manual, one periodic and periodic disabled",
    )
    expect_sql_failure(
        "INSERT INTO backup_server_settings (guild_id) VALUES (99002)",
        "Backup settings allow one row per guild",
    )

    query(
        "UPDATE backup_server_settings "
        "SET bot_removed_at=UTC_TIMESTAMP(6), "
        "purge_after=DATE_ADD(UTC_TIMESTAMP(6), INTERVAL 7 DAY) "
        "WHERE guild_id=99002"
    )
    require_equal(
        query(
            "SELECT CASE WHEN bot_removed_at IS NOT NULL "
            "AND purge_after > bot_removed_at THEN '1' ELSE '0' END "
            "FROM backup_server_settings WHERE guild_id=99002"
        ),
        "1",
        "Backup guild removal retention deadline is durable",
    )

    query(
        "INSERT INTO backup_discord "
        "(id, guild_id, original_name, backup_type, idempotency_key) "
        "VALUES (9002, 99002, 'Idempotent snapshot', 'normal', 'request-1')"
    )
    expect_sql_failure(
        "INSERT INTO backup_discord "
        "(guild_id, original_name, backup_type, idempotency_key) "
        "VALUES (99002, 'Duplicate request', 'normal', 'request-1')",
        "Backup snapshot idempotency key is unique inside one guild",
    )
    query(
        "INSERT INTO backup_discord "
        "(id, guild_id, original_name, backup_type, idempotency_key) "
        "VALUES (9003, 99003, 'Same key other guild', 'normal', 'request-1')"
    )

    query(
        "INSERT INTO backup_roles "
        "(id, backup_id, discord_id, name, color, permissions, position, hoist, mentionable) "
        "VALUES (9102, 9002, 99102, 'Cascade Role', 0, 0, 1, 0, 0)"
    )
    query(
        "INSERT INTO backup_channels "
        "(id, backup_id, discord_id, name, type, position, nsfw) "
        "VALUES (9202, 9002, 99202, 'cascade-channel', 0, 1, 0)"
    )
    query(
        "INSERT INTO backup_overwrites "
        "(id, channel_id, role_name, target_type, target_discord_id, role_id, allow_bits, deny_bits) "
        "VALUES (9302, 9202, 'Cascade Role', 'ROLE', 99102, 9102, 1, 0)"
    )
    query(
        "INSERT INTO backup_overwrites "
        "(id, channel_id, role_name, target_type, target_discord_id, role_id, allow_bits, deny_bits) "
        "VALUES (9303, 9202, '@everyone', 'EVERYONE', 99002, NULL, 0, 1)"
    )
    expect_sql_failure(
        "INSERT INTO backup_overwrites "
        "(channel_id, role_name, target_type, target_discord_id, role_id, allow_bits, deny_bits) "
        "VALUES (9202, 'Invalid everyone', 'EVERYONE', 99002, 9102, 0, 1)",
        "@everyone Backup overwrite cannot point to backup_roles",
    )
    expect_sql_failure(
        "INSERT INTO backup_overwrites "
        "(channel_id, role_name, target_type, target_discord_id, role_id, allow_bits, deny_bits) "
        "VALUES (9202, 'Invalid role', 'ROLE', 99102, NULL, 1, 0)",
        "normal Backup overwrite requires backup_roles reference",
    )
    query("DELETE FROM backup_discord WHERE id = 9002")
    require_equal(
        query(
            "SELECT CONCAT("
            "(SELECT COUNT(*) FROM backup_roles WHERE id = 9102), '|', "
            "(SELECT COUNT(*) FROM backup_channels WHERE id = 9202), '|', "
            "(SELECT COUNT(*) FROM backup_overwrites WHERE id IN (9302,9303)))"
        ),
        "0|0|0",
        "deleting a Backup snapshot cascades to roles, channels and overwrites",
    )

    query(
        "INSERT INTO backup_restore_operations "
        "(guild_id, backup_id, operation_key, scope, actor_discord_user_id, status) "
        "VALUES (99001, 9001, 'restore-1', 'full', 99111, 'PENDING')"
    )
    expect_sql_failure(
        "INSERT INTO backup_restore_operations "
        "(guild_id, backup_id, operation_key, scope, actor_discord_user_id, status) "
        "VALUES (99001, 9001, 'restore-1', 'roles', 99111, 'PENDING')",
        "restore retries cannot duplicate one guild operation key",
    )
    query(
        "INSERT INTO backup_restore_operations "
        "(guild_id, backup_id, operation_key, scope, actor_discord_user_id, status) "
        "VALUES (99003, 9003, 'restore-1', 'roles', 99333, 'PENDING')"
    )

    query(
        "INSERT INTO backup_snapshot_operations "
        "(guild_id, operation_key, backup_type, requested_name, actor_discord_user_id, status, progress_current, progress_total, current_step) "
        "VALUES (99001, 'snapshot-1', 'normal', 'Tracked snapshot', 99111, 'RUNNING', 2, 5, 'PERSISTING')"
    )
    snapshot_operation_id = query(
        "SELECT id FROM backup_snapshot_operations "
        "WHERE guild_id=99001 AND operation_key='snapshot-1'"
    )
    query(
        "INSERT INTO backup_operation_steps "
        "(guild_id, operation_kind, operation_id, step_code, step_status, message, progress_current, progress_total) "
        f"VALUES (99001, 'SNAPSHOT', {snapshot_operation_id}, 'PERSISTING', 'RUNNING', 'Persistindo snapshot', 2, 5)"
    )
    require_equal(
        query(
            "SELECT CONCAT(progress_current, '|', progress_total, '|', current_step) "
            "FROM backup_snapshot_operations WHERE guild_id=99001 AND operation_key='snapshot-1'"
        ),
        "2|5|PERSISTING",
        "snapshot operation progress is durable",
    )
    require_equal(
        query(
            "SELECT COUNT(*) FROM backup_operation_steps "
            "WHERE guild_id=99001 AND operation_kind='SNAPSHOT'"
        ),
        "1",
        "Backup operation steps are durable and guild-scoped",
    )

    query(
        "INSERT INTO backup_guild_locks "
        "(guild_id, lock_token, operation_type, expires_at) "
        "VALUES (99001, 'token-1', 'restore', DATE_ADD(UTC_TIMESTAMP(6), INTERVAL 1 HOUR))"
    )
    expect_sql_failure(
        "INSERT INTO backup_guild_locks "
        "(guild_id, lock_token, operation_type, expires_at) "
        "VALUES (99001, 'token-2', 'snapshot', DATE_ADD(UTC_TIMESTAMP(6), INTERVAL 1 HOUR))",
        "one durable Backup operation lock exists per guild",
    )

    query("DELETE FROM backup_guild_locks WHERE guild_id = 99001")
    query("DELETE FROM backup_operation_steps WHERE guild_id = 99001")
    query("DELETE FROM backup_snapshot_operations WHERE guild_id = 99001")
    query("DELETE FROM backup_restore_operations WHERE guild_id IN (99001, 99003)")
    query("DELETE FROM backup_discord WHERE id = 9003")
    query("DELETE FROM backup_server_settings WHERE guild_id = 99002")


def down() -> None:
    compose("down", "--volumes", "--remove-orphans", check=False)


def assert_no_resources_remain() -> None:
    containers = run_command(
        [
            "docker",
            "ps",
            "--all",
            "--filter",
            f"label=com.docker.compose.project={PROJECT_NAME}",
            "--format",
            "{{.ID}}",
        ],
        show_output=False,
    ).stdout.strip()
    volumes = run_command(
        [
            "docker",
            "volume",
            "ls",
            "--filter",
            f"label=com.docker.compose.project={PROJECT_NAME}",
            "--format",
            "{{.Name}}",
        ],
        show_output=False,
    ).stdout.strip()
    if containers or volumes:
        raise SmokeFailure("teardown left Compose containers or volumes behind")
    print("PASS: teardown left no Compose container or volume behind")


def run_smoke() -> None:
    down()
    start_empty_database()

    compose("run", "--rm", "flyway", "info")
    compose("run", "--rm", "flyway", "migrate")
    history_count, checksum = assert_migrated_state()
    prove_membership_uniqueness_constraint()
    prove_team_role_assignment_constraints()
    prove_community_authorization_constraints()
    prove_community_member_note_constraints()
    prove_community_network_sync_constraints()
    prove_network_membership_constraints()
    prove_user_ban_effect_constraints()
    prove_user_ban_reason_capacity()
    prove_user_warning_repetition()
    prove_bump_monthly_reward_ledger_constraints()
    prove_user_level_guild_isolation()
    assert_backup_schema()
    prove_backup_schema_constraints()
    assert_theme_schema()
    prove_theme_schema_constraints()
    compose("run", "--rm", "flyway", "info")
    compose("run", "--rm", "flyway", "validate")
    prove_identity_link_constraints()
    prove_checksum_mismatch_detection()
    compose("run", "--rm", "flyway", "validate")

    compose("run", "--rm", "flyway", "migrate")
    second_count, second_checksum = assert_migrated_state()
    require_equal(second_count, history_count, "second migrate is history-idempotent")
    require_equal(second_checksum, checksum, "second migrate preserves checksum")

    down()
    assert_no_resources_remain()

    print("Recreating the disposable environment for the existing Bump-schema proof.")
    start_empty_database()
    migrate_pre_bump_history()
    assert_pre_bump_history()
    prepare_existing_identity_link()
    prepare_existing_bump_schema()
    prepare_existing_xp_schema()
    prepare_existing_warning_schema()
    compose("run", "--rm", "flyway", "migrate")
    compose("run", "--rm", "flyway", "validate")
    assert_migrated_state()
    assert_existing_identity_link_sentinel()
    assert_existing_bump_sentinels()
    assert_existing_xp_sentinels()
    prove_membership_uniqueness_constraint()
    prove_team_role_assignment_constraints()
    prove_community_authorization_constraints()
    prove_community_member_note_constraints()
    prove_community_network_sync_constraints()
    prove_network_membership_constraints()
    prove_user_ban_effect_constraints()
    prove_user_ban_reason_capacity()
    prove_user_warning_repetition()
    prove_bump_monthly_reward_ledger_constraints()
    prove_user_level_guild_isolation()
    assert_backup_schema()
    assert_theme_schema()
    prove_theme_schema_constraints()
    prove_identity_link_constraints()


def main() -> int:
    preflight_accepted = False
    try:
        safety_preflight()
        preflight_accepted = True
        run_smoke()
    except SmokeFailure as exc:
        print(f"Smoke test failed: {exc}", file=sys.stderr)
        return_code = 1
    else:
        print("Flyway/MariaDB disposable smoke test passed.")
        return_code = 0
    finally:
        if preflight_accepted:
            try:
                down()
                assert_no_resources_remain()
            except SmokeFailure as cleanup_error:
                print(f"Cleanup verification failed: {cleanup_error}", file=sys.stderr)
                return_code = 1
    return return_code


if __name__ == "__main__":
    raise SystemExit(main())
