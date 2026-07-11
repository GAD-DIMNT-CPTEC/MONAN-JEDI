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

## Application workflow

First materialize `saber/` and `mpas-jedi/` at the revisions above. Then, from
any directory inside the MONAN-JEDI Git worktree, run:

```bash
scripts/apply_unbalance_ensemble_patches.sh
```

Apply the patches before configuring or reconfiguring the build. Both patches
modify component `CMakeLists.txt` files, so CMake must be configured again after
patch application for the new executable target to become available. The
script is idempotent: it reports a patch as already applied when its reverse
check succeeds.

The script deliberately refuses to apply the patches to different component
commits. If the bundle revisions are updated, rebase and validate the patches
explicitly rather than bypassing the revision checks.
