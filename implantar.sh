#!/bin/bash
# =====================================================================
# implantar.sh - Sobe o laboratório e aplica a segurança no gateway
# =====================================================================
set -eo pipefail   # pipefail: um erro em qualquer parte de um "|" também interrompe o script
docker compose up -d --build

# Estação admin: conta individual e par de chaves SSH de cada administrador.
# A chave pública vai para o gateway; a privada nunca sai da estação.
# (No laboratório a chave privada fica sem frase-senha para os testes rodarem sozinhos.)
docker exec gateway mkdir -p /opt/seguranca/chaves
for u in ana bruno; do
  docker exec admin bash -c "id $u >/dev/null 2>&1 || useradd -m -s /bin/bash $u"
  docker exec -u $u admin bash -c "[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_ed25519; cat ~/.ssh/id_ed25519.pub" \
    | docker exec -i gateway tee /opt/seguranca/chaves/$u.pub >/dev/null
done

# Segurança do gateway. A baseline de integridade vem por último,
# depois que o firewall e o hardening já alteraram os arquivos monitorados.
docker exec gateway /opt/seguranca/firewall.sh
docker exec gateway /opt/seguranca/hardening.sh
docker exec gateway /opt/seguranca/integridade.sh init