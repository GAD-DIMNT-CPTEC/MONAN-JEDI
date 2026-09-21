# MONAN-JEDI configuration

The `config/` directory contains only **MONAN-JEDI build/install site
configuration**.

It does not contain JEDI experiment/application inputs. Those belong under
`examples/` or in the downstream workflow repository that runs the
experiment.

## Files

- `jaci.yaml`: maintained INPE/JACI configuration.
- `template.yaml`: complete example for creating another site configuration.

The canonical key reference is
[`docs/configuration-reference.md`](../docs/configuration-reference.md).

## Configuration contract

The public YAML interface intentionally exposes only values that a site or user
can reasonably choose. Paths that follow the repository installation contract
are derived by `scripts/lib/config.sh` and are not duplicated in YAML.

Examples of derived/private values include:

- work, log, build and install directories;
- `install/bin`;
- obs2ioda source/build/install directories;
- WPS source/build/release/install/patch directories;
- the CRTM cache archive path.

Advanced diagnostics can still override those derived shell variables through
the environment before calling `scripts/monan-jedi.sh`.

## Validation

`scripts/lib/read_config.py` is the single source of truth for:

- supported YAML keys;
- value types;
- defaults;
- accepted enumerations and formats;
- YAML-to-environment mappings.

Unknown keys are errors. This is intentional: a typo such as
`pbs.wall_time` must not silently fall back to a default.

Validate a file without executing the workflow:

```bash
python3 scripts/lib/read_config.py --check config/jaci.yaml
```

## Change policy

When adding, renaming or removing a public setting:

1. update the schema in `scripts/lib/read_config.py`;
2. update `config/template.yaml`;
3. update `docs/configuration-reference.md`;
4. update configuration tests;
5. add the setting to `config/jaci.yaml` only when JACI needs a non-default
   value or when keeping it explicit materially improves operator clarity.

Do not create a second `configs/` directory. JEDI runtime examples belong in
`examples/`.
