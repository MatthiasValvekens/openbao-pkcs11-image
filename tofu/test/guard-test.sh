#!/bin/sh
# Hermetic test for tofu-destroy-guard: runs it against trimmed `tofu show
# -json` plan fixtures (taken from real plans) with the allowlist as input.
# Needs jq only. Usage: sh test/guard-test.sh [path/to/tofu-destroy-guard]
set -u
here="$(cd "$(dirname "$0")" && pwd)"
guard="${1:-$here/../tofu-destroy-guard}"
fx="$here/fixtures"
fail=0

# check EXPECTED_RC FIXTURE [ENV=VALUE ...]
check() {
    want="$1"; name="$2"; shift 2
    env -u TOFU_GUARD_ALLOW_DELETE -u TOFU_GUARD_PATH_TYPES "$@" "$guard" - < "$fx/$name.json" >/dev/null 2>&1
    got=$?
    if [ "$got" = "$want" ]; then echo "ok   $name (rc $got) $*"; else echo "FAIL $name: want rc $want, got $got  $*"; fail=1; fi
}

A="TOFU_GUARD_ALLOW_DELETE=vault_policy,vault_pki_secret_backend_role"

check 0 clean "$A"
check 0 clean                                   # no allowlist is fine without deletes
check 0 allowed-delete "$A"
check 0 allowed-delete "TOFU_GUARD_ALLOW_DELETE=vault_x vault_policy"        # whitespace separated
check 1 allowed-delete                                                      # no allowlist: nothing may go
check 1 allowed-delete "TOFU_GUARD_ALLOW_DELETE=vault_polic"                # exact match, not prefix
check 1 mount-delete "$A"
check 1 replace "$A"                                                        # delete+create
check 0 replace "TOFU_GUARD_ALLOW_DELETE=vault_mount"                       # allowlisted type: replace passes
check 1 rename "$A"                                                         # in-place path change
check 0 rename "$A" "TOFU_GUARD_PATH_TYPES=-"                               # path check disabled
check 0 rename "$A" "TOFU_GUARD_PATH_TYPES=vault_auth_backend"              # other types only
check 0 forget "$A"                                                         # removed { destroy = false }

# Failure to read a plan is an error, never a pass.
echo '{bad' | "$guard" - >/dev/null 2>&1
if [ $? = 2 ]; then echo "ok   malformed json (rc 2)"; else echo "FAIL malformed json"; fail=1; fi
"$guard" </dev/null >/dev/null 2>&1
if [ $? = 2 ]; then echo "ok   no args (rc 2)"; else echo "FAIL no args"; fail=1; fi

exit "$fail"
