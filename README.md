# MONAN-JEDI

Repository for the MONAN-JEDI development workflow on INPE/JACI.

This repository is intentionally separated from `spack-stack-inpe`.

## Scope

`spack-stack-inpe` contains the site configuration and the reproducible software stack for JACI.

`MONAN-JEDI` contains the project-controlled bundle definition, configuration, build workflow and validation workflow used to compile and test the current MPAS-JEDI-only baseline with that stack.

The repository root is now the bundle source tree. The top-level `CMakeLists.txt` is the MONAN-JEDI bundle definition. The workflow no longer clones `JCSDA/jedi-bundle` and no longer replaces its `CMakeLists.txt` during the build.

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

For JACI, the default configuration is:

```text
config/jaci.yaml
```

This file defines the stack instance, stack module, workflow run identifier, compiler wrappers, MPI wrappers, build options, CTest options and PBS options.

A generic template for new sites is available at:

```text
config/template.yaml
```

## Workflow

The main entry point is the orchestrator:

```bash
bash scripts/monan-jedi.sh <command> --config config/jaci.yaml
```

Available commands:

```text
load        Load and validate the spack-stack environment
configure   Configure the MONAN-JEDI bundle with ecbuild
build       Build the configured bundle
test        Run the login-node-safe CTest subset
test-pbs    Submit CTest to PBS
logs        Collect logs
all         Run the main workflow sequence
```

Example:

```bash
bash scripts/monan-jedi.sh load --config config/jaci.yaml
bash scripts/monan-jedi.sh configure --config config/jaci.yaml
bash scripts/monan-jedi.sh build --config config/jaci.yaml
bash scripts/monan-jedi.sh test --config config/jaci.yaml
bash scripts/monan-jedi.sh logs --config config/jaci.yaml
```

Or, for the main sequence:

```bash
bash scripts/monan-jedi.sh all --config config/jaci.yaml
```

## Manual minimal build and test

Users who do not want to use the workflow scripts can load the stack, build and run a minimal login-node-safe test directly from the repository root:

```bash
module --force purge 2>/dev/null || module purge

export STACK_ROOT=/p/projetos/monan_das/joao.gerd/work/spack-stack-inpe-overlay-20260515T181917Z/spack-stack
export STACK_ENV_NAME=jaci-mpas-jedi-gcc12-craympich
export STACK_MODULE_ROOT=${STACK_ROOT}/envs/${STACK_ENV_NAME}/modules
export STACK_ENV_MODULE=cray-mpich/8.1.31/none/none/jedi-mpas-env/1.0.0

cd ${STACK_ROOT}
source configs/sites/tier2/jaci/setup.sh

module use ${STACK_MODULE_ROOT}
module load ${STACK_ENV_MODULE}

export CC=cc
export CXX=CC
export FC=ftn
export MPICC=cc
export MPICXX=CC
export MPIFC=ftn

cd /p/projetos/monan_das/${USER}/work
git clone https://github.com/joaogerd/MONAN-JEDI.git
cd MONAN-JEDI

mkdir -p build
cd build

ecbuild .. \
  -DCMAKE_C_COMPILER=${CC} \
  -DCMAKE_CXX_COMPILER=${CXX} \
  -DCMAKE_Fortran_COMPILER=${FC} \
  -DMPI_C_COMPILER=${MPICC} \
  -DMPI_CXX_COMPILER=${MPICXX} \
  -DMPI_Fortran_COMPILER=${MPIFC} \
  -DPython3_EXECUTABLE=$(which python) \
  -DPython_EXECUTABLE=$(which python) \
  -DPYTHON_EXECUTABLE=$(which python) \
  -DBUILD_MPAS=ON \
  -DBUILD_GSIBEC=OFF

make -j 8

ctest -N
ctest --output-on-failure -R '^mpasjedi_coding_norms$'
```

The `ctest -N` command lists the configured tests without executing them. The `mpasjedi_coding_norms` test is the minimal login-node-safe test currently used by the scripted workflow.

For full validation, do not run the complete CTest suite directly on a login node. Use the workflow PBS helper instead:

```bash
cd /p/projetos/monan_das/${USER}/work/MONAN-JEDI
bash scripts/monan-jedi.sh test-pbs --config config/jaci.yaml
```

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
│   └── YAML_CONFIGURATION.md
└── scripts/
    ├── monan-jedi.sh
    └── lib/
        ├── build.sh
        ├── common.sh
        ├── config.sh
        ├── configure.sh
        ├── logs.sh
        ├── pbs.sh
        ├── read_config.py
        ├── stack.sh
        └── test.sh
```

## Design principle

User-editable settings should live in YAML configuration files, not inside shell scripts.

The repository root contains the bundle definition. The shell scripts provide workflow logic. The YAML files describe the site-specific runtime environment.

This keeps the MONAN-JEDI workflow reproducible, easier to review and easier to adapt to additional INPE systems in the future.
