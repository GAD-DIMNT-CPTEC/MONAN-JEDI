#!/usr/bin/env bash
# JEDI bundle preparation helpers.

monan_jedi_prepare_bundle() {
  require_cmd git

  monan_jedi_load_stack

  mkdir -p "$(dirname "${JEDI_BUNDLE_SRC_DIR}")"

  if [[ ! -d "${JEDI_BUNDLE_SRC_DIR}/.git" ]]; then
    git clone "${JEDI_BUNDLE_REPO}" "${JEDI_BUNDLE_SRC_DIR}"
  fi

  cd "${JEDI_BUNDLE_SRC_DIR}"

  git fetch --all --tags --prune
  git checkout "${JEDI_BUNDLE_REF}"

  log_info "Prepared JEDI bundle source"
}

monan_jedi_create_mpas_only_bundle() {
  monan_jedi_load_stack

  if [[ ! -d "${JEDI_BUNDLE_SRC_DIR}/.git" ]]; then
    log_error "JEDI bundle source not found: ${JEDI_BUNDLE_SRC_DIR}"
    exit 1
  fi

  cd "${JEDI_BUNDLE_SRC_DIR}"

  local backup_file="CMakeLists.txt.monan-jedi-backup"

  [[ -f "${backup_file}" ]] || cp CMakeLists.txt "${backup_file}"

  log_warn "Reduced MPAS-only bundle generation should reuse the validated logic from scripts/03_create_mpas_only_bundle.sh"
}
