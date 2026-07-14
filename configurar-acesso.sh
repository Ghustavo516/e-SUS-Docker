#!/bin/bash
# ============================================================
# configurar-acesso.sh
# Adiciona (ou corrige) a entrada de "esusserver.local" no
# /etc/hosts da máquina onde ESTE script é rodado — não mexe em
# nada dentro do Docker, é só resolução de nome local.
#
# Rode isso em CADA máquina que vai acessar o e-SUS pelo navegador:
#
#   - Na própria máquina do servidor Docker (gustavo-dev), rode
#     sem argumento nenhum:
#       ./configurar-acesso.sh
#
#   - Na máquina de um colega (acessando pela rede), informe o IP
#     do servidor Docker na rede local:
#       ./configurar-acesso.sh 192.168.3.117
# ============================================================
set -e

HOST="esusserver.local"
IP="${1:-127.0.0.1}"

echo "===================================================="
echo " Configurando acesso a ${HOST} -> ${IP}"
echo "===================================================="

if grep -qE "[[:space:]]${HOST}([[:space:]]|$)" /etc/hosts 2>/dev/null; then
    echo ">> Já existe uma entrada para ${HOST}. Atualizando para ${IP}..."
    sudo sed -i "s/^.*[[:space:]]${HOST}\([[:space:]]\|$\)/${IP} ${HOST}\1/" /etc/hosts
else
    echo ">> Adicionando '${IP} ${HOST}' ao /etc/hosts..."
    echo "${IP} ${HOST}" | sudo tee -a /etc/hosts > /dev/null
fi

echo ""
echo ">> Testando resolução..."
if getent hosts "$HOST" > /dev/null 2>&1; then
    echo "OK: ${HOST} resolve para $(getent hosts "$HOST" | awk '{print $1}')"
    echo ""
    echo "Acesse no navegador: https://${HOST}:8443"
else
    echo "AVISO: não consegui confirmar a resolução. Confira manualmente com: ping ${HOST}"
fi
