# MONAN-JEDI runtime install contract v1

`MONAN-JEDI` is the producer of the compiled/runtime software consumed by
`mpaswf`, `MPAS-BMatrix`, and other workflow components.

## One public root

The only MONAN-JEDI filesystem root a downstream workflow should need is:

```bash
export MONAN_JEDI_INSTALL_ROOT=/p/projetos/monan_das/$USER/build/monan-jedi
```

The default is derived from:

```text
${project.root}/build/${build.id}
```

Source trees and work/build trees are private implementation details and are not
part of this contract. Producer-specific executable alias settings may add
secondary entry points, but they do not replace the canonical `bin/` names in
this tree.

The cross-repository configuration semantics for this root and `STACK_ROOT` are
defined in [the ecosystem configuration contract](ecosystem-configuration-contract.md).
`PROJECT_ROOT` and the producer build/work roots are explicitly not part of that
shared interface.

## Public layout

```text
${MONAN_JEDI_INSTALL_ROOT}/
├── bin/
│   ├── mpas_init_atmosphere
│   ├── mpas_atmosphere
│   ├── mpasjedi_error_covariance_toolbox.x
│   ├── mpasjedi_variational.x
│   ├── mpasjedi_process_perts.x
│   ├── mpasjedi_unbalance_ensemble.x
│   ├── ungrib.exe
│   ├── link_grib.csh
│   └── obs2ioda_v3                 # when enabled
├── lib/
├── include/
├── share/
│   ├── MPAS/
│   │   └── core_atmosphere/
│   ├── wps/
│   │   ├── Vtable
│   │   └── Variable_Tables/
│   │       └── Vtable.GFS
│   └── monan-jedi/
│       ├── install-manifest.json
│       ├── mpas-jedi/
│       │   ├── namelists/
│       │   │   ├── geovars.yaml
│       │   │   ├── keptvars.yaml
│       │   │   └── stream_list.atmosphere.{background,analysis,control,ensemble}
│       │   └── testinput/
│       │       └── obsop_name_map.yaml
│       └── ufo/
│           └── testinput_tier_1/
│               ├── sondes_obs_2018041500_m.nc4
│               ├── gnssro_obs_2018041500_s.nc4
│               └── sfc_obs_2018041500_m.nc4
└── libexec/
    └── monan-jedi/
        └── wps/
            └── WPS-<version>/       # private/versioned implementation detail
```

Not every executable is required by every consumer, but consumers should derive
all runtime paths from the same root.

## Consumer rules

Downstream repositories must not depend on paths such as:

```text
${project.root}/work/...
<MONAN-JEDI checkout>/mpas-jedi/...
<MONAN-JEDI checkout>/wps/...
${MONAN_JEDI_INSTALL_ROOT}/libexec/monan-jedi/wps/WPS-<version>/...
```

The stable public paths are instead:

```text
bin/<executable>
share/MPAS/core_atmosphere
share/wps/...
share/monan-jedi/...
```

This makes installations shareable, easier to relocate, and independent of the
producer's source/build workspace.

## WPS

WPS is versioned internally, but consumers do not select a WPS release directory.
MONAN-JEDI publishes stable entry points after validating a staged release:

```text
bin/ungrib.exe
bin/link_grib.csh
share/wps/Vtable
share/wps/Variable_Tables
```

`mpaswf` should use those paths directly.

The WPS publication step must not preserve private checkout ownership or
restrictive source permissions. Runtime files are published with project-group
access so other members of the shared MONAN-DAS project can consume the same
installation.

## MPAS-JEDI and baseline workflow runtime support

Files consumed by downstream workflows are runtime inputs even when their
upstream source happens to live below a component's test tree. During
installation MONAN-JEDI therefore publishes the stable copies required by the
maintained MPAS-JEDI baseline:

```text
share/monan-jedi/mpas-jedi/namelists/
share/monan-jedi/mpas-jedi/testinput/obsop_name_map.yaml
share/monan-jedi/ufo/testinput_tier_1/
```

The namelist directory includes `geovars.yaml`, `keptvars.yaml` and the
background/analysis/control/ensemble stream lists. The UFO directory publishes
the three 2018-04-15 observation files required by the maintained static
baseline.

Consumers must use these installed copies and must not require a
`MONAN_JEDI_SOURCE` variable or a MONAN-JEDI checkout path.

## Separation from spack-stack

`MONAN_JEDI_INSTALL_ROOT` does not replace `STACK_ROOT`. The validated
spack-stack remains the compiler/MPI/dependency environment. The two contracts
are deliberately separate:

```text
STACK_ROOT               -> external software/dependency environment
MONAN_JEDI_INSTALL_ROOT  -> MONAN/MPAS/JEDI runtime products
```

An installed executable is therefore considered runtime-valid only after its
shared libraries resolve in the configured spack-stack environment. Running
`ldd` from an arbitrary login shell is not sufficient evidence of a broken
installation because that shell may not contain the required MPI/dependency
modules.

## Machine-checkable validation

The runtime contract is validated with:

```bash
bash scripts/monan-jedi.sh test-install --config config/jaci.yaml
```

The command loads and validates the configured stack before checking the
installation. It verifies the required public layout, core executables, MPAS
runtime data, MPAS-JEDI namelists, install manifest, enabled WPS/obs2ioda
products, shared-library resolution and project-group access.

The result is recorded in:

```text
${project.root}/logs/${build.id}/10_install_test.log
```

A successful result ends with:

```text
RESULT=PASS
```

`all` runs this validation automatically before producing `99_summary.log`. If
the runtime validation fails, `all` still writes the final log summary and then
returns a non-zero status.

## Regression policy

A path is part of the public runtime API when a downstream workflow consumes it.
Changes to public paths must therefore be coordinated across consumers and
covered by tests. New consumers should prefer one installation root over lists
of independently configured executable paths.
