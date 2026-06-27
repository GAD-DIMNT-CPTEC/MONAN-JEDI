# WPS / UNGRIB no JACI

O WPS é compilado com o mesmo stack carregado pelo MONAN-JEDI e publicado sob o prefixo de instalação do bundle.

## Configuração

Copie a seção de `config/wps-jaci.yaml.example` para `config/jaci.yaml`. A opção `wps.configure_option` é obrigatória e deve ser o número da alternativa serial com suporte a GRIB2 apresentada pelo `./configure` do WPS no ambiente JACI; ela não é portátil entre stacks.

## Build

```bash
bash scripts/monan-jedi-wps.sh --config config/jaci.yaml
```

O helper clona a referência declarada, faz checkout destacado, limpa a árvore, executa `./configure` e `./compile ungrib`, valida bibliotecas com `ldd` e grava um manifesto em:

```text
${install.root}/wps/WPS-${wps.version}/build-manifest.json
```

Os artefatos publicados são `ungrib.exe`, `link_grib.csh` e `Vtable.GFS`. Links estáveis para os dois executáveis são criados em `${install.bin_dir}`.

A compilação é separada da execução operacional: o `monan-jedi-workflow` usa os binários publicados, recebe o GRIB de cada ciclo como entrada explícita e gera o arquivo WPS `FILE:` para o `mpas_init_atmosphere`.
