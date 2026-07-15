#!/usr/bin/env bash
# _preflight_checks.sh — sourced (not run directly) by install_offline.sh and
# start_stack.sh. Catches the single most common offline-install failure
# class before `docker compose up` ever runs: an empty or weak
# DB_SA_PASSWORD/DB_PASSWORD, which makes SQL Server reject the login,
# fail its healthcheck, and produce a confusing
# "dependency failed to start: container ... is unhealthy" error with no
# obvious link back to the real cause.
#
# Must be sourced AFTER compose/.env has been loaded into the environment.

# Returns 0 if $1 meets SQL Server's password complexity policy: 8+ chars,
# at least 3 of {uppercase, lowercase, digit, symbol}.
_password_is_strong_enough() {
  local pw="$1"
  [ "${#pw}" -ge 8 ] || return 1
  local classes=0
  [[ "$pw" =~ [A-Z] ]] && classes=$((classes + 1))
  [[ "$pw" =~ [a-z] ]] && classes=$((classes + 1))
  [[ "$pw" =~ [0-9] ]] && classes=$((classes + 1))
  [[ "$pw" =~ [^A-Za-z0-9] ]] && classes=$((classes + 1))
  [ "$classes" -ge 3 ]
}

run_preflight_checks() {
  local fail=0

  for name in DB_SA_PASSWORD DB_PASSWORD; do
    local value="${!name:-}"
    if [ -z "$value" ]; then
      echo "ERROR: ${name} is empty in compose/.env." >&2
      echo "       Set a real password before running this script — an empty" >&2
      echo "       value here is guaranteed to make the sqlserver container fail" >&2
      echo "       its healthcheck (SQL Server rejects blank/weak passwords)." >&2
      fail=1
    elif ! _password_is_strong_enough "$value"; then
      echo "ERROR: ${name} does not meet SQL Server's password complexity policy." >&2
      echo "       Needs 8+ characters and at least 3 of: uppercase, lowercase," >&2
      echo "       digit, symbol. A weak password here will make the sqlserver" >&2
      echo "       container fail its healthcheck exactly like an empty one." >&2
      fail=1
    fi
  done

  if [ -z "${JWT_SECRET:-}" ]; then
    echo "WARNING: JWT_SECRET is empty in compose/.env — the backend will fall" >&2
    echo "         back to an insecure hardcoded default. Set a real random" >&2
    echo "         value before going to production (this is not a hard failure)." >&2
  fi

  if [ "$fail" -ne 0 ]; then
    echo >&2
    echo "Fix compose/.env and re-run this script. See documentation/TROUBLESHOOTING.md" >&2
    echo "if sqlserver already failed once before you fixed this — a stale data" >&2
    echo "volume from that failed attempt must be removed first (docker compose down -v)," >&2
    echo "or SQL Server will skip re-initializing the password and fail again." >&2
    exit 1
  fi
}
