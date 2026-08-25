# JEDI test data and Git LFS on JACI

## Why these data are required

The complete CTest inventory does not use only generated inputs. Several IODA,
UFO and MPAS-JEDI tests read pinned scientific reference files from three bundle
components:

| Bundle component | Source directory | Purpose |
|---|---|---|
| `ioda-data` | `${MONAN_JEDI_SOURCE_DIR}/ioda-data` | NetCDF/HDF5/ODB inputs for IODA tests |
| `ufo-data` | `${MONAN_JEDI_SOURCE_DIR}/ufo-data` | observation-filter and operator reference inputs |
| `mpas-jedi-data` | `${MONAN_JEDI_SOURCE_DIR}/mpas-jedi-data` | MPAS-JEDI meshes, states and reference test inputs |

These are separate repositories declared and pinned in the top-level
`CMakeLists.txt`. They are not stored below `ioda/`, `ufo/` or
`mpas-jedi/`. During configuration, ecbuild creates build-tree `Data` paths
that point to the corresponding data repositories. For example, an IODA test
running from the build tree resolves:

```text
${MONAN_JEDI_BUILD_DIR}/ioda/Data/testinput_tier_1/sondes_obs_2018041500_m.nc4
```

## Why an ordinary clone can be silently unusable

The scientific binary files use Git Large File Storage (Git LFS). A machine
without the separate Git LFS client can still clone the Git repositories
successfully. In that case each large file remains a short text pointer such as:

```text
version https://git-lfs.github.com/spec/v1
oid sha256:...
size 304016
```

CMake and the compiler do not need to open most of these files, so configure,
build and install can appear successful. CTest later passes the pointer text to
NetCDF/HDF5 and reports errors such as:

```text
NetCDF: Unknown file format
Not an HDF5 file
```

MPI tests can then wait after one rank fails, consuming their entire individual
timeout and eventually the PBS walltime.

This occurred on JACI in job `388629.pbs-ha`, submitted on 2026-08-24. Four
IODA MPI tests each consumed about 1500 seconds. The serial CTest run spent about
1 hour 40 minutes in those four timeouts and reached only test 747 of 2294 before
the two-hour PBS limit terminated it.

## Git LFS source on the current JACI baseline

The validated MONAN-JEDI spack-stack currently provides Git LFS through the
loaded environment. Users should therefore check the normal MONAN-JEDI stack
before installing anything separately:

```bash
bash scripts/monan-jedi.sh load --config config/jaci.yaml
```

A healthy current JACI baseline reports something like:

```text
[INFO] Git LFS is available
[INFO]   version=git-lfs/3.5.1 (...)
[INFO]   executable=.../spack-stack.../git-lfs-3.5.1.../bin/git-lfs
[INFO]   provider=loaded stack/environment
```

The loaded module inventory also contains a Git LFS module, and the environment
snapshot records both the executable path and `git lfs version`. This is the
preferred source because it is part of the validated software environment used
by the rest of MONAN-JEDI.

No Conda installation is required when `load` already reports a working Git LFS
client.

## Project-local fallback for custom or older stacks

A custom or older stack may not provide Git LFS. In that case MONAN-JEDI checks
a persistent user-owned fallback derived from `project.root`:

```text
${project.root}/envs/git-lfs
```

With the default JACI configuration this resolves to:

```text
/p/projetos/monan_das/${USER}/envs/git-lfs
```

If `${project.root}/envs/git-lfs/bin/git-lfs` already exists, MONAN-JEDI adds its
`bin` directory to the workflow `PATH` and reports:

```text
[INFO] Git LFS is available
[INFO]   version=git-lfs/3.5.1 (...)
[INFO]   executable=/p/projetos/monan_das/user/envs/git-lfs/bin/git-lfs
[INFO]   provider=project-local fallback
[INFO]   project_fallback_env=/p/projetos/monan_das/user/envs/git-lfs
```

The fallback remains available after logout and does not depend on the user
remembering how it was created.

### Creating the fallback for the first time

