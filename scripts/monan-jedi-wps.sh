#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib/common.sh"
source "${script_dir}/lib/config.sh"
source "${script_dir}/lib/stack.sh"
source "${script_dir}/lib/wps.sh"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      export MONAN_JEDI_CONFIG="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: bash scripts/monan-jedi-wps.sh [--config config/jaci.yaml]"
      exit 0
      ;;
    *)
      log_error "Unknown argument: $1"
      exit 2
      ;;
  esac
done

load_monan_jedi_config
monan_jedi_build_wps
