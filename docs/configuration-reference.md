# MONAN-JEDI configuration reference

This document is the detailed reference for the public MONAN-JEDI build/install
configuration. The maintained JACI example is `config/jaci.yaml`; new sites should
start from the fully documented `config/template.yaml`.

The YAML files are intentionally treated as **operator-facing documentation**,
not merely machine-readable input. A contributor should be able to understand
why a value exists, what changes when it is modified, and what is derived
automatically without reading the implementation first.

## Configuration documentation contract

Configuration documentation is part of the public interface. Every change to a
public key must preserve three synchronized layers:

1. `scripts/lib/read_config.py`: schema, type, default and environment mapping;
2. `config/template.yaml` and maintained site YAMLs: explanatory comments next
   to each user-facing value;
3. this reference: one detailed section for every public key.

`python3 scripts/check_config_documentation.py` enforces this contract. CI fails
when the template loses a public key, when a YAML value no longer has a
substantive adjacent explanation, when required conceptual header blocks are
removed, or when this reference loses/shortens a key section below the agreed
minimum. The goal is to prevent documentation erosion between pull requests,
regardless of whether a change was authored manually or by an AI coding tool.

## Scope: product configuration versus experiment configuration

These files configure **how MONAN-JEDI is prepared, built, installed and
validated on a site**. They do not define assimilation cycles, observations,
backgrounds, experiment dates or MPAS-JEDI application YAMLs. Runtime examples
belong under `examples/`; operational experiment configuration belongs in the
workflow/experiment repository.

## Precedence and validation

For every public setting, resolution order is:

1. a non-empty corresponding environment variable;
2. the value in the selected YAML file;
3. the default declared by `scripts/lib/read_config.py`.

Empty environment variables do not mask YAML/default values. Unknown YAML keys,
invalid types, invalid enumerations and malformed pinned source revisions fail
validation instead of silently falling back.

Validate a configuration without running the build:

```bash
python3 scripts/lib/read_config.py --check config/jaci.yaml
python3 scripts/check_config_documentation.py
```

## Configurable defaults and derived filesystem model

The standard layout is derived from `project.root` and `build.id`, but
legitimate site/user path choices remain part of the public YAML interface.
Leaving an optional path empty selects the documented derived default; filling
it in records a persistent, reviewable override in the configuration:

```text
work root       ${project.root}/work/${build.id}
log root        ${project.root}/logs/${build.id}
bundle build    ${project.root}/work/${build.id}/build
install root    ${project.root}/build/${build.id}
install bin     ${install root}/bin
data cache      ${work root}/cache/data
obs2ioda src    ${work root}/obs2ioda/src
obs2ioda build  ${work root}/obs2ioda/build
WPS src         ${work root}/wps/src
WPS build       ${work root}/wps/build
WPS releases    ${install root}/libexec/monan-jedi/wps
```

The public runtime contract remains `MONAN_JEDI_INSTALL_ROOT`. Downstream
workflows should consume the installation rather than assuming the default
private work/build layout. The important distinction is that a default path is
not a prohibition: users may override supported paths persistently in YAML or
temporarily with the corresponding non-empty environment variable.

## Quick index

