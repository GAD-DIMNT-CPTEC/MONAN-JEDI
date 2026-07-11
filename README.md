# MONAN-JEDI

Reproducible build and validation workflow for the MONAN-JEDI MPAS-JEDI baseline on INPE/JACI.

The repository is intentionally separated from `spack-stack-inpe`:

- `spack-stack-inpe` creates and validates the software environment;
- `MONAN-JEDI` defines the MPAS-JEDI bundle and orchestrates builds, installation, tests and auxiliary tools;
- auxiliary tools such as `obs2ioda` and WPS/UNGRIB are built outside the main bundle tree but published under the same install prefix.

## Requirements

A validated `spack-stack-inpe` environment must already exist. The current JACI baseline uses:

```text
spack-stack release/2.1
PrgEnv-gnu/8.6.0
gcc-native/12.3
cray-mpich/8.1.31
jedi-mpas-env/1.0.0
```

## Configuration

User-editable settings are centralized in YAML files under `config/`.

```text
config/jaci.yaml       JACI configuration
config/template.yaml   template for additional sites
```

Important derived paths:

| Setting | Default when empty |
|---|---|
| `build.dir` | `${project.root}/work/${build.id}/build` |
| `install.root` | `${project.root}/builds/${build.id}` |
| `install.bin_dir` | `${install.root}/bin` |
| `wps.build_dir` | `${project.root}/work/${build.id}/wps/build` |
| `wps.install_dir` | `${install.root}/wps/WPS-${wps.version}` |

Keep `model.double_precision` quoted as `'ON'` or `'OFF'`.

## Workflow

The primary entry point is:

```bash
bash scripts/monan-jedi.sh <command> --config config/jaci.yaml
```

Available commands:

```text
load        Load and validate the spack-stack environment
configure   Configure the MONAN-JEDI bundle with ecbuild
build       Build the configured bundle
install     Install the configured bundle
test        Run the login-node-safe CTest subset
test-pbs    Submit CTest to PBS
obs2ioda    Build and publish NCAR/obs2ioda
wps         Build, validate and publish WPS/UNGRIB
test-wps    Validate the published WPS installation
logs        Collect workflow logs
all         Run the bundle and all enabled auxiliary tools
```

Normal full sequence:

```bash
bash scripts/monan-jedi.sh all --config config/jaci.yaml
```

Individual auxiliary tools:

```bash
bash scripts/monan-jedi.sh obs2ioda --config config/jaci.yaml
bash scripts/monan-jedi.sh wps --config config/jaci.yaml
bash scripts/monan-jedi.sh test-wps --config config/jaci.yaml
```

The `all` command builds auxiliary tools only when their respective `enabled` setting is true.

## WPS/UNGRIB integration

The WPS build is intentionally limited to components that do not require a compiled WRF installation. It uses the CMake build shipped by WPS 4.6.0 and builds:

- `ungrib` / `ungrib.exe`;
- `g1print` and `g2print`;
- `link_grib.csh`;
- the complete `Variable_Tables` directory.

The build:

1. checks out the pinned WPS revision;
2. applies versioned compatibility patches from `patches/wps/`;
3. resolves JasPer, libpng and zlib from the loaded Spack environment;
4. configures and builds in a separate tree;
5. installs into a staging release;
6. validates executables and runtime libraries;
7. promotes the release atomically;
8. updates stable links only after validation succeeds.

Stable runtime paths:

```text
${install.bin_dir}/ungrib.exe
${install.bin_dir}/link_grib.csh
${install.root}/share/wps/Vtable
${install.root}/share/wps/Variable_Tables
```

A provenance manifest is written to:

```text
${wps.install_dir}/build-manifest.json
```

See [docs/wps-build-jaci.md](docs/wps-build-jaci.md) for details.

## Repository layout

```text
MONAN-JEDI/
├── CMakeLists.txt
├── config/
│   ├── jaci.yaml
│   └── template.yaml
├── docs/
│   ├── OBS2IODA_BUILD.md
│   ├── YAML_CONFIGURATION.md
│   └── wps-build-jaci.md
├── patches/
│   └── wps/
├── scripts/
│   ├── monan-jedi.sh
│   └── lib/
│       ├── obs2ioda.sh
│       ├── read_config.py
│       ├── wps.sh
│       └── wps_dependencies.sh
└── tests/
```

## Pinned bundle revisions

The top-level `CMakeLists.txt` pins the JEDI and MPAS components to full commit SHAs. WPS is also pinned in the YAML configuration because it is an auxiliary build rather than an `ecbuild_bundle` component.

## Design principles

- YAML is the user interface; routine use must not require editing shell scripts.
- Build, source, install and stack trees remain independent.
- Auxiliary tools share the stack and install prefix but not the main bundle build tree.
- Published runtime paths are stable and are updated only after validation.
- Logs and manifests must provide enough information to reproduce a build.
