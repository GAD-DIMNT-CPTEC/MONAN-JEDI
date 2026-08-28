# MONAN-JEDI

Reproducible build, installation and validation workflow for the MONAN-JEDI
MPAS-JEDI baseline on INPE/JACI.

The repository has two distinct responsibilities around it:

- `spack-stack-inpe` provides the compiler/MPI/dependency environment;
- `MONAN-JEDI` builds and publishes the MONAN/MPAS/JEDI runtime consumed by
  `mpaswf`, `MPAS-BMatrix`, and other workflow components.

## Public runtime installation

The default public prefix is:

```bash
export MONAN_JEDI_INSTALL_ROOT=/p/projetos/monan_das/$USER/build/monan-jedi
```

It is derived as:

```text
${project.root}/build/${build.id}
```

The important distinction is:

```text
${project.root}/work/${build.id}   private, rebuildable work/build trees
${project.root}/logs/${build.id}   logs
${project.root}/build/${build.id}  public runtime installation
```

Downstream workflows should receive `MONAN_JEDI_INSTALL_ROOT` and should not
need the MONAN-JEDI source checkout or build tree.

The public layout includes:

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
│   └── obs2ioda_v3          # when enabled
├── lib/
├── include/
└── share/
    ├── MPAS/core_atmosphere/
    ├── wps/
    │   ├── Vtable
    │   └── Variable_Tables/
    └── monan-jedi/
        ├── install-manifest.json
        └── mpas-jedi/namelists/
            ├── geovars.yaml
            └── keptvars.yaml
```

See [the runtime install contract](docs/runtime-install-contract.md) for the
producer/consumer rules.

## WPS

WPS is built as an auxiliary component but published through the same runtime
prefix. The versioned release is an internal implementation detail below:

```text
${MONAN_JEDI_INSTALL_ROOT}/libexec/monan-jedi/wps/WPS-<version>
```

Consumers use only the stable paths:

```text
${MONAN_JEDI_INSTALL_ROOT}/bin/ungrib.exe
${MONAN_JEDI_INSTALL_ROOT}/bin/link_grib.csh
${MONAN_JEDI_INSTALL_ROOT}/share/wps/Vtable
${MONAN_JEDI_INSTALL_ROOT}/share/wps/Variable_Tables
```

This is the interface used by `mpaswf`.

## Requirements

A validated spack-stack environment must already exist. The current JACI
baseline uses the configured `jedi-mpas-env` module and Cray MPICH environment.

Git LFS is also required because JEDI test-data repositories contain binary
NetCDF/HDF5 inputs. The current JACI spack-stack already provides Git LFS; the
normal diagnostic reports `provider=loaded stack/environment` when that copy is
selected.

Check the loaded environment with:

```bash
bash scripts/monan-jedi.sh load --config config/jaci.yaml
```

If a custom/older stack does not provide Git LFS, see
[docs/jedi-test-data.md](docs/jedi-test-data.md) for the supported fallback and
recovery procedure.

## Configuration

User-editable settings are centralized in:

```text
config/jaci.yaml
config/template.yaml
```

Important defaults when path values are empty:

| Setting | Default |
| --- | --- |
| `build.dir` | `${project.root}/work/${build.id}/build` |
| `install.root` | `${project.root}/build/${build.id}` |
| `install.bin_dir` | `${install.root}/bin` |
| `wps.build_dir` | `${project.root}/work/${build.id}/wps/build` |
| `wps.releases_dir` | `${install.root}/libexec/monan-jedi/wps` |
| `wps.install_dir` | `${wps.releases_dir}/WPS-${wps.version}` |

Keep `model.double_precision` quoted as `'ON'` or `'OFF'`.

## Workflow

Primary entry point:

```bash
bash scripts/monan-jedi.sh <command> --config config/jaci.yaml
```

Available commands include:

```text
load
configure
build
install
test
test-install
test-pbs
test-pbs-result
obs2ioda
wps
test-wps
logs
all
```

The normal complete sequence is:

```bash
bash scripts/monan-jedi.sh all --config config/jaci.yaml
```

`all` finishes by validating the installed runtime and then collecting the log
summary. A missing executable, runtime file, shared library or project-group
permission therefore makes the complete workflow fail instead of leaving a
partially usable installation marked as successful.

Individual stack-dependent commands bootstrap and validate the configured stack
environment themselves, so separate login sessions are supported:

```bash
bash scripts/monan-jedi.sh configure --config config/jaci.yaml
bash scripts/monan-jedi.sh build     --config config/jaci.yaml
bash scripts/monan-jedi.sh install   --config config/jaci.yaml
```

## Build versus install

Compilation products remain in the private build tree. The public prefix is
populated by installation/publication steps only.

For the main bundle:

```text
build:   ${project.root}/work/${build.id}/build/bin
install: ${MONAN_JEDI_INSTALL_ROOT}/bin
```

Auxiliary components follow the same principle: they build in their own work
trees and are published into the common installation only after successful
build/validation.

## MPAS-JEDI runtime support files

`geovars.yaml` and `keptvars.yaml` are required by downstream B-matrix runtime
workflows. They are therefore copied during `install` from the pinned MPAS-JEDI
source into:

```text
${MONAN_JEDI_INSTALL_ROOT}/share/monan-jedi/mpas-jedi/namelists/
```

This keeps `MPAS-BMatrix` independent of the MONAN-JEDI source tree.

## Validation

A login-node-safe subset can be run with:

```bash
bash scripts/monan-jedi.sh test --config config/jaci.yaml
```

The installed runtime can be validated independently after `install`, `wps` and
other selected publication steps with:

```bash
bash scripts/monan-jedi.sh test-install --config config/jaci.yaml
```

`test-install` loads the configured spack-stack environment and checks:

- required public directories and executables;
- MPAS runtime data and installed MPAS-JEDI YAML files;
- `install-manifest.json` consistency;
- WPS and obs2ioda products when enabled;
- `ldd` resolution for required executables in the configured runtime environment;
- project-group ownership, file readability, directory traversal and executable access.

The result is written to `${project.root}/logs/${build.id}/10_install_test.log`
and ends with `RESULT=PASS` or `RESULT=FAIL`.

The complete configured CTest suite is submitted to PBS with:

```bash
bash scripts/monan-jedi.sh test-pbs --config config/jaci.yaml
```

After the job finishes, validate the recorded result with:

```bash
bash scripts/monan-jedi.sh test-pbs-result --config config/jaci.yaml
```

See:

- [JACI PBS queue limits](docs/jaci-pbs-queues.md)
- [JEDI test data and Git LFS](docs/jedi-test-data.md)
- [WPS build on JACI](docs/wps-build-jaci.md)
- [YAML configuration](docs/YAML_CONFIGURATION.md)

## Design principles

- one stable public installation prefix for all MONAN/MPAS/JEDI runtime products;
- source, build, install and spack-stack trees remain distinct;
- downstream workflows derive runtime paths from `MONAN_JEDI_INSTALL_ROOT`;
- versioned/private implementation directories are not consumer APIs;
- auxiliary tools share the runtime prefix but not the main build tree;
- published runtime products appear only after the corresponding validation step;
- logs and manifests retain enough provenance to reproduce and diagnose builds.