| YAML key | Type/default | Environment override |
| --- | --- | --- |
| `site` | string; required | — |
| `project.root` | string; required | `PROJECT_ROOT` |
| `project.work_root` | string; default derived | `MONAN_JEDI_WORK_ROOT` |
| `project.log_root` | string; default derived | `MONAN_JEDI_LOG_ROOT` |
| `stack.owner` | string; default invoking user | `STACK_OWNER` |
| `stack.instance` | string; required | `STACK_INSTANCE` |
| `stack.work_root` | string; default derived | `STACK_WORK_ROOT` |
| `stack.root` | string; default derived | `STACK_ROOT` |
| `stack.env_name` | string; required | `STACK_ENV_NAME` |
| `stack.module_root` | string; default derived | `STACK_MODULE_ROOT` |
| `stack.site_setup` | string; default JACI site setup path | `STACK_SITE_SETUP` |
| `stack.env_module` | string; required | `STACK_ENV_MODULE` |
| `build.id` | string; default monan-jedi | `MONAN_JEDI_BUILD_ID` |
| `build.dir` | string; default derived | `MONAN_JEDI_BUILD_DIR` |
| `build.jobs` | integer >= 1; default 8 | `MONAN_JEDI_BUILD_JOBS` |
| `install.root` | string; default derived | `MONAN_JEDI_INSTALL_ROOT` |
| `install.bin_dir` | string; default derived | `MONAN_JEDI_INSTALL_BIN_DIR` |
| `model.double_precision` | ON or OFF; default ON | `MONAN_JEDI_MODEL_DOUBLE_PRECISION` |
| `data.root` | string; default derived | `MONAN_JEDI_DATA_ROOT` |
| `data.local_mirror_dir` | string; default empty | `MONAN_JEDI_DATA_LOCAL_ROOT` |
| `data.download_missing` | boolean; default true | `MONAN_JEDI_DATA_DOWNLOAD_MISSING` |
| `data.crtm_coeffs_url` | URL string; validated project default | `MONAN_JEDI_CRTM_COEFFS_URL` |
| `data.crtm_coeffs_tgz` | string; default derived | `MONAN_JEDI_CRTM_COEFFS_TGZ` |
| `obs2ioda.enabled` | boolean; default false | `MONAN_JEDI_OBS2IODA_ENABLED` |
| `obs2ioda.repo` | URL/string; default NCAR repository | `MONAN_JEDI_OBS2IODA_REPO` |
| `obs2ioda.ref` | full 40-character commit SHA | `MONAN_JEDI_OBS2IODA_REF` |
| `obs2ioda.source_dir` | string; default derived | `MONAN_JEDI_OBS2IODA_SOURCE_DIR` |
| `obs2ioda.build_dir` | string; default derived | `MONAN_JEDI_OBS2IODA_BUILD_DIR` |
| `obs2ioda.install_dir` | string; default install.root | `MONAN_JEDI_OBS2IODA_INSTALL_DIR` |
| `obs2ioda.executable_name` | string; default obs2ioda_v3 | `MONAN_JEDI_OBS2IODA_EXECUTABLE_NAME` |
| `obs2ioda.bufr_root` | string; default empty | `MONAN_JEDI_OBS2IODA_BUFR_ROOT` |
| `obs2ioda.bufr_lib` | string; default empty | `MONAN_JEDI_OBS2IODA_BUFR_LIB` |
| `obs2ioda.cmake_prefix_path` | string; default empty | `MONAN_JEDI_OBS2IODA_CMAKE_PREFIX_PATH` |
| `obs2ioda.build_type` | CMake build type; default Release | `MONAN_JEDI_OBS2IODA_BUILD_TYPE` |
| `obs2ioda.build_goes_abi_converter` | ON or OFF; default OFF | `MONAN_JEDI_OBS2IODA_BUILD_GOES_ABI_CONVERTER` |
| `wps.enabled` | boolean; default false | `MONAN_JEDI_WPS_ENABLED` |
| `wps.repo` | URL/string; default wrf-model repository | `MONAN_JEDI_WPS_REPO` |
| `wps.ref` | full 40-character commit SHA | `MONAN_JEDI_WPS_REF` |
| `wps.version` | string; default 4.6.0 | `MONAN_JEDI_WPS_VERSION` |
| `wps.source_dir` | string; default derived | `MONAN_JEDI_WPS_SOURCE_DIR` |
| `wps.build_dir` | string; default derived | `MONAN_JEDI_WPS_BUILD_DIR` |
| `wps.releases_dir` | string; default derived | `MONAN_JEDI_WPS_RELEASES_DIR` |
| `wps.install_dir` | string; default derived | `MONAN_JEDI_WPS_INSTALL_DIR` |
| `wps.patch_dir` | string; default repository patches/wps | `MONAN_JEDI_WPS_PATCH_DIR` |
| `wps.jasper_root` | string; default empty | `MONAN_JEDI_WPS_JASPER_ROOT` |
| `wps.png_root` | string; default empty | `MONAN_JEDI_WPS_PNG_ROOT` |
| `wps.zlib_root` | string; default empty | `MONAN_JEDI_WPS_ZLIB_ROOT` |
| `wps.cmake_prefix_path` | string; default empty | `MONAN_JEDI_WPS_CMAKE_PREFIX_PATH` |
| `wps.build_type` | CMake build type; default Release | `MONAN_JEDI_WPS_BUILD_TYPE` |
| `wps.ungrib_name` | string; default ungrib.exe | `MONAN_JEDI_WPS_UNGRIB_NAME` |
| `wps.link_grib_name` | string; default link_grib.csh | `MONAN_JEDI_WPS_LINK_GRIB_NAME` |
| `wps.default_vtable` | filename; default Vtable.GFS | `MONAN_JEDI_WPS_DEFAULT_VTABLE` |
| `compilers.cc` | string; default cc | `MONAN_JEDI_CC` |
| `compilers.cxx` | string; default CC | `MONAN_JEDI_CXX` |
| `compilers.fortran` | string; default ftn | `MONAN_JEDI_FC / F77 / F90` |
| `mpi.cc` | string; default cc | `MONAN_JEDI_MPICC` |
| `mpi.cxx` | string; default CC | `MONAN_JEDI_MPICXX` |
| `mpi.fortran` | string; default ftn | `MONAN_JEDI_MPIFC / MPIF77 / MPIF90` |
| `ctest.login_regex` | string regex; default coding-norms test | `MONAN_JEDI_CTEST_REGEX` |
| `ctest.pbs_regex` | string regex; default empty | `MONAN_JEDI_CTEST_PBS_REGEX` |
| `ctest.exclude_regex` | string regex; default empty | `MONAN_JEDI_CTEST_EXCLUDE_REGEX` |
| `ctest.jobs` | integer >= 1; default 1 | `MONAN_JEDI_CTEST_JOBS` |
| `ctest.allow_login_node_mpi_tests` | boolean; default false | `ALLOW_LOGIN_NODE_MPI_TESTS` |
| `pbs.queue` | string; default pesqmidi | `MONAN_JEDI_PBS_QUEUE` |
| `pbs.ncpus` | integer >= 1; default 64 | `MONAN_JEDI_PBS_NCPUS` |
| `pbs.walltime` | HH:MM:SS; default 02:00:00 | `MONAN_JEDI_PBS_WALLTIME` |
| `pbs.submit_job` | boolean; default false | `MONAN_JEDI_SUBMIT_JOB` |

