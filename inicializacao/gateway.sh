#!/bin/bash

# Saída para a Internet pela interface WAN (troca a rota padrão criada pelo Docker)
route del default
route add default gw 203.0.113.1

# Servidor DNS
echo nameserver 8.8.8.8 > /etc/resolv.conf

# Mantém o contêiner ligado
sleep infinity