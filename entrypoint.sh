#!/bin/bash
# ============================================================
# entrypoint.sh — roda como o serviço systemd "esus" (PID de app).
# Faz TUDO: instala (só na 1a vez), gera certificado HTTPS,
# ajusta Postgres, checa DNS/proxy, sobe a aplicação e termina
# fazendo "tail -f" dos logs — por isso tudo aparece em
# `docker logs esus_server`, sem precisar de mais nada.
# ============================================================
set -uo pipefail

HOST="esusserver.local"
KEYSTORE_PASS="changeit"

BASE_DIR="/opt/e-SUS"
CONFIG_DIR="${BASE_DIR}/webserver/config"
CERT_DIR="/opt/e-SUS/certs"          # dentro do volume principal, sem pasta solta no host
LOG_DIR="/opt/e-SUS/logs-setup"
SETUP_LOG="${LOG_DIR}/setup.log"
APP_LOG="${LOG_DIR}/esus-app.log"
MARKER_FILE="${BASE_DIR}/.esus_provisioned"

mkdir -p "$CERT_DIR" "$LOG_DIR"

log() {
    local level="$1"; shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] $*" | tee -a "$SETUP_LOG"
}

log INFO "===================================================="
log INFO " e-SUS APS — iniciando (host=${HOST})"
log INFO "===================================================="

# --- Checagem de DNS/proxy antes de tudo (item que falhou no colega) ---
log INFO "Checando resolução de DNS para ${HOST}..."
if getent hosts "$HOST" > /dev/null 2>&1; then
    log OK "DNS: ${HOST} resolve para $(getent hosts "$HOST" | awk '{print $1}')"
else
    log AVISO "DNS: ${HOST} ainda não resolve dentro do container (normal antes do extra_hosts aplicar)."
fi
if [ -n "${HTTP_PROXY:-}${HTTPS_PROXY:-}${http_proxy:-}${https_proxy:-}" ]; then
    log AVISO "Proxy detectado no ambiente (HTTP_PROXY/HTTPS_PROXY). Pode interferir na validação do link da instalação."
fi

if [ -f "$MARKER_FILE" ]; then
    log INFO "Instalação já feita anteriormente (marker encontrado). Pulando instalador."
else
    log INFO "Aguardando serviços internos (Postgres embarcado) subirem..."
    sleep 20

    log INFO "Executando instalador do e-SUS (console, treinamento)..."
    T0=$(date +%s)
    if java -jar "/opt/${INSTALADOR_NAME}.jar" -console -treinamento; then
        log OK "Instalador concluído."
    else
        log FALHA "Instalador retornou erro."
    fi
    log INFO "Tempo de instalação: $(( $(date +%s) - T0 ))s"
    sleep 5

    if [ ! -d "$CONFIG_DIR" ]; then
        log FALHA "Diretório ${CONFIG_DIR} não encontrado. Instalação incompleta. Abortando."
        exit 1
    fi

    # --- Certificado HTTPS com SAN ---
    log INFO "Gerando certificado HTTPS para ${HOST}..."
    T0=$(date +%s)
    openssl req -x509 -newkey rsa:4096 \
        -keyout "$CERT_DIR/local-key.pem" \
        -out "$CERT_DIR/local.pem" \
        -days 825 -nodes \
        -subj "/CN=${HOST}" \
        -addext "subjectAltName=DNS:${HOST},DNS:localhost,IP:127.0.0.1" \
        2>> "$SETUP_LOG" && log OK "Certificado gerado." || log FALHA "Erro ao gerar certificado."

    openssl pkcs12 -export \
        -in "$CERT_DIR/local.pem" -inkey "$CERT_DIR/local-key.pem" \
        -out "$CERT_DIR/esusaps.p12" -name esuskey \
        -passout pass:"${KEYSTORE_PASS}" 2>> "$SETUP_LOG" \
        && log OK "Keystore PKCS12 gerada." || log FALHA "Erro ao gerar keystore."
    log INFO "Tempo geração de chaves HTTPS: $(( $(date +%s) - T0 ))s"

    cp "$CERT_DIR/esusaps.p12" "$CONFIG_DIR/esusaps.p12"
    chmod 644 "$CONFIG_DIR/esusaps.p12"

    # --- application.properties ---
    APP_PROPS="$CONFIG_DIR/application.properties"
    touch "$APP_PROPS"
    set_prop() {
        grep -q "^$1=" "$APP_PROPS" 2>/dev/null \
            && sed -i "s|^$1=.*|$1=$2|" "$APP_PROPS" \
            || echo "$1=$2" >> "$APP_PROPS"
    }
    set_prop "server.port" "443"
    set_prop "security.require-ssl" "true"
    set_prop "server.ssl.key-store-type" "PKCS12"
    set_prop "server.ssl.key-store" "${CONFIG_DIR}/esusaps.p12"
    set_prop "server.ssl.key-store-password" "${KEYSTORE_PASS}"
    set_prop "server.ssl.key-alias" "esuskey"
    set_prop "server.ssl.enabled-protocols" "TLSv1.2,TLSv1.3"
    log OK "HTTPS nativo habilitado em application.properties."

    # --- Truststore do JRE embarcado ---
    ESUS_KEYTOOL="/opt/e-SUS/jre/current/bin/keytool"
    ESUS_CACERTS=$(find /opt/e-SUS/jre -iname cacerts 2>/dev/null | head -n1)
    if [ -z "$ESUS_CACERTS" ]; then
        log AVISO "cacerts do JRE embarcado não encontrado."
    else
        "$ESUS_KEYTOOL" -importcert -trustcacerts -noprompt -alias "${HOST}" \
            -file "$CERT_DIR/local.pem" -keystore "$ESUS_CACERTS" \
            -storepass changeit >> "$SETUP_LOG" 2>&1 \
            && log OK "Certificado importado no truststore do e-SUS." \
            || log AVISO "Falha ao importar (pode já existir)."
    fi

    # --- Postgres externo ---
    PG_DATA_DIR=$(find /opt/e-SUS/database -maxdepth 1 -type d -iname "postgresql-*" 2>/dev/null | head -n1)
    if [ -n "$PG_DATA_DIR" ]; then
        PG_DATA_DIR="${PG_DATA_DIR}/data"
        sed -i "s/^listen_addresses = 'localhost'/listen_addresses = '*'/" "${PG_DATA_DIR}/postgresql.conf"
        grep -q '0.0.0.0/0' "${PG_DATA_DIR}/pg_hba.conf" 2>/dev/null \
            || echo 'host    all             all             0.0.0.0/0               md5' >> "${PG_DATA_DIR}/pg_hba.conf"
        log OK "PostgreSQL liberado para conexões externas."
    else
        log AVISO "Diretório do PostgreSQL não encontrado."
    fi

    touch "$MARKER_FILE"
    log OK "Provisionamento inicial concluído."