## Safe spack-stack and module switching

MONAN-JEDI treats the dependency stack as a three-part identity:

```text
canonical stack.root
+ canonical stack.module_root
+ stack.env_module
```

After a successful `module use` and `module load`, the loader records that identity
for the current process. A later command in the same process may reuse the loaded
environment only when all three values still match and the existing toolchain checks
also pass. This closes an important ambiguity: two spack-stack installations may
publish the same module name, so the module name alone is not evidence that the
correct stack is active.

If the configured stack path, module tree or module name changes, or if an inherited
module environment has no MONAN-JEDI provenance record, the loader takes the safe
path: it purges the module environment, sources the configured site setup, adds the
configured module tree, loads the requested module again, resolves compiler/MPI
wrappers, and revalidates the complete environment. PBS compute jobs intentionally
discard any submission-shell provenance markers and establish their own identity on
the compute node.

Configuration precedence still applies before this identity check:

```text
non-empty environment variable > YAML value > schema/default derivation
```

Consequently, changing `stack.root` in YAML does not override an already exported
non-empty `STACK_ROOT`. For a persistent YAML change, either start from a clean shell
or unset the corresponding one-off overrides first. The `load` command and
`01_stack_environment.log` report both the configured stack information and the
active stack identity so operators can confirm exactly what was used.

## Detailed public-key reference

### `site`

**Type/default:** string; required  
**Environment override:** none

Human-readable identifier for the site represented by the YAML file. It currently serves as metadata rather than a workflow switch, but it makes logs, reviews and future site-specific behavior easier to understand. Use a short stable name such as jaci rather than a filesystem path or host name.

### `project.root`

**Type/default:** string; required  
**Environment override:** `PROJECT_ROOT`

Writable root from which MONAN-JEDI derives its private work tree, logs and public installation. The path must be visible to every login or compute node that participates in build and test operations. Environment expressions such as ${USER} are expanded before use.

### `stack.owner`

**Type/default:** string; default invoking user  
**Environment override:** `STACK_OWNER`

Unix account that owns the validated spack-stack instance consumed by MONAN-JEDI. It may differ from the person running the workflow, which is important on shared HPC systems. This setting helps derive the default stack location without assuming the stack is below project.root.

### `stack.instance`

**Type/default:** string; required  
**Environment override:** `STACK_INSTANCE`

Identifier of the existing spack-stack installation selected for the site. It is combined with stack.owner when deriving the default stack work path. Treat this as infrastructure identity: changing it normally changes the derived stack root and invalidates the recorded loaded-stack identity, forcing a clean module reload. A non-empty STACK_WORK_ROOT or STACK_ROOT environment override still takes precedence over the YAML-derived path.

### `stack.env_name`

**Type/default:** string; required  
**Environment override:** `STACK_ENV_NAME`

Name of the concretized environment under the selected spack-stack instance. The value participates in the derived module search path and therefore determines which JEDI dependency environment is made available. Changing it changes the default module tree and invalidates the previously recorded stack identity, so the loader purges and rebuilds the module environment before continuing.

### `stack.site_setup`

**Type/default:** string; default JACI site setup path  
**Environment override:** `STACK_SITE_SETUP`

Site initialization script interpreted relative to stack.root, not relative to the MONAN-JEDI repository. The path may contain the word configs because it belongs to spack-stack; it is unrelated to the removed MONAN-JEDI configs/ directory. Use the site-specific setup rather than a generic root setup script.

### `stack.env_module`

**Type/default:** string; required  
**Environment override:** `STACK_ENV_MODULE`

