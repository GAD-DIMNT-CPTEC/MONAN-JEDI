# MONAN-JEDI

Reproducible build and validation workflow for the MONAN-JEDI MPAS-JEDI baseline on INPE/JACI.

The repository is intentionally separated from `spack-stack-inpe`:

- `spack-stack-inpe` creates and validates the software environment;
- `MONAN-JEDI` defines the MPAS-JEDI bundle and orchestrates builds, installation, tests and auxiliary tools;
- auxiliary tools such as `obs2ioda` and WPS/UNGRIB are built outside the main bundle tree but published under the same install prefix.

## Requirements

A validated `spack-stack-inpe` environment must already exist. The current JACI baseline uses:

```text
spack-stack release/2.1
PrgEnv-gnu/8.6.0
gcc-native/12.3
cray-mpich/8.1.31
jedi-mpas-env/1.0.0
```

### Git LFS is required

The JEDI test-data repositories store NetCDF/HDF5 inputs in Git LFS. Without the
Git LFS client, Git can leave small pointer-text files in place of the scientific
data; the build may compile, but CTest will fail or wait until its timeout.

**The current JACI MONAN-JEDI spack-stack already provides Git LFS.** Normal
users should not install a second copy before checking the loaded stack.

Run:

```bash
bash scripts/monan-jedi.sh load --config config/jaci.yaml
```

A normal JACI baseline reports Git LFS from the loaded stack/environment, for
example:

```text
[INFO] Git LFS is available
[INFO]   version=git-lfs/3.5.1 (...)
[INFO]   executable=.../spack-stack.../git-lfs-3.5.1.../bin/git-lfs
[INFO]   provider=loaded stack/environment
```

The environment snapshot also records the `git` and `git-lfs` executable paths
and `git lfs version`. This makes the dependency discoverable even when the user
does not remember how Git LFS became available.

Only a custom or older stack that does not provide a usable Git LFS client needs
a user-local fallback. MONAN-JEDI checks this persistent fallback automatically:

```text
${project.root}/envs/git-lfs
```

With `config/jaci.yaml`, that is normally:

```text
/p/projetos/monan_das/${USER}/envs/git-lfs
```

If the stack does not provide Git LFS and that fallback does not already exist,
create it once. On JACI, Conda first has to be exposed with:

```bash
module load anaconda
start_conda
```

The prompt normally changes to `(base)`. JACI's `(base)` environment is the
shared, read-only `/p/app/anaconda`; it is only used to make the `conda` command
available and is **not** the installation target.

Create the fallback in the writable project area:

```bash
export GIT_LFS_ENV="/p/projetos/monan_das/${USER}/envs/git-lfs"
conda create -y -p "${GIT_LFS_ENV}" -c conda-forge git-lfs

export PATH="${GIT_LFS_ENV}/bin:${PATH}"
git lfs install
git lfs version
```

Later MONAN-JEDI sessions find that fallback automatically if the loaded stack
still does not provide Git LFS. There is no need to repeat the Conda setup.

After Git LFS is available, the normal `configure`/`all` workflow downloads and
validates the pinned `ioda-data`, `ufo-data` and `mpas-jedi-data` objects. It
stops immediately if Git LFS or required binary data are unavailable.

For recovery of an existing checkout and detailed diagnostics, see
[JEDI test data and Git LFS](docs/jedi-test-data.md).

## Configuration

User-editable settings are centralized in YAML files under `config/`.

```text
config/jaci.yaml       JACI configuration
config/template.yaml   template for additional sites
```

Important derived paths:

| Setting | Default when empty |
|---|---|
| `build.dir` | `${project.root}/work/${build.id}/build` |
| `install.root` | `${project.root}/builds/${build.id}` |
| `install.bin_dir` | `${install.root}/bin` |
| `wps.build_dir` | `${project.root}/work/${build.id}/wps/build` |
| `wps.install_dir` | `${install.root}/wps/WPS-${wps.version}` |

Keep `model.double_precision` quoted as `'ON'` or `'OFF'`.

