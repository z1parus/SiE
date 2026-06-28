#!/usr/bin/env bash
# Деплоит Edge Functions через Supabase Management API.
# Не требует supabase CLI — работает через curl + прокси.
#
# Использование:
#   ./functions-deploy.sh              — деплоит все функции
#   ./functions-deploy.sh telegram-auth ai-decompose — деплоит указанные
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUNCTIONS_DIR="$SCRIPT_DIR/../functions"

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

get_existing_slugs() {
  api_curl "$API/functions" | python3 -c "
import json,sys
for f in json.load(sys.stdin): print(f['slug'])
"
}

deploy_function() {
  local SLUG="$1"
  local FN_DIR="$FUNCTIONS_DIR/$SLUG"
  local INDEX_FILE="$FN_DIR/index.ts"

  if [ ! -f "$INDEX_FILE" ]; then
    echo "  ПРОПУСК: $INDEX_FILE не найден"
    return
  fi

  local BODY
  BODY=$(base64 -w 0 "$INDEX_FILE")

  local PAYLOAD
  if get_existing_slugs | grep -qx "$SLUG"; then
    # Обновляем существующую функцию
    PAYLOAD="{\"body\":\"$BODY\"}"
    RESULT=$(api_curl \
      -H "Content-Type: application/json" \
      -d "$PAYLOAD" \
      -X PATCH \
      "$API/functions/$SLUG")
    VERSION=$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['version'])")
    echo "  ✓ обновлена (версия $VERSION)"
  else
    # Создаём новую функцию
    PAYLOAD="{\"slug\":\"$SLUG\",\"name\":\"$SLUG\",\"verify_jwt\":true,\"body\":\"$BODY\"}"
    api_curl \
      -H "Content-Type: application/json" \
      -d "$PAYLOAD" \
      -X POST \
      "$API/functions" > /dev/null
    echo "  ✓ создана"
  fi
}

# Определяем список функций для деплоя
if [ "$#" -gt 0 ]; then
  TARGETS=("$@")
else
  TARGETS=()
  for DIR in "$FUNCTIONS_DIR"/*/; do
    [ -d "$DIR" ] && TARGETS+=("$(basename "$DIR")")
  done
fi

echo "Деплой ${#TARGETS[@]} функций в проект $REF..."
echo ""

for SLUG in "${TARGETS[@]}"; do
  echo "→ $SLUG"
  deploy_function "$SLUG"
done

echo ""
echo "Готово."
