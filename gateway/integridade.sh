# =====================================================================
# integridade.sh - Auditoria de integridade com SHA-256 
#   init       -> cria a linha de base (baseline) dos hashes
#   verificar  -> recalcula e compara; alerta na tela e no log se algo mudou
# Agendado no /etc/crontab a cada 5 minutos (hardening.sh).
# =====================================================================
ARQUIVOS="/etc/passwd /etc/shadow /etc/iptables/rules.v4"
BASE=/var/lib/integridade/baseline.sha256
LOG=/var/log/integridade.log

case "$1" in
  init)
    mkdir -p /var/lib/integridade && chmod 700 /var/lib/integridade
    sha256sum $ARQUIVOS > "$BASE" && chmod 600 "$BASE"
    echo "$(date '+%F %T') BASELINE criada" >> "$LOG"
    cat "$BASE"
    ;;
  verificar)
    FALHAS=$(sha256sum -c --quiet "$BASE" 2>/dev/null)
    if [ -n "$FALHAS" ]; then
      echo "$FALHAS" | while read -r l; do echo "$(date '+%F %T') ALERTA: alteração não autorizada -> $l" >> "$LOG"; done
      echo -e "\e[1;41m ALERTA DE INTEGRIDADE \e[0m\n$FALHAS\nDetalhes em $LOG"
      exit 1
    fi
    echo "$(date '+%F %T') OK: integridade verificada" >> "$LOG"
    echo -e "\e[1;32mOK\e[0m integridade preservada"
    ;;
  *)
    echo "Uso: $0 {init|verificar}"; exit 2 ;;
esac