## Workflow

The primary entry point is:

```bash
bash scripts/monan-jedi.sh <command> --config config/jaci.yaml
```

### Individual commands bootstrap their own environment

Commands that depend on the MONAN-JEDI software stack do **not** assume that a
previous command was run in the same login session. This matters when, for
example, a bundle is configured/built one day and `test` or `test-pbs` is run
directly after a later login.

Before using stack software, the workflow checks that the configured environment
is complete and consistent. The check includes:

- the exact `STACK_ENV_MODULE` selected by the YAML configuration;
- `CMAKE_PREFIX_PATH` and `jedi_cmake_ROOT` from the JEDI environment;
- stack-provided `ecbuild`, `cmake`, `ctest`, `git` and `python` resolution;
- configured compiler and MPI-wrapper bindings (`CC`, `CXX`, `FC`, `MPICC`,
  `MPICXX`, `MPIFC`, and related aliases).

If all of these are already valid, the command reuses the environment. If the
environment is missing, partial, stale or shadowed by another tool environment,
MONAN-JEDI automatically reloads the configured spack-stack before continuing.
The stack loader also restores the original working directory after bootstrap,
so an environment check cannot silently change where the requested command runs.

Therefore these are supported independent invocations, including from different
login sessions:

```bash
bash scripts/monan-jedi.sh configure --config config/jaci.yaml
# logout / new login / another day
bash scripts/monan-jedi.sh build --config config/jaci.yaml
# logout / new login / another day
bash scripts/monan-jedi.sh test --config config/jaci.yaml
# or
bash scripts/monan-jedi.sh test-pbs --config config/jaci.yaml
```

The user does not need to run `load` manually before each command. `load` remains
available as an explicit environment diagnostic and snapshot command.

Available commands:

```text
load             Load and validate the spack-stack environment
configure        Configure the MONAN-JEDI bundle with ecbuild
build            Build the configured bundle
install          Install the configured bundle
test             Run the login-node-safe CTest subset
test-pbs         Submit CTest to PBS
test-pbs-result  Validate the most recent PBS CTest result
obs2ioda         Build and publish NCAR/obs2ioda
wps              Build, validate and publish WPS/UNGRIB
test-wps         Validate the published WPS installation
logs             Collect workflow logs
all              Run the bundle and all enabled auxiliary tools
```

Normal full sequence:

```bash
bash scripts/monan-jedi.sh all --config config/jaci.yaml
```

Individual auxiliary tools:

```bash
bash scripts/monan-jedi.sh obs2ioda --config config/jaci.yaml
bash scripts/monan-jedi.sh wps --config config/jaci.yaml
bash scripts/monan-jedi.sh test-wps --config config/jaci.yaml
```

The `all` command builds auxiliary tools only when their respective `enabled` setting is true.

### Full CTest validation with PBS

See [JACI PBS queue limits](docs/jaci-pbs-queues.md) for current documented
queue limits, exclusive-placement policy and live scheduler query commands.
See [JEDI test data and Git LFS](docs/jedi-test-data.md) for the required binary
test-data repositories, preparation, validation and recovery procedure.

The `test` and `test-pbs` commands have different purposes.

The command:

```bash
bash scripts/monan-jedi.sh test --config config/jaci.yaml
```

runs only the login-node-safe CTest subset. With the default JACI configuration,
this currently selects `mpasjedi_coding_norms`. A successful `test` result does
not mean that the complete JEDI/MPAS-JEDI test suite has passed.

Before submission, `test-pbs` validates that the pinned `ioda-data`,
`ufo-data` and `mpas-jedi-data` Git LFS objects are materialized and reachable
through the build tree. It aborts before `qsub` if pointer text, missing files or
stale `Data` paths are detected.

Submit the complete configured validation to a compute node with:

```bash
bash scripts/monan-jedi.sh test-pbs --config config/jaci.yaml
```

