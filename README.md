# MONAN-JEDI

Repository for the MONAN-JEDI development workflow on INPE/JACI.

This repository is intentionally separated from `spack-stack-inpe`.

## Scope

`spack-stack-inpe` contains the site configuration and the reproducible software stack for JACI.

`MONAN-JEDI` contains the project-controlled bundle definition, configuration, build workflow and validation workflow used to compile and test the current MPAS-JEDI-only baseline with that stack.

The repository root is now the bundle source tree. The top-level `CMakeLists.txt` is the MONAN-JEDI bundle definition. The workflow no longer clones `JCSDA/jedi-bundle` and no longer replaces its `CMakeLists.txt` during the build.

The auxiliary `obs2ioda` build is handled by the MONAN-JEDI workflow scripts, but it is kept outside the main bundle build tree and published to the same executable directory used by the MONAN-JEDI bundle.

## Initial target

The first technical target is a reduced MPAS-JEDI-only build on JACI using:

```text
spack-stack release/2.1
JACI CrayPE
PrgEnv-gnu/8.6.0
gcc-native/12.3
cray-mpich/8.1.31
jedi-mpas-env/1.0.0
```

The stack must already have been created and validated by `spack-stack-inpe` before running the workflow in this repository.

## Configuration

Runtime settings are centralized in YAML files under `config/`.

For JACI, the default configuration file is:

```text
config/jaci.yaml
```

This file defines the stack instance, stack module, workflow run identifier, compiler wrappers, MPI wrappers, MPAS precision mode, build directory, installation directory, CTest options, and PBS options.

A generic template for new sites is also available at:

```text
config/template.yaml
```

### Important path settings

The most important path-related settings are:

```yaml
project:
  root: /p/projetos/monan_das/${USER}

build:
  id: monan-jedi
  dir:

install:
  root:
  bin_dir:
```

When some path fields are left empty, they are derived automatically:

| Setting           | If empty, it is derived as               |
| ----------------- | ---------------------------------------- |
| `build.dir`       | `${project.root}/work/${build.id}/build` |
| `install.root`    | `${project.root}/builds/${build.id}`     |
| `install.bin_dir` | `${install.root}/bin`                    |

### MPAS precision mode

The MPAS precision mode is controlled by the `model.double_precision` option.

> [!IMPORTANT]
> Keep this value quoted.
>
> YAML may interpret unquoted `ON` and `OFF` values as booleans.
> Therefore, always use quoted strings.

Use one of the following values:

```yaml
model:
  double_precision: 'ON'
```

or:

```yaml
model:
  double_precision: 'OFF'
```

### Recommended precision settings

| Value   | Mode            | When to use                                                                                                                        |
| ------- | --------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `'ON'`  | Validation mode | Use when validating the build with the `mpas-jedi` CTest suite. Upstream CTest reference files are produced with double precision. |
| `'OFF'` | Workflow mode   | Use only when the target workflow or tutorial requires a single-precision MPAS build.                                              |


## Recommended scripted workflow

The main entry point is the orchestrator:

```bash
bash scripts/monan-jedi.sh <command> --config config/jaci.yaml
```

The scripted workflow is recommended for normal use because it centralizes path handling, loads the stack consistently, checks required tools, records environment snapshots and writes persistent logs under `${project.root}/logs/${build.id}`.

Available commands:

```text
load        Load and validate the spack-stack environment
configure   Configure the MONAN-JEDI bundle with ecbuild
build       Build the configured bundle
install     Install the configured bundle into install.root
test        Run the login-node-safe CTest subset
test-pbs    Submit CTest to PBS
obs2ioda    Build and publish NCAR/obs2ioda with the MONAN-JEDI stack environment
logs        Collect logs
all         Run load, configure, build, install, obs2ioda, test, logs
```

Typical scripted sequence:

```bash
bash scripts/monan-jedi.sh load --config config/jaci.yaml
bash scripts/monan-jedi.sh configure --config config/jaci.yaml
bash scripts/monan-jedi.sh build --config config/jaci.yaml
bash scripts/monan-jedi.sh install --config config/jaci.yaml
bash scripts/monan-jedi.sh obs2ioda --config config/jaci.yaml
bash scripts/monan-jedi.sh test --config config/jaci.yaml
bash scripts/monan-jedi.sh logs --config config/jaci.yaml
```

Or, for the main sequence:

```bash
bash scripts/monan-jedi.sh all --config config/jaci.yaml
```

