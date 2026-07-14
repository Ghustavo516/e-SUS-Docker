#!/bin/bash
# ============================================================
# run-installer.sh
# Roda o instalador do e-SUS de forma totalmente interativa —
# você vê o wizard e responde as perguntas (S/N) normalmente,
# exatamente como no setup.sh antigo com `docker exec -it`.
#
# Uso (em outro terminal, com o container já rodando):
#   docker exec -it esus_server /opt/run-installer.sh
# ============================================================
set -e

BASE_DIR="/opt/e-SUS"
MARKER="${BASE_DIR}/.esus_installed"

if [ -f "$MARKER" ]; then
    echo "Instalação já foi concluída anteriormente (marker encontrado em ${MARKER})."
    echo "Se quiser reinstalar, apague o marker e o volume de dados primeiro."
    exit 0
fi

echo "===================================================="
echo " Instalador do e-SUS APS — modo automático (responde 'S' sozinho)"
echo " Você ainda vê tudo rolando na tela, só não precisa apertar tecla."
echo "===================================================="

# "yes S" envia "S" (e Enter) repetidamente para a entrada do
# instalador — responde automaticamente qualquer pergunta S/N que
# apareça (hoje só existe uma: "Tem certeza que deseja continuar?").
# A saída (stdout/stderr) do instalador não é redirecionada, então
# tudo continua aparecendo normalmente na tela.
yes S | java -jar "/opt/${INSTALADOR_NAME}.jar" -console -treinamento

echo ""
if [ -d "${BASE_DIR}/webserver/config" ]; then
    touch "$MARKER"
    echo "Instalação concluída. O entrypoint vai continuar automaticamente"
    echo "(certificado HTTPS, keystore, Postgres) — acompanhe com:"
    echo "  docker logs -f esus_server"
else
    echo "AVISO: ${BASE_DIR}/webserver/config não foi encontrado."
    echo "Parece que a instalação não terminou corretamente."
    echo "Rode este script novamente se necessário."
fi