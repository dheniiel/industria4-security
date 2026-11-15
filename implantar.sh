#!/bin/bash
# =====================================================================
# implantar.sh - Sobe o laboratório e aplica a segurança no gateway
# Executar na máquina hospedeira, na pasta do projeto.
# =====================================================================
set -e
docker compose up -d --build

# Estação admin: conta individual e par de chaves SSH de cada administrador.
# A chave pública vai para o gateway; a privada nunca sai da estação.
# (No laboratório a chave privada fica sem frase-senha para os testes rodarem sozinhos.)
docker exec gateway mkdir -p /opt/seguranca/chaves
for u in ana bruno; do
  docker exec admin bash -c "id $u >/dev/null 2>&1 || useradd -m -s /bin/bash $u"
  docker exec -u $u admin bash -c "[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_ed25519"
  docker exec -u $u admin cat /home/$u/.ssh/id_ed25519.pub | docker exec -i gateway tee /opt/seguranca/chaves/$u.pub >/dev/null
done

docker exec gateway /opt/seguranca/firewall.sh
docker exec gateway /opt/seguranca/hardening.sh
docker exec gateway /opt/seguranca/integridade.sh init    # baseline só depois do hardening
