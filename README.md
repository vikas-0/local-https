# local-https

Run any local app with HTTPS and a custom domain.

- Certificates via [mkcert](https://github.com/FiloSottile/mkcert)
- Hosts mapping in `/etc/hosts`
- HTTPS reverse proxy using WEBrick with SNI support
- Optional HTTP → HTTPS redirect on port 80

## Install

```bash
./install.sh
```

The proxy binds to port 443, which typically requires root privileges. You'll likely run proxy commands with `sudo`.

## Usage

```bash
# Add a mapping and generate a cert
local-https add myapp.test 3000

# Start the HTTPS reverse proxy (binds to :443, also starts :80 redirect)
sudo local-https start

# Start in foreground for debugging (shows logs)
sudo local-https start --no-daemon

# Disable HTTP→HTTPS redirect (only serve HTTPS on :443)
sudo local-https start --no-redirect-http

# Visit your app
open https://myapp.test
open http://myapp.test  # will redirect to https (if redirect is enabled)

# List mappings
local-https list

# Remove mapping (also stops proxy)
local-https remove myapp.test

# Stop proxy
sudo local-https stop
```

## How it works

- Certs are stored in `~/.local-https/certs` as `<domain>.pem` and `<domain>-key.pem`.
- Config is `~/.local-https/config.json`.
- `/etc/hosts` is updated with `127.0.0.1 <domain> # local-https` (requires sudo).
- The proxy uses SNI to present the right certificate per requested domain and forwards to `http://127.0.0.1:<port>` based on the `Host` header.
- If enabled, an HTTP server on port 80 issues a `301` to the equivalent `https://<host><path>` URL.
  - If port 80 is unavailable, the proxy continues without HTTP redirect and logs a warning.

## Troubleshooting

- If binding to `:443` fails: run with `sudo`.
- If binding to `:80` fails: another service is using it. Either free it or run `sudo local-https start --no-redirect-http`.
- If `mkcert` is missing: run `./install.sh` or install manually.
- If `/etc/hosts` updates fail: run commands that touch hosts with `sudo`.
- When running with `sudo`, the tool stores config and certs under the invoking user's home (via `SUDO_USER`), not `/var/root`.
- Foreground mode (`--no-daemon`) is helpful to see startup errors.

## Development

```bash
# Run from source (no install required)
bin/local-https list
sudo bin/local-https start --no-daemon

# Or build and install the gem locally
gem build local-https.gemspec
sudo gem install ./local-https-*.gem
```
