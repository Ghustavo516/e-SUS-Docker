FROM jrei/systemd-ubuntu:22.04

# ------------------------------------------------------------------
# Instalador do e-SUS hospedado no Google Drive (link compartilhado
# "qualquer pessoa com o link pode ver"). Usamos gdown porque o Drive
# interpõe uma tela de confirmação para arquivos grandes, e curl/wget
# puro não resolve isso de forma confiável.
# ------------------------------------------------------------------
ARG DRIVE_FILE_ID=1NWZufznsk2jyc7jhnPRyfQIkjHvQW1oo
ARG INSTALADOR_NAME=eSUS-AB-PEC-5.4.38-Linux64

ENV INSTALADOR_NAME=${INSTALADOR_NAME}

RUN apt-get update && \
    apt-get install -y \
        openjdk-11-jre-headless \
        file \
        sudo \
        locales \
        tzdata \
        wget \
        curl \
        python3-pip \
        nano && \
    locale-gen pt_BR.UTF-8 && \
    pip3 install --no-cache-dir gdown && \
    # LibSSL específica exigida pelo instalador
    wget -q http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb && \
    dpkg -i libssl1.1_1.1.1f-1ubuntu2_amd64.deb || apt-get install -f -y && \
    rm -f libssl1.1_1.1.1f-1ubuntu2_amd64.deb && \
    echo "RemoveIPC=no" >> /etc/systemd/logind.conf

# Baixa o instalador do Drive já na build, para a imagem final subir
# pronta com um simples `docker pull` / `docker compose up`.
RUN gdown "${DRIVE_FILE_ID}" -O "/opt/${INSTALADOR_NAME}.jar" && \
    test -s "/opt/${INSTALADOR_NAME}.jar"

# Script único que faz toda a instalação/configuração/observabilidade
COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

COPY esus.service /etc/systemd/system/esus.service
RUN systemctl enable esus.service

WORKDIR /opt