Exact environment module loaded after the site setup has prepared MODULEPATH. This module selects the validated compiler, MPI implementation and dependency set used for MONAN-JEDI. Reuse requires both this module name and the recorded canonical stack/module-tree paths to match the current configuration. Changing the module name forces reload; changing only the stack path also forces reload even when the module name stays identical.

### `build.id`

**Type/default:** string; default `monan-jedi`  
**Environment override:** `MONAN_JEDI_BUILD_ID`

Stable identifier used to derive independent work, log and installation directories. Changing it intentionally creates another build generation without overwriting the previous one. Prefer a filesystem-safe value without spaces so paths and scheduler scripts remain predictable.

### `build.jobs`

**Type/default:** integer >= 1; default 8  
**Environment override:** `MONAN_JEDI_BUILD_JOBS`

Maximum number of parallel jobs used during CMake/ecbuild compilation and auxiliary component builds. This controls compiler parallelism only; it is not the number of MPI ranks and is independent from pbs.ncpus. Choose a value appropriate for the node where compilation actually runs.

### `model.double_precision`

**Type/default:** ON or OFF; default ON  
**Environment override:** `MONAN_JEDI_MODEL_DOUBLE_PRECISION`

Precision mode forwarded to the MONAN/MPAS build through MPAS_DOUBLE_PRECISION. Keep ON/OFF quoted in YAML so they remain strings. ON is the normal validation setting because upstream MPAS-JEDI reference data are produced for double precision and single precision can exceed test tolerances.

### `data.local_mirror_dir`

**Type/default:** string; default empty  
**Environment override:** `MONAN_JEDI_DATA_LOCAL_ROOT`

Optional local or offline mirror searched before MONAN-JEDI downloads required external archives. Leave it empty when normal cache and network access are sufficient. On isolated systems, point it at a shared location that contains the expected archive filenames and keep data.download_missing disabled.

### `data.download_missing`

**Type/default:** boolean; default true  
**Environment override:** `MONAN_JEDI_DATA_DOWNLOAD_MISSING`

Controls whether the workflow may use network download when required archives are absent from the cache and local mirror. true is convenient on connected systems; false makes missing data an explicit error. Use false only when all external inputs needed by configuration have been staged in advance.

### `obs2ioda.enabled`

**Type/default:** boolean; default false  
**Environment override:** `MONAN_JEDI_OBS2IODA_ENABLED`

Enables the explicit obs2ioda build and includes the converter in aggregate MONAN-JEDI operations. When false, the main bundle can still be built without publishing obs2ioda. The maintained JACI configuration enables it because observation conversion is part of the validated working environment.

### `obs2ioda.ref`

**Type/default:** full 40-character commit SHA  
**Environment override:** `MONAN_JEDI_OBS2IODA_REF`

Exact upstream obs2ioda revision checked out for the auxiliary build. The validator deliberately rejects moving branch names such as main so two builds from the same MONAN-JEDI configuration remain reproducible. Update this SHA only after the new upstream revision has been tested with the project.

### `obs2ioda.bufr_root`

**Type/default:** string; default empty  
**Environment override:** `MONAN_JEDI_OBS2IODA_BUFR_ROOT`

Optional installation prefix used to locate the NCEP BUFR dependency before automatic stack discovery. Most validated environments should leave this empty so the loaded stack remains authoritative. Set it only when the desired BUFR package is outside the normal spack-stack discovery paths.

### `obs2ioda.bufr_lib`

**Type/default:** string; default empty  
**Environment override:** `MONAN_JEDI_OBS2IODA_BUFR_LIB`

Optional exact path to the BUFR library file. When present it takes precedence over bufr_root and automatic discovery, so it is a precise diagnostic/site override rather than a normal setting. The referenced file must exist and must be compatible with the selected compiler and stack.

### `obs2ioda.cmake_prefix_path`

**Type/default:** string; default empty  
**Environment override:** `MONAN_JEDI_OBS2IODA_CMAKE_PREFIX_PATH`

Additional semicolon-separated CMake package prefixes appended during obs2ioda configuration. Use this only when dependencies cannot be resolved from the active stack and standard NetCDF discovery. Excessive custom prefixes make builds harder to reproduce, so keep the field empty on the maintained JACI setup.

### `obs2ioda.build_type`

**Type/default:** Release, Debug, RelWithDebInfo or MinSizeRel; default Release  
**Environment override:** `MONAN_JEDI_OBS2IODA_BUILD_TYPE`

Standard CMake build type for the standalone obs2ioda build. Release is the normal operational choice, while Debug or RelWithDebInfo may be useful during development and troubleshooting. Changing this affects compiler flags and performance but does not select a different source revision.

### `obs2ioda.build_goes_abi_converter`

