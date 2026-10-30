#!/system/bin/sh
# RedMagicDualSpace fixed-operation Android secondary-user controller.
set -u

SPACE_NAME='RedMagic DualSpace'
DEFAULT_STATE_DIR="/data/adb/redmagicdualspace"
STATE_DIR=${RMDSS_STATE_DIR:-$DEFAULT_STATE_DIR}
USER_ID_FILE="$STATE_DIR/user_id"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

current_user() {
  command -v am >/dev/null 2>&1 || fail 'Android am command is unavailable'
  value=$(am get-current-user 2>/dev/null) || fail 'Unable to read current Android user'
  case "$value" in ''|*[!0-9]*) fail 'Android returned an invalid current user ID' ;; esac
  printf '%s\n' "$value"
}

list_users() {
  command -v pm >/dev/null 2>&1 || fail 'Android pm command is unavailable'
  pm list users 2>&1 || fail 'Unable to list Android users'
}

managed_ids() {
  # Match the full, exact Android UserInfo name, not a substring.
  printf '%s\n' "$1" | sed -n 's/.*UserInfo{\([0-9][0-9]*\):RedMagic DualSpace:[^}]*}.*/\1/p'
}

validate_id() {
  case "$1" in ''|*[!0-9]*) return 1 ;; esac
  [ "$1" -gt 0 ] 2>/dev/null
}

save_id() {
  id=$1
  validate_id "$id" || fail 'Refusing to save an invalid secondary-user ID'
  mkdir -p "$STATE_DIR" || fail 'Unable to create persistent state directory'
  chmod 0700 "$STATE_DIR" || fail 'Unable to secure persistent state directory'
  (umask 077; printf '%s\n' "$id" > "$USER_ID_FILE") || fail 'Unable to persist secondary-user ID'
  chmod 0600 "$USER_ID_FILE" || fail 'Unable to secure persisted secondary-user ID'
}

resolve_managed_id() {
  users=$(list_users) || return 1
  ids=$(managed_ids "$users")
  [ -n "$ids" ] || fail "Managed user '$SPACE_NAME' was not found; create it first"
  count=$(printf '%s\n' "$ids" | wc -l | tr -d ' ')
  [ "$count" = '1' ] || fail "Multiple users named '$SPACE_NAME' exist; refusing to choose"
  id=$ids
  validate_id "$id" || fail 'The managed user ID is invalid'
  save_id "$id"
  printf '%s\n' "$id"
}

status() {
  current=$(current_user) || return $?
  echo "Device model: $(getprop ro.product.model 2>/dev/null)"
  market=$(getprop ro.product.marketname 2>/dev/null)
  [ -n "$market" ] && echo "Device name: $market"
  echo "Android version: Android $(getprop ro.build.version.release 2>/dev/null)"
  echo "Build: $(getprop ro.build.display.id 2>/dev/null)"
  echo "Current user: $current"
  echo 'Android users:'
  list_users || return 1
  if [ -f "$USER_ID_FILE" ]; then
    saved=$(cat "$USER_ID_FILE" 2>/dev/null)
    if validate_id "$saved"; then
      echo "Saved managed user ID: $saved"
    else
      echo 'Saved managed user ID: invalid (will be re-detected by exact user name)'
    fi
  else
    echo 'Saved managed user ID: not configured'
  fi
  echo 'Magic Key automation: disabled (device event not verified)'
}

create_space() {
  current=$(current_user)
  [ "$current" = '0' ] || fail 'Create the managed space only while the owner user (0) is active'
  users=$(list_users) || return 1
  ids=$(managed_ids "$users")
  if [ -n "$ids" ]; then
    count=$(printf '%s\n' "$ids" | wc -l | tr -d ' ')
    [ "$count" = '1' ] || fail "Multiple users named '$SPACE_NAME' exist; refusing to choose"
    save_id "$ids"
    echo "Existing managed space found. User ID: $ids"
    return 0
  fi
  command -v pm >/dev/null 2>&1 || fail 'Android pm command is unavailable'
  output=$(pm create-user --user-type android.os.usertype.full.SECONDARY "$SPACE_NAME" 2>&1) || {
    echo "$output" >&2
    fail 'Android rejected secondary-user creation; no user was created by this module'
  }
  printf '%s\n' "$output"
  id=$(printf '%s\n' "$output" | sed -n 's/.*created user id \([0-9][0-9]*\).*/\1/p' | tail -n 1)
  validate_id "$id" || fail 'Creation output did not contain a valid user ID; inspect pm list users before retrying'
  users=$(list_users) || return 1
  exact=$(managed_ids "$users")
  [ "$exact" = "$id" ] || fail 'Android did not report the newly created managed user under the expected exact name'
  save_id "$id"
  echo "Managed space created. User ID: $id"
}

switch_user() {
  target=$1
  command -v am >/dev/null 2>&1 || fail 'Android am command is unavailable'
  am switch-user "$target" || fail "Unable to switch to Android user $target"
  echo "Requested switch to user $target"
}

case "${1:-}" in
  status)
    [ "$#" -eq 1 ] || fail 'status takes no extra arguments'
    status
    ;;
  create)
    [ "$#" -eq 1 ] || fail 'create takes no extra arguments'
    create_space
    ;;
  switch-owner)
    [ "$#" -eq 1 ] || fail 'switch-owner takes no extra arguments'
    switch_user 0
    ;;
  switch-space)
    [ "$#" -eq 1 ] || fail 'switch-space takes no extra arguments'
    id=$(resolve_managed_id) || exit $?
    switch_user "$id"
    ;;
  *)
    fail 'Usage: dualspace.sh {status|create|switch-owner|switch-space}'
    ;;
esac
