# MPAS-JEDI unbalance ensemble executable

## Purpose

`mpasjedi_unbalance_ensemble.x` generates the unbalanced ensemble samples used
after vertical-balance (VBAL) processing. Its expected member output follows
this pattern:

```text
samplesUnbalanced/PTB_f48mf24_%{member}%.nc
```

The generic application is `saber::UnbalanceEnsemble<MODEL>`. It reads the
input ensemble and calls `leftInverseMultiply` on the configured SABER outer
block chain for each member. For a VBAL block, this follows the inverse/left
path rather than the forward `applyOuterBlocks` path used by ProcessPerts. The
MPAS specialization is exposed as the executable
`mpasjedi_unbalance_ensemble.x`.

MPAS-BMatrix consumes this executable and its generated output. It does not
contain or own the executable's source code; the implementation is maintained
by MONAN-JEDI as patches against the pinned upstream components.

## Versioned files

- `patches/unbalance/saber-unbalance-ensemble.patch` adds the generic SABER
  application and registers its header.
- `patches/unbalance/mpas-jedi-unbalance-ensemble.patch` adds the MPAS main and
  executable target.
- `configs/examples/mpasjedi_unbalance_ensemble_example.yaml` is an example
  runtime configuration.
- `scripts/apply_unbalance_ensemble_patches.sh` validates and applies both
  patches.

The patches target the exact upstream revisions pinned in the MONAN-JEDI bundle:

```text
saber:     d05c06fcc7da97389a19594a2e5424e709648330
mpas-jedi: 19eb7fb3273c7b3094825201af184834c15afdd0
```

## Build integration

The normal MONAN-JEDI configure workflow now applies the required patches automatically.
Users do not need to run the patch helper manually before a standard build.

On a clean checkout, `ecbuild_bundle` first has to materialize the pinned
`saber/` and `mpas-jedi/` source trees. `scripts/lib/configure.sh` therefore uses
this sequence:

1. run one ecbuild materialization/configure pass only when those component
   worktrees are not present;
2. run `scripts/apply_unbalance_ensemble_patches.sh` against the pinned source
   revisions;
3. run the final ecbuild configure pass with the patched CMake files;
4. verify that CMake registered the target `mpasjedi_unbalance_ensemble.x`.

When the component worktrees already exist, the materialization pass is skipped.
The patch helper is idempotent, so an already patched source tree is accepted.
A wrong component revision or a partially applied patch is treated as a hard
configuration error.

Both `mpasjedi_process_perts.x` and `mpasjedi_unbalance_ensemble.x` are created
with the same MPAS-JEDI `ecbuild_add_executable` mechanism. MONAN-JEDI configures:

```text
CMAKE_INSTALL_BINDIR=bin
CMAKE_RUNTIME_OUTPUT_DIRECTORY=${install.bin_dir}
```

and the documented default for `install.bin_dir` is `${install.root}/bin`.
Therefore the unbalance executable uses the same user-facing executable directory
as the other MPAS-JEDI programs:

```text
${install.root}/bin/mpasjedi_process_perts.x
${install.root}/bin/mpasjedi_unbalance_ensemble.x
```

The build and install steps validate both paths and fail if the unbalance
executable was not produced. A successful bundle build can no longer silently
complete without this required executable.

## Manual patch helper

The helper remains available for diagnostics or development:

```bash
cd /path/to/MONAN-JEDI
scripts/apply_unbalance_ensemble_patches.sh
```

Both component worktrees must already exist at the pinned revisions. Normal
users should prefer `bash scripts/monan-jedi.sh configure` or
`bash scripts/monan-jedi.sh all`, which perform the integration automatically.

## PR #15 functional validation

The PR #15 validation built the `mpasjedi_unbalance_ensemble.x` target and ran
the executable through PBS with 128 MPI processes. The job completed with
`Exit_status = 0` and generated:

```text
PTB_f48mf24_001.nc
PTB_f48mf24_002.nc
PTB_f48mf24_003.nc
PTB_f48mf24_004.nc
```

The generated files were valid MPAS NetCDF files. The validated example uses
`read global sampling: false`, matching the local sampling and vertical-balance
statistics available to the functional run.