**Type/default:** ON or OFF; default OFF  
**Environment override:** `MONAN_JEDI_OBS2IODA_BUILD_GOES_ABI_CONVERTER`

Controls the optional GOES ABI converter in the upstream obs2ioda CMake configuration. Keep ON/OFF quoted so YAML preserves the value as a string. OFF is the project default because this optional converter is not required by the standard validated installation.

### `wps.enabled`

**Type/default:** boolean; default false  
**Environment override:** `MONAN_JEDI_WPS_ENABLED`

Enables the supported WPS/UNGRIB integration and includes it in aggregate MONAN-JEDI operations. The helper intentionally builds only the subset required by this project rather than a complete WRF preprocessing environment. The maintained JACI site enables this integration.

### `wps.ref`

**Type/default:** full 40-character commit SHA  
**Environment override:** `MONAN_JEDI_WPS_REF`

Exact tested WPS source revision checked out before local compatibility patches are applied. The full SHA is part of the reproducibility contract and moving branches are rejected. When this value changes, the WPS patch-validation CI must also continue to apply cleanly against the new source.

### `wps.version`

**Type/default:** string; default 4.6.0  
**Environment override:** `MONAN_JEDI_WPS_VERSION`

Human-readable release label used in derived private release paths and build metadata. It does not select the Git source; wps.ref is the only source selector. Keep the label consistent with the tested upstream revision so operators can understand which WPS generation an installation represents.

### `wps.jasper_root`

**Type/default:** string; default empty  
**Environment override:** `MONAN_JEDI_WPS_JASPER_ROOT`

Optional JasPer installation prefix used before automatic dependency discovery from the loaded stack. Leave empty on validated spack-stack environments so one dependency source remains authoritative. Set it only for controlled site-specific overrides or diagnostics.

### `wps.png_root`

**Type/default:** string; default empty  
**Environment override:** `MONAN_JEDI_WPS_PNG_ROOT`

Optional libpng installation prefix used before automatic stack discovery. The maintained JACI environment normally leaves this empty because the dependency should come from the validated stack. A manual prefix must be compatible with the compiler and libraries used by the rest of WPS.

### `wps.zlib_root`

**Type/default:** string; default empty  
**Environment override:** `MONAN_JEDI_WPS_ZLIB_ROOT`

Optional zlib installation prefix used before automatic stack discovery. As with the other WPS dependency overrides, an empty value keeps the active spack-stack authoritative. Use a custom location only when the standard environment cannot expose a suitable installation.

### `wps.cmake_prefix_path`

**Type/default:** string; default empty  
**Environment override:** `MONAN_JEDI_WPS_CMAKE_PREFIX_PATH`

Additional semicolon-separated CMake search prefixes appended during WPS configuration after resolved dependency roots. This is an advanced escape hatch for unusual sites, not a normal JACI requirement. Keep it minimal because extra prefixes can silently change which libraries CMake selects.

### `wps.build_type`

**Type/default:** Release, Debug, RelWithDebInfo or MinSizeRel; default Release  
**Environment override:** `MONAN_JEDI_WPS_BUILD_TYPE`

CMake build type used by the supported WPS helper build. Release is appropriate for the normal validated installation, while debug variants are useful during development. This setting changes build flags only; it does not alter the pinned WPS source revision or patch set.

### `wps.default_vtable`

**Type/default:** filename; default Vtable.GFS  
**Environment override:** `MONAN_JEDI_WPS_DEFAULT_VTABLE`

Filename of the WPS variable table exposed through the stable MONAN-JEDI share/wps/Vtable interface. It must be a simple filename available in WPS ungrib/Variable_Tables. This gives downstream workflows a stable location while preserving the versioned WPS installation internally.

### `compilers.cc`

**Type/default:** string; default cc  
**Environment override:** `MONAN_JEDI_CC`

C compiler command resolved after stack activation. On JACI CrayPE the validated wrapper is lowercase cc; other sites may use a different wrapper. This is the non-MPI compiler identity and should remain distinct from mpi.cc even when both resolve to the same command on a particular system.

### `compilers.cxx`

**Type/default:** string; default CC  
**Environment override:** `MONAN_JEDI_CXX`

C++ compiler command resolved after the configured stack is loaded. JACI uses uppercase CC, which is case-sensitive under CrayPE. Other sites may use c++ or another wrapper, but the configured value must remain consistent with the dependency stack used to build JEDI.

### `compilers.fortran`

**Type/default:** string; default ftn  
**Environment override:** `MONAN_JEDI_FC / MONAN_JEDI_F77 / MONAN_JEDI_F90`

Canonical Fortran compiler command for the site. The loader fans this single YAML value out to FC, F77 and F90 compatibility aliases so the user does not maintain three duplicate settings. JACI uses the CrayPE ftn wrapper supplied by the validated stack environment.

