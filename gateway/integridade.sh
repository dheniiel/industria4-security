#!/bin/bash
# =====================================================================
# integridade.sh - Auditoria de integridade com SHA-256
# =====================================================================
ARQUIVOS="/etc/passwd /etc/shadow /etc/iptables/rules.v4"
BASE=/var/lib/integridade/baseline.sha256
LOG=/var/log/integridade.log

log() { echo "$(date '+%F %T') $1" >> "$LOG"; }

case "$1" in
  init)
    mkdir -p -m 700 "${BASE%/*}"
    sha256sum $ARQUIVOS > "$BASE" && chmod 600 "$BASE"
    log "BASELINE criada"
    cat "$BASE"
    ;;
  verificar)
    # diff compara os hashes guardados (<) com os recalculados agora (>); sem diferença, ele termina com sucesso
    if DIFERENCAS=$(sha256sum $ARQUIVOS | diff "$BASE" - 2>&1); then
      log "OK: integridade verificada"
      echo -e "\e[1;32mOK\e[0m integridade preservada"
    else
      log "ALERTA: alteração não autorizada"$'\n'"$DIFERENCAS"
      echo -e "\e[1;41m ALERTA DE INTEGRIDADE \e[0m\n$DIFERENCAS\nDetalhes em $LOG"
      exit 1
    fi
    ;;
  *)
    echo "Uso: $0 {init|verificar}"; exit 2 ;;
esac