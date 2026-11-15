#!/bin/bash
# =====================================================================
# hardening.sh - Hardening do Ubuntu Server
# Pré-requisito: chaves públicas SSH dos administradores em
# /opt/seguranca/chaves/<usuario>.pub (o implantar.sh as copia da estação admin)
# =====================================================================
ADMINS="ana bruno"
ESTACAO=192.168.10.10        # única estação de onde os administradores podem entrar

echo "== 1. Atualização de segurança =="
apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

echo "== 2. Remoção de pacotes desnecessários (telnet, ftp, rsh) =="
apt-get -y purge telnet inetutils-telnet ftp tnftp rsh-redone-client
apt-get -y autoremove --purge

echo "== 3. Administradores: contas nominais, sem senha, só chave =="
groupadd -f adminseg
PERMITIDOS=""
for u in $ADMINS; do
  id "$u" >/dev/null 2>&1 || useradd -m -s /bin/bash -G adminseg "$u"
  install -d -m 700 -o "$u" -g "$u" /home/$u/.ssh
  install -m 600 -o "$u" -g "$u" /opt/seguranca/chaves/$u.pub /home/$u/.ssh/authorized_keys
  PERMITIDOS="$PERMITIDOS $u@$ESTACAO"
done
install -d -m 2770 -o root -g adminseg /srv/troca    # pasta de troca de arquivos GPG

echo "== 4. SSH =="
cat > /etc/ssh/sshd_config.d/00-hardening.conf <<EOF
# Porta padrão alterada; escuta só na LAN
Port 2222
ListenAddress 192.168.10.254
# Sem login direto do root
PermitRootLogin no
# Só a equipe de administradores, e só a partir da estação de administração
AllowUsers$PERMITIDOS
# Autenticação exclusiva por chave pública/privada
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
MaxAuthTries 3
EOF
chmod 600 /etc/ssh/sshd_config /etc/ssh/sshd_config.d/00-hardening.conf
sshd -t && service ssh restart

echo "== 5. Permissões em diretórios críticos =="
chown root:root /etc /etc/passwd /etc/group;  chmod 755 /etc;  chmod 644 /etc/passwd /etc/group
chown root:shadow /etc/shadow /etc/gshadow;   chmod 640 /etc/shadow /etc/gshadow
find /etc -xdev -type f -perm -o+w -exec chmod o-w {} +          # nada gravável por "outros"
chmod -R o-rwx /var/log                                          # logs fechados para "outros"

echo "== 6. Tarefas periódicas (crontab) =="
grep -q integridade.sh /etc/crontab || cat >> /etc/crontab <<'EOF'
*/5 * * * * root /opt/seguranca/integridade.sh verificar
30 3 * * * root apt-get update -q && DEBIAN_FRONTEND=noninteractive apt-get -y upgrade >> /var/log/atualizacoes.log 2>&1
EOF
service cron start
echo "Hardening concluído."
