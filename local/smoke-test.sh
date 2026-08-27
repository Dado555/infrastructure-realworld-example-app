#!/usr/bin/env bash
#
# local/smoke-test.sh -- reusable end-to-end smoke test for the RealWorld app.
#
# WHAT THIS PROVES: a scripted, repeatable run through the full user journey
# (health -> tags -> register -> login -> read own profile -> create article
# -> read it back -> comment -> favourite -> tag-filter listing -> delete),
# asserting on response BODY content at every step, not just HTTP status --
# a 200 with an empty/wrong body is a real failure this script is designed to
# catch (e.g. a 200 with an empty article list still means broken pagination).
#
# REUSE: takes the base URL as $1 so the exact same script targets local
# Docker Compose today and, unchanged, dev/prod later (see the plan's Steps
# 7.5 and 8.x) -- nothing below is compose-specific.
#
#   bash smoke-test.sh http://localhost:8080
#   bash smoke-test.sh https://dev.example.com
#
# KNOWN, DOCUMENTED, PRE-EXISTING FAILURE (do not "fix" by softening step 10):
# GET /api/articles (paginated listing, including ?tag=) returns HTTP 500 on
# a Postgres-backed stack -- org.postgresql.util.PSQLException: ERROR: LIMIT
# #,# syntax is not supported. MySQL/SQLite-dialect comma-form LIMIT syntax in
# the backend's src/main/resources/mapper/ArticleReadService.xml, tracked in
# docs/adr/0005-database-engine-and-topology.md (this repo, docs/adr-0001-0008
# branch, commit db09ad2) with the fix already spelled out there. Step 10
# below asserts the real, correct behaviour (article appears in the
# tag-filtered listing) on purpose -- it is EXPECTED to fail loudly at that
# assertion until the LIMIT bug is fixed, and that failure is the whole point:
# it proves this smoke test actually catches the dialect bug rather than
# silently passing over broken pagination. See local/README.md for the
# current-known-failure note.
#
# EXIT BEHAVIOUR: stops at the first failure (no continuing past a failure
# pretending things are fine), printing one "FAIL: <step> - <what was
# expected vs got>" line and exiting non-zero. Every successful step prints
# "PASS: <step>", so a fully green run reads as a clean checklist.
#
# UNIQUENESS: registers a freshly-generated username/email/article
# title/tag on every run (timestamp + $RANDOM, see UNIQUE below) so re-runs
# never collide on a duplicate -- reusing a fixed username is a documented
# common failure mode for scripts like this one. The test password is
# likewise generated fresh per run (see generate_password) and never printed
# or hardcoded.

set -euo pipefail

# ---------------------------------------------------------------------------
# Usage / base URL
# ---------------------------------------------------------------------------

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <base-url>   e.g. $0 http://localhost:8080" >&2
  exit 1
fi
# Strip a trailing slash so "${BASE_URL}${path}" below never produces "//".
BASE_URL="${1%/}"

# ---------------------------------------------------------------------------
# Step-tracking / failure helpers
# ---------------------------------------------------------------------------
# CURRENT_STEP names whichever step is in flight; fail()/pass() read it so
# every step body just narrates what it's doing instead of repeating the
# step name in every message.

CURRENT_STEP=""

# fail() prints one clear line naming the step and what was expected vs. got,
# then exits non-zero immediately. Never called from inside a condition that
# would let `set -e` swallow it -- always as the RHS of `||` or an `if`
# body, both of which run it as an ordinary (non-conditional) statement.
fail() {
  echo "FAIL: ${CURRENT_STEP} - $1" >&2
  exit 1
}

# pass() -- one line per successful step, so a full run reads as a checklist.
pass() {
  echo "PASS: ${CURRENT_STEP}"
}

# ---------------------------------------------------------------------------
# Preflight: fail fast and clearly if a required tool is missing, rather than
# dying deep inside a step with a raw "command not found".
# ---------------------------------------------------------------------------

CURRENT_STEP="preflight"
for tool in curl jq; do
  command -v "$tool" >/dev/null 2>&1 \
    || fail "required tool '${tool}' not found on PATH -- install it before running this script"
done