For full validation, do not run the complete CTest suite directly on a login node. Use the PBS helper:

```bash
bash scripts/monan-jedi.sh test-pbs --config config/jaci.yaml
```

## Manual build and install

The manual path is useful when the goal is to understand the process, debug CMake variables, or reproduce the build step by step without the workflow wrapper. It does not provide the same automatic checks, environment snapshots and organized logs produced by the scripts.

The commands below mirror what the scripts do conceptually.

### 1. Load the JACI stack

```bash
module --force purge 2>/dev/null || module purge

export STACK_ROOT=/p/projetos/monan_das/joao.gerd/work/spack-stack-inpe-overlay-20260515T181917Z/spack-stack
export STACK_ENV_NAME=jaci-mpas-jedi-gcc12-craympich
export STACK_MODULE_ROOT=${STACK_ROOT}/envs/${STACK_ENV_NAME}/modules
export STACK_SITE_SETUP=configs/sites/tier2/jaci/setup.sh
export STACK_ENV_MODULE=cray-mpich/8.1.31/none/none/jedi-mpas-env/1.0.0

cd ${STACK_ROOT}
source ${STACK_SITE_SETUP}

module use ${STACK_MODULE_ROOT}
module load ${STACK_ENV_MODULE}
```

### 2. Define compilers and directories

```bash
export CC=cc
export CXX=CC
export FC=ftn
export MPICC=cc
export MPICXX=CC
export MPIFC=ftn

export PROJECT_ROOT=/p/projetos/monan_das/${USER}
export MONAN_JEDI_RUN_ID=monan-jedi-mpas-only
export MONAN_JEDI_SOURCE_DIR=${PROJECT_ROOT}/work/MONAN-JEDI
export MONAN_JEDI_BUILD_DIR=${PROJECT_ROOT}/work/${MONAN_JEDI_RUN_ID}/build
export MONAN_JEDI_INSTALL_ROOT=${PROJECT_ROOT}/builds/${MONAN_JEDI_RUN_ID}
export MONAN_JEDI_INSTALL_BIN_DIR=${MONAN_JEDI_INSTALL_ROOT}/bin
```

Clone the repository if needed:

```bash
mkdir -p ${PROJECT_ROOT}/work
cd ${PROJECT_ROOT}/work
git clone https://github.com/GAD-DIMNT-CPTEC/MONAN-JEDI.git
cd MONAN-JEDI
export MONAN_JEDI_SOURCE_DIR=$(pwd)
```

### 3. Configure the MONAN-JEDI bundle

```bash
mkdir -p ${MONAN_JEDI_BUILD_DIR} ${MONAN_JEDI_INSTALL_BIN_DIR}
cd ${MONAN_JEDI_BUILD_DIR}

export PYTHON_EXE=$(command -v python)

ecbuild ${MONAN_JEDI_SOURCE_DIR} \
  -DCMAKE_C_COMPILER=${CC} \
  -DCMAKE_CXX_COMPILER=${CXX} \
  -DCMAKE_Fortran_COMPILER=${FC} \
  -DMPI_C_COMPILER=${MPICC} \
  -DMPI_CXX_COMPILER=${MPICXX} \
  -DMPI_Fortran_COMPILER=${MPIFC} \
  -DPython3_EXECUTABLE=${PYTHON_EXE} \
  -DPython_EXECUTABLE=${PYTHON_EXE} \
  -DPYTHON_EXECUTABLE=${PYTHON_EXE} \
  -DCMAKE_INSTALL_PREFIX=${MONAN_JEDI_INSTALL_ROOT} \
  -DCMAKE_INSTALL_BINDIR=bin \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_RUNTIME_OUTPUT_DIRECTORY=${MONAN_JEDI_INSTALL_BIN_DIR} \
  '-DCMAKE_INSTALL_RPATH=$ORIGIN/../lib' \
  -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON \
  -DBUILD_MPAS=ON \
  -DBUILD_GSIBEC=OFF \
  -DMPAS_DOUBLE_PRECISION=ON
```

Use `-DMPAS_DOUBLE_PRECISION=ON` for CTest validation. Use `OFF` only for single-precision workflow runs where reference-test equivalence is not the objective.

### 4. Build and install

```bash
make -j 8
make install
```

After installation, the executable directory should be:

```bash
ls -lh ${MONAN_JEDI_INSTALL_BIN_DIR}
```

### 5. Run a minimal login-node-safe test

