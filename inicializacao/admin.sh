#!/bin/bash

# Todo tráfego para fora da LAN passa obrigatoriamente pelo gateway
route del default
route add default gw 192.168.10.254

# Usuário Dheniel 
id dheniel >/dev/null 2>&1 || useradd -m -s /bin/bash dheniel

# Par de chaves GPG do Dheniel
su - dheniel -c "gpg -k dheniel@industria4.local >/dev/null 2>&1 || gpg --batch --passphrase '' --quick-gen-key 'dheniel <dheniel@industria4.local>'"

# Par de chaves SSH do Dheniel (a pública vai para o gateway pelo implantar.sh)
su - dheniel -c "[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_ed25519"

# Remove ferramentas desnecessárias: varredura de portas (nmap) e acesso remoto sem criptografia (telnet)
apt-get -y -qq purge nmap telnet inetutils-telnet >/dev/null 2>&1

# Mantém o contêiner ligado
sleep infinity