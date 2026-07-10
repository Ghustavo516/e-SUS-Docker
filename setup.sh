#!/bin/bash
set -e

# Carrega variáveis do arquivo .env
[ -f .env ] && export $(grep -v '^#' .env | xargs)

HOST="${HOST:-minhaapp.local}"
HTTPS_PORT="${HTTPS_PORT:-8443}"
ESUS_PORT="${ESUS_PORT:-8080}"
KEYSTORE_PASS="${KEYSTORE_PASS:-changeit}"

CONFIG_DIR="./data/webserver/config"   # equivalente a /opt/e-SUS/webserver/config dentro do container
CERT_DIR="./certs"

echo "===================================================="
echo " Setup e-SUS PEC — Docker (HTTPS nativo, modo produção)"
echo "===================================================="

mkdir -p ./data
mkdir -p "$CERT_DIR"

# 1. Sobe o container base (ainda sem o e-SUS instalado)
echo ">> Construindo e subindo o container..."
docker compose up --build -d || {
  echo "ERRO: falha ao subir o container"
  exit 1
}

# ---------------------------------------------------------
# CORREÇÃO: Aguarda o systemd e os serviços internos do container 
# (como o PostgreSQL embarcado) iniciarem antes de rodar o instalador
# ---------------------------------------------------------
echo ">> Aguardando inicialização dos serviços internos do container (20 segundos)..."
sleep 20

# 2. Executa o instalador interativo em modo PRODUÇÃO
#    (sem a flag -treinamento)
echo ">> Iniciando o instalador do e-SUS (modo produção)..."
echo "Acompanhe a instalação abaixo:"

#Ambiente de produção:
# docker exec -it esus_server java -jar /opt/${INSTALADOR_NAME}.jar -console

#Ambiente de desenvolvimento:
docker exec -it esus_server java -jar /opt/${INSTALADOR_NAME}.jar -console -treinamento

# Dá um tempo para o instalador terminar de gravar os arquivos
sleep 5

if [ ! -d "$CONFIG_DIR" ]; then
  echo "ERRO: diretório de configuração ($CONFIG_DIR) não foi encontrado."
  echo "Parece que a instalação não finalizou corretamente."
  echo "Rode o script novamente depois de concluir a instalação pelo console."
  exit 1
fi

# O instalador roda como root dentro do container, então os arquivos
# que caem no bind mount (./data) pertencem ao root. Ajusta a posse
# para o usuário atual poder escrever a keystore e editar o properties.
echo ">> Ajustando permissões de ./data..."
sudo chown -R "$(id -u):$(id -g)" ./data

# 3. Gera certificado autoassinado COM SAN para o HOST configurado
#    (sem SAN, o Java rejeita o certificado mesmo estando no truststore)
echo ">> Gerando certificado para ${HOST}..."
rm -f "$CERT_DIR"/local.pem "$CERT_DIR"/local-key.pem "$CERT_DIR"/esusaps.p12

openssl req -x509 -newkey rsa:4096 \
    -keyout "$CERT_DIR/local-key.pem" \
    -out "$CERT_DIR/local.pem" \
    -days 825 -nodes \
    -subj "/CN=${HOST}" \
    -addext "subjectAltName=DNS:${HOST},DNS:localhost,IP:127.0.0.1" \
    2> /dev/null

if [ ! -f "$CERT_DIR/local.pem" ]; then
  echo "ERRO: falha ao gerar o certificado. O OpenSSL está instalado?"
  exit 1
fi

# 4. Empacota o certificado numa Keystore PKCS12
#    (formato que o Spring/Tomcat do e-SUS exige)
echo ">> Gerando keystore PKCS12..."
openssl pkcs12 -export \
    -in "$CERT_DIR/local.pem" \
    -inkey "$CERT_DIR/local-key.pem" \
    -out "$CERT_DIR/esusaps.p12" \
    -name esuskey \
    -passout pass:"${KEYSTORE_PASS}"

cp "$CERT_DIR/esusaps.p12" "$CONFIG_DIR/esusaps.p12"
chmod 644 "$CONFIG_DIR/esusaps.p12"

# 5. Ajusta o application.properties para habilitar o HTTPS nativo
APP_PROPS="$CONFIG_DIR/application.properties"
touch "$APP_PROPS"

set_prop() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" "$APP_PROPS" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$APP_PROPS"
  else
    echo "${key}=${value}" >> "$APP_PROPS"
  fi
}

echo ">> Habilitando HTTPS nativo no application.properties..."
set_prop "server.port" "443"
set_prop "security.require-ssl" "true"
set_prop "server.ssl.key-store-type" "PKCS12"
set_prop "server.ssl.key-store" "/opt/e-SUS/webserver/config/esusaps.p12"
set_prop "server.ssl.key-store-password" "${KEYSTORE_PASS}"
set_prop "server.ssl.key-alias" "esuskey"
set_prop "server.ssl.enabled-protocols" "TLSv1.2,TLSv1.3"

