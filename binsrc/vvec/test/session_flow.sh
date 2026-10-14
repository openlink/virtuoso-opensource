#!/bin/bash
#
#  session_flow.sh -- end-to-end check of the vvec console sign-in session.
#
#  Exercises the whole of section 7b of sql/vvec_install.sql against a running
#  instance with the VVec VAD installed: the sign-in challenge, the session
#  cookie, CSRF, sign-out, the three expiry windows and the IP pin.
#
#  The window and pin cases need to age a session without waiting, so they
#  backdate its row through isql; give ISQL/PORT/DBA_USER/DBA_PASS if the
#  defaults do not match your instance.  Without a working isql they are
#  skipped and the rest still runs.
#
#  Usage:  binsrc/vvec/test/session_flow.sh [base-url] [account] [password]
#          binsrc/vvec/test/session_flow.sh http://localhost:8890/vvec dba dba
#
set -u

BASE=${1:-http://localhost:8890/vvec}
USER_=${2:-dba}
PASS_=${3:-dba}
ISQL=${ISQL:-isql}
PORT=${PORT:-1111}
DBA_USER=${DBA_USER:-dba}
DBA_PASS=${DBA_PASS:-dba}

# Path part of BASE ("/vvec") and its last segment ("vvec"), for asserting
# exactly where a redirect points.
BASE_PATH=$(printf '%s' "$BASE" | sed -e 's|^[a-zA-Z][a-zA-Z0-9+.-]*://[^/]*||')
BASE_SEG=${BASE_PATH##*/}

J=$(mktemp); rm -f "$J"
pass=0; fail=0; skip=0

chk(){ if [ "$2" = "$3" ]; then printf '  PASS  %s (%s)\n' "$1" "$2"; pass=$((pass+1))
       else printf '  FAIL  %s: got %s want %s\n' "$1" "$2" "$3"; fail=$((fail+1)); fi }

md5hex(){ printf '%s' "$1" | openssl dgst -md5 -hex 2>/dev/null | awk '{print $NF}'; }

# Sign in the way the browser does: fetch the form, answer its single-use
# nonce with MD5(nonce || password), never send the password itself.
login(){
  rm -f "$J"
  local html nonce resp
  html=$(curl -s -c "$J" "$BASE/login")
  nonce=$(printf '%s' "$html" | grep -o 'name="nonce" value="[a-f0-9]*"' | sed 's/.*value="//;s/"//')
  resp=$(md5hex "$nonce$2")
  curl -s -b "$J" -c "$J" -o /dev/null -w '%{http_code}' -X POST "$BASE/login" \
       --data-urlencode "username=$1" --data-urlencode "password=$resp" \
       --data-urlencode "nonce=$nonce" --data-urlencode "url=$BASE/indexes"
}

code(){ curl -s -b "$J" -o /dev/null -w '%{http_code}' "$@"; }
sid(){ grep vvec_sid "$J" 2>/dev/null | awk '{print $7}'; }

have_isql=0
if command -v "$ISQL" >/dev/null 2>&1; then
  if printf 'select 1;\n' | "$ISQL" "$PORT" "$DBA_USER" "$DBA_PASS" \
       VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT >/dev/null 2>&1; then have_isql=1; fi
fi
sql(){ printf '%s\ncommit work;\n' "$1" | "$ISQL" "$PORT" "$DBA_USER" "$DBA_PASS" \
         VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT >/dev/null 2>&1; }
age(){ sql "update DB.DBA.VVEC_SESSION set $1 = dateadd ('$2', -$3, now ()) where VS_SID = '$(sid)';"; }

# Where a redirect points, not just that one happened: the mount prefix has to
# survive. Deriving it from the request path once dropped it for the bare
# directory URL, sending /vvec to /login rather than /vvec/login.
loc(){ curl -s -o /dev/null -D - "$1" | tr -d '\r' | sed -n 's/^[Ll]ocation: //p'; }

echo "--- signed out ---"
chk "console redirects to sign-in"  "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/")" "302"
chk "  ... keeping the mount prefix" "$(loc "$BASE/")" "$BASE_PATH/login?url=%2F${BASE_SEG}%2F"
chk "bare directory URL redirects"  "$(curl -s -o /dev/null -w '%{http_code}' "$BASE")" "302"
chk "  ... keeping the mount prefix" "$(loc "$BASE")" "$BASE_PATH/login?url=%2F${BASE_SEG}"
chk "sign-in page is reachable"     "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/login")" "200"
chk "heartbeat refused"             "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/ping")" "401"
chk "unknown cookie redirects"      "$(curl -s -o /dev/null -w '%{http_code}' -H 'Cookie: vvec_sid=deadbeef' "$BASE/indexes")" "302"

