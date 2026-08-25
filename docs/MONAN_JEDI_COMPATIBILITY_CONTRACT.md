# MONAN--JEDI compatibility contract

## 1. Purpose

This document defines the interfaces between MONAN/MPAS and MONAN-JEDI that
must remain explicit, traceable and tested as both systems evolve.

MONAN may change the scientific formulation, implementation, parallelism and
internal organization inherited from MPAS. This contract does not freeze that
evolution. It prevents an interface used by data assimilation from changing
silently.

A successful standalone MONAN forecast is necessary, but it is not sufficient
evidence of MONAN-JEDI compatibility. Compatibility also requires that JEDI can
construct the model geometry, read and write complete model states, propagate a
physically and logically consistent trajectory, evaluate observations and
restart MONAN from the analysis.

## 2. Scope and normative language

The contract applies to changes in MONAN/MPAS, MPAS-JEDI, the MONAN-JEDI bundle
and the model-state files exchanged between forecast and assimilation
workflows.

The words **MUST**, **MUST NOT**, **SHOULD** and **MAY** are normative:

- **MUST** and **MUST NOT** identify compatibility requirements;
- **SHOULD** identifies a strong recommendation that requires justification if
  it is not followed;
- **MAY** identifies an optional or normally compatible action.

The source code and automated tests remain authoritative for the complete set
of fields and symbols consumed by a particular revision. Lists in this document
make the protected interface visible; they are not a substitute for dependency
and integration testing.

## 3. Audited baseline

The initial contract is based on the bundle pinned by this repository:

| Component | Audited revision |
|---|---|
| MPAS-Model | `0e5a47a0e1bcccd6e3d99909b76e740a643c4db6` |
| MPAS-JEDI | `19eb7fb3273c7b3094825201af184834c15afdd0` |

The MPAS-JEDI nonlinear model interface was also reviewed against upstream
`develop` on 2026-08-24. In the audited implementation, one OOPS
`Model::step()` call performs one MPAS physical timestep. The OOPS
`model.tstep` advances logical time, while MPAS `config_dt` controls the physical integration
performed by that call.

Therefore, for this implementation:

```text
seconds(OOPS model.tstep) == MPAS config_dt
```

This equality MUST be validated before execution. If MPAS-JEDI is changed to
perform more than one MPAS timestep or explicit substeps within one
`Model::step()`, the new mapping MUST be documented and tested before that
revision can replace this contract.

The failure can otherwise be silent. For a six-hour window with
`model.tstep = PT45M`, OOPS makes eight logical advances. With
`config_dt = 1800`, MPAS integrates only four physical hours; with
`config_dt = 1200`, it integrates only two hours and forty minutes. OOPS may
still finish successfully even though the physical and logical FGAT
trajectories do not represent the same times.

## 4. Protected interfaces

| Interface | Examples | Compatibility requirement |
|---|---|---|
| Model state | names, units, dimensions, types, staggering and physical meaning | Existing fields consumed by MPAS-JEDI MUST NOT change silently. |
| Registry and pools | `Registry.xml`, configuration entries, `state`, `diag`, `mesh`, subpools | A consumed name, location or retrieval path MUST be preserved or changed together with the adapter. |
| Model time | `config_dt`, `atm_do_timestep`, time-level shifts and clock advancement | The mapping between an OOPS step and physical MONAN integration MUST be explicit and tested. |
| Clock and validity | start/stop time, `MPAS_NOW`, `xtime`, alarms, restart time | Logical time, physical time and file validity MUST remain consistent. |
| Initialization and cycling | model initialization, `config_do_DAcycling`, restart/analysis initialization | Equivalent DA behavior MUST exist before an old mechanism is removed or renamed. |
| Geometry | dimensions, connectivity, coordinates, vertical levels and decomposition | Geometry changes MUST trigger adapter, operator and covariance impact analysis. |
| Wind representation | edge-normal wind, edge orientation, normal vectors and reconstructed components | Sign, staggering and reconstruction conventions MUST remain traceable and tested. |
| Diagnostics | pressure, temperature, density, wind reconstruction and surface fields | Diagnostics consumed by JEDI MUST remain available with documented semantics. |
| State files | NetCDF dimensions, variables, attributes, shapes, precision and `xtime` | JEDI MUST read and write a complete restartable MONAN state. |
| Covariance compatibility | mesh, resolution, vertical coordinate and control-variable definitions | A B matrix MUST NOT be reused after a potentially invalidating change without scientific validation. |

