# Contrato de compatibilidade MONAN--JEDI

## 1. Objetivo

Este documento define as interfaces entre MONAN/MPAS e MONAN-JEDI que devem
permanecer explícitas, rastreáveis e testadas à medida que os dois sistemas
evoluem.

O MONAN pode alterar a formulação científica, a implementação, o paralelismo e
a organização interna herdada do MPAS. Este contrato não impede essa evolução.
Seu objetivo é evitar que uma interface utilizada pela assimilação de dados seja
modificada sem comunicação, avaliação de impacto e testes de integração.

Uma previsão isolada do MONAN executada com sucesso é necessária, mas não é
evidência suficiente de compatibilidade com o MONAN-JEDI. A compatibilidade
também exige que o JEDI consiga representar a malha do modelo, ler e escrever
estados completos, avançar o modelo de forma temporalmente consistente, utilizar
as observações e permitir que o MONAN seja reiniciado a partir da análise.

A compatibilidade somente DEVE ser declarada após a execução de um ciclo
integrado que atravesse as interfaces reais entre os componentes:

```text
previsão MONAN/MPAS
        ↓
assimilação MONAN-JEDI
        ↓
análise
        ↓
nova previsão MONAN
        ↓
entrada válida para o ciclo seguinte
```

Testes isolados do modelo, do adaptador ou de partes do JEDI são importantes
para localizar erros, mas não substituem essa verificação do sistema completo.

## 2. Escopo e linguagem normativa

O contrato se aplica a mudanças no MONAN/MPAS, no MPAS-JEDI, no conjunto de
componentes reunidos pelo MONAN-JEDI e nos arquivos de estado trocados entre os
fluxos de previsão e assimilação.

As expressões **DEVE**, **NÃO DEVE**, **RECOMENDA-SE** e **PODE** têm sentido
normativo:

- **DEVE** e **NÃO DEVE** indicam requisitos de compatibilidade;
- **RECOMENDA-SE** indica uma orientação importante, cujo não atendimento
  requer justificativa;
- **PODE** indica uma ação opcional ou normalmente compatível.

O código-fonte e os testes automatizados continuam sendo a referência definitiva
para o conjunto completo de campos e símbolos utilizados por cada versão. As
listas apresentadas neste documento tornam as interfaces protegidas visíveis,
mas não substituem a análise de dependências nem os testes de integração.

## 3. Termos utilizados neste documento

Este contrato utiliza alguns nomes do ecossistema JEDI:

- **JEDI**: sistema utilizado para executar a assimilação de dados;
- **MPAS-JEDI**: componente que faz a ligação entre o JEDI e o MPAS;
- **adaptador**: código do MPAS-JEDI que permite ao JEDI acessar e avançar o
  modelo;
- **OOPS**: camada do JEDI que organiza a execução do problema de assimilação e
  controla, entre outros elementos, o tempo lógico do experimento;
- **FGAT**: configuração na qual as observações são comparadas com estados do
  modelo em diferentes horários dentro da janela de assimilação;
- **HofX**: aplicação do operador de observação ao estado do modelo, produzindo o
  equivalente modelado de uma observação;
- **matriz B**: representação estatística dos erros do estado de referência do
  modelo utilizada na assimilação.

Conhecer a implementação interna desses componentes não é necessário para
revisar o objetivo geral do contrato. Os nomes são mantidos quando identificam
interfaces ou opções existentes no código.

## 4. Referência técnica auditada

A versão inicial deste contrato foi elaborada a partir dos componentes fixados
por este repositório:

| Componente | Revisão auditada |
|---|---|
| MPAS-Model | `0e5a47a0e1bcccd6e3d99909b76e740a643c4db6` |
| MPAS-JEDI | `19eb7fb3273c7b3094825201af184834c15afdd0` |

A interface do modelo não linear do MPAS-JEDI também foi comparada com a branch
`develop` do projeto original em 24 de agosto de 2026.

Na implementação auditada, cada chamada de `Model::step()` feita pelo OOPS
executa um passo físico do MPAS. O parâmetro `model.tstep` controla o avanço do
tempo lógico no OOPS, enquanto `config_dt` controla a duração física integrada
pelo MPAS nessa chamada.

Portanto, nessa implementação:

```text
segundos(OOPS model.tstep) == MPAS config_dt
```

