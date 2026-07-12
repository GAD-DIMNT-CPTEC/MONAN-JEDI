# WPS/UNGRIB build on JACI

## Scope

MONAN-JEDI builds the WPS components required to decode GRIB input for MPAS initialization. The integration intentionally sets `USE_WRF=OFF`, so it does not build `geogrid` or `metgrid` and does not require a compiled WRF tree.

The primary product is `ungrib.exe` together with `link_grib.csh` and the WPS variable tables. The auxiliary `g1print` and `g2print` targets are also compiled.

## Configuration

The complete configuration lives in `config/jaci.yaml`:

```yaml
wps:
  enabled: true
  repo: https://github.com/wrf-model/WPS.git
  ref: 335c76a111f84503e8b963abaf273ea8053645bb
  version: 4.6.0
  source_dir:
  build_dir:
  releases_dir:
  install_dir:
  patch_dir:
  jasper_root:
  png_root:
  zlib_root:
  cmake_prefix_path:
  build_type: Release
  ungrib_name: ungrib.exe
  link_grib_name: link_grib.csh
  default_vtable: Vtable.GFS
```

Empty paths are derived from `project.root`, `build.id` and `install.root`.

For JasPer, libpng and zlib, dependency discovery uses the following precedence:

1. an explicit root in `config/jaci.yaml`;
2. dependency prefixes already exported by the loaded stack environment;
3. `spack location -i` using the Spack executable shipped inside `STACK_ROOT`;
4. a controlled search below known stack installation trees.

No configure-menu number is required. The workflow uses the native CMake build included in WPS 4.6.0.

## Compatibility patches

The pinned WPS source is kept unchanged in Git. Compatibility changes are stored as ordered patch files under `patches/wps/`, checked before application and recorded with SHA-256 hashes in `build-manifest.json`.

The current patch set is:

### `0001-modern-jasper-api.patch`

WPS 4.6.0 calls the old JasPer decoder function:

```c
jpc_decode(...)
```

JasPer 4.x exposes the supported generic decoder API:

```c
jas_image_decode(...)
```

The patch changes only this decoder call and its associated error message. A build log containing:

```text
Applied WPS patch: 0001-modern-jasper-api.patch
```

confirms that this API compatibility patch was applied before CMake configuration.

### `0002-relax-jasper-version.patch`

The WPS 4.6.0 CMake configuration restricts JasPer to the historical range `1.900.1...1.900.29`. The JACI stack provides JasPer 4.x. This patch retains the minimum version requirement but removes the obsolete upper bound.

### `0003-handle-empty-wps-definitions.patch`

When WPS is configured directly with CMake and without a legacy architecture file, `WPS_DEFINITIONS` may legitimately be empty. WPS 4.6.0 expands that value without quotes:

```cmake
string(REPLACE " " ";" WPS_DEFINITIONS_LIST ${WPS_DEFINITIONS})
```

With an empty value, CMake receives too few arguments and reports:

```text
string sub-command REPLACE requires at least four arguments
```

The patch quotes the input variable so that an empty string remains a valid fourth argument. This error is independent of the JasPer decoder API patch.

## Build

```bash
bash scripts/monan-jedi.sh wps --config config/jaci.yaml
```

The command performs a clean detached checkout of `wps.ref`, applies all patches in filename order, configures WPS with CMake and builds `ungrib`, `g1print` and `g2print`.

Because the source checkout is reset and cleaned at the beginning of every build, rerunning the command after updating the MONAN-JEDI branch is sufficient. No manual editing or cleanup inside the WPS source directory is required.

## Publication contract

The versioned release is installed under:

```text
${install.root}/wps/WPS-${wps.version}
```

Stable links are published only after the staged release passes validation:

```text
${install.bin_dir}/ungrib.exe
${install.bin_dir}/link_grib.csh
${install.root}/share/wps/Vtable
${install.root}/share/wps/Variable_Tables
```

If a rebuild fails, existing stable links continue to reference the previously validated release. An incomplete staging directory is never promoted as the active release.

## Validation

The build verifies that:

- `ungrib.exe` exists and is executable;
- `link_grib.csh` passes `csh -n`;
- the configured default Vtable exists;
- `ldd` reports no missing runtime libraries.

The installed release can be checked again with:

```bash
bash scripts/monan-jedi.sh test-wps --config config/jaci.yaml
```

Run `test-wps` only after the `wps` command completes successfully. If configuration or compilation fails, no new release is promoted and the expected `WPS-4.6.0/bin/ungrib.exe` may not exist.

A GRIB-to-`FILE:*` functional test should be run by the operational workflow with the same sample and namelist used by `mpas_init_atmosphere`. This repository validates the compiled runtime contract; cycle-specific GRIB input remains the responsibility of the runtime workflow.

## Logs

Relevant files under `${project.root}/logs/${build.id}` include:

```text
09_wps_clone.log
09_wps_fetch.log
09_wps_checkout.log
09_wps_cmake.log
09_wps_build.log
09_wps_install.log
09_wps_validate.log
09_wps_test.log
```

The first failing phase should be diagnosed from its corresponding log. For example, a CMake configuration failure is recorded in `09_wps_cmake.log`; it is not a runtime failure of `ungrib.exe`.

## Manifest

`build-manifest.json` records:

- source repository, requested ref and resolved commit;
- WPS version label;
- compatibility patch names and SHA-256 hashes;
- resolved JasPer, libpng and zlib roots;
- build type and disabled WRF/MPI/OpenMP options;
- installed runtime artifacts.
