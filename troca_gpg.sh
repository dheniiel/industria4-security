#!/bin/bash
# =====================================================================
# troca_gpg.sh - Compartilha as chaves públicas GPG dos administradores
# =====================================================================

set -e
CORREIO=/opt/seguranca/correio
docker exec gateway mkdir -p $CORREIO

# 1. Cada administrador deposita a sua chave pública no correio
docker exec -u dheniel admin     gpg --armor --export dheniel@industria4.local | docker exec -i gateway tee $CORREIO/dheniel.asc >/dev/null
docker exec -u felipe  telemetria gpg --armor --export felipe@industria4.local  | docker exec -i gateway tee $CORREIO/felipe.asc  >/dev/null

# 2. Cada um retira do correio a chave do colega e importa
docker exec gateway cat $CORREIO/felipe.asc  | docker exec -i -u dheniel admin      gpg --import
docker exec gateway cat $CORREIO/dheniel.asc | docker exec -i -u felipe  telemetria gpg --import

# 3. Cada um confere a impressão digital da chave recebida e a assina
FPR_FELIPE=$(docker exec gateway gpg --show-keys --with-colons $CORREIO/felipe.asc   | awk -F: '/^fpr/{print $10; exit}')
FPR_DHENIEL=$(docker exec gateway gpg --show-keys --with-colons $CORREIO/dheniel.asc | awk -F: '/^fpr/{print $10; exit}')
echo "dheniel assina a chave de felipe: $FPR_FELIPE"
docker exec -u dheniel admin      gpg --batch --yes --quick-sign-key $FPR_FELIPE
echo "felipe assina a chave de dheniel: $FPR_DHENIEL"
docker exec -u felipe  telemetria gpg --batch --yes --quick-sign-key $FPR_DHENIEL

# Mostra as assinaturas: cada chave recebida agora está assinada pelo colega
docker exec -u dheniel admin      gpg --check-sigs felipe@industria4.local
docker exec -u felipe  telemetria gpg --check-sigs dheniel@industria4.local