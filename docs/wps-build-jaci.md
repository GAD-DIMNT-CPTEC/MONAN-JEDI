# WPS/UNGRIB build on JACI

## Scope

MONAN-JEDI builds the WPS components required to decode GRIB input for MPAS initialization. The integration intentionally sets `USE_WRF=OFF`, so it does not build `geogrid` or `metgrid` and does not require a compiled WRF tree.

The primary product is `ungrib.exe` together with `link_grib.csh` and the WPS variable tables.

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

Empty paths are derived from `project.root`, `build.id` and `install.root`. JasPer, libpng and zlib are located with `spack location -i` unless explicit roots are provided.

No configure-menu number is required. The workflow uses the native CMake build included in WPS 4.6.0.

## Build

```bash
bash scripts/monan-jedi.sh wps --config config/jaci.yaml
```

The command performs a clean detached checkout of `wps.ref`, applies the patches in `patches/wps`, configures WPS with CMake and builds `ungrib`, `g1print` and `g2print`.

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

If a rebuild fails, existing stable links continue to reference the previously validated release.

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

## Manifest

`build-manifest.json` records:

- source repository, requested ref and resolved commit;
- WPS version label;
- compatibility patch names and SHA-256 hashes;
- resolved JasPer, libpng and zlib roots;
- build type and disabled WRF/MPI/OpenMP options;
- installed runtime artifacts.
