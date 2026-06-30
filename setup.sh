#!/bin/bash

# Carrega variáveis do arquivo .env
[ -f .env ] && export $(grep -v '^#' .env | xargs)

# 1. Garante que os diretórios necessários existam
mkdir -p ./data
mkdir -p ./caddy

# 2. Geração de certificados SSL autoassinados para o Caddy (caso não existam)
echo "Verificando certificados SSL em ./caddy/..."

# Remove arquivos corrompidos ou incompletos se existirem para garantir uma nova geração limpa
rm -f ./caddy/local.pem ./caddy/local-key.pem

echo "Gerando novos certificados..."
openssl req -x509 -newkey rsa:4096 -keyout ./caddy/local-key.pem -out ./caddy/local.pem \
    -days 365 -nodes -subj "/CN=minhaapp.local" 2> /dev/null

# Verifica se os arquivos foram criados
if [ -f "./caddy/local.pem" ] && [ -f "./caddy/local-key.pem" ]; then
    echo "Certificados gerados com sucesso em ./caddy/"
    chmod 644 ./caddy/local.pem ./caddy/local-key.pem
else
    echo "ERRO: Falha ao gerar certificados. O OpenSSL está instalado?"
    exit 1
fi

# 3. Inicia o build e sobe os containers
echo "Construindo e subindo containers..."
docker compose up --build -d || {
  echo "ERRO: falha ao subir containers"
  exit 1
}

# 4. Aguarda a inicialização do sistema
echo "Aguardando sistema iniciar (15s)..."
sleep 15 

# 5. Executa o instalador do e-SUS dentro do container
echo "Iniciando o instalador interativo do e-SUS..."
echo "Atenção: Acompanhe a instalação abaixo no console:"
docker exec -it esus_server java -jar /opt/${INSTALADOR_NAME}.jar -console

echo ""
echo "======================================"
echo "Processo finalizado."
echo "Acesse: https://minhaapp.local"
echo "======================================"