`test-pbs` is asynchronous: a successful `qsub` means that PBS accepted the job,
not that the CTest suite passed. The submission prints the timestamped CTest log
and result-file paths and records the PBS job ID under the run log directory.

After the PBS job has completed, validate the result with:

```bash
bash scripts/monan-jedi.sh test-pbs-result --config config/jaci.yaml
```

The validator reports one of three states:

- `PASS`: CTest completed and no configured test failed.
- `FAIL`: CTest completed and one or more configured tests failed, or CTest returned a failure status.
- `INCOMPLETE`: there is no complete final CTest result for the current submission.

The command returns exit status `0` for `PASS`, `1` for `FAIL`, and `2` for `INCOMPLETE`.

Current PBS jobs write a machine-readable `.result` file containing the PBS job ID,
CTest exit code, total/passed/failed counts and CTest log path. For backward
compatibility, `test-pbs-result` can also validate older `test-pbs` executions
from the newest timestamped `jedi_all_tests_*.ctest.log` when no current submission
metadata exists.

The full PBS validation respects `ctest.exclude_regex` from the YAML configuration.
Therefore, `PASS` means that all configured tests except those explicitly excluded
by that setting passed.

## WPS/UNGRIB integration

The WPS build is intentionally limited to components that do not require a compiled WRF installation. It uses the CMake build shipped by WPS 4.6.0 and builds:

- `ungrib` / `ungrib.exe`;
- `g1print` and `g2print`;
- `link_grib.csh`;
- the complete `Variable_Tables` directory.

The build:

1. checks out the pinned WPS revision;
2. applies versioned compatibility patches from `patches/wps/`;
3. resolves JasPer, libpng and zlib from the loaded Spack environment;
4. configures and builds in a separate tree;
5. installs into a staging release;
6. validates executables and runtime libraries;
7. promotes the release atomically;
8. updates stable links only after validation succeeds.

Stable runtime paths:

```text
${install.bin_dir}/ungrib.exe
${install.bin_dir}/link_grib.csh
${install.root}/share/wps/Vtable
${install.root}/share/wps/Variable_Tables
```

A provenance manifest is written to:

```text
${wps.install_dir}/build-manifest.json
```

See [docs/wps-build-jaci.md](docs/wps-build-jaci.md) for details.

## MONAN--JEDI compatibility contract

Changes to MONAN/MPAS interfaces consumed by data assimilation must follow the
[MONAN--JEDI compatibility contract](docs/MONAN_JEDI_COMPATIBILITY_CONTRACT.md).
It identifies protected model-state, time, geometry, Registry/pool, diagnostic,
file and covariance interfaces; classifies changes by compatibility impact; and
defines the minimum end-to-end validation required before integration.

A successful standalone forecast does not by itself demonstrate MONAN-JEDI
compatibility.

## Repository layout

```text
MONAN-JEDI/
├── CMakeLists.txt
├── config/
│   ├── jaci.yaml
│   └── template.yaml
├── docs/
│   ├── OBS2IODA_BUILD.md
│   ├── YAML_CONFIGURATION.md
│   └── wps-build-jaci.md
├── patches/
│   └── wps/
├── scripts/
│   ├── monan-jedi.sh
│   └── lib/
│       ├── obs2ioda.sh
│       ├── pbs.sh
│       ├── pbs_result.sh
│       ├── read_config.py
│       ├── wps.sh
│       └── wps_dependencies.sh
└── tests/
```

## Pinned bundle revisions

The top-level `CMakeLists.txt` pins the JEDI and MPAS components to full commit SHAs. WPS is also pinned in the YAML configuration because it is an auxiliary build rather than an `ecbuild_bundle` component.

## Design principles

- YAML is the user interface; routine use must not require editing shell scripts.
- Every stack-dependent command is self-bootstrapping and safe to invoke in a fresh login session.
- Build, source, install and stack trees remain independent.
- Auxiliary tools share the stack and install prefix but not the main bundle build tree.
- Published runtime paths are stable and are updated only after validation.
- Logs and manifests must provide enough information to reproduce a build.
