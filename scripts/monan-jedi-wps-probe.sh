#!/usr/bin/env bash
# Show the WPS configure menu under the active MONAN-JEDI JACI stack.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/lib/common.sh"
source "${script_dir}/lib/config.sh"
source "${script_dir}/lib/stack.sh"
source "${script_dir}/lib/wps.sh"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) export MONAN_JEDI_CONFIG="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: bash scripts/monan-jedi-wps-probe.sh [--config config/jaci.yaml]"
      exit 0
      ;;
    *) log_error "Unknown argument: $1"; exit 2 ;;
  esac
done

load_monan_jedi_config
monan_jedi_load_wps_config
monan_jedi_load_stack
require_cmd git
mkdir -p "${MONAN_JEDI_LOG_ROOT}"
monan_jedi_prepare_wps_source

cd "${MONAN_JEDI_WPS_SOURCE_DIR}"
./clean -a >/dev/null 2>&1 || true
rm -f configure.wps configure.wps.original
set +e
printf '\n' | ./configure --nowrf 2>&1 | tee "${MONAN_JEDI_LOG_ROOT}/09_wps_configure_menu.log"
status=${PIPESTATUS[1]}
set -e

echo
log_info "Review ${MONAN_JEDI_LOG_ROOT}/09_wps_configure_menu.log and record the serial GRIB2 menu number as wps.configure_option."
exit 0