fi

# --- Sobe a aplicação ---
log INFO "Iniciando a aplicação e-SUS..."
if [ -x "${BASE_DIR}/webserver/standalone.sh" ]; then
    nohup "${BASE_DIR}/webserver/standalone.sh" >> "$APP_LOG" 2>&1 &
else
    log FALHA "standalone.sh não encontrado — instalação incompleta."
fi

log INFO "Aguardando aplicação responder em HTTPS (até 2 min)..."
T0=$(date +%s)
UP=0
for i in $(seq 1 24); do
    if curl -sk --max-time 4 -o /dev/null "https://127.0.0.1:443/"; then UP=1; break; fi
    sleep 5
done

if [ "$UP" -eq 1 ]; then
    log OK "Aplicação no ar após $(( $(date +%s) - T0 ))s."
else
    log FALHA "Aplicação não respondeu após $(( $(date +%s) - T0 ))s."
    log AVISO "Se isso persistir com o container 'rodando', suspeite de proxy/firewall/antivírus na máquina host bloqueando o handshake TLS."
fi

# --- Diagnóstico de DNS/proxy pós-subida ---
curl -sk --max-time 8 -o /dev/null "https://${HOST}:443/"
case $? in
    0)  log OK "https://${HOST}:443 acessível internamente." ;;
    6)  log FALHA "DNS: '${HOST}' não resolve. Confira extra_hosts do compose e o /etc/hosts do host." ;;
    7)  log FALHA "Conexão recusada — nada escutando em 443 ainda." ;;
    28) log FALHA "Timeout — possível bloqueio de proxy/firewall entre o container e ele mesmo." ;;
    *)  log AVISO "Falha inesperada ao testar HTTPS (curl exit $?)." ;;
esac

log INFO "===================================================="
log INFO " Pronto. No host (fora do Docker), adicione ao /etc/hosts:"
log INFO "   127.0.0.1 ${HOST}"
log INFO " Acesse: https://${HOST}:8443"
log INFO " Link da instalação (dentro do sistema): https://${HOST}:443"
log INFO "===================================================="

# Mantém o serviço "vivo" e espelha os logs para o stdout do
# container -> é isso que aparece em `docker logs esus_server`.
exec tail -n +1 -F "$SETUP_LOG" "$APP_LOG"
