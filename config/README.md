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

## Complete template, concise site files

`config/template.yaml` is the complete public interface. It must expose every
legitimate user/site choice, including configurable paths, caches, download
URLs, upstream repository locations, component directories and published names.

A maintained site file such as `config/jaci.yaml` should be shorter. It records
only values that are operationally important to keep explicit or that differ
from defaults. Omitting an optional key is not the same as removing user
autonomy: the user can copy/add that key from the complete template whenever an
override is required.

For configurable derived paths, the preferred contract is:

```text
empty/omitted YAML value  -> derive the documented default
explicit YAML value       -> use the persistent user/site override
non-empty environment var -> temporary override of the YAML value
```

Do not remove a legitimate path/source option merely because the project has a
good default for it. Simplify duplicate values, not operator autonomy.

## Changing spack-stack or modules

Changing the stack is treated as an infrastructure change, not as a cosmetic
edit. MONAN-JEDI identifies a loaded environment by the canonical `stack.root`,
canonical `stack.module_root`, and `stack.env_module` together. If any of these
change, the previous environment is rejected and the configured stack is loaded
from a clean module state. This remains true when two different stacks publish
the same module name.

Remember that non-empty environment variables override YAML. If `STACK_ROOT`,
`STACK_MODULE_ROOT` or `STACK_ENV_MODULE` was exported manually, unset it when
you intend the YAML value to take effect. Use `bash scripts/monan-jedi.sh load
--config <file>` and inspect the resulting stack report/snapshot before a build
when migrating to another stack.

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