## 5. Model-state contract

For each field consumed by MONAN-JEDI, its name alone is not the interface. The
contract comprises:

```text
name + physical meaning + units + dimensions + staggering + type + validity
```

Examples of fields currently consumed, produced or explicitly checked by the
MPAS-JEDI workflow include:

```text
theta
rho
u
qv
pressure_p
surface_pressure
qc
qg
qi
qr
qs
uReconstructZonal
uReconstructMeridional
```

Before changing an existing field, the MONAN change MUST identify whether
MPAS-JEDI reads it from `state`, `diag`, `mesh` or a model-state file. A change
to units, dimensions, vertical placement, cell/edge placement, sign convention,
missing-value convention, precision or scientific definition requires a
coordinated adapter update and integration validation.

Adding a new field is normally compatible. Removing or renaming a consumed
field, or retaining its name while changing its meaning, is a breaking change.

MONAN-JEDI MUST preserve a complete model state when producing an analysis.
Tests MUST validate required content and restartability, not a fixed total
variable count. Different valid states may contain different numbers of
diagnostic or optional variables.

## 6. Registry, pools and callable model routines

Names retrieved through MPAS pool APIs are part of the adapter interface. This
includes configuration entries and content under structures such as `state`,
`diag` and `mesh`.

The following categories MUST receive a MONAN-JEDI impact review when their
names, signatures, ownership or side effects change:

- Registry configuration entries used during JEDI initialization and cycling;
- pools and subpools traversed by MPAS-JEDI;
- model initialization routines;
- the routine that performs a physical timestep;
- clock advancement and time-level shifting;
- output-diagnostic computation.

Representative routines in the audited baseline include
`atm_mpas_init_block`, `atm_do_timestep` and
`atm_compute_output_diagnostics`. This list is illustrative; the pinned adapter
source determines the exact dependency set.

An internal refactor MAY reorganize implementation details, but it MUST preserve
the consumed interface or provide the corresponding MPAS-JEDI change in the
same coordinated integration.

## 7. Time, clock and FGAT trajectory contract

Time is part of the scientific state of a data-assimilation experiment. It MUST
not be treated as decorative metadata.

For every supported nonlinear trajectory, validation MUST establish:

- the OOPS window begin, analysis time and window end;
- the OOPS `model.tstep`;
- the physical integration represented by each model step;
- the MPAS start, current and stop times;
- consistent `xtime` and restart validity;
- equal total logical and physical integration durations.

For the audited adapter, the required mapping is:

```text
one OOPS Model::step()
    = one atm_do_timestep(...)
    = config_dt seconds of physical integration
    = model.tstep seconds of logical advancement
```

Any change to `config_dt`, adaptive or nested stepping, subcycling,
`atm_do_timestep`, clock advancement, alarms or time-level management MUST be
reviewed jointly with the data-assimilation team.

A normal process exit or `OOPS Ending` marker does not by itself prove temporal
consistency.

## 8. Geometry and wind contract

Changes to horizontal or vertical geometry can affect the MPAS-JEDI Geometry,
observation operators and the statistical covariance model. The following are
protected examples:

```text
nCells
nEdges
nVertLevels
nVertLevelsP1
cellsOnEdge
edgesOnCell
latCell
lonCell
edgeNormalVectors
```

A change to connectivity, ordering, decomposition, vertical coordinates,
staggering or coordinate conventions MUST be evaluated beyond the standalone
forecast.

Wind requires special attention because MPAS stores edge-normal wind while
JEDI also uses zonal and meridional representations. Changes to edge
orientation, normal vectors, reconstruction, sign conventions or staggering
MUST include tests that would detect a physically plausible but incorrectly
interpreted wind field.

## 9. Diagnostics, files and restartability

Diagnostics used by JEDI MUST remain computable at the points required by the
adapter and MUST retain documented units, dimensions and semantics.

Model-state NetCDF files exchanged by the workflows MUST preserve:

- required dimensions and connectivity;
- required state, diagnostic and metadata variables;
- variable types, shapes and precision required by the adapter;
- a valid and consistent `xtime`;
- sufficient content to initialize a MONAN forecast from the analysis.

