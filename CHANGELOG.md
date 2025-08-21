# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
- Add global config option for HTTP->HTTPS redirect (planned)
- Add basic test suite (planned)

## [0.1.0] - 2025-08-21
### Added
- Initial release of `local-https` gem and CLI
- mkcert integration, `/etc/hosts` management, JSON config
- HTTPS reverse proxy with SNI and HTTP->HTTPS redirect
- Foreground mode, sudo user home handling
