# MONAN-JEDI ecosystem runtime standard

This document is the normative configuration contract for the MONAN-JEDI
ecosystem. It applies to MONAN-JEDI, mpaswf, monan-jedi-workflow and
MPAS-BMatrix.

The purpose of the standard is to keep the ecosystem predictable as it grows:
software ownership, site/runtime ownership, scientific case data and scheduler
policy must not be mixed.

## 1. The only cross-repository environment anchors

Normal users and downstream applications share exactly two environment
variables:

\`\`\`bash
export MONAN_JEDI_INSTALL_ROOT=/path/to/monan-jedi-install
export STACK_ROOT=/path/to/validated/spack-stack
\`\`\`

Their meanings are fixed.

| Anchor | Meaning | Must never mean |
| --- | --- | --- |
| \`MONAN_JEDI_INSTALL_ROOT\` | Public installed MONAN/MPAS/JEDI runtime prefix | source checkout, CMake/ecbuild tree, experiment data |
| \`STACK_ROOT\` | Actual spack-stack checkout selected for compiler/MPI/dependencies | MONAN-JEDI work tree, case root |

No additional global environment variable is required by the ecosystem
contract. Site/module details are carried by the installed runtime manifest,
while application-specific data remain in YAML.

MONAN-JEDI keeps producer-only variables such as \`PROJECT_ROOT\`,
\`MONAN_JEDI_SOURCE_DIR\`, \`MONAN_JEDI_WORK_ROOT\`,
\`MONAN_JEDI_BUILD_DIR\`, \`MONAN_JEDI_LOG_ROOT\` and
\`MONAN_JEDI_BUILD_ID\`. Downstream repositories must not depend on them.

## 2. Authoritative installed contract

Every supported MONAN-JEDI installation publishes:

\`\`\`text
\${MONAN_JEDI_INSTALL_ROOT}/share/monan-jedi/install-manifest.json
\`\`\`

The manifest currently retains `schema_version: 1` as a producer-side compatibility envelope, while `ecosystem_contract_version: 2` is the normative cross-repository API. Consumers must select the ecosystem contract version and read its `layout`, `stack`, `capabilities` and `public_anchors` fields instead of duplicating stack settings.

The v2 document contains:

- stable relative install layout;
- canonical executable names;
- required runtime-support files;
- stack compatibility metadata;
- enabled capabilities;
- producer provenance.

The manifest is relocatable: it intentionally does not record the absolute
installation root or the absolute \`STACK_ROOT\`.

The operator chooses \`STACK_ROOT\`; the manifest describes which environment
inside that stack is compatible with the installation.

## 3. Ownership boundaries

### MONAN-JEDI owns software

The install prefix may contain:

\`\`\`text
bin/
lib/
include/
share/MPAS/core_atmosphere/
share/wps/
share/monan-jedi/mpas-jedi/namelists/
share/monan-jedi/mpas-jedi/testinput/obsop_name_map.yaml
\`\`\`

Runtime-support YAML/stream files that are version-coupled to MPAS-JEDI may be
published with the installation.

### Experiment repositories own scientific data

Case-specific fields are not software. Examples include backgrounds,
analysis/reference states, mesh/case inputs, date-specific IODA/UFO
observations, NMC ensembles and B-matrix products.

In particular, observations such as \`sondes_obs_2018041500_m.nc4\` belong to a
case/reference-data root, not to the MONAN-JEDI installation.

### Site/profile configuration owns machine policy

The site layer owns \`STACK_ROOT\` selection, PBS queues/resources, MPI launcher
policy, site filesystem roots and job-local runtime settings.

Variables such as \`OMP_NUM_THREADS\`, \`FI_CXI_RX_MATCH_MODE\`,
\`F_UFMTENDIAN\` and \`GFORTRAN_CONVERT_UNIT\` are not global ecosystem
anchors. A site may provide defaults, and a validated historical case may
override them explicitly with documentation.

## 4. Standard stack bootstrap

Every compute-node job that uses the MONAN-JEDI runtime must reconstruct the
selected stack explicitly. It must not rely on the login shell or \`qsub -V\`.

The canonical sequence is:

\`\`\`text
set -euo pipefail
export MONAN_JEDI_INSTALL_ROOT=...
export STACK_ROOT=...

validate install manifest
read stack.env_name / stack.env_module / stack.site_setup
derive module root from STACK_ROOT + env_name

purge modules
remember whether nounset was active
temporarily disable nounset
cd STACK_ROOT
source stack.site_setup
restore nounset state
module use derived module root
module load stack.env_module

validate required executable
export job-local runtime variables
cd run directory
mpiexec ...
\`\`\`

The temporary \`set +u\` around the spack-stack site setup is mandatory because
site setup scripts are not required to be nounset-safe. The caller's nounset
state must be restored immediately afterwards.

A same-named module from another stack is not sufficient proof of provenance.
Interactive loaders that reuse an already-loaded module must validate stack
root, module root and module name together.

## 5. Configuration precedence

### MONAN-JEDI producer

For backward compatibility:

\`\`\`text
non-empty environment override
        ↓
site YAML
        ↓
derived/default value
\`\`\`

### Consumers

Consumers use explicit, reproducible configuration:

\`\`\`text
explicit CLI override
        ↓
case/platform YAML
        ↓
included/base YAML
        ↓
environment anchors explicitly referenced by YAML
        ↓
values derived from install-manifest.json
        ↓
internal defaults
\`\`\`

Consumers must not read \`MONAN_JEDI_INSTALL_ROOT\` a second time after a
resolved configuration object already owns that value.

An unresolved \`\${VARIABLE}\` in a configuration-time field is an error.
Shell expressions intentionally deferred to PBS must remain literal.

## 6. Canonical executable derivation

Consumers derive executables below \`MONAN_JEDI_INSTALL_ROOT/bin\`, for example
\`mpas_atmosphere\`, \`mpas_init_atmosphere\`,
\`mpasjedi_variational.x\`, \`mpasjedi_error_covariance_toolbox.x\`,
\`ungrib.exe\`, \`link_grib.csh\` and \`obs2ioda_v3\`.

A downstream application must never search the MONAN-JEDI build tree for these
programs.

## 7. User workflow

MONAN-JEDI can print the two official shell anchors resolved from a site
configuration:

\`\`\`bash
bash scripts/monan-jedi.sh env --config config/jaci.yaml
\`\`\`

Use the output with \`eval\` when desired:

\`\`\`bash
eval "$(bash scripts/monan-jedi.sh env --config config/jaci.yaml)"
\`\`\`

This is a convenience hand-off; it does not add new public variables.

## 8. Backward compatibility

Legacy aliases may remain temporarily, but every compatibility path must prefer
the new setting, use the legacy setting only when the new one is absent, emit a
deprecation warning and never reinterpret the old name with a new meaning.

## 9. Mandatory regression rules

Maintained code and CI must enforce all of the following:

1. downstream consumers use one \`MONAN_JEDI_INSTALL_ROOT\`;
2. downstream consumers use the operator-selected \`STACK_ROOT\`;
3. stack module/site details come from the v2 installed manifest rather than
   copied independently into every repository;
4. consumers do not depend on MONAN-JEDI source/build roots;
5. scientific observations are not exposed or consumed as generic v2 runtime software;
6. PBS jobs reconstruct their compute-node environment explicitly;
7. spack-stack setup is protected from Bash \`nounset\`;
8. unresolved configuration-time environment references fail early;
9. PBS-only shell variables are not accidentally expanded at configuration time;
10. maintained cases have no personal user path unless the file is explicitly
    marked as immutable historical provenance.

The public filesystem layout is described in
[Runtime install contract](runtime-install-contract.md).