### `mpi.cc`

**Type/default:** string; default cc  
**Environment override:** `MONAN_JEDI_MPICC`

MPI-aware C compiler wrapper used when a build system asks explicitly for an MPI compiler. Some platforms use mpicc while JACI's loaded Cray environment uses cc for both roles. The separate setting is retained because the concepts differ even when the command happens to be identical.

### `mpi.cxx`

**Type/default:** string; default CC  
**Environment override:** `MONAN_JEDI_MPICXX`

MPI-aware C++ wrapper used when components request an MPI C++ compiler. On JACI the validated Cray wrapper is uppercase CC, while generic sites may use mpicxx. Keep this aligned with the MPI implementation provided by the selected spack-stack environment.

### `mpi.fortran`

**Type/default:** string; default ftn  
**Environment override:** `MONAN_JEDI_MPIFC / MONAN_JEDI_MPIF77 / MONAN_JEDI_MPIF90`

Canonical MPI Fortran wrapper for the site. The loader derives MPIFC, MPIF77 and MPIF90 aliases from this single setting, eliminating duplicate YAML while preserving compatibility with upstream build systems. JACI uses ftn after the Cray MPI environment is loaded.

### `ctest.login_regex`

**Type/default:** string regex; default coding-norms test  
**Environment override:** `MONAN_JEDI_CTEST_REGEX`

Extended regular expression passed to ctest -R for login-node validation. It should remain deliberately narrow so login nodes execute only tests known to be safe without compute-node MPI. Broadening this regex is a site-policy change and should be reviewed with the same care as scheduler settings.

### `ctest.pbs_regex`

**Type/default:** string regex; default empty  
**Environment override:** `MONAN_JEDI_CTEST_PBS_REGEX`

Optional inclusion expression reserved for PBS-side CTest selection. An empty value means the current PBS workflow does not apply an extra -R filter and instead relies on the complete suite plus exclusions. Keep the distinction documented because this setting is not equivalent to ctest.login_regex.

### `ctest.exclude_regex`

**Type/default:** string regex; default empty  
**Environment override:** `MONAN_JEDI_CTEST_EXCLUDE_REGEX`

Extended regular expression passed to ctest -E to omit known unsupported or temporarily excluded cases from compute-node validation. Site configurations should list only exclusions that are understood and documented. An empty string requests no exclusions.

### `ctest.jobs`

**Type/default:** integer >= 1; default 1  
**Environment override:** `MONAN_JEDI_CTEST_JOBS`

Number of CTest cases that the test driver may execute concurrently. This controls test-level scheduling, not MPI ranks inside a test and not PBS resource size. Keep it conservative unless the suite and allocated node resources have been validated for higher concurrency.

### `ctest.allow_login_node_mpi_tests`

**Type/default:** boolean; default false  
**Environment override:** `ALLOW_LOGIN_NODE_MPI_TESTS`

Explicit safety flag associated with running MPI-oriented tests on login nodes. The project default is false because MPI work belongs on compute nodes. Setting it true must not be treated as a casual speed optimization; it should reflect an explicit site policy and supported test path.

### `pbs.queue`

**Type/default:** string; default pesqmidi  
**Environment override:** `MONAN_JEDI_PBS_QUEUE`

PBS queue selected by the compute-node validation helper. The queue determines scheduler policy and can affect placement requirements, so repository tests validate known JACI behavior. Other sites must replace it with a valid queue and document any corresponding scheduler assumptions.

### `pbs.ncpus`

**Type/default:** integer >= 1; default 64  
**Environment override:** `MONAN_JEDI_PBS_NCPUS`

Number of CPUs requested in the PBS validation allocation. This is a scheduler resource request and intentionally remains separate from build.jobs, which controls compilation parallelism. Size it for the test workload and site policy rather than copying compiler job counts blindly.

### `pbs.walltime`

**Type/default:** HH:MM:SS; default 02:00:00  
**Environment override:** `MONAN_JEDI_PBS_WALLTIME`

Wall-clock limit requested for the PBS validation job. The parser validates the time syntax so typographical errors fail early. Choose a value based on the observed complete test suite and update the explanatory site comments when operational experience changes the maintained limit.

### `pbs.submit_job`

**Type/default:** boolean; default false  
**Environment override:** `MONAN_JEDI_SUBMIT_JOB`

Controls whether the PBS helper submits the generated job immediately or only prepares it for review/manual submission. Generic templates default to false to avoid accidental scheduler work, while the maintained JACI configuration may enable automatic submission as part of its normal validation workflow.

### `project.work_root`

**Type/default:** string; empty means derived  
**Environment override:** `MONAN_JEDI_WORK_ROOT`

