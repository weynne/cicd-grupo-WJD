#!/bin/bash
# ABOUTME: Bootstrap da VM do laboratório: Docker, kind, kubectl, cluster e ingress.
# ABOUTME: Roda como root no primeiro boot, via cloud-init. Log em /var/log/cicd-lab-bootstrap.log.
set -euxo pipefail
exec > >(tee -a /var/log/cicd-lab-bootstrap.log) 2>&1

KIND_CLUSTER="${kind_cluster_name}"
KIND_VERSION="${kind_version}"
LAB_USER="ec2-user"
LAB_HOME="/home/$LAB_USER"

echo "=== 1/6 Docker ==="
dnf install -y docker
systemctl enable --now docker
usermod -aG docker "$LAB_USER"

echo "=== 2/6 kind e kubectl ==="
curl -fsSLo /usr/local/bin/kind \
  "https://kind.sigs.k8s.io/dl/$KIND_VERSION/kind-linux-amd64"
chmod +x /usr/local/bin/kind

KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
curl -fsSLo /usr/local/bin/kubectl \
  "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl"
chmod +x /usr/local/bin/kubectl

echo "=== 3/6 chave SSH gerada dentro da VM ==="
# O enunciado pede a chave gerada na própria VM. A privada fica só aqui; quem
# precisa dela copia uma vez pelo EC2 Instance Connect e cola no secret
# EC2_SSH_KEY do GitHub.
if [ ! -f "$LAB_HOME/.ssh/cicd-lab" ]; then
  runuser -l "$LAB_USER" -c \
    'ssh-keygen -t ed25519 -C "cicd-course" -f ~/.ssh/cicd-lab -N ""'
  runuser -l "$LAB_USER" -c \
    'cat ~/.ssh/cicd-lab.pub >> ~/.ssh/authorized_keys'
  chmod 600 "$LAB_HOME/.ssh/authorized_keys"
fi

echo "=== 4/6 cluster kind ==="
# apiServerAddress 0.0.0.0 permite falar com o control plane de fora do
# container. extraPortMappings 80 e 443 são o que faz o ingress-nginx do nó
# responder na porta pública da EC2. node-labels ingress-ready=true é o rótulo
# que o manifesto do ingress-nginx para kind exige no nó.
cat > /root/kind-config.yaml <<'KINDCONF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "0.0.0.0"
  apiServerPort: 6443
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
KINDCONF

kind create cluster --name "$KIND_CLUSTER" --config /root/kind-config.yaml --wait 5m

# O cluster é criado por root, mas quem entra por SSH é o ec2-user: o kubeconfig
# precisa estar na casa dele para os workflows de CD acharem o contexto.
install -d -o "$LAB_USER" -g "$LAB_USER" -m 700 "$LAB_HOME/.kube"
install -o "$LAB_USER" -g "$LAB_USER" -m 600 /root/.kube/config "$LAB_HOME/.kube/config"

echo "=== 5/6 ingress-nginx ==="
kubectl apply -f \
  https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

echo "=== 6/6 namespaces da aplicação ==="
# Criados aqui para que o secret do Docker Hub possa ser cadastrado antes do
# primeiro deploy. O workflow de Blue/Green copia esse secret de todolist para
# todolist-bg e falha se ele não existir.
kubectl create namespace todolist --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace todolist-bg --dry-run=client -o yaml | kubectl apply -f -

touch /var/lib/cloud/cicd-lab-ready
echo "=== bootstrap concluído ==="
