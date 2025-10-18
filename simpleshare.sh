#!/bin/bash
#
# simpleshare.sh - Instalador Simpleshare V1 (Modo SIMPLE)
# Execução: sudo ./simpleshare.sh

set -e

#################################################################
# CONFIGURAÇÕES COMUNS (IDÊNTICAS EM V1 E V2)
#################################################################

INSTALL_DIR="$(pwd)"
AUTH_PASSWORD="NovaSenha"  # Updated password
SERVICE_PORT=8081
SERVICE_NAME="simpleshare"
CODE_FILE="$INSTALL_DIR/simpleshare.code"
SESSION_FILE="$INSTALL_DIR/simpleshare.sessions"
SESSION_DURATION_SECONDS=1800
SERVER_SCRIPT="$INSTALL_DIR/simpleshare_server.sh"

#################################################################
# GERAÇÃO DO SERVIDOR HTTP (IDÊNTICO EM V1 E V2)
#################################################################

cat > "$SERVER_SCRIPT" << 'SERVEOF'
#!/bin/bash
# simpleshare_server.sh - Servidor HTTP (Executado pelo xinetd)
# ⚠️  NÃO EXECUTE DIRETAMENTE - Este script é chamado pelo xinetd

AUTH_PASSWORD="SuaSenha"
CODE_FILE="/home/ubuntu/simpleshare.code"
SESSION_FILE="/home/ubuntu/simpleshare.sessions"
SESSION_DURATION_SECONDS=1800
HTML_DIR="/home/ubuntu"

[[ ! -f "$CODE_FILE" ]] && touch "$CODE_FILE"
[[ ! -f "$SESSION_FILE" ]] && touch "$SESSION_FILE"

html_encode() {
    cat | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g'
}

send_response() {
    local status="$1"
    local content_type="$2"
    local body_content="$3"
    local extra_headers="$4"
    echo -ne "HTTP/1.1 ${status}\r\n"
    echo -ne "Content-Type: ${content_type}; charset=UTF-8\r\n"
    echo -ne "Connection: close\r\n"
    [[ -n "$extra_headers" ]] && echo -ne "$extra_headers\r\n"
    echo -ne "Content-Length: ${#body_content}\r\n"
    echo -ne "\r\n"
    echo -n "$body_content"
}

is_authenticated() {
    local CLIENT_IP="$1"
    local USER_AGENT="$2"
    local SESSION_ID="${CLIENT_IP}|${USER_AGENT}"
    local expiration_time
    local current_time=$(date +%s)
    awk -v now="$current_time" -F'::' '$2 > now' "$SESSION_FILE" > "${SESSION_FILE}.tmp" 2>/dev/null && mv "${SESSION_FILE}.tmp" "$SESSION_FILE"
    SESSION_LINE=$(grep -F "$SESSION_ID::" "$SESSION_FILE" 2>/dev/null | head -n 1)
    [[ -z "$SESSION_LINE" ]] && return 1
    expiration_time=$(echo "$SESSION_LINE" | sed 's/.*:://')
    (( current_time < expiration_time )) && return 0 || return 1
}

HTML_PAGE() {
    if [ -f "$HTML_DIR/simpleshare.html" ]; then
        cat "$HTML_DIR/simpleshare.html"
    else
        echo "<h1>404 Not Found</h1><p>simpleshare.html não encontrado em $HTML_DIR</p>"
    fi
}

read -t 1 -r REQUEST_LINE || exit 1
REQUEST_HEADERS=""
CONTENT_LENGTH=0
while IFS= read -t 0.1 -r LINE; do
    LINE="${LINE%$'\r'}"
    [[ -z "$LINE" ]] && break
    REQUEST_HEADERS+="$LINE\n"
    if [[ "$LINE" =~ ^Content-Length: ]]; then
        CONTENT_LENGTH=$(echo "$LINE" | awk '{print $2}')
    fi
done

if [[ $CONTENT_LENGTH -gt 0 ]]; then
    REQUEST_BODY=$(dd bs=1 count=$CONTENT_LENGTH 2>/dev/null)
else
    REQUEST_BODY=""
fi

CLIENT_IP=$(echo -e "$REQUEST_HEADERS" | grep -i 'X-Real-IP:' | head -1 | cut -d ':' -f 2- | sed 's/^ *//' | tr -d '\r')
CLIENT_IP="${CLIENT_IP:-${REMOTE_HOST:-127.0.0.1}}"
METHOD=$(echo "$REQUEST_LINE" | awk '{print $1}')
PATH_URI=$(echo "$REQUEST_LINE" | awk '{print $2}' | cut -d '?' -f 1)
USER_AGENT=$(echo -e "$REQUEST_HEADERS" | grep -i 'User-Agent:' | cut -d ':' -f 2- | sed 's/^ *//' | tr -d '\r')
USER_AGENT="${USER_AGENT:-Unknown}"

if [[ "$METHOD" =~ ^(GET|HEAD)$ ]] && [[ "$PATH_URI" == "/" ]]; then
    RESPONSE_BODY=$(HTML_PAGE)
    CACHE_HEADERS="Cache-Control: no-cache, no-store, must-revalidate\r\nPragma: no-cache\r\nExpires: 0"
    send_response 200 "text/html" "$RESPONSE_BODY" "$CACHE_HEADERS"
    exit 0
