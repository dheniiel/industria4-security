#!/bin/bash
# =====================================================================
# implantar.sh - Sobe o laboratório e aplica a segurança no gateway
# =====================================================================
set -eo pipefail   # pipefail: um erro em qualquer parte de um "|" também interrompe o script
docker compose up -d --build

# Aguarda a inicialização dos contêineres gerar as chaves SSH (admin.sh e telemetria.sh)
until docker exec admin test -f /home/dheniel/.ssh/id_ed25519.pub && docker exec telemetria test -f /home/felipe/.ssh/id_ed25519.pub; do sleep 1; done

# A chave pública de cada administrador vai para o gateway (hardening.sh); a privada nunca sai do contêiner
docker exec gateway mkdir -p /opt/seguranca/chaves
docker exec admin      cat /home/dheniel/.ssh/id_ed25519.pub | docker exec -i gateway tee /opt/seguranca/chaves/dheniel.pub >/dev/null
docker exec telemetria cat /home/felipe/.ssh/id_ed25519.pub  | docker exec -i gateway tee /opt/seguranca/chaves/felipe.pub  >/dev/null

# Segurança do gateway. A baseline de integridade vem por último,
# depois que o firewall e o hardening já alteraram os arquivos monitorados.
docker exec gateway /opt/seguranca/firewall.sh
docker exec gateway /opt/seguranca/hardening.sh
docker exec gateway /opt/seguranca/integridade.sh init