# MPAS double precision and CTest reference files

## Summary

The `mpas-bundle` build can be configured with either double precision or single precision for MPAS through the CMake option:

```bash
-DMPAS_DOUBLE_PRECISION=ON
````

or:

```bash
-DMPAS_DOUBLE_PRECISION=OFF
```

This option affects numerical results from MPAS and MPAS-JEDI tests. It is especially important when interpreting `ctest` results.

## Confirmed upstream behavior

The upstream `mpas-bundle` README states that `MPAS_DOUBLE_PRECISION` should be enabled for running the `mpas-jedi` test suite:

```bash
-DMPAS_DOUBLE_PRECISION=ON
```

The same README indicates that `MPAS_DOUBLE_PRECISION=OFF` may be used for MPAS-Workflow calculations when using the `mpas-bundle` build.

The default value is:

```bash
-DMPAS_DOUBLE_PRECISION=ON
```

## MPAS-JEDI 2024 tutorial note

The MPAS-JEDI 2024 tutorial, page 21, documents the following:

> Note: ctest reference files are produced with the double-precision build, thus some of ctest cases with single-precision build will fail due to difference larger than tolerance.

Therefore, if `mpas-bundle` is configured with:

```bash
-DMPAS_DOUBLE_PRECISION=OFF
```

some `ctest` failures are expected and should not immediately be interpreted as MPI, compiler, filesystem, or platform failures.

## Recommended procedure

Use a double-precision build for validating the build with the full `ctest` suite:

```bash
-DMPAS_DOUBLE_PRECISION=ON
```

Use a single-precision build only when the target workflow or tutorial explicitly requires it:

```bash
-DMPAS_DOUBLE_PRECISION=OFF
```

In practice, this means that two build modes may be needed:

1. a validation build, using double precision;
2. a workflow build, using single precision when required.

## Diagnostic guidance

If tests fail with `MPAS_DOUBLE_PRECISION=OFF`, first check whether the failures are numerical comparison failures.

Recommended commands:

```bash
ctest -R mpasjedi_state -VV
ctest -R mpasjedi_hofx3d -VV
ctest -R mpasjedi_3dvar -VV
```

Also confirm the actual CMake configuration:

```bash
grep -R "MPAS_DOUBLE_PRECISION" build/CMakeCache.txt build/*/CMakeCache.txt 2>/dev/null
```

If the failures are mostly concentrated in `mpasjedi` tests and the build was configured with `MPAS_DOUBLE_PRECISION=OFF`, the failures may be caused by differences between single-precision output and double-precision reference files.

If the same tests fail with `MPAS_DOUBLE_PRECISION=ON`, then other causes should be investigated, such as MPI runtime, compiler wrappers, missing data, Python environment, or filesystem issues.

## References

1. JCSDA `mpas-bundle` README: [https://github.com/JCSDA/mpas-bundle](https://github.com/JCSDA/mpas-bundle)
2. MPAS-JEDI 2024 tutorial, page 21: [https://www2.mmm.ucar.edu/projects/mpas-jedi/tutorial/202410HOWARD/lectures/3-Overview.pdf](https://www2.mmm.ucar.edu/projects/mpas-jedi/tutorial/202410HOWARD/lectures/3-Overview.pdf)