echo "--- sign in ---"
chk "sign-in accepted"              "$(login "$USER_" "$PASS_")" "302"
chk "session cookie set"            "$(grep -c vvec_sid "$J" | head -1)" "1"
chk "cookie is HttpOnly"            "$(grep -c '^#HttpOnly_' "$J" | head -1)" "1"
chk "dashboard reachable"           "$(code "$BASE/")" "200"
chk "heartbeat accepted"            "$(code "$BASE/ping")" "200"
chk "sign-in page bounces"          "$(code "$BASE/login")" "302"

echo "--- CSRF ---"
TOK=$(curl -s -b "$J" "$BASE/maintenance" | grep -o 'name="csrf" value="[a-f0-9]*"' | head -1 | sed 's/.*value="//;s/"//')
chk "form carries a token"          "$( [ -n "$TOK" ] && echo yes || echo no )" "yes"
chk "POST, no token"                "$(code -X POST "$BASE/action" -d 'op=noop')" "403"
chk "POST, wrong token"             "$(code -X POST "$BASE/action" --data-urlencode 'csrf=deadbeef' -d 'op=noop')" "403"
chk "GET of a state change"         "$(code "$BASE/action?op=noop&csrf=$TOK")" "403"
chk "cross-origin POST"             "$(code -X POST -H 'Origin: http://evil.example' "$BASE/action" --data-urlencode "csrf=$TOK" -d 'op=noop')" "403"

echo "--- sign out ---"
chk "sign-out page renders"         "$(curl -s -b "$J" -c "$J" -o /dev/null -w '%{http_code}' "$BASE/logout")" "200"
chk "session is gone"               "$(code "$BASE/indexes")" "302"
chk "heartbeat is gone"             "$(code "$BASE/ping")" "401"

echo "--- rejected sign-ins ---"
login "$USER_" "not-the-password" >/dev/null
chk "wrong password, no session"    "$(grep -c vvec_sid "$J" 2>/dev/null | head -1)" "0"
login "no-such-account-here" "x" >/dev/null
chk "unknown account, no session"   "$(grep -c vvec_sid "$J" 2>/dev/null | head -1)" "0"

if [ "$have_isql" = 1 ]; then
  echo "--- expiry windows and the IP pin (rows aged through isql) ---"
  login "$USER_" "$PASS_" >/dev/null; age VS_BEAT second 200
  chk "page closed: beats stopped"  "$(code "$BASE/indexes")" "302"
  login "$USER_" "$PASS_" >/dev/null; age VS_SEEN minute 45
  chk "idle out despite beating"    "$(code "$BASE/indexes")" "302"
  login "$USER_" "$PASS_" >/dev/null; age VS_CREATED hour 13
  chk "absolute lifetime cap"       "$(code "$BASE/indexes")" "302"
  login "$USER_" "$PASS_" >/dev/null
  sql "update DB.DBA.VVEC_SESSION set VS_IP = '10.9.9.9' where VS_SID = '$(sid)';"
  chk "pinned to the client IP"     "$(code "$BASE/indexes")" "302"
  login "$USER_" "$PASS_" >/dev/null
  chk "signed in"                   "$(code "$BASE/indexes")" "200"
  sql "delete from DB.DBA.VVEC_SESSION;"
  chk "gone when the store is"      "$(code "$BASE/indexes")" "302"
else
  echo "--- expiry windows and the IP pin: SKIPPED (no usable isql at port $PORT) ---"
  skip=6
fi

echo
echo "passed $pass, failed $fail, skipped $skip"
rm -f "$J"
[ "$fail" = 0 ]
