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
separate client, Git can leave small pointer-text files in place of the
scientific data; the build may compile, but CTest will fail or wait until its
timeout.

On JACI, Conda is initialized with:

```bash
module load anaconda
start_conda
```

The prompt normally changes to `(base)`. JACI's `(base)` environment is the
shared, read-only `/p/app/anaconda`; it is **not** the persistent installation
location for MONAN-JEDI dependencies.

MONAN-JEDI keeps Git LFS in the user-owned project tree:

```text
${project.root}/envs/git-lfs
```

With `config/jaci.yaml`, that is normally:

```text
/p/projetos/monan_das/${USER}/envs/git-lfs
```

Before installing anything, check whether the persistent installation already
exists:

```bash
ls -l /p/projetos/monan_das/${USER}/envs/git-lfs/bin/git-lfs
```

If that file exists, **do not reinstall Git LFS**. MONAN-JEDI automatically
finds it on later login sessions, adds its `bin` directory to the workflow
`PATH`, and reports the version and executable path being reused.

For a first-time installation only:

```bash
module load anaconda
start_conda

export GIT_LFS_ENV="/p/projetos/monan_das/${USER}/envs/git-lfs"
conda create -y -p "${GIT_LFS_ENV}" -c conda-forge git-lfs

export PATH="${GIT_LFS_ENV}/bin:${PATH}"
git lfs install
git lfs version
```

The `conda create -p` command writes the environment below the project area, so
it remains available after logout or `conda deactivate`. The `(base)` prompt is
only used to make the `conda` command available during first-time creation.

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
- Build, source, install and stack trees remain independent.
- Auxiliary tools share the stack and install prefix but not the main bundle build tree.
- Published runtime paths are stable and are updated only after validation.
- Logs and manifests must provide enough information to reproduce a build.
