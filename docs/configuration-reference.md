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

## Derived filesystem model

Private implementation paths are intentionally absent from the public YAML
interface. The normal layout is derived from `project.root` and `build.id`:

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

The public runtime contract is `MONAN_JEDI_INSTALL_ROOT`. Downstream workflows
should consume the installation rather than private work/build trees. Advanced
environment overrides for derived paths remain available for controlled
development and diagnostics, but they are intentionally not normal YAML keys.

## Quick index

| YAML key | Type/default | Environment override |
| --- | --- | --- |
| `site` | string; required | — |
| `project.root` | string; required | `PROJECT_ROOT` |
| `stack.owner` | string; default invoking user | `STACK_OWNER` |
| `stack.instance` | string; required | `STACK_INSTANCE` |
| `stack.env_name` | string; required | `STACK_ENV_NAME` |
| `stack.site_setup` | string; default JACI site setup path | `STACK_SITE_SETUP` |
| `stack.env_module` | string; required | `STACK_ENV_MODULE` |
| `build.id` | string; required | `MONAN_JEDI_BUILD_ID` |
| `build.jobs` | integer >= 1; default 8 | `MONAN_JEDI_BUILD_JOBS` |
| `model.double_precision` | ON or OFF; default ON | `MONAN_JEDI_MODEL_DOUBLE_PRECISION` |
| `data.local_mirror_dir` | string; default empty | `MONAN_JEDI_DATA_LOCAL_ROOT` |
| `data.download_missing` | boolean; default true | `MONAN_JEDI_DATA_DOWNLOAD_MISSING` |
| `obs2ioda.enabled` | boolean; default false | `MONAN_JEDI_OBS2IODA_ENABLED` |
| `obs2ioda.ref` | full 40-character commit SHA | `MONAN_JEDI_OBS2IODA_REF` |
| `obs2ioda.bufr_root` | string; default empty | `MONAN_JEDI_OBS2IODA_BUFR_ROOT` |
| `obs2ioda.bufr_lib` | string; default empty | `MONAN_JEDI_OBS2IODA_BUFR_LIB` |
| `obs2ioda.cmake_prefix_path` | string; default empty | `MONAN_JEDI_OBS2IODA_CMAKE_PREFIX_PATH` |
| `obs2ioda.build_type` | Release, Debug, RelWithDebInfo or MinSizeRel; default Release | `MONAN_JEDI_OBS2IODA_BUILD_TYPE` |
| `obs2ioda.build_goes_abi_converter` | ON or OFF; default OFF | `MONAN_JEDI_OBS2IODA_BUILD_GOES_ABI_CONVERTER` |
| `wps.enabled` | boolean; default false | `MONAN_JEDI_WPS_ENABLED` |
| `wps.ref` | full 40-character commit SHA | `MONAN_JEDI_WPS_REF` |
| `wps.version` | string; default 4.6.0 | `MONAN_JEDI_WPS_VERSION` |
| `wps.jasper_root` | string; default empty | `MONAN_JEDI_WPS_JASPER_ROOT` |
| `wps.png_root` | string; default empty | `MONAN_JEDI_WPS_PNG_ROOT` |
| `wps.zlib_root` | string; default empty | `MONAN_JEDI_WPS_ZLIB_ROOT` |
| `wps.cmake_prefix_path` | string; default empty | `MONAN_JEDI_WPS_CMAKE_PREFIX_PATH` |
| `wps.build_type` | Release, Debug, RelWithDebInfo or MinSizeRel; default Release | `MONAN_JEDI_WPS_BUILD_TYPE` |
| `wps.default_vtable` | filename; default Vtable.GFS | `MONAN_JEDI_WPS_DEFAULT_VTABLE` |
| `compilers.cc` | string; default cc | `MONAN_JEDI_CC` |
| `compilers.cxx` | string; default CC | `MONAN_JEDI_CXX` |
| `compilers.fortran` | string; default ftn | `MONAN_JEDI_FC / MONAN_JEDI_F77 / MONAN_JEDI_F90` |
| `mpi.cc` | string; default cc | `MONAN_JEDI_MPICC` |
| `mpi.cxx` | string; default CC | `MONAN_JEDI_MPICXX` |
| `mpi.fortran` | string; default ftn | `MONAN_JEDI_MPIFC / MONAN_JEDI_MPIF77 / MONAN_JEDI_MPIF90` |
| `ctest.login_regex` | string regex; default coding-norms test | `MONAN_JEDI_CTEST_REGEX` |
| `ctest.pbs_regex` | string regex; default empty | `MONAN_JEDI_CTEST_PBS_REGEX` |
| `ctest.exclude_regex` | string regex; default empty | `MONAN_JEDI_CTEST_EXCLUDE_REGEX` |
| `ctest.jobs` | integer >= 1; default 1 | `MONAN_JEDI_CTEST_JOBS` |
| `ctest.allow_login_node_mpi_tests` | boolean; default false | `ALLOW_LOGIN_NODE_MPI_TESTS` |
| `pbs.queue` | string; default pesqmidi | `MONAN_JEDI_PBS_QUEUE` |
| `pbs.ncpus` | integer >= 1; default 64 | `MONAN_JEDI_PBS_NCPUS` |
| `pbs.walltime` | HH:MM:SS; default 02:00:00 | `MONAN_JEDI_PBS_WALLTIME` |
| `pbs.submit_job` | boolean; default false | `MONAN_JEDI_SUBMIT_JOB` |

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

Identifier of the existing spack-stack installation selected for the site. It is combined with stack.owner when deriving the private stack work path. Treat this as infrastructure identity: changing it points the workflow at a different dependency stack and should be reviewed accordingly.

### `stack.env_name`

**Type/default:** string; required  
**Environment override:** `STACK_ENV_NAME`

Name of the concretized environment under the selected spack-stack instance. The value participates in the derived module search path and therefore determines which JEDI dependency environment is made available. It must match a real environment in the validated stack.

### `stack.site_setup`

**Type/default:** string; default JACI site setup path  
**Environment override:** `STACK_SITE_SETUP`

Site initialization script interpreted relative to stack.root, not relative to the MONAN-JEDI repository. The path may contain the word configs because it belongs to spack-stack; it is unrelated to the removed MONAN-JEDI configs/ directory. Use the site-specific setup rather than a generic root setup script.

### `stack.env_module`

**Type/default:** string; required  
**Environment override:** `STACK_ENV_MODULE`

Exact environment module loaded after the site setup has prepared MODULEPATH. This module selects the validated compiler, MPI implementation and dependency set used for MONAN-JEDI. A module change is therefore an infrastructure change, not merely a cosmetic configuration edit.

### `build.id`

**Type/default:** string; required  
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

## Fixed implementation values

Some values are deliberately implementation-owned rather than site choices:
the CRTM coefficient archive URL, the obs2ioda repository URL and published
executable name, and the WPS repository/public helper names. They have internal
defaults and can be overridden through advanced environment variables for
development, but they are not part of the public site YAML contract.

## Maintaining this reference

Do not add a public key only to the parser or only to YAML. Update the schema,
the fully documented template, any maintained site configuration that needs an
explicit value, and this detailed reference in the same pull request. Then run
both configuration validators locally. The CI check exists specifically to
prevent a future cleanup/refactor from shortening these files back into bare
key/value lists.