elif [[ "$METHOD" == "POST" ]] && [[ "$PATH_URI" == "/share" ]]; then
    AUTH_PASS=$(echo -e "$REQUEST_HEADERS" | grep -i 'X-Auth-Pass:' | awk '{print $2}' | tr -d '\r')
    if [[ -n "$AUTH_PASS" ]] && [[ "$AUTH_PASS" == "$AUTH_PASSWORD" ]]; then
        SESSION_ID="${CLIENT_IP}|${USER_AGENT}"
        EXPIRATION_TIME=$(( $(date +%s) + $SESSION_DURATION_SECONDS))
        sed -i "@${SESSION_ID}::@d" "$SESSION_FILE" 2>/dev/null
        echo "${SESSION_ID}::${EXPIRATION_TIME}" >> "$SESSION_FILE"
        send_response 200 "application/json" '{"status":"authenticated"}'
        exit 0
    elif is_authenticated "$CLIENT_IP" "$USER_AGENT"; then
        CODE_TO_SAVE=$(python3 -c "import sys, json; print(json.load(sys.stdin).get('code',''))" <<< "$REQUEST_BODY")
        echo -n "$CODE_TO_SAVE" > "$CODE_FILE"
        send_response 200 "application/json" '{"status":"ok"}'
        exit 0
    else
        send_response 401 "text/plain" "Unauthorized or session expired."
        exit 0
    fi
elif [[ "$METHOD" == "GET" ]] && [[ "$PATH_URI" == "/code" ]]; then
    if ! is_authenticated "$CLIENT_IP" "$USER_AGENT"; then
        send_response 401 "application/json" '{"error":"Unauthorized"}'
        exit 0
    fi
    SAVED_CODE=$(python3 -c "import json, sys; print(json.dumps(sys.stdin.read()).strip('\"'))" < "$CODE_FILE")
    send_response 200 "application/json" "{\"code\":\"$SAVED_CODE\"}"
    exit 0
fi
send_response 404 "text/plain" "Not Found"
exit 0
SERVEOF

sed -i "s|CODE_FILE=\"/home/ubuntu/simpleshare.code\"|CODE_FILE=\"$CODE_FILE\"|g" "$SERVER_SCRIPT"
sed -i "s|SESSION_FILE=\"/home/ubuntu/simpleshare.sessions\"|SESSION_FILE=\"$SESSION_FILE\"|g" "$SERVER_SCRIPT"
sed -i "s|SESSION_DURATION_SECONDS=1800|SESSION_DURATION_SECONDS=$SESSION_DURATION_SECONDS|g" "$SERVER_SCRIPT"
sed -i "s|HTML_DIR=\"/home/ubuntu\"|HTML_DIR=\"$INSTALL_DIR\"|g" "$SERVER_SCRIPT"

chmod +x "$SERVER_SCRIPT"
chown ubuntu:ubuntu "$SERVER_SCRIPT" 2>/dev/null || true
echo "✅ Servidor gerado: $SERVER_SCRIPT"

#################################################################
# CONFIGURAÇÃO DE ARQUIVOS (IDÊNTICO EM V1 E V2)
#################################################################

echo "📁 Configurando arquivos..."
rm -f "$SESSION_FILE" "${SESSION_FILE}.tmp"
[[ ! -f "$CODE_FILE" ]] && touch "$CODE_FILE"
[[ ! -f "$SESSION_FILE" ]] && touch "$SESSION_FILE"
chown ubuntu:ubuntu "$CODE_FILE" "$SESSION_FILE" 2>/dev/null || true
chmod 664 "$CODE_FILE" "$SESSION_FILE" 2>/dev/null || true
echo "✅ Arquivos configurados"

#################################################################
# INSTALAÇÃO E CONFIGURAÇÃO DO XINETD (IDÊNTICO EM V1 E V2)
#################################################################

if ! command -v xinetd &>/dev/null; then
    echo "📦 Instalando xinetd..."
    apt update -qq && apt install -y xinetd >/dev/null 2>&1
    echo "✅ xinetd instalado"
else
    echo "✅ xinetd já instalado"
fi

echo "⚙️  Configurando xinetd..."
cat > /etc/xinetd.d/$SERVICE_NAME <<EOF
service $SERVICE_NAME
{
    disable             = no
    type                = UNLISTED
    socket_type         = stream
    protocol            = tcp
    port                = $SERVICE_PORT
    server              = $SERVER_SCRIPT
    wait                = no
    log_type            = FILE /var/log/xinetd.log
    log_on_success      = PID HOST DURATION
    log_on_failure      = HOST ATTEMPT
    user                = ubuntu
}
EOF
echo "✅ xinetd configurado"

echo "🔄 Reiniciando xinetd..."
systemctl restart xinetd

if systemctl is-active --quiet xinetd; then
    echo "✅ xinetd iniciado"
else
    echo "❌ Falha ao iniciar xinetd"
    systemctl status xinetd
    exit 1
fi

#################################################################
# MENSAGEM FINAL (IDÊNTICA EM V1 E V2 MODO SIMPLE)
#################################################################

echo ""
echo "════════════════════════════════════════"
echo "✅ Simpleshare instalado com sucesso!"
echo "════════════════════════════════════════"
echo "🔹 Servidor: $SERVER_SCRIPT"
echo "🔹 Backend: http://localhost:$SERVICE_PORT"
echo "🔹 Modo: SIMPLE (xinetd standalone)"
echo ""
echo "⚠️  Configure seu proxy reverso (nginx):"
echo "  proxy_pass http://localhost:$SERVICE_PORT;"
echo "  proxy_set_header X-Real-IP \$remote_addr;"
echo ""
echo "🧪 Teste local:"
echo "  curl http://localhost:$SERVICE_PORT"
echo "════════════════════════════════════════"
echo ""