Essa igualdade DEVE ser verificada antes da execução. Se o MPAS-JEDI for
modificado para executar mais de um passo do MPAS, ou subpassos explícitos,
dentro de uma chamada de `Model::step()`, a nova correspondência DEVE ser
documentada e testada antes que a nova versão substitua este contrato.

Caso contrário, o erro pode não ser percebido durante a execução. Em uma janela
de seis horas com `model.tstep = PT45M`, o OOPS realiza oito avanços lógicos. Com
`config_dt = 1800`, o MPAS integra fisicamente apenas quatro horas; com
`config_dt = 1200`, integra apenas duas horas e quarenta minutos. O processo pode
terminar sem erro mesmo que a trajetória física do MPAS e a trajetória lógica
usada pelo FGAT não representem os mesmos horários.

## 5. Interfaces protegidas

| Interface | Exemplos | Requisito de compatibilidade |
|---|---|---|
| Estado do modelo | nomes, unidades, dimensões, tipos, localização na malha e significado físico | Campos existentes utilizados pelo MPAS-JEDI NÃO DEVEM mudar sem comunicação e atualização coordenada. |
| `Registry` e `pools` | `Registry.xml`, opções de configuração, `state`, `diag`, `mesh` e subestruturas | O nome, a localização e o caminho de acesso de um item utilizado DEVEM ser preservados ou alterados juntamente com o adaptador. |
| Tempo do modelo | `config_dt`, `atm_do_timestep`, níveis temporais e avanço do relógio | A correspondência entre um passo lógico do JEDI e a integração física do MONAN DEVE ser explícita e testada. |
| Relógio e validade | horários inicial e final, `MPAS_NOW`, `xtime`, alarmes e horário de reinício | Os tempos lógico e físico e a validade registrada nos arquivos DEVEM permanecer consistentes. |
| Inicialização e ciclo | inicialização do modelo, `config_do_DAcycling`, reinício e inicialização da análise | Um comportamento equivalente para assimilação DEVE existir antes que um mecanismo seja removido ou renomeado. |
| Geometria | dimensões, conectividade, coordenadas, níveis verticais e decomposição | Mudanças na geometria DEVEM gerar uma avaliação de impacto no adaptador, nos operadores e nas covariâncias. |
| Representação do vento | vento normal às arestas, orientação, vetores normais e componentes reconstruídas | Convenções de sinal, localização na malha e reconstrução DEVEM permanecer rastreáveis e testadas. |
| Diagnósticos | pressão, temperatura, densidade, reconstrução do vento e campos de superfície | Diagnósticos utilizados pelo JEDI DEVEM continuar disponíveis e conservar uma definição documentada. |
| Arquivos de estado | dimensões, variáveis, atributos, formatos, precisão e `xtime` do NetCDF | O JEDI DEVE ler e escrever um estado completo a partir do qual o MONAN possa reiniciar. |
| Compatibilidade da matriz B | malha, resolução, coordenada vertical e definição das variáveis de controle | Uma matriz B NÃO DEVE ser reutilizada após uma mudança potencialmente incompatível sem validação científica. |

## 6. Contrato do estado do modelo

Para cada campo utilizado pelo MONAN-JEDI, o nome sozinho não constitui a
interface completa. O contrato inclui:

```text
nome + significado físico + unidade + dimensão + localização na malha + tipo + validade temporal
```

Exemplos de campos atualmente utilizados, produzidos ou verificados
explicitamente pelo fluxo MPAS-JEDI incluem:

```text
theta
rho
u
qv
pressure_p
surface_pressure
qc
qg
qi
qr
qs
uReconstructZonal
uReconstructMeridional
```

Antes de alterar um campo existente, a mudança no MONAN DEVE identificar se o
MPAS-JEDI o obtém de `state`, `diag`, `mesh` ou de um arquivo de estado do
modelo. Mudanças de unidade, dimensão, nível vertical, localização em célula ou
aresta, convenção de sinal, valor ausente, precisão ou definição científica
exigem atualização coordenada do adaptador e validação de integração.

A inclusão de um novo campo é normalmente compatível. A remoção ou renomeação de
um campo utilizado, ou a manutenção do nome acompanhada de mudança em seu
significado, é uma alteração incompatível até que a integração seja atualizada e
revalidada.

Ao produzir uma análise, o MONAN-JEDI DEVE preservar um estado completo do
modelo. Os testes DEVEM verificar o conteúdo necessário e a capacidade de
reinício, e não uma quantidade total fixa de variáveis. Estados válidos
diferentes podem conter quantidades distintas de variáveis diagnósticas ou
opcionais.

