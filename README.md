# aws-profile-selector (Oh My Zsh plugin)

Interactive AWS CLI profile picker for zsh / Oh My Zsh.

## Features

- Lists AWS CLI profiles and lets you choose one by number
- Asks on shell startup whether the selector should run
- Sets `AWS_PROFILE` in your current shell
- Replaces the `default` label with a friendlier value derived from STS ARN:
  - If ARN contains `user/`, displays what comes after `user/`
  - Otherwise displays the last segment of the ARN
- Prints the menu one entry per line
- Provides commands:
  - `awsp` (switch profile)
  - `ap` (alias)

## Install (Oh My Zsh)

### Clone into custom plugins

```sh
git clone <THIS_REPO_URL> ~/.oh-my-zsh/custom/plugins/aws-profile-selector
```

## Behavior

When a new interactive shell starts, the plugin now asks:

```sh
Run AWS profile selector now? [y/N]:
```

- `y` or `yes` opens the selector
- `n`, `no`, or Enter skips it for that shell session
- `ap` still opens the selector manually at any time

## Configuration

- `AWS_PROFILE_SELECTOR_AUTORUN=1` enables the startup check
- `AWS_PROFILE_SELECTOR_CONFIRM_AUTORUN=1` asks before autorun starts

Set `AWS_PROFILE_SELECTOR_CONFIRM_AUTORUN=0` if you want the old behavior where the selector opens immediately on shell startup.
