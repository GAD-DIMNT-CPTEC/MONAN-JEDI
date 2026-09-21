# AGENTS.md

Instructions for AI coding agents and automated contributors working in this
repository.

## Configuration documentation is mandatory

Treat `config/jaci.yaml`, `config/template.yaml` and
`docs/configuration-reference.md` as parts of the public user interface, not as
incidental text.

When editing configuration behavior:

1. preserve the explanatory header blocks in the YAML files;
2. keep meaningful comments immediately above every public value;
3. never replace the self-documenting YAML with a compact bare key/value file;
4. keep `config/template.yaml` complete with every legitimate user/site override;
   prefer an empty value plus a documented derived default for optional paths;
   do not hide paths, URLs, repositories or component locations in code merely
   because a standard default exists;
5. update the detailed reference section for every key whose meaning, default,
   allowed values or environment override changes;
6. run `python3 scripts/check_config_documentation.py`;
7. run the configuration/unit test suite and do not merge failing CI.

The inline comments intentionally repeat some information from the reference.
That duplication is by design: operators should understand the configuration
file while reading it, while the reference provides a searchable canonical
description.

Do not reintroduce a repository-level `configs/` directory. A path such as
`configs/sites/tier2/jaci/setup.sh` is relative to spack-stack and is unrelated
to MONAN-JEDI repository layout.

If a refactor proposes reducing documentation because it appears repetitive,
preserve the documentation and refactor implementation duplication instead.