Only when the loaded stack does not provide Git LFS and the project-local
fallback does not already exist, initialize Conda on a JACI login node:

```bash
module load anaconda
start_conda
```

The prompt normally changes to `(base)`. That base environment lives under
`/p/app/anaconda`, is shared by the site and is not the installation target.
It is used only to expose the `conda` command.

Create the fallback in the writable project tree:

```bash
export GIT_LFS_ENV="/p/projetos/monan_das/${USER}/envs/git-lfs"
conda create -y -p "${GIT_LFS_ENV}" -c conda-forge git-lfs

export PATH="${GIT_LFS_ENV}/bin:${PATH}"
git lfs install
git lfs version
```

Later MONAN-JEDI sessions find this fallback automatically if the loaded stack
still lacks Git LFS. The Conda initialization does not need to be repeated.

## Required preparation of the bundle data

For a new or clean build, use the normal workflow:

```bash
bash scripts/monan-jedi.sh configure --config config/jaci.yaml
bash scripts/monan-jedi.sh build --config config/jaci.yaml
bash scripts/monan-jedi.sh install --config config/jaci.yaml
```

The configure step runs `git lfs pull` and `git lfs checkout` in all three data
repositories and rejects missing, empty or pointer-only files.

## Recovering an existing source and build tree

First load the normal MONAN-JEDI environment and confirm which Git LFS provider
is active:

```bash
bash scripts/monan-jedi.sh load --config config/jaci.yaml
```

If the stack provides Git LFS, no additional activation is needed. If the
project-local fallback is required for manual commands in the current shell, use:

```bash
export GIT_LFS_ENV="/p/projetos/monan_das/${USER}/envs/git-lfs"
export PATH="${GIT_LFS_ENV}/bin:${PATH}"

git lfs version
```

Then materialize the existing checkouts from the MONAN-JEDI repository root:

```bash
git lfs install

for repo in ioda-data ufo-data mpas-jedi-data; do
  git -C "${repo}" lfs pull
  git -C "${repo}" lfs checkout
done
```

Then rerun `test-pbs`. Its preflight validates every Git LFS tracked path and
representative build-tree `Data` paths before calling `qsub`:

```bash
bash scripts/monan-jedi.sh test-pbs --config config/jaci.yaml
```

If the existing build-tree links are missing or stale, rerun `configure` and
then rebuild. Do not increase PBS walltime merely to hide Git LFS or input-data
failures.

## Manual diagnostics

Check the provider selected by the normal workflow:

```bash
bash scripts/monan-jedi.sh load --config config/jaci.yaml
```

For direct shell diagnostics after loading the stack:

```bash
command -v git-lfs
git lfs version
module list 2>&1 | grep -i lfs
```

To check whether a project-local fallback also exists:

```bash
ls -l /p/projetos/monan_das/${USER}/envs/git-lfs/bin/git-lfs
```

Inspect the actual locations used by CTest:

```bash
file work/monan-jedi/build/ioda/Data/testinput_tier_1/sondes_obs_2018041500_m.nc4
head -n 3 work/monan-jedi/build/ioda/Data/testinput_tier_1/sondes_obs_2018041500_m.nc4
```

A materialized NetCDF-4 file normally reports HDF5/NetCDF binary data. It must
not begin with the Git LFS pointer signature.

To inspect repository state:

```bash
git -C ioda-data lfs status
git -C ufo-data lfs status
git -C mpas-jedi-data lfs status
```

## Workflow contract

The MONAN-JEDI contract is now:

1. the validated loaded stack/environment is the preferred Git LFS provider;
2. a project-local persistent installation is used only as fallback;
3. the workflow reports which provider and executable are actually in use;
4. `configure` requires a working Git LFS client;
5. all pinned test-data repositories are explicitly pulled and checked out;
6. every tracked path is checked for missing, empty or pointer-only content;
7. `test-pbs` repeats the non-mutating validation before allocating a node;
8. a failure prints actionable fallback and recovery commands and prevents `qsub`.

A successful compilation alone does not certify that CTest data are usable.
