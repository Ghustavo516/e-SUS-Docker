#!/bin/bash
# ============================================================
# setup.sh — instala o e-SUS do começo ao fim em UM ÚNICO
# terminal:
#   1) sobe o container (builda se precisar, ou usa a imagem
#      já publicada no Docker Hub se você deu "docker pull")
#   2) espera o serviço "esus" (systemd) ficar de pé lá dentro
#   3) dispara o instalador NA HORA, na mesma janela — você vê tudo
#      rolando na tela, mas a pergunta de confirmação (S/N) já é
#      respondida sozinha, sem precisar apertar tecla
#   4) depois que você termina o instalador, continua sozinho
#      mostrando a configuração automática (HTTPS, truststore,
#      Postgres) até aparecer "Pronto."
#
# Uso:
#   ./setup.sh
# ============================================================
set -e

CONTAINER="esus_server"
MARKER_CHECK_TIMEOUT=90   # segundos esperando o systemd subir dentro do container

echo "===================================================="
echo " e-SUS APS — instalação (tudo em um terminal só)"
echo "===================================================="

echo ">> Subindo o container (builda automaticamente se a imagem"
echo "   ainda não existir localmente; senão usa a imagem já pronta)..."
docker compose up -d

echo ">> Aguardando o serviço interno do container ficar pronto..."
READY=0
for i in $(seq 1 "$MARKER_CHECK_TIMEOUT"); do
    if docker exec "$CONTAINER" systemctl is-active esus.service > /dev/null 2>&1; then
        READY=1
        break
    fi
    sleep 1
done

if [ "$READY" -ne 1 ]; then
    echo "AVISO: o serviço 'esus' não respondeu dentro do tempo esperado."
    echo "Vou tentar continuar mesmo assim — se falhar, rode 'docker logs ${CONTAINER}' para investigar."
fi

# Já foi instalado antes (ex.: você reiniciou o container)? Pula o wizard.
if docker exec "$CONTAINER" test -f /opt/e-SUS/.esus_installed > /dev/null 2>&1; then
    echo ">> Instalação já tinha sido concluída anteriormente. Pulando o instalador."
else
    echo ""
    echo "===================================================="
    echo " Instalador do e-SUS — modo automático (acompanhe na tela)"
    echo "===================================================="
    docker exec -it "$CONTAINER" /opt/run-installer.sh
fi

echo ""
echo ">> Instalador concluído (ou já estava). Acompanhando a configuração"
echo "   automática (certificado HTTPS, truststore, Postgres, subida da app)..."
echo "   Pressione Ctrl+C quando ver a linha 'Pronto.' — o container"
echo "   continua rodando normalmente depois disso."
echo ""
docker logs -f "$CONTAINER"