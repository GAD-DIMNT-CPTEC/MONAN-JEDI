# Obsolete document

This document described the previous MONAN-JEDI workflow based on numbered scripts such as:

```text
scripts/01_load_stack_env.sh
scripts/02_prepare_jedi_bundle.sh
scripts/03_create_mpas_only_bundle.sh
scripts/04_configure_mpas_jedi.sh
scripts/05_build_mpas_jedi.sh
scripts/06_test_mpas_jedi.sh
scripts/07_collect_logs.sh
```

That workflow has been replaced by the YAML-driven workflow in the `feature/central-yaml-config` branch.

Use the new entry point instead:

```bash
bash scripts/monan-jedi.sh <command> --config config/jaci.yaml
```

Main commands:

```bash
bash scripts/monan-jedi.sh load      --config config/jaci.yaml
bash scripts/monan-jedi.sh prepare   --config config/jaci.yaml
bash scripts/monan-jedi.sh reduce    --config config/jaci.yaml
bash scripts/monan-jedi.sh configure --config config/jaci.yaml
bash scripts/monan-jedi.sh build     --config config/jaci.yaml
bash scripts/monan-jedi.sh test      --config config/jaci.yaml
bash scripts/monan-jedi.sh test-pbs  --config config/jaci.yaml
bash scripts/monan-jedi.sh logs      --config config/jaci.yaml
```

For the YAML configuration reference, see:

```text
docs/YAML_CONFIGURATION.md
```

This file is intentionally kept only as a transition notice and should be removed after the new documentation is fully consolidated.
