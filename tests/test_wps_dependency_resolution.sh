#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../scripts/lib/wps_dependencies.sh
source "${repo_root}/scripts/lib/wps_dependencies.sh"

log_info() {
  printf '[INFO] %s\n' "$*"
}

log_warn() {
  printf '[WARN] %s\n' "$*" >&2
}

log_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

make_dependency_prefix() {
  local root="$1"
  local package="$2"

  mkdir -p "${root}/include" "${root}/lib"
  case "${package}" in
    jasper)
      mkdir -p "${root}/include/jasper"
      : > "${root}/include/jasper/jasper.h"
      : > "${root}/lib/libjasper.so"
      ;;
    libpng)
      : > "${root}/include/png.h"
      : > "${root}/lib/libpng16.so"
      ;;
    zlib)
      : > "${root}/include/zlib.h"
      : > "${root}/lib/libz.so"
      ;;
    *)
      echo "unknown dependency: ${package}" >&2
      return 1
      ;;
  esac
}

assert_equal() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  if [[ "${expected}" != "${actual}" ]]; then
    echo "assertion failed for ${label}: expected=${expected}, actual=${actual}" >&2
    exit 1
  fi
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

jasper_root="${tmp_dir}/prefixes/jasper"
png_root="${tmp_dir}/prefixes/libpng"
zlib_root="${tmp_dir}/prefixes/zlib"
make_dependency_prefix "${jasper_root}" jasper
make_dependency_prefix "${png_root}" libpng
make_dependency_prefix "${zlib_root}" zlib

# A loaded environment may expose dependency prefixes without exposing the
# Spack CLI. This is the failure mode observed on JACI.
export PATH="/usr/bin:/bin"
export CMAKE_PREFIX_PATH="${jasper_root};${png_root}:${zlib_root}"
export STACK_ROOT="${tmp_dir}/stack-without-spack"
export STACK_WORK_ROOT="${tmp_dir}/work-without-spack"
export STACK_OWNER="test-owner"
export STACK_INSTANCE="test-instance"
unset MONAN_JEDI_WPS_JASPER_ROOT MONAN_JEDI_WPS_PNG_ROOT MONAN_JEDI_WPS_ZLIB_ROOT

monan_jedi_wps_resolve_dependencies
assert_equal "${jasper_root}" "${MONAN_JEDI_WPS_JASPER_RESOLVED_ROOT}" "JasPer from CMAKE_PREFIX_PATH"
assert_equal "${png_root}" "${MONAN_JEDI_WPS_PNG_RESOLVED_ROOT}" "libpng from CMAKE_PREFIX_PATH"
assert_equal "${zlib_root}" "${MONAN_JEDI_WPS_ZLIB_RESOLVED_ROOT}" "zlib from CMAKE_PREFIX_PATH"

# When available, use the Spack executable shipped inside STACK_ROOT even when
# no global `spack` command exists.
fake_stack="${tmp_dir}/fake-stack"
mkdir -p "${fake_stack}/spack/bin"
cat > "${fake_stack}/spack/bin/spack" <<EOF
#!/usr/bin/env bash
set -euo pipefail
[[ "\$1" == location && "\$2" == -i ]]
case "\$3" in
  jasper) printf '%s\n' '${jasper_root}' ;;
  libpng) printf '%s\n' '${png_root}' ;;
  zlib) printf '%s\n' '${zlib_root}' ;;
  *) exit 1 ;;
esac
EOF
chmod +x "${fake_stack}/spack/bin/spack"

export STACK_ROOT="${fake_stack}"
unset CMAKE_PREFIX_PATH
assert_equal "${jasper_root}" "$(monan_jedi_wps_location_from_spack jasper)" "stack-local Spack"

# Final fallback: inspect the stack installation tree directly.
install_stack="${tmp_dir}/install-layout/spack-stack"
install_jasper="${tmp_dir}/install-layout/install/gcc/test/jasper-test"
mkdir -p "${install_stack}"
make_dependency_prefix "${install_jasper}" jasper
export STACK_ROOT="${install_stack}"
export STACK_WORK_ROOT="${tmp_dir}/unused-work"
assert_equal "${install_jasper}" "$(monan_jedi_wps_location_from_install_tree jasper)" "stack install tree"

printf 'WPS dependency resolution tests passed.\n'
