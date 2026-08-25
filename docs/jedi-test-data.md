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

## Persistent Git LFS installation on JACI

JACI starts normal users without a writable Conda environment. To use Conda on
a login node, first load the site module and initialize Conda:

```bash
module load anaconda
start_conda
```

The prompt normally changes to `(base)`. That `base` environment lives under
`/p/app/anaconda`, is shared by the site and is not the place where MONAN-JEDI
stores Git LFS. Do not try to make the dependency permanent by installing it
into `(base)`.

MONAN-JEDI uses a persistent user-owned location derived from `project.root`:

```text
${project.root}/envs/git-lfs
```

With the default JACI configuration this resolves to:

```text
/p/projetos/monan_das/${USER}/envs/git-lfs
```

This directory is the durable record that Git LFS has already been installed for
the user. It remains there after logout, after `conda deactivate`, and after a
new login session. The user does not need to remember whether installation was
performed previously; MONAN-JEDI checks this location automatically.

### First-time installation

Only when `${project.root}/envs/git-lfs/bin/git-lfs` does not already exist, run:

```bash
module load anaconda
start_conda

export GIT_LFS_ENV="/p/projetos/monan_das/${USER}/envs/git-lfs"
conda create -y -p "${GIT_LFS_ENV}" -c conda-forge git-lfs

export PATH="${GIT_LFS_ENV}/bin:${PATH}"
git lfs install
git lfs version
```

The `conda create -p` command creates an independent environment in the writable
project tree. It does not modify JACI's shared `(base)` environment.

### Later sessions

After the first installation, users do **not** need to repeat the Conda setup in
order to run MONAN-JEDI. The workflow checks normal `PATH` first and, if `git
lfs` is not there, automatically checks:

```text
${project.root}/envs/git-lfs/bin/git-lfs
```

When found, the workflow adds that directory to its own `PATH` and reports the
version, executable and persistent project location, for example:

```text
[INFO] Git LFS is available
[INFO]   version=git-lfs/3.5.1 (...)
[INFO]   executable=/p/projetos/monan_das/user/envs/git-lfs/bin/git-lfs
[INFO]   persistent_project_env=/p/projetos/monan_das/user/envs/git-lfs
```

Therefore, an existing persistent environment is reused rather than recreated.

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

If Git LFS is already installed in the persistent project location, there is no
need to reinstall it. Restore it to the current interactive shell only when you
want to run Git LFS commands manually:

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

To check whether the persistent Git LFS environment already exists:

```bash
ls -l /p/projetos/monan_das/${USER}/envs/git-lfs/bin/git-lfs
/p/projetos/monan_das/${USER}/envs/git-lfs/bin/git-lfs version
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

1. Git LFS is installed once in a persistent user-owned project location;
2. later sessions automatically discover and reuse that installation;
3. `configure` requires the Git LFS client;
4. all pinned test-data repositories are explicitly pulled and checked out;
5. every tracked path is checked for missing, empty or pointer-only content;
6. `test-pbs` repeats the non-mutating validation before allocating a node;
7. a failure prints the persistent location and executable recovery commands and prevents `qsub`.

A successful compilation alone does not certify that CTest data are usable.
