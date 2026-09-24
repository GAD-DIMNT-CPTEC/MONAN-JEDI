# MONAN-JEDI ecosystem configuration contract

This document defines the small cross-repository configuration interface shared
by MONAN-JEDI runtime consumers. It complements the producer-side configuration
reference; it does not make every MONAN-JEDI build variable a public ecosystem
API.

## Public anchors

The ecosystem has two cross-repository anchors:

```bash
export MONAN_JEDI_INSTALL_ROOT=/path/to/monan-jedi-install
export STACK_ROOT=/path/to/spack-stack
```

They have deliberately different responsibilities.

| Variable | Meaning | Owner | Consumers |
| --- | --- | --- | --- |
| `MONAN_JEDI_INSTALL_ROOT` | Public installed MONAN/MPAS/JEDI runtime prefix | MONAN-JEDI | mpaswf, MPAS-BMatrix, monan-jedi-workflow |
| `STACK_ROOT` | Actual spack-stack checkout/environment root used to provide compiler, MPI and external libraries | site/operator | MONAN-JEDI and HPC consumers |

`MONAN_JEDI_INSTALL_ROOT` must name the installed product tree containing
stable `bin/`, `lib/`, `include/` and `share/` interfaces. It must never
mean the MONAN-JEDI source checkout, ecbuild/CMake build directory or private
work tree.

`STACK_ROOT` must name the actual spack-stack checkout used by the runtime.
Consumers must not silently replace it with a user-specific hard-coded path.

## Private producer roots

The following MONAN-JEDI concepts are producer implementation details and are
not cross-repository configuration interfaces:

```text
PROJECT_ROOT
MONAN_JEDI_SOURCE_DIR
MONAN_JEDI_WORK_ROOT
MONAN_JEDI_BUILD_DIR
MONAN_JEDI_LOG_ROOT
MONAN_JEDI_BUILD_ID
```

A downstream workflow may have its own repository root, work root, case root or
run directory, but it must not infer MONAN-JEDI source/build paths from them.

In particular, `PROJECT_ROOT` is not an ecosystem-wide variable. MONAN-JEDI
keeps that name for backward compatibility with its own build workflow only.
Documentation in downstream repositories should use local names such as
`REPOS_ROOT` when it merely needs a parent directory for source checkouts.

## Consumer resolution rule

A maintained consumer configuration should bind the public anchors explicitly,
for example:

```yaml
software:
  monan_jedi_install_root: ${MONAN_JEDI_INSTALL_ROOT}

stack:
  root: ${STACK_ROOT}
```

The exact YAML section names may remain application-specific, but their
semantics must not change.

After configuration has been resolved, application code should use the resolved
configuration object rather than read the same environment variable again.
This prevents two simultaneous sources of truth.

## Configuration precedence

Consumer applications should prefer explicit, inspectable configuration. The
recommended precedence is:

```text
explicit CLI option
    ↓
case/platform YAML
    ↓
included/base YAML
    ↓
environment references explicitly present in YAML
    ↓
derived values
    ↓
internal defaults
```

MONAN-JEDI retains its historical producer-side `non-empty environment > YAML >
default` precedence for compatibility. Consumers do not need to reproduce that
behavior.

An unresolved `${VARIABLE}` reference in maintained configuration must fail
during preflight/config loading rather than survive as a literal path.

## Installed-runtime derivation

Consumers should derive runtime products from
`MONAN_JEDI_INSTALL_ROOT`, including paths such as:

```text
bin/mpas_atmosphere
bin/mpas_init_atmosphere
bin/mpasjedi_variational.x
bin/mpasjedi_error_covariance_toolbox.x
bin/ungrib.exe
bin/link_grib.csh
bin/obs2ioda_v3
share/MPAS/core_atmosphere
share/wps
share/monan-jedi/mpas-jedi/namelists
```

A consumer must not require the producer checkout or build tree when an
equivalent installed resource exists.

## HPC/PBS rule

A scientific PBS job must reproduce the runtime environment explicitly on the
compute node. It must not rely on modules that happened to be loaded in the
submitting login shell.

The rendered job should carry enough information to establish the selected
stack and runtime, conceptually:

```text
PBS directives
set -euo pipefail

export STACK_ROOT=...
export MONAN_JEDI_INSTALL_ROOT=...

load/validate configured stack
validate required executable
export job-specific runtime variables
cd run_directory
mpiexec ...
```

Stack reuse must validate the identity of the stack root, module tree and
environment module together. A matching module name alone is not sufficient
when two different stacks publish the same module name.

## What is not a global ecosystem API

The following are examples of application-local or job-local settings and
should not become shared integration variables merely because tutorials use
them:

```text
WORK_ROOT
BMATRIX_ROOT
MPASWF_ROOT
MPASWF_WORK
MPASWF_CONFIG
MANIFEST
BFLOW
PATH
LD_LIBRARY_PATH
PYTHONPATH
OMP_NUM_THREADS
FI_CXI_RX_MATCH_MODE
F_UFMTENDIAN
GFORTRAN_CONVERT_UNIT
```

Applications may still use these locally where appropriate.

## Backward compatibility

When a consumer renames an existing public setting, migration should follow:

```text
new setting
    ↓ when absent
legacy setting
    ↓
deprecation warning
```

Do not reinterpret an existing name with a different semantic meaning.

## Required regression checks

Cross-repository work should preserve these invariants:

1. every maintained consumer can resolve the same
   `MONAN_JEDI_INSTALL_ROOT`;
2. every JACI PBS renderer uses the selected `STACK_ROOT` rather than a
   user-specific hard-coded stack path;
3. maintained consumers do not introduce dependencies on MONAN-JEDI source or
   build roots;
4. unresolved environment references fail during configuration/preflight;
5. changing to another stack with the same module name does not silently reuse
   the old stack identity.

The producer-side public filesystem contract remains defined in
[Runtime install contract](runtime-install-contract.md).
