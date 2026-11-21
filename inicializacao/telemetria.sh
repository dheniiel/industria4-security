#!/bin/bash

# Todo tráfego para fora da rede OT passa obrigatoriamente pelo gateway
route del default
route add default gw 192.168.20.254

# Usuário Felipe 
id felipe >/dev/null 2>&1 || useradd -m -s /bin/bash felipe

# Par de chaves GPG do Felipe
su - felipe -c "gpg -k felipe@industria4.local >/dev/null 2>&1 || gpg --batch --passphrase '' --quick-gen-key 'felipe <felipe@industria4.local>'"

# Par de chaves SSH do Felipe (a pública vai para o gateway pelo implantar.sh)
su - felipe -c "[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_ed25519"

# Serviços simulados: painel 80, banco 5432 e CLP Modbus 502.
# São servidores HTTP simples que publicam a pasta /tmp 
cd /tmp
python3 -m http.server 80 &
python3 -m http.server 5432 &
python3 -m http.server 502 &

# Mantém o contêiner ligado
sleep infinity