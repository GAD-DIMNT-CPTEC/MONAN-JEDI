# MONAN-JEDI test troubleshooting

This guide is the first diagnostic checklist when a MONAN-JEDI validation step
fails. It describes the **current** workflow and intentionally does not restore
the historical PR #6 implementation: Git LFS preparation is already handled by
`scripts/lib/test_data.sh` and the current configure/PBS preflight.

For Git LFS internals, recovery commands and the JACI fallback, see
[jedi-test-data.md](jedi-test-data.md). For the public installed layout, see
[runtime-install-contract.md](runtime-install-contract.md).

## 1. Identify which validation layer failed

MONAN-JEDI has distinct validation layers. Do not treat them as interchangeable.

| Command | What it proves | Typical failure domain |
|---|---|---|
| `load` | configured spack-stack can be activated | stack/modules/toolchain |
| `configure` | bundle can be configured and required source/test data prepared | CMake, Git LFS, external data |
| `build` | configured sources compile | compiler/link/dependency |
| `test` | login-safe CTest subset passes | component/unit integration |
| `test-install` | published runtime satisfies the install contract | missing products, libraries, manifest |
| `test-pbs` | full CTest job can be prepared/submitted after preflight | data/PBS/site configuration |
| `test-pbs-result` | latest PBS CTest execution completed acceptably | compute-node tests/runtime |
| `test-wps` | published WPS/UNGRIB products are usable | WPS publication/runtime |

Start by rerunning the smallest failing layer instead of repeating `all`.

## 2. Confirm the selected configuration and stack

Validate the YAML before investigating build failures:

```bash
python3 scripts/lib/read_config.py --check config/jaci.yaml
python3 scripts/check_config_documentation.py
bash scripts/monan-jedi.sh load --config config/jaci.yaml
```

The `load` output must identify the configured stack root, module root,
environment module and active compiler/toolchain. A same-named module loaded
from another spack-stack is not considered equivalent.

Remember that non-empty environment variables override YAML. When testing a
configuration change, remove stale overrides first, especially temporary
`STACK_ROOT`, `STACK_MODULE_ROOT`, `STACK_ENV_NAME` and
`STACK_ENV_MODULE` values.

## 3. Configure failures

Run:

```bash
bash scripts/monan-jedi.sh configure --config config/jaci.yaml
```

Inspect the configure logs under the configured log root. Check, in this order:

1. the configured spack-stack was loaded successfully;
2. `ecbuild`, CMake, Git and Python resolve from the validated environment;
3. Git LFS is available;
4. external archives are present, downloadable or available through the
   configured local/cache paths;
5. the pinned JEDI bundle repositories were materialized;
6. the required MONAN-JEDI patches/targets were registered.

Do not work around a configure failure by manually copying files into the build
tree. Fix the configured source/cache/input path or the responsible preparation
step so the build remains reproducible.

## 4. NetCDF/HDF5 errors during CTest

Errors such as:

```text
NetCDF: Unknown file format
Not an HDF5 file
```

often indicate that a Git LFS pointer was passed to NetCDF/HDF5 instead of the
binary scientific file.

The current workflow validates all Git LFS tracked files in `ioda-data`,
`ufo-data` and `mpas-jedi-data`; `test-pbs` also validates the exact
build-tree `Data` links before allocating a compute node.

Use:

```bash
bash scripts/monan-jedi.sh load --config config/jaci.yaml
git -C ioda-data lfs status
git -C ufo-data lfs status
git -C mpas-jedi-data lfs status
```

Then follow [jedi-test-data.md](jedi-test-data.md). Do not increase PBS
walltime to hide missing or pointer-only test data.

## 5. Build failures

Run the build independently:

```bash
bash scripts/monan-jedi.sh build --config config/jaci.yaml
```

Before changing source code, verify that the build uses the same configured
stack as `configure`. Compiler, MPI or Python paths inherited from Conda or a
different module tree can produce misleading compile/link errors.

If configuration inputs changed materially, rerun `configure` rather than
trying to repair a stale CMake cache manually.

## 6. Installed-runtime failures

After installation/publication, run:

```bash
bash scripts/monan-jedi.sh test-install --config config/jaci.yaml
```

This is the authoritative check for the public runtime. A successful build does
not prove that downstream repositories can consume the installation.

Check:

- required executables under `${MONAN_JEDI_INSTALL_ROOT}/bin`;
- required shared libraries and `ldd` resolution;
- MPAS runtime/support files;
- MPAS-JEDI namelist support files;
- `share/monan-jedi/install-manifest.json`;
- WPS and obs2ioda products when those capabilities are enabled.

Do not point consumers at the private CMake/build tree to compensate for a
missing installed product. Fix the publication/install step.

## 7. PBS failures

`test-pbs` performs local preflight before `qsub`. If preflight fails, fix
that failure first.

If the job was submitted but later fails, separate scheduler/resource failures
from CTest failures. Record at least:

- PBS job id and final scheduler state;
- requested and consumed walltime/resources;
- stdout/stderr;
- CTest summary and the first meaningful failing test;
- exact MONAN-JEDI revision and configuration.

A walltime termination does not establish that the scientific test itself is
wrong. Conversely, increasing walltime should not be the first response to
repeated NetCDF/HDF5 input failures.

After completion, use:

```bash
bash scripts/monan-jedi.sh test-pbs-result --config config/jaci.yaml
```

## 8. WPS/obs2ioda capability failures

WPS and obs2ioda are optional configured capabilities published into the common
runtime prefix. Their source/build locations are implementation details.

For WPS:

```bash
bash scripts/monan-jedi.sh wps --config config/jaci.yaml
bash scripts/monan-jedi.sh test-wps --config config/jaci.yaml
```

After auxiliary products change, the runtime manifest must describe what was
actually published. Downstream repositories should discover capabilities from
the installed runtime contract rather than reconstructing producer paths.

## 9. What to preserve in a bug report

A useful failure report should contain:

```text
MONAN-JEDI commit:
configuration file:
STACK_ROOT:
STACK_ENV_MODULE:
MONAN_JEDI_INSTALL_ROOT:
command that failed:
first relevant error:
log file:
PBS job id (if applicable):
changes since last successful run:
```

Prefer the first causal error over hundreds of secondary messages. Preserve the
full log separately.

## 10. Minimal recovery sequence

When the source tree is intact but the state of the build is uncertain:

```bash
python3 scripts/lib/read_config.py --check config/jaci.yaml
bash scripts/monan-jedi.sh load      --config config/jaci.yaml
bash scripts/monan-jedi.sh configure --config config/jaci.yaml
bash scripts/monan-jedi.sh build     --config config/jaci.yaml
bash scripts/monan-jedi.sh install   --config config/jaci.yaml
bash scripts/monan-jedi.sh test      --config config/jaci.yaml
bash scripts/monan-jedi.sh test-install --config config/jaci.yaml
```

Run the full PBS validation separately when a compute-node allocation is
required. This sequence intentionally uses the public workflow instead of
undocumented manual fixes, so a recovered installation remains reproducible.
