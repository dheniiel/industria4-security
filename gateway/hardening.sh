#!/bin/bash
# =====================================================================
# hardening.sh - Hardening do gateway (Ubuntu)
# =====================================================================
ADMINS="dheniel felipe"      # usuários criados pelos contêineres admin e telemetria

# 1. Atualização de segurança do sistema
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

# 2. Remoção de pacotes desnecessários (clientes inseguros, sem criptografia)
apt-get -y purge telnet inetutils-telnet ftp tnftp rsh-redone-client nmap
apt-get -y autoremove --purge

# 3. Contas dos administradores, com acesso só por chave
groupadd -f adminseg
for u in $ADMINS; do
  id "$u" >/dev/null 2>&1 || useradd -m -s /bin/bash "$u"     # criada sem senha
  usermod -aG adminseg "$u"
  mkdir -p /home/$u/.ssh
  cp /opt/seguranca/chaves/$u.pub /home/$u/.ssh/authorized_keys
  chown -R "$u":"$u" /home/$u/.ssh
  chmod 700 /home/$u/.ssh
  chmod 600 /home/$u/.ssh/authorized_keys
done

# Pasta de troca de arquivos GPG (troca_gpg.sh). Só o grupo adminseg entra;
mkdir -p /srv/troca
chown root:adminseg /srv/troca
chmod 770 /srv/troca

# 4. SSH
cat > /etc/ssh/sshd_config <<EOF
# Porta padrão (22) alterada
Port 2222
# Sem login direto do root
PermitRootLogin no
# Só os administradores
AllowUsers $ADMINS
# Autenticação exclusiva por chave pública/privada
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
# Necessárias para o sistema: PAM (contas sem senha) e SFTP (usado pelo scp)
UsePAM yes
Subsystem sftp /usr/lib/openssh/sftp-server
EOF
sshd -t && service ssh restart

# 5. Permissões em diretórios críticos
chown root:root /etc && chmod 755 /etc
chmod -R o-w /etc                                     # nada em /etc gravável por "outros"
chown root:shadow /etc/shadow /etc/gshadow && chmod 640 /etc/shadow /etc/gshadow
chmod 600 /etc/ssh/sshd_config
chmod -R o-rwx /var/log      

# Auditoria de integridade (integridade.sh) a cada 5 minutos pelo cron
grep -q integridade.sh /etc/crontab || echo "*/5 * * * * root /opt/seguranca/integridade.sh verificar >/dev/null" >> /etc/crontab
service cron start