## 7. `Registry`, `pools` e rotinas do modelo chamadas pelo adaptador

Os nomes recuperados por meio das interfaces de `pool` do MPAS fazem parte da
interface do adaptador. Isso inclui opções de configuração e conteúdos
organizados em estruturas como `state`, `diag` e `mesh`.

As categorias abaixo DEVEM passar por uma avaliação de impacto no MONAN-JEDI
quando seus nomes, assinaturas, responsabilidades ou efeitos forem modificados:

- opções do `Registry` utilizadas durante a inicialização e o ciclo de
  assimilação;
- `pools` e subestruturas acessados pelo MPAS-JEDI;
- rotinas de inicialização do modelo;
- rotina responsável por executar um passo físico;
- avanço do relógio e deslocamento dos níveis temporais;
- cálculo dos diagnósticos de saída.

Na versão auditada, exemplos dessas rotinas incluem `atm_mpas_init_block`,
`atm_do_timestep` e `atm_compute_output_diagnostics`. Essa lista é ilustrativa;
o código da versão do adaptador utilizada em cada experimento determina o
conjunto exato de dependências.

Uma reorganização interna PODE modificar detalhes de implementação, mas DEVE
preservar a interface utilizada ou fornecer, na mesma integração coordenada, a
mudança correspondente no MPAS-JEDI.

## 8. Contrato de tempo, relógio e trajetória FGAT

O tempo faz parte do estado científico de um experimento de assimilação de
dados. Ele NÃO DEVE ser tratado apenas como um metadado informativo.

Para cada trajetória não linear utilizada, a validação DEVE estabelecer:

- início da janela, horário da análise e fim da janela;
- valor de `model.tstep` utilizado pelo OOPS;
- integração física representada por cada passo do modelo;
- horários inicial, atual e final do MPAS;
- consistência do `xtime` e do horário de reinício;
- igualdade entre as durações totais das integrações lógica e física.

Para o adaptador auditado, a correspondência necessária é:

```text
uma chamada OOPS Model::step()
    = uma chamada atm_do_timestep(...)
    = config_dt segundos de integração física
    = model.tstep segundos de avanço lógico
```

Qualquer mudança em `config_dt`, passos adaptativos ou aninhados, subciclos,
`atm_do_timestep`, avanço do relógio, alarmes ou gerenciamento dos níveis
temporais DEVE ser avaliada conjuntamente com o grupo de Assimilação de Dados.

O encerramento normal do processo ou a presença da mensagem `OOPS Ending`, por
si só, não comprova a consistência temporal.

## 9. Contrato da geometria e da representação do vento

Mudanças na geometria horizontal ou vertical podem afetar a representação da
malha no MPAS-JEDI, os operadores de observação e o modelo estatístico de
covariâncias. Alguns exemplos de elementos protegidos são:

```text
nCells
nEdges
nVertLevels
nVertLevelsP1
cellsOnEdge
edgesOnCell
latCell
lonCell
edgeNormalVectors
```

Mudanças na conectividade, ordenação, decomposição, coordenadas verticais,
localização das variáveis na malha ou convenções de coordenadas DEVEM ser
avaliadas além do teste de previsão isolada.

O vento exige atenção especial porque o MPAS armazena o vento normal às arestas,
enquanto o JEDI também utiliza representações zonal e meridional. Mudanças na
orientação das arestas, nos vetores normais, na reconstrução, nas convenções de
sinal ou na localização das variáveis DEVEM incluir testes capazes de detectar
um campo de vento fisicamente plausível, mas interpretado incorretamente.

## 10. Diagnósticos, arquivos e capacidade de reinício

Os diagnósticos utilizados pelo JEDI DEVEM continuar disponíveis nos pontos
necessários ao adaptador e DEVEM manter unidades, dimensões e significados
documentados.

Os arquivos NetCDF de estado do modelo trocados entre os fluxos DEVEM preservar:

- dimensões e conectividade necessárias;
- variáveis de estado, diagnóstico e metadados exigidas;
- tipos, formatos e precisão necessários ao adaptador;
- `xtime` válido e consistente;
- conteúdo suficiente para inicializar uma previsão do MONAN a partir da
  análise.