Optional private/rebuildable work root for MONAN-JEDI. When empty, `config.sh` derives `${project.root}/work/${build.id}`. Set it when a site needs work files on a different filesystem, scratch area or project allocation while keeping the rest of the configuration unchanged.

### `project.log_root`

**Type/default:** string; empty means derived  
**Environment override:** `MONAN_JEDI_LOG_ROOT`

Optional root for MONAN-JEDI logs. When empty, the workflow uses `${project.root}/logs/${build.id}`. Making this configurable is useful when logs need a persistent filesystem independent from a disposable work tree, while the default keeps the normal layout predictable.

### `stack.work_root`

**Type/default:** string; empty means derived  
**Environment override:** `STACK_WORK_ROOT`

Optional directory containing the selected stack instance. When empty, JACI derives `/p/projetos/monan_das/${stack.owner}/work/${stack.instance}`. Other sites or users may point directly to a shared stack area without changing project.root or copying the stack into their own workspace.

### `stack.root`

**Type/default:** string; empty means derived  
**Environment override:** `STACK_ROOT`

Optional root of the actual spack-stack checkout/installation. When empty it is derived as `${stack.work_root}/spack-stack`. Changing this path is treated as an infrastructure change: MONAN-JEDI will not reuse an environment identified with another stack root, even if both installations publish exactly the same `stack.env_module` name. A non-empty `STACK_ROOT` already exported in the invoking shell overrides this YAML value by design.

### `stack.module_root`

**Type/default:** string; empty means derived  
**Environment override:** `STACK_MODULE_ROOT`

Optional module directory added to MODULEPATH before loading the configured environment module. The default is `${stack.root}/envs/${stack.env_name}/modules`. Its canonical path is part of the loaded-stack identity. Changing it therefore forces reload even when `stack.env_module` itself is unchanged. Override it only when a stack publishes modules in a nonstandard location.

### `build.dir`

**Type/default:** string; empty means derived  
**Environment override:** `MONAN_JEDI_BUILD_DIR`

Optional ecbuild/CMake build directory for the main MONAN-JEDI bundle. The default is `${project.work_root}/build`. Because configuration/build commands may recreate this tree, the chosen path should be considered disposable and separate from the published installation.

### `install.root`

**Type/default:** string; empty means derived  
**Environment override:** `MONAN_JEDI_INSTALL_ROOT`

Optional public installation prefix consumed by downstream workflows. The default is `${project.root}/build/${build.id}`. This is an important user/site choice: the default provides consistency, while an explicit value supports shared software prefixes or alternate project filesystems.

### `install.bin_dir`

**Type/default:** string; empty means derived  
**Environment override:** `MONAN_JEDI_INSTALL_BIN_DIR`

Optional directory used for stable published executable paths. The default is `${install.root}/bin`. Most users should leave it empty, but keeping the override public preserves compatibility with sites that separate executable publication from the installation prefix.

### `data.root`

**Type/default:** string; empty means derived  
**Environment override:** `MONAN_JEDI_DATA_ROOT`

Optional persistent cache root for external archives used during configuration and auxiliary builds. The default is `${project.work_root}/cache/data`. Sites with shared read-mostly caches or dedicated data filesystems can point this elsewhere without changing the project work tree.

### `data.crtm_coeffs_url`

**Type/default:** URL/string; validated SSEC CRTM archive URL  
**Environment override:** `MONAN_JEDI_CRTM_COEFFS_URL`

Source URL used when the required CRTM coefficient archive is not available from the local mirror/cache. It remains configurable so disconnected sites can use an institutional mirror and so upstream hosting changes do not require editing workflow code.

### `data.crtm_coeffs_tgz`

**Type/default:** string; empty means derived  
**Environment override:** `MONAN_JEDI_CRTM_COEFFS_TGZ`

Optional exact local path for the CRTM coefficient archive. The default is `${data.root}/crtm/fix_REL-3.1.2.0.tgz`. An explicit value supports pre-staged datasets and unusual cache layouts while keeping download policy independently configurable.

### `obs2ioda.repo`

**Type/default:** URL/string; `https://github.com/NCAR/obs2ioda.git`  
**Environment override:** `MONAN_JEDI_OBS2IODA_REPO`

Repository cloned for the standalone obs2ioda build. The official NCAR repository is the default, but a site may use a controlled mirror or development fork while still keeping the exact revision pinned by `obs2ioda.ref`.

### `obs2ioda.source_dir`

**Type/default:** string; empty means derived  
**Environment override:** `MONAN_JEDI_OBS2IODA_SOURCE_DIR`

Optional obs2ioda source checkout directory. The default is `${project.work_root}/obs2ioda/src`. This override is useful for development checkouts or filesystem policies that separate source trees from build scratch space.

