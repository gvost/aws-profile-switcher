# ------------------------------
# AWS Profile Selector
# ------------------------------

select_aws_profile() {
  command -v aws >/dev/null 2>&1 || return 0

  local -a profiles display_profiles
  profiles=("${(@f)$(aws configure list-profiles 2>/dev/null)}")
  (( ${#profiles[@]} == 0 )) && return 0

  local p arn trimmed

  for p in "${profiles[@]}"; do
    if [[ "$p" == "default" ]]; then
      arn="$(aws sts get-caller-identity --profile default --query Arn --output text 2>/dev/null)"

      if [[ -n "$arn" && "$arn" != "None" ]]; then
        # Prefer trimming to what's after "user/"
        if [[ "$arn" == *"user/"* ]]; then
          trimmed="${arn##*user/}"
          display_profiles+=("$trimmed")
        else
          # Fallback: last path segment of ARN (roles, etc.)
          display_profiles+=("${arn##*/}")
        fi
      else
        display_profiles+=("default (unverified)")
      fi
    else
      display_profiles+=("$p")
    fi
  done

  echo
  echo "Select AWS profile:"
  echo "-------------------"

  # Print menu on new lines
  local i
  for (( i=1; i<=${#display_profiles[@]}; i++ )); do
    printf "%2d) %s\n" $i "${display_profiles[$i]}"
  done

  echo
  local reply selected_profile
  while true; do
    read -r "?Enter number (or Ctrl+C to skip): " reply

    if [[ "$reply" == <-> ]] && (( reply >= 1 && reply <= ${#profiles[@]} )); then
      selected_profile="${profiles[$reply]}"
      export AWS_PROFILE="$selected_profile"

      echo
      echo "AWS_PROFILE set to: $AWS_PROFILE"
      echo
    # aws sts get-caller-identity 2>/dev/null || echo "Unable to verify identity."
    # echo
      return 0
    fi

    echo "Invalid selection."
  done
}

# run it automatically on new shells (only if AWS_PROFILE isn’t set)
if [[ -o interactive ]] && [[ -z "${AWS_PROFILE:-}" ]]; then
  select_aws_profile
fi

# Command to switch on-demand
awsp() { select_aws_profile; }
alias ap='awsp'