FROM jrei/systemd-ubuntu:22.04

ARG INSTALADOR_NAME

ENV INSTALADOR_NAME=${INSTALADOR_NAME}

# Instala dependências
RUN apt-get update && \
    apt-get install -y \
        openjdk-11-jre-headless \
        file \
        sudo \
        locales \
        tzdata \
        wget \
        nano && \
    locale-gen pt_BR.UTF-8 && \

    # Instala LibSSL específica
    wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb && \
    
    dpkg -i libssl1.1_1.1.1f-1ubuntu2_amd64.deb || apt-get install -f -y && \

    # Configurações do Systemd
    echo "RemoveIPC=no" >> /etc/systemd/logind.conf && \

    systemctl daemon-reload && \
    
    systemctl restart systemd-logind || true

# Prepara o diretório de instalação
COPY ${INSTALADOR_NAME}.jar /opt/

WORKDIR /opt