#!/bin/bash
# =====================================================================
# troca_gpg.sh - Troca de chaves públicas GPG e de um arquivo cifrado entre os administradores, com o gateway como "correio"
# =====================================================================

set -e
CORREIO=/srv/troca
docker exec gateway mkdir -p $CORREIO

# 1. Cada administrador deposita a sua chave pública no correio
docker exec -u dheniel admin     gpg --armor --export dheniel@industria4.local | docker exec -i gateway tee $CORREIO/dheniel.asc >/dev/null
docker exec -u felipe  telemetria gpg --armor --export felipe@industria4.local  | docker exec -i gateway tee $CORREIO/felipe.asc  >/dev/null

# 2. Cada um retira do correio a chave do colega e importa
docker exec gateway cat $CORREIO/felipe.asc  | docker exec -i -u dheniel admin      gpg --import
docker exec gateway cat $CORREIO/dheniel.asc | docker exec -i -u felipe  telemetria gpg --import

# 3. Cada um assina a chave recebida do correio usando a impressão digital informada pelo PRÓPRIO dono. Se o correio entregou outra chave, a impressão digital não bate, a assinatura falha e o script para.
FPR_FELIPE=$(docker exec -u felipe telemetria gpg --with-colons -k felipe@industria4.local | awk -F: '/^fpr/{print $10; exit}')
FPR_DHENIEL=$(docker exec -u dheniel admin    gpg --with-colons -k dheniel@industria4.local | awk -F: '/^fpr/{print $10; exit}')
echo "dheniel assina a chave de felipe: $FPR_FELIPE"
docker exec -u dheniel admin      gpg --batch --yes --quick-sign-key $FPR_FELIPE
echo "felipe assina a chave de dheniel: $FPR_DHENIEL"
docker exec -u felipe  telemetria gpg --batch --yes --quick-sign-key $FPR_DHENIEL

# Mostra as assinaturas: cada chave recebida agora está assinada pelo colega
docker exec -u dheniel admin      gpg --check-sigs felipe@industria4.local
docker exec -u felipe  telemetria gpg --check-sigs dheniel@industria4.local

# 4. dheniel cifra para felipe e assina um arquivo com credenciais, e deposita no correio
docker exec -u dheniel admin bash -c "umask 077; printf 'DB_HOST=192.168.20.10\nDB_USER=scada\nDB_PASS=S3nh@-Sup3r-Secr3ta\nAPI_TOKEN=tk_live_9f8e7d6c5b4a3210\n' > ~/config.env"
docker exec -u dheniel admin gpg --batch --armor --sign --encrypt -r $FPR_FELIPE -o - /home/dheniel/config.env | docker exec -i gateway tee $CORREIO/config.env.asc >/dev/null

# 5. O correio guarda o arquivo, mas não consegue ler. Não tem a chave privada de felipe
docker exec gateway head -n 3 $CORREIO/config.env.asc
docker exec gateway gpg --batch --decrypt $CORREIO/config.env.asc || echo "O gateway não consegue decifrar o arquivo"

# 6. felipe retira do correio, decifra e confere a assinatura de dheniel
docker exec gateway cat $CORREIO/config.env.asc | docker exec -i -u felipe telemetria bash -c "umask 077; gpg --batch --yes --decrypt -o ~/config.env && cat ~/config.env"