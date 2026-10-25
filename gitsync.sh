#!/usr/bin/env bash
# GitSync Ultra — macOS / Linux Wrapper
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/gitsync" "$@"
