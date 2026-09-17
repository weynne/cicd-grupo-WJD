# ABOUTME: Provisiona a EC2 do laboratório de CD, com kind e ingress-nginx prontos.
# ABOUTME: Substitui as seções 1 a 6 do guia manual docs/cd-lab-vm-setup.md.
#
# O que este arquivo NÃO faz, de propósito:
#
#   - Não cria a chave SSH. O enunciado pede a chave gerada DENTRO da VM, então
#     quem a gera é o user_data. Assim a chave privada nunca passa pelo estado
#     do Terraform, que é um arquivo em texto puro.
#   - Não cria o secret do Docker Hub no cluster. Um token passado por variável
#     acabaria no user_data, legível por qualquer processo da instância através
#     do metadata service.

# A conta do Learner Lab já vem com a VPC padrão e uma subnet pública por AZ.
# Criar uma VPC nova só acrescentaria recursos para dar manutenção.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# A AMI mais recente do Amazon Linux 2023, resolvida no momento do plano. Fixar
# um ID de AMI quebraria o plano na semana seguinte, quando a Amazon publica a
# imagem nova e aposenta a antiga.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_security_group" "lab" {
  name        = "${var.project_name}-sg"
  description = "Acesso ao laboratorio de CD: SSH para o pipeline e HTTP para o Ingress"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# Por onde o job de CD entra para rodar kubectl.
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.lab.id
  description       = "SSH usado pelo GitHub Actions e pelo EC2 Instance Connect"
  cidr_ipv4         = var.ssh_ingress_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

# Por onde a aplicação é aberta no navegador, via ingress-nginx.
resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.lab.id
  description       = "HTTP do ingress-nginx"
  cidr_ipv4         = var.http_ingress_cidr
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# Saída liberada: a instância baixa pacotes, imagens do kind e a imagem da
# aplicação no Docker Hub.
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.lab.id
  description       = "Saida liberada para baixar pacotes e imagens"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "lab" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.lab.id]
  associate_public_ip_address = true

  # IMDSv2 obrigatório: sem isso o metadata service responde a qualquer
  # requisição HTTP simples que rode na instância.
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    kind_cluster_name = var.kind_cluster_name
    kind_version      = var.kind_version
  })

  # Trocar o conteúdo do bootstrap recria a instância: o user_data só roda uma
  # vez, no primeiro boot, então editá-lo sem recriar não teria efeito nenhum.
  user_data_replace_on_change = true

  tags = {
    Name = "${var.project_name}-kind"
  }
}

# O Learner Lab para a instância ao fim de cada sessão, e no start seguinte o IP
# público muda. O Elastic IP mantém o endereço, e com ele o secret EC2_HOST
# continua valendo de uma sessão para a outra.
resource "aws_eip" "lab" {
  count    = var.allocate_eip ? 1 : 0
  instance = aws_instance.lab.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-eip"
  }
}