```bash
cd ${MONAN_JEDI_BUILD_DIR}
ctest -N
ctest --output-on-failure -R '^mpasjedi_coding_norms$'
```

The `ctest -N` command lists the configured tests without executing them. The `mpasjedi_coding_norms` test is the minimal login-node-safe test currently used by the scripted workflow.

## Manual obs2ioda build

The `obs2ioda` build is separate from the MONAN-JEDI bundle. It uses the same loaded stack, but a different source and build tree. The final executable should be published to `${MONAN_JEDI_INSTALL_BIN_DIR}` so all user-facing executables remain in one place.

### 1. Define paths

```bash
export OBS2IODA_SOURCE_DIR=${PROJECT_ROOT}/work/${MONAN_JEDI_RUN_ID}/obs2ioda/src
export OBS2IODA_BUILD_DIR=${PROJECT_ROOT}/work/${MONAN_JEDI_RUN_ID}/obs2ioda/build
export OBS2IODA_INSTALL_DIR=${MONAN_JEDI_INSTALL_ROOT}
export OBS2IODA_EXE=${MONAN_JEDI_INSTALL_BIN_DIR}/obs2ioda_v3
```

### 2. Clone the source

```bash
mkdir -p $(dirname ${OBS2IODA_SOURCE_DIR})
if [ ! -d ${OBS2IODA_SOURCE_DIR}/.git ]; then
  git clone https://github.com/NCAR/obs2ioda.git ${OBS2IODA_SOURCE_DIR}
fi

cd ${OBS2IODA_SOURCE_DIR}
git fetch --tags origin
git checkout main
```

### 3. Locate required dependencies

```bash
export BUFR_LIB=$(find /p/projetos/monan_das/joao.gerd/env/spack-stack/spack-stack-inpe-overlay-20260515T181917Z/install \
  -type f \( -name 'libbufr_4.so' -o -name 'libbufr_4.a' -o -name 'libbufr.so' -o -name 'libbufr.a' \) \
  | grep '/bufr-' \
  | grep -v '/bufr-query-' \
  | head -n 1)

export OBS2IODA_PREFIX_PATH="$(nc-config --prefix);$(nf-config --prefix);$(ncxx4-config --prefix)"

echo ${BUFR_LIB}
echo ${OBS2IODA_PREFIX_PATH}
```

If `BUFR_LIB` is empty, the BUFR package was not found in the expected stack installation path. In that case, locate the correct `libbufr_4.so` or `libbufr_4.a` manually and set `BUFR_LIB` to its full path.

### 4. Configure, build and publish obs2ioda

```bash
rm -rf ${OBS2IODA_BUILD_DIR}
mkdir -p ${OBS2IODA_BUILD_DIR} ${OBS2IODA_INSTALL_DIR} ${MONAN_JEDI_INSTALL_BIN_DIR}
cd ${OBS2IODA_BUILD_DIR}

cmake ${OBS2IODA_SOURCE_DIR} \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=${OBS2IODA_INSTALL_DIR} \
  -DCMAKE_INSTALL_BINDIR=bin \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_RUNTIME_OUTPUT_DIRECTORY=${MONAN_JEDI_INSTALL_BIN_DIR} \
  '-DCMAKE_INSTALL_RPATH=$ORIGIN/../lib' \
  -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON \
  -DCMAKE_C_COMPILER=${CC} \
  -DCMAKE_CXX_COMPILER=${CXX} \
  -DCMAKE_Fortran_COMPILER=${FC} \
  -DCMAKE_PREFIX_PATH="${OBS2IODA_PREFIX_PATH}" \
  -DNCEP_BUFR_LIB=${BUFR_LIB} \
  -DBUILD_GOES_ABI_CONVERTER=OFF

cmake --build . -j 8
```

Try the upstream install target first:

```bash
cmake --install . || true
```

Then publish the executable explicitly if needed:

```bash
if [ -x ${OBS2IODA_INSTALL_DIR}/bin/obs2ioda_v3 ]; then
  install -D -m 755 ${OBS2IODA_INSTALL_DIR}/bin/obs2ioda_v3 ${OBS2IODA_EXE}
elif [ -x ${OBS2IODA_BUILD_DIR}/bin/obs2ioda_v3 ]; then
  install -D -m 755 ${OBS2IODA_BUILD_DIR}/bin/obs2ioda_v3 ${OBS2IODA_EXE}
else
  echo "obs2ioda_v3 was not found"
  exit 1
fi
```