# ---------------------------------------------------------------------------
# HTTP helper
# ---------------------------------------------------------------------------
# request METHOD PATH [BODY] [TOKEN]
#
# Bash has no clean multi-value return, and a temp-file-per-call scheme adds
# cleanup complexity for no real benefit here -- so this populates two
# globals, RESP_STATUS and RESP_BODY, which the caller reads immediately.
#
# RESP_STATUS is set to the literal "000" sentinel on a connect()-level
# failure (refused/unreachable/timed out) -- curl itself never emits a "000"
# HTTP status, so this cleanly distinguishes "couldn't even reach the server"
# from any real HTTP response (including a 5xx from the app). That
# distinction is what makes the backend-down acceptance test below produce a
# clear, specific message instead of a generic one.
#
# --connect-timeout/--max-time bound how long a dead backend can make this
# script wait -- this is the mechanism behind "fails fast, not a hang".
RESP_STATUS=""
RESP_BODY=""
request() {
  local method="$1" path="$2" body="${3:-}" token="${4:-}"
  local -a curl_args=(
    --silent --show-error
    --connect-timeout 5 --max-time 15
    -w '\n%{http_code}'
    -X "$method" "${BASE_URL}${path}"
    -H "Content-Type: application/json"
  )
  [[ -n "$token" ]] && curl_args+=(-H "Authorization: Token ${token}")
  [[ -n "$body" ]] && curl_args+=(-d "$body")

  # stderr is captured to its own temp file rather than merged via 2>&1:
  # on a hard failure (e.g. --max-time expiring) curl can still flush the
  # `-w '\n%{http_code}'` format's default "000" to stdout after its error
  # line, so a merged capture would leak a stray trailing "000" into the
  # error message below. Keeping the streams separate means the failure
  # branch gets curl's clean diagnostic text and nothing else.
  local raw stderr_file
  stderr_file="$(mktemp)"
  # Guarded with `if !` so a curl-level failure (connection refused, DNS,
  # timeout) can't kill the script via `set -e` with curl's own raw stderr --
  # it's captured into RESP_BODY and reported via the "000" sentinel instead.
  if ! raw=$(curl "${curl_args[@]}" 2>"$stderr_file"); then
    RESP_STATUS="000"
    RESP_BODY="$(cat "$stderr_file")"
    rm -f "$stderr_file"
    return
  fi
  rm -f "$stderr_file"
  RESP_STATUS="${raw##*$'\n'}"
  RESP_BODY="${raw%$'\n'*}"
}

# expect_status EXPECTED -- asserts RESP_STATUS from the last request(),
# with a clear message for either a hard connection failure or a
# wrong-but-received status. Body-content assertions happen separately per
# step (see header: a 200 with a wrong/empty body is still a failure).
expect_status() {
  local expected="$1"
  if [[ "$RESP_STATUS" == "000" ]]; then
    fail "could not reach ${BASE_URL} (connection failed or timed out). curl said: ${RESP_BODY}"
  fi
  if [[ "$RESP_STATUS" != "$expected" ]]; then
    fail "expected HTTP ${expected} but got HTTP ${RESP_STATUS}. Body: ${RESP_BODY}"
  fi
}

# jqget FILTER -- extracts a field from RESP_BODY. Deliberately does NOT use
# jq's `-e` flag: `-e` reports a `false`/`null` *result* as a failure exit
# code, which would wrongly be indistinguishable from "the body wasn't valid
# JSON" for perfectly legitimate fields like `.article.favorited` -- this
# only needs to catch the latter (unparsable/unexpected body shape), so a
# plain non-zero exit (parse error) is what's treated as failure here.
jqget() {
  local filter="$1" value
  if ! value=$(printf '%s' "$RESP_BODY" | jq -r "$filter" 2>&1); then
    fail "could not extract '${filter}' from response body (not valid JSON?): ${RESP_BODY}"
  fi
  printf '%s' "$value"
}

# assert_eq ACTUAL EXPECTED DESCRIPTION -- also catches jq's "null" text for
# a missing field, since that will simply never equal a real expected value.
assert_eq() {
  local actual="$1" expected="$2" desc="$3"
  [[ "$actual" == "$expected" ]] || fail "${desc}: expected '${expected}', got '${actual}'"
}

# assert_present VALUE DESCRIPTION -- for fields with no fixed expected
# value (e.g. a JWT), where "was something returned at all" is the check.
assert_present() {
  local value="$1" desc="$2"
  if [[ -z "$value" || "$value" == "null" ]]; then
    fail "${desc}: expected a non-empty value, got '${value}'"
  fi
}

