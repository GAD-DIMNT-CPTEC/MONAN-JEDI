# MONAN-JEDI YAML configuration reference

The YAML file is the user-facing build/install interface. Routine use should not
require editing scripts.

The default JACI file is `config/jaci.yaml`; use `config/template.yaml` for
another site.

## Loader contract

`scripts/lib/read_config.py` maps YAML scalars to safely quoted shell exports.
`scripts/lib/config.sh` then derives values that depend on multiple settings.

Precedence is:

1. existing environment variable;
2. YAML value;
3. built-in scalar default;
4. empty string when none exists.

YAML booleans become `1`/`0`; `${NAME}` expressions in scalar strings are
expanded from the environment. Lists/mappings are not exported through this
shell-variable boundary.

## Filesystem model

When optional paths are empty:

```text
work root       ${project.root}/work/${build.id}
log root        ${project.root}/logs/${build.id}
bundle build    ${work root}/build
install root    ${project.root}/build/${build.id}
install bin     ${install root}/bin
WPS source      ${work root}/wps/src
WPS build       ${work root}/wps/build
WPS releases    ${install root}/libexec/monan-jedi/wps
```

The central rule is:

```text
work/  = private/rebuildable
build/ = public runtime installation
```

Downstream workflows should consume `MONAN_JEDI_INSTALL_ROOT` only. See
[runtime-install-contract.md](runtime-install-contract.md).

## `site`

Human-readable site identifier.

## `project`

```yaml
project:
  root: /p/projetos/monan_das/${USER}
```

Writable user/project root used to derive work, log and install paths.

## `stack`

```yaml
stack:
  owner: joao.gerd
  instance: stack-instance
  work_root:
  root:
  env_name: jaci-mpas-jedi-gcc12-craympich
  module_root:
  site_setup: configs/sites/tier2/jaci/setup.sh
  env_module: module/name
```

The stack is a separate dependency environment and does not live inside the
MONAN-JEDI runtime prefix.

## `build` and `install`

```yaml
build:
  id: monan-jedi
  dir:
  jobs: 64

install:
  root:
  bin_dir:
```

Empty `install.root` resolves to:

```text
${project.root}/build/${build.id}
```

This becomes the canonical `MONAN_JEDI_INSTALL_ROOT` consumed by downstream
workflows.

## `model`

```yaml
model:
  double_precision: 'ON'
```

Keep `ON`/`OFF` quoted.

## `data`

```yaml
data:
  root:
  local_root:
  download_missing: true
  crtm_coeffs_url: https://example/archive.tgz
  crtm_coeffs_tgz:
```

Controls cached external archives. Git-LFS test-data repositories are handled
separately; see [jedi-test-data.md](jedi-test-data.md).

## `obs2ioda`

```yaml
obs2ioda:
  enabled: true
  repo: https://github.com/NCAR/obs2ioda.git
  ref: main
  source_dir:
  build_dir:
  install_dir:
  executable_name: obs2ioda_v3
  bufr_root:
  bufr_lib:
  cmake_prefix_path:
  build_type: Release
  build_goes_abi_converter: 'OFF'
```

`obs2ioda` builds in its private work tree and publishes its stable executable
into `install.bin_dir`.

## `wps`

```yaml
wps:
  enabled: true
  repo: https://github.com/wrf-model/WPS.git
  ref: 335c76a111f84503e8b963abaf273ea8053645bb
  version: 4.6.0
  source_dir:
  build_dir:
  releases_dir:
  install_dir:
  patch_dir:
  jasper_root:
  png_root:
  zlib_root:
  cmake_prefix_path:
  build_type: Release
  ungrib_name: ungrib.exe
  link_grib_name: link_grib.csh
  default_vtable: Vtable.GFS
```

Defaults:

```text
source_dir    ${work root}/wps/src
build_dir     ${work root}/wps/build
releases_dir  ${install.root}/libexec/monan-jedi/wps
install_dir   ${releases_dir}/WPS-${wps.version}
patch_dir     <MONAN-JEDI checkout>/patches/wps
```

The versioned release path is private. After validation, MONAN-JEDI publishes:

```text
${install.root}/bin/ungrib.exe
${install.root}/bin/link_grib.csh
${install.root}/share/wps/Vtable
${install.root}/share/wps/Variable_Tables
```

These are the WPS paths consumed by `mpaswf`.

## `compilers` and `mpi`

```yaml
compilers:
  cc: cc
  cxx: CC
  fc: ftn
  f77: ftn
  f90: ftn

mpi:
  mpicc: cc
  mpicxx: CC
  mpifc: ftn
  mpif77: ftn
  mpif90: ftn
```

On JACI these are normally CrayPE wrappers selected after loading the configured
stack module.

## `ctest`

```yaml
ctest:
  login_regex: "^mpasjedi_coding_norms$"
  pbs_regex: ""
  exclude_regex: ""
  jobs: 1
  allow_login_node_mpi_tests: false
```

## `pbs`

```yaml
pbs:
  queue: pesqmidi
  ncpus: 64
  walltime: "02:00:00"
  submit_job: true
```

See [jaci-pbs-queues.md](jaci-pbs-queues.md) for JACI queue policy.

## Runtime support publication

The bundle install step also publishes downstream runtime YAMLs:

```text
${install.root}/share/monan-jedi/mpas-jedi/namelists/geovars.yaml
${install.root}/share/monan-jedi/mpas-jedi/namelists/keptvars.yaml
```

This deliberately prevents `MPAS-BMatrix` from depending on the MONAN-JEDI
source tree.