Check runtime shared libraries:

```bash
ldd ${OBS2IODA_EXE}
```

If `ldd` reports `not found`, the executable was built successfully but the runtime loader cannot find one or more shared libraries. In that case, check whether the required libraries are under `${MONAN_JEDI_INSTALL_ROOT}/lib`, whether the stack module is loaded, and whether the executable RPATH is sufficient for the chosen install layout.

## Repository layout

```text
MONAN-JEDI/
├── CMakeLists.txt
├── README.md
├── config/
│   ├── jaci.yaml
│   └── template.yaml
├── docs/
│   ├── BUNDLE_ORIGIN.md
│   ├── JACI_MPAS_JEDI_BUILD_STEPS.md
│   ├── OBS2IODA_BUILD.md
│   └── YAML_CONFIGURATION.md
└── scripts/
    ├── monan-jedi.sh
    └── lib/
        ├── build.sh
        ├── common.sh
        ├── config.sh
        ├── configure.sh
        ├── logs.sh
        ├── obs2ioda.sh
        ├── pbs.sh
        ├── read_config.py
        ├── stack.sh
        └── test.sh
```

## Pinned component revisions

The MONAN-JEDI bundle builds a reduced MPAS-JEDI-oriented set of JEDI and MPAS components. The source revisions below are declared directly in the top-level `CMakeLists.txt` through `ecbuild_bundle(...)`.

Each component is pinned to a full Git commit SHA to ensure that the same source revision is selected in future builds. The commit date corresponds to the Git commit timestamp reported by the upstream repository.

These entries describe components downloaded and built by the MONAN-JEDI bundle. They do not include packages supplied externally by the preconfigured `spack-stack` environment, such as compilers, MPI, NetCDF, ecbuild, `jedi-cmake`, BUFR and other system dependencies.

| Component | Upstream repository | Commit SHA | Commit date | Official tag|
|---|---|---|---|---|
| IODA | `jcsda/ioda` | `1d390ad1c719cf9f8a30ff2f1e137461e4b925f9` | 2026-05-19 | — |
| MPAS-JEDI | `jcsda/mpas-jedi` | `19eb7fb3273c7b3094825201af184834c15afdd0` | 2026-05-20 | — |
| UFO | `jcsda/ufo` | `90979fa048477f2b240117d98efd1d1bfa8acd4d` | 2026-05-19 | — |
| MPAS-JEDI data | `jcsda-internal/mpas-jedi-data` | `3307edcdb27cef650fe121367c3bb48d6cfa968b` | 2026-05-12 | — |
| IODA data | `jcsda-internal/ioda-data` | `f0f963eef555c6d7ce8b22da490128374da75bc7` | 2026-05-19 | — |
| GSW-Fortran | `jcsda/GSW-Fortran` | `697cbeb7605d70ed3857664c5f54a5c05346e31f` | 2024-04-01| `v3.08` |
| SABER | `jcsda/saber` | `d05c06fcc7da97389a19594a2e5424e709648330` | 2026-05-18 | — |
| VADER | `jcsda/vader` | `f74de9519c02084ac4ed80738374ddf1d7771e44` | 2026-05-11 | — |
| OOPS | `jcsda/oops` | `192c83c4d706017d906ec0ad58d27e4093c7dced` | 2026-05-19 | — |
| CRTMv3 | `jcsda/CRTMv3` | `9b63e4ef162e4738ec807938122f2e21296a629a` | 2026-04-09 | — |
| MPAS-Model | `MPAS-Dev/MPAS-Model` | `0e5a47a0e1bcccd6e3d99909b76e740a643c4db6` | 2026-04-01 | — |
| UFO data | `jcsda-internal/ufo-data` | `d8c77d388cd43b017fce3964b5a6c90e371015a7` | 2026-05-19 | — |

> [!NOTE]
> `GSIbec` is available as an optional component through `BUILD_GSIBEC`, but it is disabled in the default MONAN-JEDI configuration.
>
> `obs2ioda` is built separately by the workflow scripts and is currently configured from the `main` branch. It is therefore not included in the pinned-revision table until its configuration is changed to a specific commit SHA.


## Design principle

User-editable settings should live in YAML configuration files, not inside shell scripts.

The repository root contains the bundle definition. The shell scripts provide workflow logic, checks and logging. The YAML files describe the site-specific runtime environment.

This keeps the MONAN-JEDI workflow reproducible, easier to review and easier to adapt to additional INPE systems in the future.
