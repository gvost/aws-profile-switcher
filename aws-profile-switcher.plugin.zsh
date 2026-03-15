# aws-profile-selector.plugin.zsh
# Interactive AWS profile selector for Oh My Zsh

# ------------------------------------------------
# Settings (can override in ~/.zshrc)
# ------------------------------------------------

: "${AWS_PROFILE_SELECTOR_AUTORUN:=1}"
: "${AWS_PROFILE_SELECTOR_CONFIRM_AUTORUN:=1}"
: "${AWS_PROFILE_SELECTOR_SHOW_ACCOUNT_ID:=0}"
: "${AWS_PROFILE_SELECTOR_CACHE_TTL:=600}"
: "${AWS_PROFILE_SELECTOR_CACHE_FILE:=$HOME/.aws/aws-profile-selector-cache}"
: "${AWS_PROFILE_SELECTOR_CTRL_C_CLEARS_PROFILE:=1}"

# Optional: comma separated list of prod account IDs
# Example: export AWS_PROD_ACCOUNTS="123456789012,999999999999"
: "${AWS_PROD_ACCOUNTS:=}"

# ------------------------------------------------
# Helpers
# ------------------------------------------------

_awsps_sanitize() {
  local s="$1"
  s="${s//$'\r'/}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  print -r -- "$s"
}

_awsps_ensure_cache_dir() {
  local dir="${AWS_PROFILE_SELECTOR_CACHE_FILE:h}"
  [[ -d "$dir" ]] || mkdir -p "$dir" 2>/dev/null
}

# ------------------------------------------------
# Cache helpers
# ------------------------------------------------

_awsps_cache_get_account() {
  local profile="$1"
  local now line ts acct

  [[ -f "$AWS_PROFILE_SELECTOR_CACHE_FILE" ]] || return 1
  now=$(date +%s) || return 1

  line=$(awk -F '\t' -v p="$profile" '$1 == p {print $0}' "$AWS_PROFILE_SELECTOR_CACHE_FILE" 2>/dev/null | tail -n 1)
  [[ -n "$line" ]] || return 1

  ts="${line#*$'\t'}"
  ts="${ts%%$'\t'*}"
  acct="${line##*$'\t'}"

  [[ "$ts" == <-> ]] || return 1
  (( now - ts <= AWS_PROFILE_SELECTOR_CACHE_TTL )) || return 1
  [[ -n "$acct" && "$acct" != "None" ]] || return 1

  print -r -- "$acct"
  return 0
}

_awsps_cache_set_account() {
  local profile="$1"
  local acct="$2"

  [[ -n "$profile" && -n "$acct" && "$acct" != "None" ]] || return 0

  _awsps_ensure_cache_dir
  printf '%s\t%s\t%s\n' "$profile" "$(date +%s)" "$acct" >> "$AWS_PROFILE_SELECTOR_CACHE_FILE"
}

_awsps_get_account_id() {
  local profile="$1"
  local acct

  acct="$(_awsps_cache_get_account "$profile")"
  if [[ -n "$acct" ]]; then
    print -r -- "$acct"
    return 0
  fi

  acct=$(aws sts get-caller-identity \
    --profile "$profile" \
    --query Account \
    --output text 2>/dev/null)

  acct="$(_awsps_sanitize "$acct")"

  if [[ -n "$acct" && "$acct" != "None" ]]; then
    _awsps_cache_set_account "$profile" "$acct"
    print -r -- "$acct"
    return 0
  fi

  return 1
}

# ------------------------------------------------
# ARN label parsing
# ------------------------------------------------

_awsps_label_from_arn() {
  local arn="$1"

  if [[ "$arn" == *"user/"* ]]; then
    print -r -- "${arn##*user/}"
  elif [[ "$arn" == *":role/"* ]]; then
    print -r -- "${arn##*:role/}"
  elif [[ "$arn" == *":assumed-role/"* ]]; then
    local role="${arn##*:assumed-role/}"
    print -r -- "${role%%/*}"
  else
    print -r -- "${arn##*/}"
  fi
}

# ------------------------------------------------
# Profile label builder
# ------------------------------------------------

