#!/bin/bash

# Ensina o caminho até as redes internas (192.168.0.0/16), ou seja, bater na porta WAN do gateway.
route add -net 192.168.0.0 netmask 255.255.0.0 gw 203.0.113.2

# Mantém o contêiner ligado
sleep infinity