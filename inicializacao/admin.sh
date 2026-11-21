#!/bin/bash

# Todo tráfego para fora da LAN passa obrigatoriamente pelo gateway
route del default
route add default gw 192.168.10.254

# Usuário Dheniel 
id dheniel >/dev/null 2>&1 || useradd -m -s /bin/bash dheniel

# Mantém o contêiner ligado
sleep infinity