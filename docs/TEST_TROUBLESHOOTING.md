# Test troubleshooting checklist

This document lists the first checks that should be performed when MONAN-JEDI tests fail.

The goal is to eliminate simple and frequent problems before assuming that the failure is caused by MPAS-JEDI, MONAN-JEDI, Spack Stack, MPI, CMake or the compiler toolchain.

These checks are especially useful when:

- `ctest` fails after a successful build;
- login-node-safe tests pass, but the complete PBS test suite fails;
- NetCDF, HDF5, CRTM, IODA, UFO, SABER, OOPS or MPAS-JEDI tests fail with file, Python or runtime errors;
- different users get different test results using what should be the same stack.

## 1. Confirm that the expected stack environment is loaded

Run these commands before executing tests:

```bash
module list
which cmake
which ecbuild
which ctest
which python
which git
which mpiexec || true

echo "PATH entries:"
echo "$PATH" | tr ':' '\n'

echo "LD_LIBRARY_PATH entries:"
echo "${LD_LIBRARY_PATH:-}" | tr ':' '\n'
```

Expected result:

- `cmake`, `ecbuild`, `ctest`, `python` and MPI launchers should come from the intended Spack Stack environment or from the expected system modules.
- They should not come from a personal Conda, Anaconda, Miniconda, Miniforge, Mambaforge or unrelated user environment.

If the output does not match the expected stack, stop and reload the environment before continuing.

## 2. Check for Conda, Anaconda or user Python contamination

A common cause of inconsistent test behavior is a user Python environment appearing before the Spack Stack Python in `PATH`.

Check:

```bash
echo "$PATH" | tr ':' '\n' | grep -Ei 'conda|anaconda|miniconda|miniforge|mambaforge' || true
which python
python -c 'import sys; print(sys.executable); print(sys.version)'
```

Possible problem indicators:

```text
/home/<user>/anaconda3/bin/python
/home/<user>/miniconda3/bin/python
/home/<user>/miniforge3/bin/python
/home/<user>/mambaforge/bin/python
```

If Conda or Anaconda appears unexpectedly, clean the shell and reload the stack:

```bash
conda deactivate 2>/dev/null || true
module --force purge 2>/dev/null || module purge
```

Then load the official MONAN-JEDI stack again.

Important: this is not a statement that Conda is always wrong. It is a diagnostic rule for this workflow. The build and tests should use the Python resolved by the validated stack, not an accidental user-level Python.

## 3. Check whether Git LFS data were downloaded correctly

Some JEDI-related repositories and submodules may use Git LFS for large test data. If Git LFS content is not downloaded, the repository may contain small text pointer files instead of the real data files.

This can affect different components, including but not limited to CRTM, IODA, UFO, SABER, OOPS and MPAS-JEDI tests. Do not assume this problem is restricted to one specific file or one specific test.

Typical symptoms include errors such as:

```text
NetCDF: Unknown file format
HDF5-DIAG: Error detected in HDF5
file signature not found
Not an HDF5 file
invalid data file
unable to open file
```

First check whether Git LFS is available:

```bash
git lfs version
```

Then list LFS-tracked files in the repository and submodules:

```bash
git lfs ls-files | head

git submodule foreach --recursive 'echo "== $name =="; git lfs ls-files | head || true'
```

If the test log points to a specific input file, inspect that file generically:

```bash
file /path/to/suspect/test/data/file
head -n 5 /path/to/suspect/test/data/file
```

A valid binary scientific data file may appear as HDF5, NetCDF, GRIB, BUFR or another binary format, depending on the test.

A Git LFS pointer usually appears as plain text and starts with content similar to:

```text
version https://git-lfs.github.com/spec/v1
oid sha256:...
size ...
```

If pointer files are found, download the actual LFS content:

```bash
git lfs install
git lfs pull

git submodule foreach --recursive 'git lfs pull || true'
```

After that, recheck the suspect files:

```bash
file /path/to/suspect/test/data/file
head -n 5 /path/to/suspect/test/data/file
```

For binary files, `head` may print unreadable characters. That is usually a good sign. The problem is when the file is readable text containing the Git LFS pointer metadata.

## 4. Check whether submodules are complete

Incomplete submodules can produce missing input files, outdated source trees or inconsistent test behavior.

Check:

```bash
git submodule status --recursive
```

Warning signs:

- lines beginning with `-`, indicating submodules not initialized;
- unexpected commits compared with the documented bundle baseline;
- local modifications inside submodules that were not intentional.

Repair:

```bash
git submodule update --init --recursive

git submodule foreach --recursive 'git lfs pull || true'
```

Then rerun the failing test group.