### `obs2ioda.build_dir`

**Type/default:** string; empty means derived  
**Environment override:** `MONAN_JEDI_OBS2IODA_BUILD_DIR`

Optional out-of-source obs2ioda CMake build directory. The default is `${project.work_root}/obs2ioda/build`. The helper treats this as rebuildable state, so an override should point to writable scratch/work storage rather than a protected installation prefix.

### `obs2ioda.install_dir`

**Type/default:** string; empty means `install.root`  
**Environment override:** `MONAN_JEDI_OBS2IODA_INSTALL_DIR`

Optional CMAKE_INSTALL_PREFIX for obs2ioda. The normal default is the common MONAN-JEDI installation root so consumers see one coherent product, but the override supports controlled component staging or site packaging workflows.

### `obs2ioda.executable_name`

**Type/default:** string; `obs2ioda_v3`  
**Environment override:** `MONAN_JEDI_OBS2IODA_EXECUTABLE_NAME`

Stable filename published for the obs2ioda converter in the common executable directory. This changes the user-facing published name rather than the upstream target identity, allowing compatibility with downstream workflows that expect a specific executable name.

### `wps.repo`

**Type/default:** URL/string; `https://github.com/wrf-model/WPS.git`  
**Environment override:** `MONAN_JEDI_WPS_REPO`

Repository cloned for the supported WPS integration. The official upstream repository is the default; controlled mirrors or forks may be configured while `wps.ref` continues to pin the exact source revision used for reproducibility.

### `wps.source_dir`

**Type/default:** string; empty means derived  
**Environment override:** `MONAN_JEDI_WPS_SOURCE_DIR`

Optional WPS source checkout directory. The default is `${project.work_root}/wps/src`. Keeping it configurable supports development trees and site-specific filesystem placement without forcing users to modify the WPS helper scripts.

### `wps.build_dir`

**Type/default:** string; empty means derived  
**Environment override:** `MONAN_JEDI_WPS_BUILD_DIR`

Optional WPS out-of-source CMake build directory. The default is `${project.work_root}/wps/build`. This directory is private/rebuildable state and can be redirected to fast scratch storage independently from the public installation.

### `wps.releases_dir`

**Type/default:** string; empty means derived  
**Environment override:** `MONAN_JEDI_WPS_RELEASES_DIR`

Optional parent directory containing validated/versioned WPS releases. The default is `${install.root}/libexec/monan-jedi/wps`. An explicit value lets a site relocate private versioned WPS payloads while stable public links remain under the MONAN-JEDI installation.

### `wps.install_dir`

**Type/default:** string; empty means derived  
**Environment override:** `MONAN_JEDI_WPS_INSTALL_DIR`

Optional final validated WPS release directory. The default is `${wps.releases_dir}/WPS-${wps.version}`. The build helper validates staging before promotion, so this override controls where that validated versioned release is ultimately stored.

### `wps.patch_dir`

**Type/default:** string; empty means repository `patches/wps`  
**Environment override:** `MONAN_JEDI_WPS_PATCH_DIR`

Optional directory containing ordered local WPS compatibility patches. The normal default points at this repository's maintained patch set. Exposing the path supports controlled development/testing of alternate patch sets without editing the helper implementation.

### `wps.ungrib_name`

**Type/default:** string; `ungrib.exe`  
**Environment override:** `MONAN_JEDI_WPS_UNGRIB_NAME`

Stable executable/link name published for UNGRIB in the common installation bin directory. Most sites should retain the default, but the public option supports downstream naming conventions without changing upstream WPS source code.

### `wps.link_grib_name`

**Type/default:** string; `link_grib.csh`  
**Environment override:** `MONAN_JEDI_WPS_LINK_GRIB_NAME`

Stable published name for the WPS link_grib helper. The default matches upstream convention. A configurable name preserves compatibility for sites or workflows that require a different stable command name while the validated WPS payload remains unchanged.

## Default-versus-override policy

Paths, download URLs, upstream repository locations and published helper names
that a site may legitimately need to change are part of the public YAML
interface. They still have project defaults; exposing them does not make them
mandatory. The maintained JACI file intentionally omits most of these options
and relies on defaults, while `config/template.yaml` shows the complete
interface.

Pure implementation details that have no meaningful user/site decision remain
internal. The guiding rule is to simplify duplicate values, not to remove
reasonable operator autonomy.

## Maintaining this reference

Do not add a public key only to the parser or only to YAML. Update the schema,
the fully documented template, any maintained site configuration that needs an
explicit value, and this detailed reference in the same pull request. Then run
both configuration validators locally. The CI check exists specifically to
prevent a future cleanup/refactor from shortening these files back into bare
key/value lists.