O critério de compatibilidade do ciclo completo não é apenas a capacidade de o
JEDI escrever um arquivo NetCDF. O MONAN DEVE conseguir inicializar e avançar a
partir da análise produzida.

## 11. Matriz B e configuração científica

Uma matriz B estática está associada a uma configuração específica do modelo.
No mínimo, mudanças nos itens abaixo exigem uma avaliação explícita de
compatibilidade da covariância:

- malha horizontal ou resolução;
- coordenada vertical ou quantidade de níveis;
- definição das variáveis de controle;
- definições termodinâmicas, como `theta` ou `rho`;
- representação do vento;
- variáveis de umidade e suas transformações;
- climatologia do modelo ou estatísticas de previsão utilizadas para estimar a
  matriz B.

A capacidade de ler uma matriz B antiga não demonstra que ela continua
cientificamente válida. Uma mudança do modelo que possa invalidá-la DEVE
resultar na validação documentada da matriz existente ou na geração e validação
de uma nova matriz.

## 12. Classificação das mudanças

### 12.1 Normalmente compatíveis

As mudanças abaixo PODEM seguir o processo normal de testes do MONAN quando a
interface protegida permanece inalterada:

- otimizações de laços e memória;
- otimizações de paralelismo e comunicação;
- reorganizações internas que preservam as interfaces utilizadas pelo
  adaptador;
- inclusão de diagnósticos ou variáveis opcionais;
- mudanças em algoritmos científicos que alteram intencionalmente os resultados,
  mas preservam o significado das interfaces.

Mudanças científicas podem modificar legitimamente as previsões e as análises.
Elas ainda exigem avaliação científica, mas não são automaticamente
incompatíveis com a interface.

### 12.2 Mudanças que exigem coordenação

As mudanças abaixo exigem avaliação conjunta com o grupo de Assimilação de Dados
antes da integração:

- alteração de uma opção de configuração, `pool`, rotina ou organização de
  arquivo pertencente à interface protegida;
- mudança de unidade, dimensão, localização na malha ou significado de um estado
  ou diagnóstico;
- mudança na integração temporal, nos relógios, no ciclo ou no reinício;
- mudança na geometria, nas coordenadas verticais ou nas convenções de vento;
- mudança que possa invalidar operadores de observação ou uma matriz B.

### 12.3 Incompatíveis até nova validação

Uma mudança é considerada incompatível até que o adaptador e os testes sejam
atualizados quando:

- remove ou renomeia uma interface utilizada pelo MPAS-JEDI;
- altera o significado de um campo e mantém seu nome anterior;
- permite que as trajetórias lógica e física representem horários diferentes;
- produz uma análise que não seja um estado completo e reinicializável do MONAN;
- altera a geometria ou as variáveis de controle e reutiliza, sem avaliação, uma
  matriz de covariância incompatível.

## 13. Processo necessário para mudanças

Para uma proposta de mudança no MONAN que atinja uma interface protegida:

1. identificar, na descrição da mudança, a interface MONAN-JEDI afetada;
2. comunicar os responsáveis pela Assimilação de Dados antes da integração;
3. registrar as versões exatas do MONAN e do MPAS-JEDI utilizadas nos testes;
4. atualizar, quando necessário, o adaptador, a configuração e a documentação de
   forma coordenada;
5. executar os testes de interface e a validação do ciclo completo descritos na
   Seção 14;
6. registrar os resultados e os possíveis impactos na matriz B e nos operadores
   de observação;
7. não declarar compatibilidade com base apenas em uma previsão isolada ou em
   testes separados dos componentes;
8. preservar as evidências da execução integrada, incluindo versões, configurações,
   logs e produtos transferidos entre MONAN e JEDI.

Mecanismos temporários de compatibilidade PODEM ser utilizados durante uma
migração coordenada. O período de transição e os critérios para sua remoção DEVEM
ser documentados.

## 14. Validação de integração e do ciclo completo

A verificação de compatibilidade possui dois níveis complementares. Os testes
reduzidos de interface ajudam a detectar rapidamente problemas específicos. A
validação de ponta a ponta comprova que os componentes continuam funcionando
juntos. Os testes reduzidos NÃO DEVEM ser usados como substitutos da execução do
sistema completo.

RECOMENDA-SE que ambos os níveis sejam automatizados em integração contínua ou
em um fluxo reproduzível no ambiente de computação de alto desempenho.

### 14.1 Testes reduzidos de interface

