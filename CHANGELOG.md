# Changelog

All notable changes to **aws-profile-selector** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

### Added

- Startup confirmation prompt before autorun opens the AWS profile selector.
- Configurable `AWS_PROFILE_SELECTOR_CONFIRM_AUTORUN` toggle for enabling or disabling the confirmation step.

### Improved

- Manual `awsp` and `ap` commands remain available even when startup autorun is skipped.

---

## [1.0.0] - 2026-03-14

### Added

- Interactive AWS CLI profile selector for Oh My Zsh.
- `awsp` command for manual profile switching.
- `ap` shorthand alias for the selector.
- Optional automatic profile prompt on new interactive shells.
- ASCII banner with skull + AWS logo.
- Display of the currently active AWS profile.
- Support for extracting friendly labels from AWS ARNs:
  - `user/<name>`
  - `role/<name>`
  - `assumed-role/<role>`
- Optional AWS account ID display beside profiles.
- Local caching system for AWS account ID lookups to reduce STS calls.
- Configurable cache TTL (`AWS_PROFILE_SELECTOR_CACHE_TTL`).
- Configurable cache file location (`AWS_PROFILE_SELECTOR_CACHE_FILE`).
- Optional production account highlighting via `AWS_PROD_ACCOUNTS`.

### Changed

- Replaced literal `\t` separators in cache storage with real tab characters using `printf`.
- Improved parsing of cached values to prevent malformed timestamp calculations.
- Sanitized profile input to remove whitespace and carriage returns.

### Fixed

- Fixed `bad math expression: illegal character: \` error caused by invalid cache formatting.
- Fixed broken terminal prompt behavior when cancelling with `Ctrl+C`.
- Fixed blank profile entries caused by hidden characters in AWS CLI output.
- Fixed profile matching logic to prevent partial matches (e.g., `dev` matching `devops`).

### Improved

- Robust Ctrl+C handling:
  - Cancelling the selector now exits cleanly.
  - Optionally clears `AWS_PROFILE` and `AWS_DEFAULT_PROFILE`.
- Improved terminal compatibility across common shells and terminals.
- Reduced unnecessary AWS STS calls via caching.
- Improved banner rendering for standard terminal character aspect ratios.

---

## Configuration Options

| Variable | Description | Default |
|--------  |--------     |-------- |
| `AWS_PROFILE_SELECTOR_AUTORUN` | Prompt for profile on new shells | `1` |
| `AWS_PROFILE_SELECTOR_SHOW_ACCOUNT_ID` | Show account IDs beside profiles | `0` |
| `AWS_PROFILE_SELECTOR_CACHE_TTL` | Cache lifetime in seconds | `600` |
| `AWS_PROFILE_SELECTOR_CACHE_FILE` | Cache file location | `~/.aws/aws-profile-selector-cache` |
| `AWS_PROFILE_SELECTOR_CTRL_C_CLEARS_PROFILE` | Ctrl+C clears active AWS profile | `1` |
| `AWS_PROD_ACCOUNTS` | Comma-separated list of production account IDs | unset |

---

## Notes

This release focuses on stability, terminal compatibility, and improved safety for multi-account AWS workflows.

Future releases may include:

- prompt integration displaying active AWS account
- account colorization based on environment
- faster profile detection
- optional fzf selector mode
