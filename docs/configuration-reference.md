# MONAN-JEDI configuration reference

The YAML file is the user-facing interface for building, installing and
validating MONAN-JEDI. It is **not** an operational data-assimilation experiment
file.

The maintained JACI file is `config/jaci.yaml`. Start another site from
`config/template.yaml`.

## Precedence and validation

For public settings, precedence is:

1. a non-empty environment variable;
2. the YAML value;
3. the default defined by `scripts/lib/read_config.py`.

Unknown YAML keys, invalid types and invalid enumerated values are rejected.
Validate without running the workflow:

```bash
python3 scripts/lib/read_config.py --check config/jaci.yaml
```

## Derived filesystem layout

The following paths are derived and intentionally absent from the YAML API:

```text
work root       ${project.root}/work/${build.id}
log root        ${project.root}/logs/${build.id}
bundle build    ${work root}/build
install root    ${project.root}/build/${build.id}
install bin     ${install root}/bin
data cache      ${work root}/cache/data
obs2ioda src    ${work root}/obs2ioda/src
obs2ioda build  ${work root}/obs2ioda/build
WPS src         ${work root}/wps/src
WPS build       ${work root}/wps/build
WPS releases    ${install root}/libexec/monan-jedi/wps
```

The public runtime contract is `MONAN_JEDI_INSTALL_ROOT`. Downstream
workflows must not consume private work/build trees.

## Public keys

