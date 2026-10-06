# Contributing

## How to contribute

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/my-change`
3. Commit your changes
4. Push and open a Pull Request against `main`

## Script guidelines

- All scripts must be POSIX-compatible bash (`#!/usr/bin/env bash`)
- Use `set -euo pipefail`
- Read connection details from environment variables (`ES_URL`, `ES_USER`, `ES_PASS`)
- Include a `-h` help flag and `-n` dry-run flag where destructive actions are involved
- Test against Elasticsearch 9.x

## Code of Conduct

Please read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
