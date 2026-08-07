#!/usr/bin/env bash
# A real Postgres to run supabase/tests/*.sql against, without Docker.
#
# WHY THIS EXISTS. `supabase test db` needs the Docker daemon, and there is none in the session
# container. The consequence, recorded in E2's task list, was that a negative test could only be
# *seen* to fail by pushing it in its own commit and reading a pull request's CI — one extra push
# and a round trip for every red the constitution requires. This script removes that.
#
# It is not `supabase start`. It is a Postgres of the SAME MAJOR VERSION Supabase runs, plus the
# smallest set of Supabase objects the migrations actually reference. That difference is the whole
# caveat:
#
#   WHAT IT PROVES        table shape, CHECK constraints, NOT NULL, triggers, and the pgTAP suites
#                         that exercise them.
#   WHAT IT DOES NOT      that the real Supabase Auth issues the JWTs these policies read, that
#                         PostgREST exposes what we think, or that a preview branch behaves the
#                         same. The Authorization workflow on a pull request remains the authority
#                         for RLS. This is the fast loop, not the verdict.
#
# A local pass is therefore necessary, not sufficient. Do not use it to skip the pull request run.
#
#   scripts/local-db.sh start          bring a cluster up and apply migrations + seed
#   scripts/local-db.sh test [file]    run every supabase/tests/*.sql, or just one
#   scripts/local-db.sh psql           an interactive shell on it
#   scripts/local-db.sh stop           tear it down

set -uo pipefail

# THE MAJOR VERSION IS READ FROM supabase/config.toml, NEVER HARDCODED HERE.
#
# This harness was first built on Postgres 16 while config.toml pinned Supabase to 17, so every
# local run was exercising the migrations against a different major version than the one they would
# be applied to — the classic source of "it worked locally", and the same mistake config.toml itself
# records having made in the opposite direction on 2026-08-01. Deriving it from the pin means the
# two cannot drift apart again without the file that defines the pin being edited.
PG_MAJOR=$(grep -E '^major_version[[:space:]]*=' "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/supabase/config.toml" \
           | head -1 | tr -dc '0-9')
PGBIN="/usr/lib/postgresql/${PG_MAJOR}/bin"
CLUSTER="${KAFOO_PGDATA:-/tmp/kafoo-pg}"
SOCKET="${CLUSTER}/socket"
DB=kafoo_test
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export PGHOST="${SOCKET}"
export PGDATABASE="${DB}"
export PGUSER=postgres

log() { printf '   %s\n' "$*"; }