# 6. Importa o certificado no truststore do Java dentro do container.
#    Necessário porque o próprio e-SUS valida o "Link da minha instalação"
#    fazendo uma chamada HTTPS para si mesmo — e precisa confiar no
#    próprio certificado autoassinado.
#
#    IMPORTANTE: o e-SUS roda com um JRE embarcado próprio
#    (/opt/e-SUS/jre/current), que é DIFERENTE do Java instalado no
#    sistema do container (which java -> /usr/lib/jvm/...). Se
#    importarmos o certificado no cacerts genérico, o e-SUS nunca vai
#    confiar nele e a validação do link vai falhar mesmo com tudo
#    "certo". Por isso resolvemos o caminho real do keystore do JRE
#    embarcado dinamicamente em vez de usar "-cacerts" (que aponta pro
#    JAVA_HOME do processo que chama o keytool via docker exec).
echo ">> Importando certificado no truststore do Java embarcado do e-SUS..."
docker cp "$CERT_DIR/local.pem" esus_server:/tmp/local.pem

ESUS_KEYTOOL="/opt/e-SUS/jre/current/bin/keytool"
ESUS_CACERTS=$(docker exec esus_server sh -c \
  'find /opt/e-SUS/jre -iname "cacerts" 2>/dev/null | head -n1')

if [ -z "$ESUS_CACERTS" ]; then
  echo "AVISO: não foi possível localizar o cacerts do JRE embarcado do e-SUS."
  echo "A validação do 'Link da minha instalação' pode falhar."
  echo "Verifique manualmente com: docker exec esus_server find /opt/e-SUS/jre -iname cacerts"
else
  echo "   Keystore do e-SUS encontrado em: ${ESUS_CACERTS}"
  docker exec esus_server "$ESUS_KEYTOOL" -importcert -trustcacerts -noprompt \
      -alias "${HOST}" \
      -file /tmp/local.pem \
      -keystore "$ESUS_CACERTS" \
      -storepass changeit || {
    echo "AVISO: não foi possível importar o certificado automaticamente."
    echo "A validação do 'Link da minha instalação' pode falhar."
  }

  # Confirma que o certificado realmente entrou no keystore
  if docker exec esus_server "$ESUS_KEYTOOL" -list \
      -keystore "$ESUS_CACERTS" -storepass changeit -alias "${HOST}" \
      > /dev/null 2>&1; then
    echo "   Certificado confirmado no truststore do e-SUS."
  else
    echo "AVISO: certificado não encontrado no truststore após o import."
    echo "A validação do 'Link da minha instalação' pode falhar."
  fi
fi

# 7. Libera o PostgreSQL interno para aceitar conexões externas
#    (por padrão o instalador do e-SUS sobe o Postgres só escutando em
#    "localhost" dentro do container, e o pg_hba.conf só libera
#    127.0.0.1/::1. Isso funciona para o próprio e-SUS, mas impede
#    acesso via DBeaver/outros clientes de fora do container, mesmo
#    com a porta 5433 publicada no docker-compose. Ajustamos aqui pra
#    não precisar mexer manualmente toda vez que o ambiente é recriado)
echo ">> Ajustando PostgreSQL interno para aceitar conexões externas (DBeaver etc)..."

PG_DATA_DIR=$(docker exec esus_server sh -c \
  'find /opt/e-SUS/database -maxdepth 1 -type d -iname "postgresql-*"' | head -n1)

if [ -z "$PG_DATA_DIR" ]; then
  echo "AVISO: não foi possível localizar o diretório de instalação do PostgreSQL."
  echo "Ajuste manualmente listen_addresses e pg_hba.conf se precisar acessar via DBeaver."
else
  PG_DATA_DIR="${PG_DATA_DIR}/data"

  docker exec esus_server bash -c \
    "sed -i \"s/^listen_addresses = 'localhost'/listen_addresses = '*'/\" '${PG_DATA_DIR}/postgresql.conf'"

  docker exec esus_server bash -c \
    "grep -q '0.0.0.0/0' '${PG_DATA_DIR}/pg_hba.conf' || echo 'host    all             all             0.0.0.0/0               md5' >> '${PG_DATA_DIR}/pg_hba.conf'"

  echo "   PostgreSQL configurado para aceitar conexões externas (porta ${DB_PORT:-5433})."
fi

# 8. Reinicia o container para o e-SUS subir já com HTTPS nativo (443)
#    e também com o PostgreSQL já lendo a config nova
echo ">> Reiniciando o e-SUS para aplicar o HTTPS e a config do PostgreSQL..."
docker compose restart esus

echo "Aguardando o serviço subir novamente (20s)..."
sleep 20

echo ""
echo "======================================"
echo "Processo finalizado."
echo ""
echo "Adicione isso ao /etc/hosts da sua máquina (fora do Docker):"
echo "  127.0.0.1 ${HOST}"
echo ""
echo "Acesse pelo navegador (fora do Docker): https://${HOST}:${HTTPS_PORT}"
echo ""
echo "Dentro do sistema, em 'Configurações da Instalação > Servidores"
echo "> Link da instalação', use o campo único de link com a PORTA 443"
echo "(não 8443!). A validação roda de DENTRO do container, e lá dentro"
echo "o Tomcat só escuta na porta 443 — a 8443 só existe no mapeamento"
echo "para o seu host, fora do Docker."
echo ""
echo "  Link da minha instalação: https://${HOST}:443"
echo ""
echo "IMPORTANTE: os containers NÃO iniciam sozinhos com a máquina"
echo "(restart: \"no\"). Para ligar/desligar quando quiser, use:"
echo "  docker compose start   # inicia"
echo "  docker compose stop    # para"
echo "======================================"