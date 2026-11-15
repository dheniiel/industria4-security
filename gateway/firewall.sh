# =====================================================================
# firewall.sh - Firewall perimetral do servidor Ubuntu (gateway)
#   WAN 203.0.113.2 | LAN 192.168.10.254 | OT/SCADA 192.168.20.254
# =====================================================================

# Descobre o nome de cada interface pelo seu IP estático (o Docker Compose não garante
# a ordem eth0/eth1/eth2 ao ligar o container às redes)
interface() { ip -o -4 addr show | awk -v ip="$1" '$4 ~ "^"ip"/" {print $2}'; }
WAN=$(interface 203.0.113.2); LAN=$(interface 192.168.10.254); OT=$(interface 192.168.20.254)
echo "Interfaces: WAN=$WAN  LAN=$LAN  OT=$OT"
REDE_LAN=192.168.10.0/24
ADMIN=192.168.10.10          # estação de administração (única com SSH e acesso ao banco)
TELEMETRIA=192.168.20.10     # servidor de telemetria/banco de dados industrial
SSH=2222

# 1. Roteamento (ip_forward já ligado pelo "docker run --sysctl"; aqui só conferimos)
[ "$(cat /proc/sys/net/ipv4/ip_forward)" = "1" ] || echo "AVISO: ip_forward desligado!"

# 2. Limpeza de regras, chains e contadores
iptables -F; iptables -t nat -F; iptables -X; iptables -Z

# 3. Política padrão restritiva 
iptables -P INPUT   DROP
iptables -P FORWARD DROP
iptables -P OUTPUT  ACCEPT

# 4. Chains de usuário 
#    ANTI_SCAN: flags TCP que só aparecem em varreduras (NULL, XMAS, SYN+FIN) e
#    pacotes INVALID (ex.: FIN/ACK scan)
iptables -N ANTI_SCAN
iptables -A ANTI_SCAN -p tcp --tcp-flags ALL NONE        -j DROP
iptables -A ANTI_SCAN -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP
iptables -A ANTI_SCAN -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
iptables -A ANTI_SCAN -m state --state INVALID -m limit --limit 2/min -j LOG --log-prefix "[FW SCAN] "
iptables -A ANTI_SCAN -m state --state INVALID -j DROP

#    LIMITE_DOS: no máximo 20 novas conexões TCP por segundo (rajada de 40)
iptables -N LIMITE_DOS
iptables -A LIMITE_DOS -m limit --limit 20/s --limit-burst 40 -j RETURN
iptables -A LIMITE_DOS -m limit --limit 2/min -j LOG --log-prefix "[FW DOS] "
iptables -A LIMITE_DOS -j DROP

# 5. Proteções gerais e regra de ouro stateful 
iptables -A INPUT -i lo -j ACCEPT
for CHAIN in INPUT FORWARD; do
  iptables -A $CHAIN -j ANTI_SCAN
  iptables -A $CHAIN -m state --state ESTABLISHED,RELATED -j ACCEPT
  iptables -A $CHAIN -p tcp --syn -j LIMITE_DOS
done

# 6. INPUT - serviços do próprio servidor
#    SSH: só da estação admin, porta 2222, máx. 4 conexões/min (força bruta)
iptables -A INPUT -i $LAN -s $ADMIN -p tcp --dport $SSH -m state --state NEW -m limit --limit 4/min --limit-burst 5 -j ACCEPT
iptables -A INPUT -p tcp --dport $SSH -m limit --limit 2/min -j LOG --log-prefix "[FW SSH NEGADO] "

#    Ping: só da LAN, limitado (anti ping-flood)
iptables -A INPUT -i $LAN -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT
iptables -A INPUT -i $WAN -m limit --limit 2/min -j LOG --log-prefix "[FW WAN BLOQUEADO] "

# 7. FORWARD - tráfego entre as redes 
#    LAN -> telemetria: painel 80/443 para a LAN; banco 5432 só para a estação admin.
#    O Modbus (502, sem senha) nunca é liberado: fica restrito à própria OT.
iptables -A FORWARD -i $LAN -o $OT -s $REDE_LAN -d $TELEMETRIA -p tcp -m multiport --dports 80,443 -m state --state NEW -j ACCEPT
iptables -A FORWARD -i $LAN -o $OT -s $ADMIN -d $TELEMETRIA -p tcp --dport 5432 -m state --state NEW -j ACCEPT

#    LAN -> Internet: HTTP/HTTPS e DNS (com NAT, seção 9)
iptables -A FORWARD -i $LAN -o $WAN -s $REDE_LAN -p tcp -m multiport --dports 80,443,53 -m state --state NEW -j ACCEPT
iptables -A FORWARD -i $LAN -o $WAN -s $REDE_LAN -p udp --dport 53 -m state --state NEW -j ACCEPT

#    Todo o resto (WAN -> LAN/OT, OT -> qualquer lugar, LAN -> 502...) é registrado e cai no DROP
iptables -A FORWARD -m limit --limit 2/min -j LOG --log-prefix "[FW FORWARD NEGADO] "

# 8. OUTPUT - o servidor de borda não inicia conexões para a OT:
#    se ele for invadido, não vira trampolim até o chão de fábrica
iptables -A OUTPUT -o $OT -m state --state NEW -m limit --limit 2/min -j LOG --log-prefix "[FW GATEWAY->OT] "
iptables -A OUTPUT -o $OT -m state --state NEW -j DROP

# 9. NAT: só a LAN sai para a Internet; a OT não tem saída 
iptables -t nat -A POSTROUTING -o $WAN -s $REDE_LAN -j MASQUERADE

# 10. Salva as regras (auditadas pelo integridade.sh). Sem comentários de data
#     nem contadores, para o hash só mudar quando as REGRAS mudarem.
mkdir -p /etc/iptables
iptables-save | sed -e '/^#/d' -e 's/ \[[0-9]*:[0-9]*\]//' > /etc/iptables/rules.v4
chmod 600 /etc/iptables/rules.v4
echo "Firewall aplicado e salvo em /etc/iptables/rules.v4"
