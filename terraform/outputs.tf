# ABOUTME: O que sai do apply e vai direto para os secrets e variables do GitHub.
# ABOUTME: Nenhum valor sensível aqui: a chave privada nunca sai da VM.

output "ec2_host" {
  description = "Valor do secret EC2_HOST. Com Elastic IP, não muda entre sessões do lab."
  value       = var.allocate_eip ? aws_eip.lab[0].public_ip : aws_instance.lab.public_ip
}

output "ec2_user" {
  description = "Valor do secret EC2_USER."
  value       = "ec2-user"
}

output "kind_cluster" {
  description = "Valor da variable KIND_CLUSTER."
  value       = var.kind_cluster_name
}

output "instance_id" {
  description = "ID da instância, usado para abrir o EC2 Instance Connect no console."
  value       = aws_instance.lab.id
}

output "proximos_passos" {
  description = "O que fazer depois do apply."
  value       = <<-EOT

    1. Acompanhe o bootstrap (leva de 4 a 6 minutos):

         aws ec2 get-console-output --instance-id ${aws_instance.lab.id} --output text | tail -40

    2. No console da AWS, abra a instância ${aws_instance.lab.id} em
       Connect > EC2 Instance Connect e copie a chave privada:

         cat ~/.ssh/cicd-lab

    3. Cadastre no GitHub, em Settings > Secrets and variables > Actions:

         EC2_HOST     = ${var.allocate_eip ? aws_eip.lab[0].public_ip : aws_instance.lab.public_ip}
         EC2_USER     = ec2-user
         EC2_SSH_KEY  = a chave privada inteira, com as linhas BEGIN e END
         KIND_CLUSTER = ${var.kind_cluster_name}   (aba Variables, não Secrets)

    4. Ainda na VM, crie o secret que o cluster usa para puxar a imagem:

         kubectl create secret docker-registry dockerhub-secret \
           --docker-server=https://index.docker.io/v1/ \
           --docker-username=SEU_USUARIO \
           --docker-password='SEU_TOKEN_SOMENTE_LEITURA' \
           -n todolist

    5. Rode o workflow Validate SSH to EC2 pela aba Actions. Verde ali significa
       que o canal do CD está de pé.

  EOT
}
