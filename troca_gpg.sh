#!/bin/bash
# =====================================================================
# troca_gpg.sh - Gestão de chaves GPG e troca cifrada de credenciais
#   Ana   (estação admin, 192.168.10.10)  -> remetente
#   Bruno (servidor gateway)              -> destinatário
# O transporte dos arquivos usa scp na porta 2222, já com o SSH endurecido.
# Executar na máquina hospedeira, depois do implantar.sh.
# (As frases-senha ficam no script só para a demonstração rodar sozinha.)
# =====================================================================
set -e
SENHA_ANA="frase longa da Ana para o laboratorio OT"
SENHA_BRUNO="frase longa do Bruno para o laboratorio OT"
GW=192.168.10.254
SCP="scp -q -P 2222 -o StrictHostKeyChecking=accept-new"
LOOP="--batch --yes --pinentry-mode loopback"

gerar_chave() {  # $1=container $2=usuario $3=nome $4=frase-senha
  docker exec -u "$2" "$1" bash -c "gpg --list-keys '$3' >/dev/null 2>&1 || \
    gpg $LOOP --passphrase '$4' --quick-generate-key '$3 <$2@industria.local>'"
}

echo "### 1. Geração dos pares de chaves (chave de assinatura + subchave de cifragem)"
gerar_chave admin   ana   "Ana Admin"   "$SENHA_ANA"
gerar_chave gateway bruno "Bruno Admin" "$SENHA_BRUNO"

echo "### 2. Exportação das chaves públicas (gpg -a --export) e troca via scp"
docker exec -u bruno gateway bash -c "gpg -a --export 'Bruno Admin' > /srv/troca/bruno.asc"
docker exec -u ana admin bash -c "gpg -a --export 'Ana Admin' > ~/ana.asc && \
  $SCP ~/ana.asc ana@$GW:/srv/troca/ && $SCP ana@$GW:/srv/troca/bruno.asc ~/"

echo "### 3. Importação, conferência da impressão digital e assinatura cruzada"
docker exec -u ana admin bash -c "gpg --import ~/bruno.asc && gpg --fingerprint 'Bruno Admin' && \
  gpg $LOOP --passphrase '$SENHA_ANA' --sign-key 'Bruno Admin'"
docker exec -u bruno gateway bash -c "gpg --import /srv/troca/ana.asc && gpg --fingerprint 'Ana Admin' && \
  gpg $LOOP --passphrase '$SENHA_BRUNO' --sign-key 'Ana Admin'"
docker exec -u ana admin gpg --list-sigs 'Bruno Admin'

echo "### 4. Ana cria o arquivo sensível, assina e cifra para o Bruno (gpg -s -e -r)"
docker exec -u ana admin bash -c "umask 077 && cat > ~/credenciais_scada.conf <<'EOF'
# Credenciais do banco de telemetria industrial - CONFIDENCIAL
DB_HOST=192.168.20.10
DB_PORT=5432
DB_USER=telemetria_rw
DB_PASS=Tm#2026!plantaA
API_TOKEN=ot-9f3c1a7e5b2d4c8a
EOF
gpg $LOOP --passphrase '$SENHA_ANA' -a -s -r 'Bruno Admin' -e ~/credenciais_scada.conf && \
chmod 640 ~/credenciais_scada.conf.asc && \
$SCP ~/credenciais_scada.conf.asc ana@$GW:/srv/troca/ && \
shred -u ~/credenciais_scada.conf && echo 'Texto claro apagado na origem (shred).'"

echo "### 5. Conteúdo que trafegou/ficou armazenado (ilegível sem a chave privada do Bruno)"
docker exec gateway head -n 4 /srv/troca/credenciais_scada.conf.asc

echo "### 6. Bruno decifra e verifica a assinatura da Ana (gpg -d)"
docker exec -u bruno gateway bash -c "umask 077 && \
  gpg $LOOP --passphrase '$SENHA_BRUNO' -d /srv/troca/credenciais_scada.conf.asc > ~/credenciais_scada.conf && \
  ls -l ~/credenciais_scada.conf && cat ~/credenciais_scada.conf"

echo "### 7. Um terceiro (root da estação admin, sem a chave do Bruno) não consegue ler"
docker exec -u ana admin bash -c "$SCP ana@$GW:/srv/troca/credenciais_scada.conf.asc /tmp/c.asc"
docker exec admin bash -c "gpg --batch -d /tmp/c.asc 2>&1 | tail -n 1 || true"