# generate_password -- a fresh random string every run, never a hardcoded or
# reused value (per this repo's secret-handling rules). Prefers openssl
# (present on virtually every dev machine and CI image); falls back to
# /dev/urandom filtered through tr so the script still works without it.
generate_password() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 24
  else
    head -c 64 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | head -c 32
  fi
}

# ---------------------------------------------------------------------------
# Step 1: GET /healthz
# ---------------------------------------------------------------------------
CURRENT_STEP="1. GET /healthz"
request GET "/healthz"
expect_status 200
[[ "$RESP_BODY" == *"ok"* ]] || fail "expected body to contain 'ok', got: ${RESP_BODY}"
pass

# ---------------------------------------------------------------------------
# Step 2: GET /api/tags
# ---------------------------------------------------------------------------
CURRENT_STEP="2. GET /api/tags"
request GET "/api/tags"
expect_status 200
assert_eq "$(jqget '.tags | type')" "array" "GET /api/tags response .tags"
pass

# ---------------------------------------------------------------------------
# Step 3: Register a uniquely-named user
# ---------------------------------------------------------------------------
# Timestamp + $RANDOM (twice, for extra spread) -- avoids the "reusing a
# fixed username" failure mode called out in the plan: re-running this script
# against a stack that already has a prior run's data must not collide on a
# duplicate username/email/article.
CURRENT_STEP="3. Register unique user"
UNIQUE="$(date +%s)${RANDOM}${RANDOM}"
USERNAME="smoketest${UNIQUE}"
EMAIL="smoketest${UNIQUE}@example.com"
PASSWORD="$(generate_password)"

register_body=$(jq -n --arg u "$USERNAME" --arg e "$EMAIL" --arg p "$PASSWORD" \
  '{user: {username: $u, email: $e, password: $p}}')
request POST "/api/users" "$register_body"
expect_status 201
assert_eq "$(jqget '.user.username')" "$USERNAME" "registered username"
assert_eq "$(jqget '.user.email')" "$EMAIL" "registered email"
assert_present "$(jqget '.user.token')" "registration response token"
pass

# ---------------------------------------------------------------------------
# Step 4: Log in and capture the JWT (never printed)
# ---------------------------------------------------------------------------
CURRENT_STEP="4. Log in"
login_body=$(jq -n --arg e "$EMAIL" --arg p "$PASSWORD" '{user: {email: $e, password: $p}}')
request POST "/api/users/login" "$login_body"
expect_status 200
assert_eq "$(jqget '.user.email')" "$EMAIL" "login response email"
TOKEN="$(jqget '.user.token')"
assert_present "$TOKEN" "login response token"
pass

# ---------------------------------------------------------------------------
# Step 5: GET /api/user with the token
# ---------------------------------------------------------------------------
CURRENT_STEP="5. GET /api/user (current user)"
request GET "/api/user" "" "$TOKEN"
expect_status 200
assert_eq "$(jqget '.user.username')" "$USERNAME" "current-user username"
pass

# ---------------------------------------------------------------------------
# Step 6: Create an article
# ---------------------------------------------------------------------------
CURRENT_STEP="6. Create article"
ARTICLE_TITLE="Smoke Test Article ${UNIQUE}"
ARTICLE_DESCRIPTION="Created by smoke-test.sh"
ARTICLE_BODY_TEXT="This article was created by the automated smoke test."
TAG="smoketest${UNIQUE}"
# The backend derives the slug by lowercasing the title and collapsing
# whitespace/punctuation runs to single hyphens (Article.toSlug in the
# backend repo's io.spring.core.article.Article). The title above is
# alnum-and-spaces only, so this mirrors that transformation exactly and
# gives a real assertion below instead of just checking the field is
# non-empty.
EXPECTED_SLUG="$(printf '%s' "$ARTICLE_TITLE" | tr '[:upper:]' '[:lower:]' | tr -s ' ' '-')"

create_body=$(jq -n --arg t "$ARTICLE_TITLE" --arg d "$ARTICLE_DESCRIPTION" \
  --arg b "$ARTICLE_BODY_TEXT" --arg tag "$TAG" \
  '{article: {title: $t, description: $d, body: $b, tagList: [$tag]}}')