The end-to-end compatibility criterion is not merely that JEDI can write a
NetCDF file. MONAN MUST be able to initialize and advance from that analysis.

## 10. B-matrix and scientific configuration

A static B matrix is tied to a model configuration. At minimum, changes to any
of the following require an explicit covariance compatibility assessment:

- horizontal mesh or resolution;
- vertical coordinate or number of levels;
- control-variable definitions;
- thermodynamic definitions such as `theta` or `rho`;
- wind representation;
- moisture variables and their transforms;
- model climatology or forecast statistics used to estimate B.

The ability to read an old B matrix is not evidence that it remains
scientifically valid. A potentially invalidating model change MUST result in
either a documented validation of the existing B matrix or generation and
validation of a new one.

## 11. Change classification

### 11.1 Normally compatible

The following changes MAY proceed with normal MONAN testing when the protected
interface remains unchanged:

- loop and memory optimizations;
- parallel and communication optimizations;
- internal refactoring with stable adapter-facing interfaces;
- new optional diagnostics or variables;
- scientific algorithm changes that intentionally alter results but preserve
  interface semantics.

Scientific changes can legitimately change forecasts and analyses. They still
require scientific evaluation, but are not automatically interface-breaking.

### 11.2 Coordination required

The following changes require review with the data-assimilation team before
integration:

- a protected configuration entry, pool, routine or file layout is changed;
- state or diagnostic units, dimensions, staggering or semantics change;
- time integration, clocks, cycling or restart behavior changes;
- geometry, vertical coordinates or wind conventions change;
- a change may invalidate observation operators or a B matrix.

### 11.3 Breaking until revalidated

A change is considered incompatible until the adapter and tests are updated if
it:

- removes or renames an interface consumed by MPAS-JEDI;
- changes a field's meaning while retaining its existing name;
- permits logical and physical trajectories to diverge;
- produces an analysis that is not a complete restartable MONAN state;
- changes geometry or control variables while silently reusing incompatible
  covariance artifacts.

## 12. Required change process

For a MONAN pull request that touches a protected interface:

1. Identify the affected MONAN-JEDI interface in the pull-request description.
2. Notify the data-assimilation maintainers before merge.
3. Pin or otherwise identify the exact MONAN and MPAS-JEDI revisions tested.
4. Update the adapter, configuration and documentation as one coordinated
   change when required.
5. Run the minimum integration tests in Section 13.
6. Record results and any B-matrix or observation-operator impact.
7. Do not declare compatibility based only on a standalone forecast.

Temporary compatibility shims MAY be used for coordinated migrations. Their
deprecation period and removal criteria MUST be documented.

## 13. Minimum integration validation

The validation SHOULD be automated in CI or in a reproducible HPC test workflow
and MUST cover, at minimum:

1. load a complete MONAN/MPAS state;
2. construct the MPAS-JEDI Geometry;
3. execute at least one nonlinear `Model::step()`;
4. prove that logical advancement equals physical model integration;
5. run a small HofX or equivalent observation-operator test;
6. run a variational smoke test;
7. write the analysis as a complete model state;
8. confirm required variables, finite values and valid `xtime`;
9. initialize MONAN from the analysis and advance it successfully.

Changes affecting geometry, state semantics or covariance compatibility require
additional scientific validation appropriate to the affected interface.

## 14. Pull-request checklist

MONAN changes that may affect this contract SHOULD include the following in the
pull-request description:

```text
[ ] I checked whether this change affects a MONAN-JEDI protected interface.
[ ] I documented changes to state names, units, dimensions, staggering or meaning.
[ ] I documented changes to time integration, clocks, cycling or restart behavior.
[ ] I documented changes to geometry, wind representation or diagnostics.
[ ] I assessed observation-operator and B-matrix compatibility where applicable.
[ ] I ran or requested the MONAN-JEDI minimum integration validation.
[ ] I recorded the exact MONAN and MPAS-JEDI revisions used for validation.
```

## 15. Ownership and evolution of this contract

This is a shared interface contract. Changes to it SHOULD be reviewed by both
MONAN/Computational Science and Data Assimilation maintainers.

The contract MUST evolve when an interface is intentionally redesigned. Such a
revision must describe the new behavior, migration path and validation evidence;
it must not retroactively classify an untested interface change as compatible.