Os testes de interface DEVEM, no mínimo:

1. carregar um estado completo do MONAN/MPAS;
2. construir a representação da geometria no MPAS-JEDI;
3. executar pelo menos um passo não linear por meio de `Model::step()`;
4. comprovar que o avanço lógico corresponde à integração física do modelo;
5. executar um teste reduzido de `HofX` ou equivalente;
6. executar um teste variacional reduzido;
7. escrever uma análise de teste como um estado completo do modelo;
8. confirmar a presença das variáveis necessárias, valores numéricos finitos e
   `xtime` válido;
9. comprovar que o MONAN consegue inicializar a partir da análise produzida.

### 14.2 Validação obrigatória do sistema completo

Antes de uma versão do MONAN ser declarada compatível com o MONAN-JEDI, DEVE ser
executado pelo menos um ciclo integrado de ponta a ponta. O caso PODE ser
reduzido para controlar o custo computacional, mas DEVE utilizar os componentes,
arquivos e transferências reais do sistema, sem substituir as interfaces
protegidas por dados simulados ou etapas manuais que ocultem incompatibilidades.

A validação integrada DEVE:

1. executar uma previsão do MONAN/MPAS que produza o estado de referência
   utilizado pela assimilação;
2. preparar e validar os arquivos necessários à assimilação, incluindo estado do
   modelo, observações, geometria, arquivos estáticos e matriz B;
3. executar o MONAN-JEDI completo com a configuração de assimilação escolhida;
4. confirmar que as observações foram lidas e utilizadas e que o processo de
   minimização ou análise terminou corretamente;
5. produzir a análise como um estado completo, temporalmente consistente e
   reinicializável do MONAN;
6. verificar nos estados de entrada e saída as variáveis obrigatórias, horários,
   dimensões, valores não finitos e demais critérios numéricos definidos pelo
   experimento;
7. inicializar o MONAN a partir da análise, sem reconstrução manual de campos que
   deveria ser realizada pelo fluxo;
8. executar a nova previsão até o horário do ciclo seguinte;
9. comprovar que a previsão resultante pode ser utilizada diretamente como
   entrada de uma nova assimilação;
10. quando o fluxo se destinar a ciclos sucessivos, executar também a assimilação
    do horário seguinte, comprovando a continuidade do encadeamento;
11. registrar as versões exatas dos componentes, configurações, logs, arquivos de
    entrada e saída e resultados da validação.

O critério esperado é, portanto:

```text
MONAN/MPAS isolado executa
        +
MONAN-JEDI isolado executa
        ≠
compatibilidade comprovada

compatibilidade comprovada
        =
ciclo integrado executado e validado
```

Mudanças que afetem a geometria, o significado do estado ou a compatibilidade da
covariância exigem validação científica adicional apropriada à interface
modificada.

## 15. Lista de verificação para propostas de mudança

Recomenda-se que mudanças no MONAN que possam afetar este contrato incluam a
seguinte lista de verificação em sua descrição:

```text
[ ] Verifiquei se esta mudança afeta uma interface protegida do MONAN-JEDI.
[ ] Documentei mudanças em nomes, unidades, dimensões, localização ou significado dos estados.
[ ] Documentei mudanças na integração temporal, nos relógios, no ciclo ou no reinício.
[ ] Documentei mudanças na geometria, na representação do vento ou nos diagnósticos.
[ ] Avaliei a compatibilidade dos operadores de observação e da matriz B, quando aplicável.
[ ] Executei ou solicitei os testes reduzidos de interface do MONAN-JEDI.
[ ] Executei ou solicitei a validação do ciclo completo MONAN/MPAS → MONAN-JEDI → MONAN.
[ ] Confirmei que a saída do ciclo pode alimentar diretamente o ciclo seguinte.
[ ] Registrei as versões exatas do MONAN e do MPAS-JEDI utilizadas na validação.
```

## 16. Responsabilidade e evolução deste contrato

Este é um contrato de interface compartilhado. Recomenda-se que suas mudanças
sejam revisadas conjuntamente pelos responsáveis pelo MONAN/Computação
Científica e pela Assimilação de Dados.

O contrato DEVE evoluir quando uma interface for intencionalmente reformulada.
A revisão deve descrever o novo comportamento, o caminho de transição e as
evidências de validação. Uma alteração não testada não deve ser classificada
retroativamente como compatível.
