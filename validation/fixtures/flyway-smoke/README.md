# Flyway smoke fixture

Files in this directory are executable test fixtures only. They are deliberately isolated from `flyway/sql/`, use the impossible official date `00000000`, and may create only synthetic objects prefixed with `__brf_flyway_smoke_`.

They are not an official baseline or migration history and must never be deployed outside the disposable validation database.
