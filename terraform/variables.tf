# ABOUTME: Entradas do laboratório de CD, com padrões que já servem ao Learner Lab.
# ABOUTME: Quem quiser outro cluster ou outro tipo de instância muda só aqui.

variable "aws_region" {
  description = "Região da AWS. O Learner Lab libera us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefixo dos nomes dos recursos criados."
  type        = string
  default     = "cicd-wjd"
}

variable "instance_type" {
  description = <<-EOT
    Tipo da instância EC2. O t3.small é o mínimo confortável: o cluster kind
    sobe o control plane e o ingress-nginx no mesmo nó.
  EOT
  type        = string
  default     = "t3.small"
}

variable "root_volume_size" {
  description = <<-EOT
    Tamanho do disco em GB. O padrão da AMI (8 GB) não acomoda as imagens do
    kind, do ingress-nginx e da aplicação com folga.
  EOT
  type        = number
  default     = 30
}

variable "kind_cluster_name" {
  description = <<-EOT
    Nome do cluster kind. Precisa ser igual à variable KIND_CLUSTER do
    repositório no GitHub, que os workflows de CD usam no kubectl config
    use-context.
  EOT
  type        = string
  default     = "devops-labs"
}

variable "kind_version" {
  description = "Versão do kind instalada na VM."
  type        = string
  default     = "v0.24.0"
}

variable "ssh_ingress_cidr" {
  description = <<-EOT
    De onde a porta 22 aceita conexão. O runner do GitHub Actions não tem faixa
    de IP fixa e previsível, então o laboratório abre para 0.0.0.0/0 e se apoia
    na chave SSH. Quem quiser restringir, troque aqui.
  EOT
  type        = string
  default     = "0.0.0.0/0"
}

variable "http_ingress_cidr" {
  description = "De onde a porta 80 aceita conexão, usada para abrir a aplicação no navegador."
  type        = string
  default     = "0.0.0.0/0"
}

variable "allocate_eip" {
  description = <<-EOT
    Associa um Elastic IP à instância. É o que impede o EC2_HOST de mudar a cada
    stop/start do Learner Lab. Desligue só se a conta não permitir alocar EIP.
  EOT
  type        = bool
  default     = true
}