## 5. Check whether the build cache used the expected compilers and Python

Inside the build directory, inspect `CMakeCache.txt`:

```bash
grep -E 'CMAKE_C_COMPILER|CMAKE_CXX_COMPILER|CMAKE_Fortran_COMPILER' CMakeCache.txt

grep -E 'MPI_C_COMPILER|MPI_CXX_COMPILER|MPI_Fortran_COMPILER' CMakeCache.txt

grep -E 'Python_EXECUTABLE|Python3_EXECUTABLE|PYTHON_EXECUTABLE' CMakeCache.txt
```

For JACI/CrayPE, the expected compiler wrappers are normally:

```text
cc
CC
ftn
```

or their resolved CrayPE paths.

The Python executable should match the validated stack environment. It should not unexpectedly point to a personal Conda or Anaconda installation.

If the cache contains the wrong compilers or Python, do not try to fix the cache manually. Recreate the build directory after loading the correct environment.

Example:

```bash
cd /path/to/MONAN-JEDI
rm -rf build
mkdir -p build
cd build
# rerun ecbuild with the expected environment loaded
```

## 6. Start with a small test before running the full suite

Before submitting the full test suite, confirm that CTest is correctly configured:

```bash
ctest -N
ctest --output-on-failure -R '^mpasjedi_coding_norms$'
```

The first command lists available tests without executing them. The second command runs a minimal login-node-safe test.

If this minimal test fails, investigate the environment, build directory and CMake cache before running larger test groups.

## 7. Run tests by component

Avoid starting the investigation with the complete test suite. Use component filters first:

```bash
ctest -R ioda --output-on-failure
ctest -R crtm --output-on-failure
ctest -R ufo --output-on-failure
ctest -R oops --output-on-failure
ctest -R saber --output-on-failure
ctest -R vader --output-on-failure
ctest -R mpasjedi --output-on-failure
```

For more details on a specific failure:

```bash
ctest -R '<test-name-or-pattern>' --output-on-failure -V
```

Use the failing test log to identify whether the first error is related to:

- missing or invalid input data;
- Git LFS pointer files;
- Python import errors;
- wrong shared libraries;
- MPI launcher problems;
- PBS walltime limits;
- actual scientific code failure.

## 8. Check for PBS walltime or scheduler termination

If a PBS test job stops with a message similar to:

```text
PBS: job killed: walltime exceeded limit
```

then the failure may be caused by scheduler termination, not by a failing test assertion.

Check the PBS log and the CTest log together. If CTest was still running when PBS killed the job, increase the walltime before interpreting the result as a test failure.

Example:

```bash
#PBS -l walltime=02:00:00
```

or, if needed and permitted by the queue policy:

```bash
#PBS -l walltime=04:00:00
```

This does not fix real test failures. It only prevents premature job termination from masking the real result.

## 9. Minimal information to collect before reporting a test failure

When reporting a test failure, collect these outputs from the same shell used to run the tests:

```bash
module list
which python
python -c 'import sys; print(sys.executable); print(sys.version)'
which cmake
which ecbuild
which ctest
which git
which mpiexec || true

echo "$PATH" | tr ':' '\n'
echo "${LD_LIBRARY_PATH:-}" | tr ':' '\n'

git status
git submodule status --recursive
git lfs version
git lfs ls-files | head

grep -E 'CMAKE_C_COMPILER|CMAKE_CXX_COMPILER|CMAKE_Fortran_COMPILER' build/CMakeCache.txt || true
grep -E 'MPI_C_COMPILER|MPI_CXX_COMPILER|MPI_Fortran_COMPILER' build/CMakeCache.txt || true
grep -E 'Python_EXECUTABLE|Python3_EXECUTABLE|PYTHON_EXECUTABLE' build/CMakeCache.txt || true
```

Also attach the relevant logs, for example:

```text
01_stack_environment.log
04_configure_environment.log
04_ecbuild.log
05_make.log
06_ctest.log
11_ctest_all_pbs_environment.log
jedi_all_tests*.ctest.log
jedi_all_tests*.pbs.log
```

## 10. Interpretation rule

Do not assume that a test failure means a source-code bug until the following simple causes have been checked:

- wrong or partially loaded stack environment;
- Conda, Anaconda or user Python contamination;
- missing Git LFS content;
- incomplete submodules;
- stale CMake cache from another environment;
- wrong compiler or MPI wrappers in `CMakeCache.txt`;
- missing input data;
- PBS walltime termination.

Only after these checks should the failure be escalated as a possible MONAN-JEDI, MPAS-JEDI, JEDI, Spack Stack, MPI or compiler issue.
