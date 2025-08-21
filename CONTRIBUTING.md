# Contributing to local-https

Thanks for your interest in contributing!

## Getting started
- Requires Ruby >= 3.0
- Install mkcert and run `mkcert -install` (see README or `install.sh`)

```bash
# Clone and setup
git clone https://github.com/<your-org>/local-https.git
cd local-https

# Run from source
bin/local-https list
sudo bin/local-https start --no-daemon

# Lint
bundle install
bundle exec rubocop

# Build gem
gem build local-https.gemspec
```

## Development notes
- Runtime config lives in `~/.local-https/`
- When starting with `sudo`, the tool uses the invoking user's home (via `SUDO_USER`).
- Foreground mode (`--no-daemon`) helps debug startup issues.

## Making changes
- Keep changes small and focused.
- Add/expand README or docs for user-facing changes.
- Follow conventional commits if possible (feat:, fix:, docs:, chore:, refactor:).

## Pull Requests
- Ensure CI is passing (lint, build).
- Link related issues and add a brief description of the change and rationale.

## Releasing
- Bump version in `lib/local_https/VERSION`.
- Update `CHANGELOG.md`.
- Build and publish gem:
  ```bash
  gem build local-https.gemspec
  gem push local-https-<version>.gem
  ```
