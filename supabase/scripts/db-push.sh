#!/usr/bin/env bash
# Применяет неприменённые миграции через Supabase Management API.
# Не требует supabase CLI — работает через curl + прокси.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATIONS_DIR="$SCRIPT_DIR/../migrations"

TOKEN="${SUPABASE_ACCESS_TOKEN:?Нужна переменная SUPABASE_ACCESS_TOKEN}"
REF="${SUPABASE_PROJECT_REF:?Нужна переменная SUPABASE_PROJECT_REF}"
PROXY="${HTTPS_PROXY:-}"
CA="${SSL_CERT_FILE:-}"

API="https://api.supabase.com/v1/projects/$REF"

api_curl() {
  local EXTRA_ARGS=()
  [ -n "$PROXY" ] && EXTRA_ARGS+=(-x "$PROXY")
  [ -n "$CA" ] && EXTRA_ARGS+=("--cacert" "$CA")
  curl -fsSL "${EXTRA_ARGS[@]}" \
    -H "Authorization: Bearer $TOKEN" \
    "$@"
}

query() {
  local SQL="$1"
  local JSON_SQL
  JSON_SQL=$(python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$SQL")
  api_curl \
    -H "Content-Type: application/json" \
    -d "{\"query\":$JSON_SQL}" \
    "$API/database/query"
}

echo "Получаю список применённых миграций..."
APPLIED=$(query "SELECT version FROM supabase_migrations.schema_migrations ORDER BY version" \
  | python3 -c "import json,sys; [print(r['version']) for r in json.load(sys.stdin)]")

APPLIED_COUNT=$(echo "$APPLIED" | grep -c . 2>/dev/null || echo 0)
echo "Уже применено: $APPLIED_COUNT миграций"

PENDING=0
for SQL_FILE in $(ls "$MIGRATIONS_DIR"/*.sql 2>/dev/null | sort); do
  FILENAME=$(basename "$SQL_FILE")
  VERSION="${FILENAME%%_*}"

  if echo "$APPLIED" | grep -qx "$VERSION"; then
    continue
  fi

  echo ""
  echo "Применяю: $FILENAME"

  if ! query "$(cat "$SQL_FILE")" > /dev/null; then
    echo "ОШИБКА при применении $FILENAME"
    exit 1
  fi

  # Регистрируем миграцию в таблице миграций
  NAME="${FILENAME%.sql}"
  NAME="${NAME#*_}"
  query "INSERT INTO supabase_migrations.schema_migrations (version, name, statements) VALUES ('$VERSION', '$NAME', ARRAY[]::text[])" > /dev/null

  echo "✓ $FILENAME применена"
  PENDING=$((PENDING + 1))
done

echo ""
if [ "$PENDING" -eq 0 ]; then
  echo "Все миграции уже применены."
else
  echo "Применено новых миграций: $PENDING"
fi
