# Contributing to MONAN-JEDI

Changes should preserve both technical behavior and the ability of scientists
and operators to understand that behavior without reconstructing it from source
code. The project is maintained primarily for meteorology/data-assimilation
work, so documentation should explain operational meaning in plain technical
language and introduce implementation terminology only when it helps.

## Configuration changes

Configuration is a public interface. Any pull request that changes
`scripts/lib/read_config.py`, `config/*.yaml`, configuration-related shell
logic or documented defaults must preserve the configuration documentation
contract described in `config/README.md`.

Before opening or merging such a pull request, run:

```bash
python3 scripts/lib/read_config.py --check config/jaci.yaml
python3 scripts/lib/read_config.py --check config/template.yaml
python3 scripts/check_config_documentation.py
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

A configuration cleanup must not remove explanatory comments merely because the
same information exists in `docs/configuration-reference.md`. Configuration changes must not remove legitimate user/site overrides merely
because a derived default exists.
The complete template is the discoverable configuration API; maintained site
files may stay concise by relying on those defaults.

When a public key changes, update together:

- schema/type/default/environment mapping;
- inline comments in the complete template;
- maintained site YAML where applicable;
- the detailed key section in the configuration reference;
- regression tests when behavior or policy changes.

GitHub Actions enforces the minimum documentation structure and detail. Reviewers
should still judge whether the explanation is scientifically/operationally
clear, because no character-count check can replace meaningful review.

## Pull requests

Prefer focused pull requests with a clear reason for each behavior change. Keep
reproducibility-sensitive external revisions pinned to tested commit SHAs. Do
not merge a configuration or build-system change while CI is failing.
