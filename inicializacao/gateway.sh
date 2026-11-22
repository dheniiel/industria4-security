#!/bin/bash

# Saída para a Internet pela interface WAN (troca a rota padrão criada pelo Docker)
route del default
route add default gw 203.0.113.1

# Servidor DNS
echo nameserver 8.8.8.8 > /etc/resolv.conf

# Reaplica a segurança a cada inicialização (as configurações já ficam gravadas no contêiner)
/opt/seguranca/firewall.sh
service ssh start
service cron start

# Mantém o contêiner ligado
sleep infinity