request POST "/api/articles" "$create_body" "$TOKEN"
expect_status 200
assert_eq "$(jqget '.article.title')" "$ARTICLE_TITLE" "created article title"
SLUG="$(jqget '.article.slug')"
assert_eq "$SLUG" "$EXPECTED_SLUG" "created article slug"
# Baseline so step 9 can assert the count genuinely *incremented*, rather
# than just asserting it equals a hardcoded 1.
BASELINE_FAVORITES="$(jqget '.article.favoritesCount')"
pass

# ---------------------------------------------------------------------------
# Step 7: Fetch it by slug
# ---------------------------------------------------------------------------
CURRENT_STEP="7. GET /api/articles/{slug}"
request GET "/api/articles/${SLUG}"
expect_status 200
assert_eq "$(jqget '.article.slug')" "$SLUG" "fetched article slug"
assert_eq "$(jqget '.article.title')" "$ARTICLE_TITLE" "fetched article title"
assert_eq "$(jqget '.article.description')" "$ARTICLE_DESCRIPTION" "fetched article description"
assert_eq "$(jqget '.article.body')" "$ARTICLE_BODY_TEXT" "fetched article body"
pass

# ---------------------------------------------------------------------------
# Step 8: Comment on it
# ---------------------------------------------------------------------------
CURRENT_STEP="8. Comment on article"
COMMENT_BODY_TEXT="Nice article! (posted by smoke-test.sh)"
comment_body=$(jq -n --arg b "$COMMENT_BODY_TEXT" '{comment: {body: $b}}')
request POST "/api/articles/${SLUG}/comments" "$comment_body" "$TOKEN"
expect_status 201
assert_eq "$(jqget '.comment.body')" "$COMMENT_BODY_TEXT" "posted comment body"
pass

# ---------------------------------------------------------------------------
# Step 9: Favourite it
# ---------------------------------------------------------------------------
CURRENT_STEP="9. Favourite article"
request POST "/api/articles/${SLUG}/favorite" "" "$TOKEN"
expect_status 200
assert_eq "$(jqget '.article.favorited')" "true" "favorited flag"
new_favorites="$(jqget '.article.favoritesCount')"
expected_favorites=$((BASELINE_FAVORITES + 1))
assert_eq "$new_favorites" "$expected_favorites" "favoritesCount after favouriting"
pass

# ---------------------------------------------------------------------------
# Step 10: GET /api/articles?tag=<the-tag-used>
# ---------------------------------------------------------------------------
# EXPECTED TO FAIL RIGHT NOW -- see the header comment and
# docs/adr/0005-database-engine-and-topology.md. This asserts the real,
# correct behaviour (the article we just created and favourited shows up in
# its own tag's listing) on purpose, unweakened, so this script actually
# proves the known LIMIT-syntax bug rather than quietly stepping around it.
CURRENT_STEP="10. GET /api/articles?tag= (tag-filtered listing)"
request GET "/api/articles?tag=${TAG}"
if [[ "$RESP_STATUS" == "000" ]]; then
  fail "could not reach ${BASE_URL} (connection failed or timed out). curl said: ${RESP_BODY}"
fi
if [[ "$RESP_STATUS" != "200" ]]; then
  fail "expected HTTP 200 but got HTTP ${RESP_STATUS}. This matches the known, pre-existing MySQL-dialect LIMIT bug in ArticleReadService.xml (org.postgresql.util.PSQLException: LIMIT #,# syntax is not supported) -- tracked in docs/adr/0005-database-engine-and-topology.md, not yet fixed. Body: ${RESP_BODY}"
fi
found="$(printf '%s' "$RESP_BODY" | jq -r --arg slug "$SLUG" '[(.articles // [])[] | select(.slug == $slug)] | length > 0' 2>&1)"
[[ "$found" == "true" ]] \
  || fail "article '${SLUG}' not found in GET /api/articles?tag=${TAG} results. Body: ${RESP_BODY}"
pass

# ---------------------------------------------------------------------------
# Step 11: Delete the article
# ---------------------------------------------------------------------------
CURRENT_STEP="11. Delete article"
request DELETE "/api/articles/${SLUG}" "" "$TOKEN"
expect_status 204
pass

echo
echo "All steps passed against ${BASE_URL}."
