# aws-profile-selector.plugin.zsh
# Oh My Zsh plugin: interactive AWS profile selector with friendly identity labels,
# optional account-id display with caching, profile clearing.

# ------------------------------
# User-configurable settings
# ------------------------------
: "${AWS_PROFILE_SELECTOR_AUTORUN:=1}"          # 1=prompt on new interactive shells if AWS_PROFILE unset
: "${AWS_PROFILE_SELECTOR_SHOW_ACCOUNT_ID:=0}"  # 1=show (account id) beside each entry (uses cache / STS)
: "${AWS_PROFILE_SELECTOR_CACHE_TTL:=600}"      # seconds
: "${AWS_PROFILE_SELECTOR_CACHE_FILE:=$HOME/.aws/aws-profile-selector-cache}"

# ------------------------------
# Internal helpers
# ------------------------------

_awsps_ensure_cache_dir() {
  local dir="${AWS_PROFILE_SELECTOR_CACHE_FILE:h}"
  [[ -d "$dir" ]] || mkdir -p "$dir" 2>/dev/null || true
}

# Trim leading/trailing whitespace, remove carriage returns.
_awsps_sanitize() {
  local s="$1"
  s="${s//$'\r'/}"              # remove CR if present
  s="${s#"${s%%[![:space:]]*}"}" # ltrim
  s="${s%"${s##*[![:space:]]}"}" # rtrim
  print -r -- "$s"
}

# Cache format (TSV): <profile>\t<epoch>\t<account_id>
_awsps_cache_get_account() {
  local profile="$1"
  local now line ts acct

  [[ -f "$AWS_PROFILE_SELECTOR_CACHE_FILE" ]] || return 1
  now="$(date +%s 2>/dev/null)" || return 1

  line="$(command grep -F $'\t'"$profile"$'\t' "$AWS_PROFILE_SELECTOR_CACHE_FILE" 2>/dev/null | tail -n 1)"
  [[ -n "$line" ]] || return 1

  ts="${line#*$'\t'}"; ts="${ts%%$'\t'*}"
  acct="${line##*$'\t'}"

  [[ "$ts" == <-> ]] || return 1
  (( now - ts <= AWS_PROFILE_SELECTOR_CACHE_TTL )) || return 1
  [[ -n "$acct" && "$acct" != "None" ]] || return 1

  print -r -- "$acct"
  return 0
}

_awsps_cache_set_account() {
  local profile="$1" acct="$2" now
  [[ -n "$profile" && -n "$acct" && "$acct" != "None" ]] || return 0
  now="$(date +%s 2>/dev/null)" || return 0
  _awsps_ensure_cache_dir
  print -r -- "${profile}\t${now}\t${acct}" >> "$AWS_PROFILE_SELECTOR_CACHE_FILE" 2>/dev/null || true
}

_awsps_get_account_id() {
  local profile="$1" acct
  if acct="$(_awsps_cache_get_account "$profile")"; then
    print -r -- "$acct"
    return 0
  fi

  acct="$(aws sts get-caller-identity --profile "$profile" --query Account --output text 2>/dev/null)"
  acct="$(_awsps_sanitize "$acct")"
  if [[ -n "$acct" && "$acct" != "None" ]]; then
    _awsps_cache_set_account "$profile" "$acct"
    print -r -- "$acct"
    return 0
  fi
  return 1
}

# ARN -> friendly label
_awsps_label_from_arn() {
  local arn="$1" label=""
  arn="$(_awsps_sanitize "$arn")"

  if [[ "$arn" == *"user/"* ]]; then
    label="${arn##*user/}"
  elif [[ "$arn" == *":role/"* ]]; then
    label="${arn##*:role/}"
  elif [[ "$arn" == *":assumed-role/"* ]]; then
    # arn:aws:sts::123:assumed-role/ROLE/SESSION
    label="${arn##*:assumed-role/}"
    label="${label%%/*}"  # ROLE
  else
    label="${arn##*/}"
  fi

  label="$(_awsps_sanitize "$label")"
  print -r -- "${label:-$arn}"
}

_awsps_profile_display_label() {
  local profile="$1"
  local label="$profile" arn acct

  if [[ "$profile" == "default" ]]; then
    arn="$(aws sts get-caller-identity --profile default --query Arn --output text 2>/dev/null)"
    arn="$(_awsps_sanitize "$arn")"
    if [[ -n "$arn" && "$arn" != "None" ]]; then
      label="$(_awsps_label_from_arn "$arn")"
    else
      label="default (unverified)"
    fi
  fi

  if [[ "${AWS_PROFILE_SELECTOR_SHOW_ACCOUNT_ID}" == "1" ]]; then
    if acct="$(_awsps_get_account_id "$profile")"; then
      label="${label} (${acct})"
    fi
  fi

  print -r -- "$label"
}

# ------------------------------
# Public: selector
# ------------------------------
select_aws_profile() {
  command -v aws >/dev/null 2>&1 || return 0

  # Local traps so we don’t mess with OMZ/global traps
  setopt localtraps

  # local interrupted=0
  # trap 'interrupted=1; echo; return 0' INT
  trap '
    echo
    if [[ "${AWS_PROFILE_SELECTOR_CTRL_C_CLEARS_PROFILE}" == "1" ]]; then
      unset AWS_PROFILE AWS_DEFAULT_PROFILE
      echo "AWS profile cleared."
      echo
    fi
    return 0
  ' INT

  # Read profiles, sanitize, skip empties
  local -a raw profiles display_profiles
  raw=("${(@f)$(aws configure list-profiles 2>/dev/null)}")

  local p s
  profiles=()
  for p in "${raw[@]}"; do
    s="$(_awsps_sanitize "$p")"
    [[ -n "$s" ]] && profiles+=("$s")
  done
  (( ${#profiles[@]} == 0 )) && return 0

  display_profiles=()
  for p in "${profiles[@]}"; do
    display_profiles+=("$(_awsps_profile_display_label "$p")")
  done

  echo
  echo "Select AWS profile:"
  echo "-------------------"
  local i
  for (( i=1; i<=${#display_profiles[@]}; i++ )); do
    printf "%2d) %s\n" $i "${display_profiles[$i]}"
  done
  echo

  local reply selected_profile
  while true; do
    # If Ctrl-C: trap sets interrupted + prints newline + returns 0
    read -r "?Enter number (or Ctrl+C to skip): " reply || { echo; return 0; }

    # In case the trap fired, bail cleanly
    (( interrupted )) && return 0

    reply="$(_awsps_sanitize "$reply")"
    if [[ "$reply" == <-> ]] && (( reply >= 1 && reply <= ${#profiles[@]} )); then
      selected_profile="${profiles[$reply]}"
      export AWS_PROFILE="$selected_profile"
      echo
      echo "AWS_PROFILE set to: $AWS_PROFILE"
      echo
      return 0
    fi

    echo "Invalid selection."
  done
}

# Commands
awsp() { select_aws_profile; }
alias ap='awsp'

# Autorun
if [[ -o interactive ]] \
  && [[ "${AWS_PROFILE_SELECTOR_AUTORUN}" == "1" ]] \
  && [[ -z "${AWS_PROFILE:-}" ]]; then
  select_aws_profile 2>/dev/null || true
fi

export AWS_PROFILE_SELECTOR_CTRL_C_CLEARS_PROFILE=1