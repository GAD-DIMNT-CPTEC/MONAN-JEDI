# MONAN-JEDI configuration files

The files in this directory are executable documentation as well as workflow input. Their comments are intentionally detailed because they record site assumptions, path derivations, safety constraints and the rationale behind non-obvious values.

## Files

- `jaci.yaml` is the maintained configuration for INPE/JACI.
- `template.yaml` is the starting point for another site or stack installation.

The YAML files configure preparation, compilation, installation and validation of the MONAN-JEDI bundle and its auxiliary components. They are not operational data-assimilation experiment files.

## Documentation contract

Every configuration key should remain documented next to the value. A useful comment must state, when applicable:

1. what the key controls;
2. whether it is required or optional;
3. accepted values or expected format;
4. the exact derived value when left empty;
5. important side effects, destructive behavior or scheduler constraints;
6. whether another key or environment variable takes precedence.

The introductory filesystem model in both YAML files is part of this contract. It explains that the writable user workspace and the existing spack-stack installation are independent areas and must not be conflated.

## Change policy

When adding, renaming or removing a key:

- update `config/jaci.yaml` and `config/template.yaml` together;
- update `scripts/lib/read_config.py` and any derived-path logic;
- update or add configuration tests;
- preserve historical rationale when behavior remains relevant;
- remove comments only when the associated behavior no longer exists, and explain that removal in the commit or pull request.

The CI includes documentation regression checks for the core conceptual guidance so that future refactors do not silently reduce these files to undocumented value lists.
