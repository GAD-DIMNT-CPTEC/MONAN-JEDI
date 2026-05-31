# Building obs2ioda with MONAN-JEDI

This document describes the auxiliary build of `NCAR/obs2ioda` using the same `spack-stack-inpe` environment used by the MONAN-JEDI workflow on JACI.

The `obs2ioda` build is kept outside the main MONAN-JEDI bundle CMake tree. This avoids mixing the MPAS-JEDI bundle build with an external converter while still making the converter reproducible from the same YAML configuration and module environment.

## Configuration

The JACI configuration is in `config/jaci.yaml`.

The relevant block is `obs2ioda:`. It controls the repository URL, git reference, optional source/build/install paths, optional BUFR path, build type, GOES ABI converter option and number of build jobs.

By default, the script derives user-owned paths under the configured project root:

```text
work/obs2ioda
work/obs2ioda/build
install/obs2ioda
```

## BUFR library

On the tested JACI `spack-stack-inpe` environment, the BUFR package provides `libbufr_4.so`. It does not provide the generic names `libbufr.so` or `libbufr.a`.

The script therefore searches for `libbufr_4.so`, `libbufr_4.a`, `libbufr.so` and `libbufr.a`, preferring the `bufr` package and avoiding `bufr-query`.

If automatic detection fails, set `obs2ioda.bufr_lib` in `config/jaci.yaml` to the exact BUFR library path.

## Command

From the MONAN-JEDI repository root, run:

```bash
bash scripts/monan-jedi.sh obs2ioda --config config/jaci.yaml
```

The command loads the configured stack environment, clones or updates `NCAR/obs2ioda`, configures it with CMake and builds `obs2ioda_v3`.

## Expected output

The expected executable is:

```text
install/obs2ioda/bin/obs2ioda_v3
```

relative to the configured project root.

The obs2ioda logs are written in the same log directory used by the MONAN-JEDI workflow. The main files are:

```text
08_obs2ioda_clone.log
08_obs2ioda_fetch.log
08_obs2ioda_checkout.log
08_obs2ioda_cmake.log
08_obs2ioda_build.log
08_obs2ioda_ldd.log
```

## Validation

The script checks whether `obs2ioda_v3` was created and then runs `ldd`. It fails if any runtime library is reported as `not found`.

On JACI, the compilers should normally resolve to the CrayPE wrappers `cc`, `CC` and `ftn`. NetCDF C, NetCDF Fortran and NetCDF CXX are detected through `nc-config`, `nf-config` and `ncxx4-config`.