| YAML key | Type / default | Environment override | Purpose |
| --- | --- | --- | --- |
| `site` | string, required | — | Human-readable site name. |
| `project.root` | string, required | `PROJECT_ROOT` | Writable project root used to derive work, logs and install. |
| `stack.owner` | string, current user | `STACK_OWNER` | Owner account used when deriving the shared stack work path. |
| `stack.instance` | string, required | `STACK_INSTANCE` | Installed spack-stack instance name. |
| `stack.env_name` | string, required | `STACK_ENV_NAME` | spack-stack environment name. |
| `stack.site_setup` | string, `configs/sites/tier2/jaci/setup.sh` | `STACK_SITE_SETUP` | Path relative to `stack.root`; the file belongs to spack-stack, not this repository. |
| `stack.env_module` | string, required | `STACK_ENV_MODULE` | Environment module loaded for the JEDI stack. |
| `build.id` | string, required | `MONAN_JEDI_BUILD_ID` | Identifier used in derived work/log/install paths. |
| `build.jobs` | integer >= 1, `8` | `MONAN_JEDI_BUILD_JOBS` | Parallel compilation jobs. |
| `model.double_precision` | `ON` or `OFF`, `ON` | `MONAN_JEDI_MODEL_DOUBLE_PRECISION` | MPAS double-precision build option. Keep YAML ON/OFF quoted. |
| `data.local_mirror_dir` | string, empty | `MONAN_JEDI_DATA_LOCAL_ROOT` | Optional local mirror searched before downloading external archives. |
| `data.download_missing` | boolean, `true` | `MONAN_JEDI_DATA_DOWNLOAD_MISSING` | Allow missing external data to be downloaded. |
| `obs2ioda.enabled` | boolean, `false` | `MONAN_JEDI_OBS2IODA_ENABLED` | Build and publish obs2ioda. |
| `obs2ioda.ref` | full 40-char SHA | `MONAN_JEDI_OBS2IODA_REF` | Reproducible obs2ioda source revision. Moving branches are rejected. |
| `obs2ioda.bufr_root` | string, empty | `MONAN_JEDI_OBS2IODA_BUFR_ROOT` | Optional BUFR search root. |
| `obs2ioda.bufr_lib` | string, empty | `MONAN_JEDI_OBS2IODA_BUFR_LIB` | Exact BUFR library override. |
| `obs2ioda.cmake_prefix_path` | string, empty | `MONAN_JEDI_OBS2IODA_CMAKE_PREFIX_PATH` | Extra CMake package search prefixes. |
| `obs2ioda.build_type` | CMake build type, `Release` | `MONAN_JEDI_OBS2IODA_BUILD_TYPE` | obs2ioda build mode. |
| `obs2ioda.build_goes_abi_converter` | `ON` or `OFF`, `OFF` | `MONAN_JEDI_OBS2IODA_BUILD_GOES_ABI_CONVERTER` | Build the optional GOES ABI converter. |
| `wps.enabled` | boolean, `false` | `MONAN_JEDI_WPS_ENABLED` | Build and publish WPS/UNGRIB. |
| `wps.ref` | full 40-char SHA | `MONAN_JEDI_WPS_REF` | Reproducible WPS source revision. |
| `wps.version` | string, `4.6.0` | `MONAN_JEDI_WPS_VERSION` | Version label used for the private release directory/manifest. |
| `wps.jasper_root` | string, empty | `MONAN_JEDI_WPS_JASPER_ROOT` | Optional Jasper dependency override. |
| `wps.png_root` | string, empty | `MONAN_JEDI_WPS_PNG_ROOT` | Optional PNG dependency override. |
| `wps.zlib_root` | string, empty | `MONAN_JEDI_WPS_ZLIB_ROOT` | Optional zlib dependency override. |
| `wps.cmake_prefix_path` | string, empty | `MONAN_JEDI_WPS_CMAKE_PREFIX_PATH` | Extra WPS CMake package search prefixes. |
| `wps.build_type` | CMake build type, `Release` | `MONAN_JEDI_WPS_BUILD_TYPE` | WPS build mode. |
| `wps.default_vtable` | filename, `Vtable.GFS` | `MONAN_JEDI_WPS_DEFAULT_VTABLE` | Vtable published at `share/wps/Vtable`. |
| `compilers.cc` | string, `cc` | `MONAN_JEDI_CC` | C compiler/wrapper. |
| `compilers.cxx` | string, `CC` | `MONAN_JEDI_CXX` | C++ compiler/wrapper. |
| `compilers.fortran` | string, `ftn` | `MONAN_JEDI_FC`, `MONAN_JEDI_F77`, `MONAN_JEDI_F90` | Canonical Fortran compiler; aliases are generated internally. |
| `mpi.cc` | string, `cc` | `MONAN_JEDI_MPICC` | MPI C compiler/wrapper. |
| `mpi.cxx` | string, `CC` | `MONAN_JEDI_MPICXX` | MPI C++ compiler/wrapper. |
| `mpi.fortran` | string, `ftn` | `MONAN_JEDI_MPIFC`, `MONAN_JEDI_MPIF77`, `MONAN_JEDI_MPIF90` | Canonical MPI Fortran compiler; aliases are generated internally. |
| `ctest.login_regex` | string, coding norms | `MONAN_JEDI_CTEST_REGEX` | Tests selected on the login node. |
| `ctest.pbs_regex` | string, empty | `MONAN_JEDI_CTEST_PBS_REGEX` | Optional inclusion regex for PBS CTest. |
| `ctest.exclude_regex` | string, empty | `MONAN_JEDI_CTEST_EXCLUDE_REGEX` | CTest exclusions. |
| `ctest.jobs` | integer >= 1, `1` | `MONAN_JEDI_CTEST_JOBS` | Parallel CTest jobs. |
| `ctest.allow_login_node_mpi_tests` | boolean, `false` | `ALLOW_LOGIN_NODE_MPI_TESTS` | Explicit opt-in for MPI tests on login nodes. |
| `pbs.queue` | string, `pesqmidi` | `MONAN_JEDI_PBS_QUEUE` | Queue used by test submission. |
| `pbs.ncpus` | integer >= 1, `64` | `MONAN_JEDI_PBS_NCPUS` | CPUs requested from PBS. This is separate from `build.jobs`. |
| `pbs.walltime` | `HH:MM:SS`, `02:00:00` | `MONAN_JEDI_PBS_WALLTIME` | PBS walltime request. |
| `pbs.submit_job` | boolean, `false` | `MONAN_JEDI_SUBMIT_JOB` | Submit the generated PBS job instead of only preparing it. |

## Fixed implementation values

The following are intentionally not YAML settings:

- CRTM coefficient archive URL;
- obs2ioda repository URL and published executable name;
- WPS repository URL and public executable/helper names.

They are controlled by the implementation and may be overridden only through
advanced environment variables when diagnosing or developing the build.

## Application configuration is separate

YAML files consumed by JEDI executables are a different class of file. Examples
live under `examples/`, such as:

```text
examples/unbalance-ensemble/config.yaml
```

This distinction is deliberate: `config/` configures the MONAN-JEDI product;
`examples/` demonstrates runtime applications.
