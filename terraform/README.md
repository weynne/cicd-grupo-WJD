# Infraestrutura do laboratório de CD

Provisiona, com Terraform, a EC2 que hospeda o cluster Kubernetes usado pelos
workflows de entrega contínua: `cd.yml`, `cd-blue-green.yml` e
`cd-blue-green-switch.yml`.

Substitui as seções 1 a 6 do guia manual
[`docs/cd-lab-vm-setup.md`](../docs/cd-lab-vm-setup.md), do starter-kit. O
resultado é o mesmo daquele passo a passo; a diferença é que o ambiente vira
código versionado, refazível com um comando e destruível com outro.

## O que é criado

| Recurso | Papel |
| --- | --- |
| Security group | Libera 22 para o pipeline entrar por SSH e 80 para abrir a aplicação no navegador |
| Instância EC2 | Amazon Linux 2023, `t3.small`, disco gp3 de 30 GB criptografado |
| Elastic IP | Mantém o `EC2_HOST` estável entre as sessões do Learner Lab |
| Bootstrap (`user_data.sh`) | Docker, kind, kubectl, cluster `devops-labs`, ingress-nginx, namespaces e a chave SSH gerada dentro da VM |

A VPC e a subnet são as padrão da conta, lidas por *data source*. Nada de rede
é criado.

## Uso

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

O bootstrap leva de 4 a 6 minutos depois que o `apply` retorna. Para acompanhar:

```bash
aws ec2 get-console-output --instance-id "$(terraform output -raw instance_id)" \
  --output text | tail -40
```

Ao final, `terraform output proximos_passos` imprime o que cadastrar no GitHub.

Para desfazer tudo:

```bash
terraform destroy
```

## Credenciais no AWS Academy Learner Lab

As credenciais do Learner Lab são temporárias e **expiram ao fim de cada
sessão**. A cada nova sessão:

1. Clique em **Start Lab** e espere o círculo ficar verde.
2. Abra **AWS Details → AWS CLI → Show**.
3. Copie o bloco exibido para `~/.aws/credentials`, substituindo o perfil
   `[default]`. São três linhas: `aws_access_key_id`, `aws_secret_access_key` e
   `aws_session_token`.
4. Confira com `aws sts get-caller-identity`.

O estado do Terraform é local (`terraform.tfstate`) e está no `.gitignore`, junto
com qualquer `*.tfvars`. Nenhum segredo entra no repositório.

## O que este código deliberadamente não faz

**Não gera a chave SSH.** O enunciado pede a chave criada dentro da VM, e é o
`user_data` que a gera. Fosse o Terraform a criar o par, a chave privada ficaria
no `terraform.tfstate`, que é um arquivo em texto puro.

**Não cria o `dockerhub-secret` no cluster.** Um token passado por variável
acabaria dentro do `user_data`, que qualquer processo rodando na instância lê
pelo metadata service. Esse passo continua manual, e está no output
`proximos_passos`.

## Limites do Learner Lab

- Só `us-east-1` (e, em algumas turmas, `us-west-2`).
- Não é possível criar roles do IAM. Este código não precisa de nenhuma.
- A instância é parada automaticamente quando a sessão termina. Com o Elastic IP
  associado, o endereço sobrevive ao stop/start e o `EC2_HOST` continua válido.
- Ao fim do curso: `terraform destroy`, e depois revogue o access token do Docker
  Hub e remova o webhook do Discord.

## Depois de um stop/start da instância

O cluster kind roda dentro de um container Docker. Parar a EC2 derruba esse
container de forma abrupta, e nem sempre o Docker o levanta sozinho no boot
seguinte. Se um workflow de CD falhar logo depois de uma retomada do lab, entre
na VM e confira:

```bash
docker ps -a --filter name=devops-labs
docker start devops-labs-control-plane   # se estiver como Exited
kubectl get nodes
```

O `docker start` recupera o cluster com os deployments e os secrets intactos: o
estado vive no volume do container, não no comando que o criou.
