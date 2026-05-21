# JACI MPAS-JEDI build steps

This document summarizes the current MONAN-JEDI build flow on JACI.

## Current model

The MONAN-JEDI repository root is the bundle source tree.

The top-level file below controls the bundle contents:

```text
CMakeLists.txt
```

The workflow no longer clones `JCSDA/jedi-bundle` and no longer applies a CMakeLists template during the build.

## Recommended scripted workflow

From the MONAN-JEDI repository root:

```bash
bash scripts/monan-jedi.sh load --config config/jaci.yaml
bash scripts/monan-jedi.sh configure --config config/jaci.yaml
bash scripts/monan-jedi.sh build --config config/jaci.yaml
bash scripts/monan-jedi.sh test --config config/jaci.yaml
bash scripts/monan-jedi.sh logs --config config/jaci.yaml
```

Or run the main sequence:

```bash
bash scripts/monan-jedi.sh all --config config/jaci.yaml
```

## Manual minimal workflow

The manual workflow is documented in the top-level `README.md`.

In summary, the manual steps are:

```text
1. Clean the module environment
2. Source the JACI site setup from the validated spack-stack tree
3. Add the generated stack module path
4. Load the generated jedi-mpas-env module
5. Export CrayPE compiler and MPI wrappers
6. Run ecbuild from a separate build directory, pointing to the MONAN-JEDI repository root
7. Run make
```

## Historical note

Older versions of this repository used numbered scripts and a `reduce` step:

```text
scripts/01_load_stack_env.sh
scripts/02_prepare_jedi_bundle.sh
scripts/03_create_mpas_only_bundle.sh
scripts/04_configure_mpas_jedi.sh
scripts/05_build_mpas_jedi.sh
scripts/06_test_mpas_jedi.sh
scripts/07_collect_logs.sh
```

That model has been replaced. The old `prepare` and `reduce` concepts are no longer part of the main workflow.

## Related documentation

```text
docs/BUNDLE_ORIGIN.md
docs/YAML_CONFIGURATION.md
```
