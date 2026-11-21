#!/bin/bash
# =====================================================================
# firewall.sh - Firewall do gateway (iptables)
#   WAN 203.0.113.2 | LAN 192.168.10.254 | OT/SCADA 192.168.20.254
# =====================================================================

# Nome de cada interface pelo IP (o Docker não garante a ordem eth0/eth1/eth2)
iface() { ip -o -4 addr show to "$1" | awk '{print $2}'; }
WAN=$(iface 203.0.113.2); LAN=$(iface 192.168.10.254); OT=$(iface 192.168.20.254)

ADMIN=192.168.10.10        # estação de administração
TELEMETRIA=192.168.20.10   # painel e banco de dados industrial

# 1. Limpa as regras e define a política padrão: bloquear tudo
iptables -F; iptables -X; iptables -t nat -F
iptables -P INPUT   DROP
iptables -P FORWARD DROP
iptables -P OUTPUT  ACCEPT

# 2. Proteções que valem para o gateway (INPUT) e para quem passa por ele (FORWARD)
iptables -A INPUT -i lo -j ACCEPT
for C in INPUT FORWARD; do
  # Anti-varredura: pacotes que nenhuma conexão normal usa
  iptables -A $C -m conntrack --ctstate INVALID -j DROP                # pacote fora de qualquer conexão
  iptables -A $C -p tcp --tcp-flags ALL NONE -j DROP                   # NULL scan (sem flags)
  iptables -A $C -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP            # XMAS scan
  iptables -A $C -p tcp ! --syn -m conntrack --ctstate NEW -j DROP     # conexão nova sem SYN

  # Respostas de conexões já autorizadas
  iptables -A $C -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

  # Anti-DoS: no máximo 20 conexões novas por segundo POR IP (rajada de 40)
  iptables -A $C -p tcp --syn -m hashlimit --hashlimit-above 20/sec --hashlimit-burst 40 --hashlimit-mode srcip --hashlimit-name dos_$C -j DROP
done

# O gateway só aceita SSH (porta 2222) do admin (dheniel) e da telemetria (felipe), no máximo 4 conexões por minuto (anti-força bruta)
iptables -A INPUT -i $LAN -s $ADMIN -p tcp --dport 2222 -m limit --limit 4/min --limit-burst 5 -j ACCEPT
iptables -A INPUT -i $OT  -s $TELEMETRIA -p tcp --dport 2222 -m limit --limit 4/min --limit-burst 5 -j ACCEPT

# Só o necessário entre as redes
iptables -A FORWARD -i $LAN -o $OT  -d $TELEMETRIA -p tcp --dport 80   -j ACCEPT    # LAN -> painel (HTTP)
iptables -A FORWARD -i $LAN -o $OT  -s $ADMIN -d $TELEMETRIA -p tcp --dport 5432 -j ACCEPT  # admin -> banco
iptables -A FORWARD -i $LAN -o $WAN -p tcp -m multiport --dports 53,80,443 -j ACCEPT # LAN -> Internet (DNS, HTTP, HTTPS)
iptables -A FORWARD -i $LAN -o $WAN -p udp --dport 53 -j ACCEPT                      # LAN -> Internet (DNS)

# O gateway não inicia conexões para a OT
iptables -A OUTPUT -o $OT -m conntrack --ctstate NEW -j DROP

# Só a LAN sai para a Internet, com o IP da WAN do gateway
iptables -t nat -A POSTROUTING -o $WAN -s 192.168.10.0/24 -j MASQUERADE

# Salva as regras para o integridade.sh (sem data e sem contadores, para o hash só mudar quando as REGRAS mudarem)
mkdir -p /etc/iptables
iptables-save | sed -e '/^#/d' -e 's/ \[[0-9]*:[0-9]*\]//' > /etc/iptables/rules.v4
chmod 600 /etc/iptables/rules.v4
echo "Firewall aplicado (WAN=$WAN LAN=$LAN OT=$OT)"