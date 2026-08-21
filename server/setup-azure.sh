#!/usr/bin/env bash
# Bootstrap del servidor HogarQuest en una VM Azure (B1S, Ubuntu).
# Uso:  bash setup-azure.sh
set -euo pipefail

echo "== Actualizando paquetes =="
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg ufw git

echo "== Instalando Docker =="
if ! command -v docker >/dev/null; then
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
sudo systemctl enable --now docker

echo "== Clonando repositorio =="
if [ ! -d hogarquest ]; then
  git clone https://github.com/Legend-cop/hogarquest.git
fi
cd hogarquest/server

echo "== Levantando contenedor (API en :8080) =="
sudo docker compose up -d --build

echo "== Firewall =="
sudo ufw allow OpenSSH
sudo ufw allow 8080/tcp
sudo ufw --force enable

echo "== Listo =="
echo "La API escucha en :8080. Apunta Cloudflare (modo proxy) a la IP publica de la VM en el puerto 8080."
echo "Luego define la variable API_BASE_URL = https://api.TU-DOMINIO en GitHub y re-despliega web/APK."