# WHAT THE CLUSTER WAS BUILT FROM, so a reused one cannot silently answer for a stale schema.
#
# `start` returned early on "already running" and stopped there until 2026-08-06. A migration that
# landed after the cluster was created was therefore never applied, and `test` did not notice: it
# exited 0 and reported 69 passing assertions against a schema missing a column, when the true count
# was 76. Nothing warned, because a stale run and a correct run print identically — the discrepancy
# surfaced only because a documented number had been derived independently and did not match.
#
# A cached environment turns "the tests passed" into "the tests passed against whatever this
# environment happens to contain". The exit code cannot tell those apart, so the harness has to.
STAMP="${CLUSTER}/built-from.sha256"
built_from() {
  cat "${REPO}"/supabase/migrations/*.sql "${REPO}/supabase/seed.sql" \
      "${REPO}/scripts/local-db-bootstrap.sql" 2>/dev/null | sha256sum | cut -d' ' -f1
}

stop_cluster() {
  su kafoopg -s /bin/bash -c "${PGBIN}/pg_ctl -D '${CLUSTER}/data' -m immediate stop" >/dev/null 2>&1
  rm -rf "${CLUSTER}"
}

start() {
  if [ ! -x "${PGBIN}/initdb" ]; then
    echo "PostgreSQL ${PG_MAJOR} is not installed, and supabase/config.toml pins that version." >&2
    echo "Run ./scripts/install-toolchain.sh, which adds the PostgreSQL apt repository and" >&2
    echo "installs postgresql-${PG_MAJOR}, postgresql-${PG_MAJOR}-pgtap and" >&2
    echo "postgresql-${PG_MAJOR}-pgvector." >&2
    return 1
  fi

  # Named separately from the initdb check because the failure it prevents looks nothing like a
  # missing Postgres. Without pgvector the cluster starts, the migrations begin, and E3's
  # `CREATE EXTENSION vector` fails — reported as a broken migration rather than a missing
  # package, which is how it reached CI on 2026-08-07.
  if [ ! -f "/usr/share/postgresql/${PG_MAJOR}/extension/vector.control" ]; then
    echo "pgvector is not installed for PostgreSQL ${PG_MAJOR}, and the discovery migration" >&2
    echo "runs CREATE EXTENSION vector. Install postgresql-${PG_MAJOR}-pgvector, or re-run" >&2
    echo "./scripts/install-toolchain.sh." >&2
    return 1
  fi

  if [ -d "${CLUSTER}/data" ] && "${PGBIN}/pg_isready" -q 2>/dev/null; then
    if [ "$(cat "${STAMP}" 2>/dev/null)" = "$(built_from)" ]; then
      log "already running"
      return 0
    fi
    log "migrations or seed changed since this cluster was built — rebuilding"
    stop_cluster
  fi

  rm -rf "${CLUSTER}"
  mkdir -p "${CLUSTER}/data" "${SOCKET}"

  # The distribution package refuses to initdb as root, and this container is root. A dedicated
  # unprivileged user is cheaper than arguing with it, and matches how the cluster would run
  # anywhere else.
  if ! id kafoopg >/dev/null 2>&1; then
    useradd -M -s /usr/sbin/nologin kafoopg
  fi
  chown -R kafoopg "${CLUSTER}"

  log "initdb"
  su kafoopg -s /bin/bash -c \
    "${PGBIN}/initdb -D '${CLUSTER}/data' -U postgres --auth=trust --no-sync" >/dev/null 2>&1 || {
      echo "initdb failed" >&2; return 1; }

  log "starting"
  su kafoopg -s /bin/bash -c \
    "${PGBIN}/pg_ctl -D '${CLUSTER}/data' -o \"-k '${SOCKET}' -c listen_addresses=''\" -w start" \
    >/dev/null 2>&1 || { echo "pg_ctl start failed" >&2; return 1; }

  "${PGBIN}/createdb" -h "${SOCKET}" -U postgres "${DB}" || return 1

  log "supabase scaffolding"
  psql -h "${SOCKET}" -U postgres -d "${DB}" -v ON_ERROR_STOP=1 -q \
    -f "${REPO}/scripts/local-db-bootstrap.sql" || return 1

  log "migrations"
  for f in "${REPO}"/supabase/migrations/*.sql; do
    [ -e "$f" ] || continue
    psql -h "${SOCKET}" -U postgres -d "${DB}" -v ON_ERROR_STOP=1 -q -f "$f" || {
      echo "migration failed: $(basename "$f")" >&2; return 1; }
  done

  log "seed"
  psql -h "${SOCKET}" -U postgres -d "${DB}" -v ON_ERROR_STOP=1 -q \
    -f "${REPO}/supabase/seed.sql" || return 1

  # Written last, and only on success, so a cluster left half-built by a failed migration has no
  # stamp and is rebuilt on the next run rather than reused.
  built_from > "${STAMP}"

  log "ready — Postgres ${PG_MAJOR}, matching supabase/config.toml"
}

run_tests() {
  local files
  if [ $# -gt 0 ]; then
    files="$1"
  else
    files=$(find "${REPO}/supabase/tests" -name '*.sql' -type f | sort)
  fi
  [ -n "${files}" ] || { echo "no test files"; return 0; }

  local failed=0
  for f in ${files}; do
    echo ""
    echo "── $(basename "$f")"
    # Each suite opens and rolls back its own transaction — do not wrap it in another, or every
    # run reports "there is already a transaction in progress" and the rollback nests confusingly.
    #
    # -t -A because pgTAP returns TAP lines as ROWS. Without them psql draws a table around the
    # output and nothing matches, which looks exactly like a suite that produced no assertions.
    out=$(psql -h "${SOCKET}" -U postgres -d "${DB}" -X -q -t -A -v ON_ERROR_STOP=0 -f "$f" 2>&1)
    printf '%s\n' "${out}" | grep -E '^(ok |not ok |# |1\.\.)' | head -80

    # A suite that errors out before its plan produces NO "not ok" at all, so counting failures is
    # not enough — an empty result has to be a failure too, or a broken suite reports as a clean one.
    #
    # '# Looks like' catches a PLAN MISMATCH, and it was missing until 2026-08-07. pgTAP reports a
    # wrong plan as a comment rather than a failure, so a suite that silently stopped running
    # assertions — or had one deleted — went green through here and through the Authorization
    # workflow. That is not hypothetical: supabase/tests/policy_isolation_test.sql planned 9 while
    # running 10 from WP-008 until this branch, and nothing anywhere noticed.
    if printf '%s\n' "${out}" | grep -qE '^not ok|^ERROR|^psql:|^# Looks like'; then
      failed=1
      printf '%s\n' "${out}" | grep -E '^(not ok|ERROR|psql:|# Looks like)' | head -20
    elif ! printf '%s\n' "${out}" | grep -qE '^ok '; then
      failed=1
      echo "   no assertions ran — the suite failed before its plan" >&2
      printf '%s\n' "${out}" | head -10 >&2
    fi
  done
  return "${failed}"
}

case "${1:-}" in
  start) start ;;
  test)  shift; start >/dev/null || exit 1; run_tests "$@" ;;
  psql)  exec psql -h "${SOCKET}" -U postgres -d "${DB}" ;;
  stop)  stop_cluster; log "stopped" ;;
  *) sed -n '2,25p' "${BASH_SOURCE[0]}"; exit 2 ;;
esac
