## Summary

Describe what changed and why.

## Validation

- [ ] Relevant local tests were run.
- [ ] GitHub Actions is green.

## Configuration/documentation checklist

Complete this section when the PR changes configuration behavior, defaults,
`config/*.yaml`, `scripts/lib/read_config.py`, build/install paths, scheduler
settings, or related documentation.

- [ ] Public schema/type/default/environment mappings are synchronized.
- [ ] `config/template.yaml` still documents every legitimate public override in context.
- [ ] No configurable path/source option was hidden in code merely because a default exists.
- [ ] Stack/module changes preserve origin validation; a same-named module from another stack is rejected.
- [ ] Maintained site YAMLs retain self-explanatory comments near changed values.
- [ ] `docs/configuration-reference.md` contains/updates the detailed key sections.
- [ ] `python3 scripts/check_config_documentation.py` passes.
- [ ] No explanatory comments were removed merely because the information exists elsewhere.

The CI check is authoritative: configuration documentation is part of the
public interface and must not erode between pull requests.
