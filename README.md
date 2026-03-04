# aws-profile-selector (Oh My Zsh plugin)

Interactive AWS CLI profile picker for zsh / Oh My Zsh.

## Features

- Lists AWS CLI profiles and lets you choose one by number
- Sets `AWS_PROFILE` in your current shell
- Replaces the `default` label with a friendlier value derived from STS ARN:
  - If ARN contains `user/`, displays what comes after `user/`
  - Otherwise displays the last segment of the ARN
- Prints the menu one entry per line
- Provides commands:
  - `awsp` (switch profile)
  - `ap` (alias)

## Install (Oh My Zsh)

### Option A: Clone into custom plugins

```sh
git clone <THIS_REPO_URL> ~/.oh-my-zsh/custom/plugins/aws-profile-selector
```
