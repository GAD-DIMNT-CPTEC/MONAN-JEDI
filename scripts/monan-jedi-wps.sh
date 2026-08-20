#!/usr/bin/env bash
# Compatibility wrapper. Prefer: scripts/monan-jedi.sh wps --config <file>

set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${script_dir}/monan-jedi.sh" wps "$@"
