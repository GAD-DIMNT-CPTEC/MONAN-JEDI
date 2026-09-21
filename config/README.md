# MONAN-JEDI configuration

The `config/` directory contains only **MONAN-JEDI build/install site
configuration**. It does not contain JEDI experiment/application inputs or operational
assimilation-cycle configuration; those belong in the workflow/experiment
repository, while maintained usage examples belong under `examples/`.

## Files

- `jaci.yaml`: maintained INPE/JACI configuration and operator-facing documentation.
- `template.yaml`: complete, fully documented public configuration interface.
- `../docs/configuration-reference.md`: detailed reference for every public key.

## Documentation is part of the interface

The YAML files are intentionally self-documenting. A user reading
`config/jaci.yaml` should understand the filesystem model, the purpose of each
explicit value, the difference between build/test/scheduler controls, and the
consequences of changing a setting without first reading Python or shell code.

This is a repository contract, not a style preference. Do not simplify a
configuration file into a bare key/value list and do not move all explanation
to an external document. The inline comments and the detailed reference serve
different purposes and both must remain useful.

The quality baseline is:

- a PURPOSE block explaining what the file configures and what it does not;
- an IMPORTANT FILESYSTEM MODEL block;
- a MAIN DERIVED PATHS block;
- GENERAL RULES covering overrides, YAML/CMake values and reproducibility;
- meaningful comments immediately above every user-facing YAML value;
- a detailed reference section for every public key.

## Public versus derived settings

The public YAML interface exposes only decisions a site or user can reasonably
make. Paths that follow the repository installation contract are derived by
`scripts/lib/config.sh` rather than duplicated in YAML.

Examples of derived/private values include work, log, build and install
directories, `install/bin`, obs2ioda source/build/install directories, WPS
source/build/release/install/patch directories and the CRTM cache archive path.

Advanced diagnostics may still override those shell variables through the
environment before calling `scripts/monan-jedi.sh`.

## Automated documentation contract

Run:

```bash
python3 scripts/lib/read_config.py --check config/jaci.yaml
python3 scripts/lib/read_config.py --check config/template.yaml
python3 scripts/check_config_documentation.py
```

The documentation checker is executed by GitHub Actions on every pull request
to `main` and on every push to `main`. It fails when:

- `config/template.yaml` no longer contains every public schema key;
- a public YAML value lacks sufficiently substantive adjacent comments;
- required conceptual header blocks disappear;
- `docs/configuration-reference.md` lacks a detailed section for a public key;
- a detailed reference section becomes too short to meet the minimum contract.

The check is deliberately mechanical so the standard applies equally to
changes written by people, GPT/Codex or other automated tools.

## Change procedure

When adding, renaming, removing or changing the meaning/default of a setting:

1. update the schema in `scripts/lib/read_config.py`;
2. update the explanatory comments in `config/template.yaml`;
3. update `config/jaci.yaml` when JACI needs an explicit value or explanation;
4. update the corresponding detailed section in
   `docs/configuration-reference.md`;
5. run both configuration validation and documentation validation locally;
6. do not merge unless CI is green.

Do not create a second `configs/` directory. Paths such as
`configs/sites/.../setup.sh` refer to files inside spack-stack, not this
repository.
