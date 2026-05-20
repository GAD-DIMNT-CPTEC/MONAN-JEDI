# Known issue: IODA BUFR Python tests on JACI

## Summary

Two IODA tests currently fail in the JACI MPAS-JEDI/JEDI validation workflow:

```text
ioda_bufr_python_encoder
ioda_bufr_python_parallel
```

The failure is caused by the Python script tests expecting a module named:

```python
import bufr
```

The active JACI stack provides NCEPLIBS-bufr and bufr-query, but the Python module expected by these tests is not available as `bufr` in the active Python environment.

## Observed error

The tests fail with:

```text
ModuleNotFoundError: No module named 'bufr'
```

## Confirmed environment details

The validated JACI stack loads:

```text
gcc/12.3.0/bufr/12.1.0
cray-mpich/8.1.31/gcc/12.3.0/bufr-query/0.0.5
cray-mpich/8.1.31/none/none/py-eccodes/1.5.0
```

The `bufr` package provides a Python module named:

```text
ncepbufr
```

not:

```text
bufr
```

The diagnostic check showed:

```text
bufr: None
_bufr: None
ncepbufr: ModuleSpec(...)
NCEPLIBSbufr: None
```

Therefore, the installed NCEPLIBS-bufr Python interface is not the Python API expected by these IODA tests.

## IODA test behavior

The failing IODA scripts import:

```python
import bufr
from pyioda.ioda.Engines.Bufr import Encoder
```

and use objects such as:

```python
bufr.Parser(...)
bufr.mpi.Comm(...)
```

This indicates that the tests expect a Python package exposing the `bufr` namespace with parser and MPI helper APIs.

## Evidence from spack-stack release/2.1

The issue is already recognized in the `spack-stack` recipe for `ioda`.

In:

```text
repos/spack_stack/spack_repo/spack_stack/packages/ioda/package.py
```

from `spack-stack release/2.1`, the IODA package declares:

```python
depends_on("bufr")
depends_on("bufr@12.0.1:", when="@2.9:")
depends_on("bufr-query@0.0.4:", when="@2.9:")
```

but the package `check()` method explicitly skips:

```python
skipped_tests = [
    "test_ioda_bufr_python_encoder",
    "test_ioda_bufr_python_parallel",
]
```

with the comment:

```python
# No time to deal with the bufr Python dependency
```

Therefore, this is not currently treated as a JACI-specific compiler, MPI or PBS failure. It is a known upstream stack/test dependency issue in the IODA BUFR Python tests.

## Recommended validation behavior

For complete JEDI CTest validation on JACI using the current stack, exclude these two known tests:

```yaml
ctest:
  exclude_regex: "^(ioda_bufr_python_encoder|ioda_bufr_python_parallel)$"
```

When combining with the known MPAS-JEDI numerical reference issue, use:

```yaml
ctest:
  exclude_regex: "^(ioda_bufr_python_encoder|ioda_bufr_python_parallel|mpasjedi_lgetkf_height_vloc)$"
```

Then run:

```bash
bash scripts/monan-jedi.sh test-pbs --config config/jaci.yaml
```

Expected result for the current validation set:

```text
100% tests passed, 0 tests failed out of 2291
```

## Future work

A future investigation may determine whether `bufr-query` should provide the missing `bufr` Python module, whether a CMake/install option is disabled, or whether an additional Python package is required.

Until then, these tests should be treated as known issues inherited from the current `spack-stack release/2.1` IODA package behavior.
