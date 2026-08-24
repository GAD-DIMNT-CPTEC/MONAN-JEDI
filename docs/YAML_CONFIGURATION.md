# MONAN-JEDI YAML configuration reference

The YAML file is the user-facing interface for the build workflow. Routine use should not require editing shell scripts.

The default JACI configuration is `config/jaci.yaml`; `config/template.yaml` is the starting point for another site.

## Configuration loader contract

`scripts/lib/read_config.py` is the boundary between the user-facing YAML file
and the shell workflow. It emits safely quoted `export NAME=value` commands;
`scripts/lib/config.sh` evaluates those commands and then derives paths that
depend on multiple settings.

Each mapped value follows this precedence:

1. an existing environment variable, including an explicitly empty value;
2. the corresponding YAML value;
3. the built-in scalar default;
4. an empty string when no value or default exists.

YAML booleans are exported as `1` or `0`. References such as `${USER}` in
YAML scalar values are expanded from the loader process environment. Strings,
numbers and booleans are supported; lists and mappings are rejected because they
cannot be represented unambiguously by the shell-variable contract.

The generated values are quoted with Python's `shlex.quote`, so spaces and shell
metacharacters remain data when `config.sh` evaluates the output. Diagnostics
are written to standard error, and loader failures are not evaluated as partial
configuration.

The loader must remain compatible with Python 3.6 because a JACI PBS job can
execute it on a compute node before the spack-stack environment has been loaded.

## Path derivation

When optional paths are empty, the workflow derives them from `project.root`, `build.id` and `install.root`.

```text
work root       ${project.root}/work/${build.id}
log root        ${project.root}/logs/${build.id}
bundle build    ${work root}/build
install root    ${project.root}/builds/${build.id}
install bin     ${install root}/bin
```

Environment variables already set before invoking the workflow override YAML values. Persistent configuration should remain in YAML; environment overrides are intended for temporary tests.

## `site`

Human-readable site identifier. It does not by itself make the workflow portable; module loading is controlled by `stack.*` and `scripts/lib/stack.sh`.

## `project`

```yaml
project:
  root: /p/projetos/monan_das/${USER}
```

The writable root used for work trees, logs and default installation paths.

## `stack`

```yaml
stack:
  owner: joao.gerd
  instance: spack-stack-instance
  work_root:
  root:
  env_name: jaci-mpas-jedi-gcc12-craympich
  module_root:
  site_setup: configs/sites/tier2/jaci/setup.sh
  env_module: module/name
```

- `owner`: account that owns the stack;
- `instance`: stack instance directory name;
- `work_root`: optional explicit parent of the stack checkout;
- `root`: optional explicit `spack-stack` root;
- `env_name`: generated stack environment name;
- `module_root`: optional explicit module tree;
- `site_setup`: site setup script relative to `stack.root`;
- `env_module`: environment module loaded by the workflow.

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

`build.jobs` controls bundle and auxiliary CMake parallelism. Build and install paths are independent from the source and stack paths.

## `model`

```yaml
model:
  double_precision: 'ON'
```

Use `'ON'` when validating against MPAS-JEDI reference tests. Use `'OFF'` only for workflows that explicitly require single precision. Keep the value quoted.

## `data`

```yaml
data:
  root:
  local_root:
  download_missing: true
  crtm_coeffs_url: https://example/archive.tgz
  crtm_coeffs_tgz:
```

Controls local and cached external data used while configuring and testing the bundle.

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

The converter is built outside the main bundle tree with the same stack environment and is published to `install.bin_dir`.

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

- `enabled`: include WPS in `all` and allow `wps`/`test-wps` commands;
- `repo`, `ref`, `version`: pinned source identity;
- `source_dir`: checkout directory, default `${work root}/wps/src`;
- `build_dir`: CMake tree, default `${work root}/wps/build`;
- `releases_dir`: versioned release parent, default `${install.root}/wps`;
- `install_dir`: validated release path, default `${releases_dir}/WPS-${version}`;
- `patch_dir`: compatibility patches, default `${repository}/patches/wps`;
- `jasper_root`, `png_root`, `zlib_root`: optional explicit dependency roots; when empty they are resolved through Spack;
- `cmake_prefix_path`: optional additional CMake prefixes;
- `build_type`: `Release`, `Debug`, `RelWithDebInfo` or `MinSizeRel`;
- `ungrib_name`, `link_grib_name`: stable names in `install.bin_dir`;
- `default_vtable`: file selected by the stable `${install.root}/share/wps/Vtable` link.

The WPS integration uses CMake with WRF, MPI, OpenMP and bundled externals disabled. It builds the standalone UNGRIB toolchain required by MPAS initialization.

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

On JACI these should normally be CrayPE wrappers. They are resolved after the stack module is loaded.

## `ctest`

```yaml
ctest:
  login_regex: "^mpasjedi_coding_norms$"
  pbs_regex: ""
  exclude_regex: ""
  jobs: 1
  allow_login_node_mpi_tests: false
```

Controls login-node-safe and PBS test selection. Keep MPI tests off login nodes unless explicitly validated as safe.

## `pbs`

```yaml
pbs:
  queue: pesqmidi
  ncpus: 64
  walltime: "02:00:00"
  submit_job: true
```

Controls generated PBS jobs for compute-node validation. The complete serial
JACI inventory contains more than 2200 tests and does not fit in the 30-minute
`pesqmini` limit. The default therefore uses the two-hour `pesqmidi` maximum.
See [JACI PBS queue limits](jaci-pbs-queues.md) for the observed queue table,
selection constraints and commands that query the live scheduler.

On JACI, every generated job for a queue other than `aux` automatically
contains:

```text
#PBS -l place=excl
```

This is a mandatory site policy for queues that use compute nodes. The `aux`
queue is the documented exception and remains shared; the generator omits the
directive for both `aux` and server-qualified names such as `aux@pbs-ha`.
The generated PBS script is checked against this policy before any `qsub`.