_awsps_profile_display_label() {
  local profile="$1"
  local label="$profile"

  if [[ "$profile" == "default" ]]; then
    local arn
    arn=$(aws sts get-caller-identity \
      --profile default \
      --query Arn \
      --output text 2>/dev/null)

    arn="$(_awsps_sanitize "$arn")"

    if [[ -n "$arn" && "$arn" != "None" ]]; then
      label="$(_awsps_label_from_arn "$arn")"
    else
      label="default"
    fi
  fi

  if [[ "$AWS_PROFILE_SELECTOR_SHOW_ACCOUNT_ID" == "1" ]]; then
    local acct
    acct="$(_awsps_get_account_id "$profile")"
    [[ -n "$acct" ]] && label="$label ($acct)"
  fi

  print -r -- "$label"
}

# ------------------------------------------------
# Banner
# ------------------------------------------------

_awsps_print_banner() {
  local color=208

  if [[ -n "$AWS_PROD_ACCOUNTS" && -n "${AWS_PROFILE:-}" ]]; then
    local acct
    acct="$(_awsps_get_account_id "$AWS_PROFILE")"

    if [[ -n "$acct" && ",$AWS_PROD_ACCOUNTS," == *",$acct,"* ]]; then
      color=196
    fi
  fi

  print -P "%F{$color}
   █████  ██     ██  ██████
  ██   ██ ██     ██ ██
  ███████ ██  █  ██  █████
  ██   ██ ██ ███ ██      ██
  ██   ██  ███ ███  ██████

     PROFILE SELECTOR
%f"
}

# ------------------------------------------------
# Autorun prompt
# ------------------------------------------------

_awsps_confirm_autorun() {
  local reply

  while true; do
    read -r "?Run AWS profile selector now? [y/N]: " reply || return 1

    reply="$(_awsps_sanitize "$reply")"
    reply="${reply:l}"

    case "$reply" in
      y|yes)
        return 0
        ;;
      ""|n|no)
        return 1
        ;;
    esac

    echo "Please enter y or n."
  done
}

# ------------------------------------------------
# Main selector
# ------------------------------------------------

select_aws_profile() {
  command -v aws >/dev/null 2>&1 || return 0

  setopt localtraps

  trap '
    echo
    if [[ "$AWS_PROFILE_SELECTOR_CTRL_C_CLEARS_PROFILE" == "1" ]]; then
      unset AWS_PROFILE AWS_DEFAULT_PROFILE
      echo "AWS profile cleared."
      echo
    fi
    return 0
  ' INT

  local -a raw profiles display_profiles
  local p reply

  raw=("${(@f)$(aws configure list-profiles 2>/dev/null)}")

  profiles=()
  for p in "${raw[@]}"; do
    p="$(_awsps_sanitize "$p")"
    [[ -n "$p" ]] && profiles+=("$p")
  done

  (( ${#profiles[@]} == 0 )) && return 0

  display_profiles=()
  for p in "${profiles[@]}"; do
    display_profiles+=("$(_awsps_profile_display_label "$p")")
  done

  echo
  _awsps_print_banner
  echo
  echo "----------------------------------------"
  echo "Select AWS profile:"
  echo "----------------------------------------"

  local i
  for (( i=1; i<=${#display_profiles[@]}; i++ )); do
    printf "%2d) %s\n" $i "${display_profiles[$i]}"
  done

  echo
  echo "Current profile: ${AWS_PROFILE:-none}"
  echo

  while true; do
    read -r "?Enter number (or Ctrl+C to clear/skip): " reply || return 0

    reply="$(_awsps_sanitize "$reply")"

    if [[ "$reply" == <-> ]] && (( reply >= 1 && reply <= ${#profiles[@]} )); then
      export AWS_PROFILE="${profiles[$reply]}"

      echo
      echo "AWS_PROFILE set to: $AWS_PROFILE"
      echo

      return 0
    fi

    echo "Invalid selection."
  done
}

# ------------------------------------------------
# Commands
# ------------------------------------------------

awsp() { select_aws_profile; }
alias ap='awsp'

# ------------------------------------------------
# Autorun
# ------------------------------------------------

_awsps_maybe_autorun() {
  command -v aws >/dev/null 2>&1 || return 0
  [[ -o interactive ]] || return 0
  [[ "$AWS_PROFILE_SELECTOR_AUTORUN" == "1" ]] || return 0
  [[ -z "${AWS_PROFILE:-}" ]] || return 0

  if [[ "$AWS_PROFILE_SELECTOR_CONFIRM_AUTORUN" == "1" ]]; then
    echo
    _awsps_confirm_autorun || return 0
  fi

  select_aws_profile 2>/dev/null || true
}

_awsps_maybe_autorun
