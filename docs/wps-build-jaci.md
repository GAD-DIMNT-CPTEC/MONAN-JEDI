# WPS/UNGRIB build on JACI

MONAN-JEDI builds the WPS components required to decode GRIB input for MPAS
initialization. The integration intentionally uses `USE_WRF=OFF`, so it builds
UNGRIB without requiring a compiled WRF tree.

## Public versus private paths

WPS has a versioned internal release, but downstream workflows must not depend on
that directory.

Private implementation path:

```text
${install.root}/libexec/monan-jedi/wps/WPS-${wps.version}
```

Stable public paths:

```text
${install.root}/bin/ungrib.exe
${install.root}/bin/link_grib.csh
${install.root}/share/wps/Vtable
${install.root}/share/wps/Variable_Tables
```

`mpaswf` consumes only the stable public paths through the shared
`MONAN_JEDI_INSTALL_ROOT` contract.

## Configuration

The WPS block lives in `config/jaci.yaml`:

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

Empty paths are derived from `project.root`, `build.id`, and `install.root`.

The default work trees are private:

```text
${project.root}/work/${build.id}/wps/src
${project.root}/work/${build.id}/wps/build
```

The default release parent is:

```text
${install.root}/libexec/monan-jedi/wps
```

## Dependency resolution

JasPer, libpng and zlib are resolved in this order:

1. explicit root in the YAML;
2. prefixes from the loaded stack environment;
3. `spack location -i` through the configured stack;
4. controlled searches in known stack installation trees.

## Compatibility patches

The pinned upstream source is reset before each build. MONAN-JEDI then applies
ordered patches from `patches/wps/` and records their SHA-256 hashes in the WPS
`build-manifest.json`.

The current patch set covers:

- the modern JasPer decoder API;
- removal of the obsolete JasPer upper-version restriction;
- an empty `WPS_DEFINITIONS` CMake case;
- the GNU/Linux architecture flags required by the standalone CMake path;
- disabling unrelated utilities in the standalone UNGRIB build;
- a relocatable UNGRIB executable symlink produced by the WPS build itself.

## Build

```bash
bash scripts/monan-jedi.sh wps --config config/jaci.yaml
```

The command:

1. resets/checks out the pinned WPS source;
2. applies the compatibility patches;
3. resolves the stack dependencies;
4. configures an out-of-source CMake build;
5. builds `ungrib`, `g1print`, and `g2print`;
6. installs into a temporary staging release;
7. adds `link_grib.csh` and the complete `Variable_Tables` runtime tree;
8. validates executables and runtime libraries;
9. writes the release manifest;
10. promotes the validated release and updates stable public links.

If any pre-promotion step fails, the previously published stable runtime remains
untouched.

## Validation

The WPS tree is checked for:

- executable `ungrib.exe`;
- valid/executable `link_grib.csh`;
- configured default Vtable;
- no `ldd` runtime dependency reported as `not found`.

Re-run the installed-tree validation with:

```bash
bash scripts/monan-jedi.sh test-wps --config config/jaci.yaml
```

A real GRIB-to-`FILE:*` functional test belongs in the operational workflow
(`mpaswf`), which supplies the real GFS file and case-specific `namelist.wps`.
This cleanly separates build/runtime validation from experiment input validation.

## Logs

Relevant logs under `${project.root}/logs/${build.id}` include:

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

The private versioned release contains:

```text
build-manifest.json
```

It records source/ref/commit, WPS version, patch hashes, resolved dependencies,
build type, runtime configuration and installed WPS artifacts.
