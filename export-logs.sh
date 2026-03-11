#!/bin/bash

echo "SCRIPT INICIADO $(date)" >> /tmp/script_debug.txt

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Carrega variáveis do arquivo .env

ENV_FILE="/opt/auditoria_vm/.env"

if [ -f "$ENV_FILE" ]; then
    set -a
	. "$ENV_FILE"
	set +a
else
    echo "Arquivo ".env" não encontrado" >> /opt/auditoria_vm/cron.log
    exit 1
fi
# ===============================
# FUNÇÕES
# ===============================

coletar_memoria() {
    read MEM_TOTAL MEM_USADO MEM_DISP MEM_PERC_USADO MEM_PERC_DISP <<< \
    "$(free -m | awk '/Mem:/ {printf "%d %d %d %.2f %.2f", $2, $3, $7, ($3/$2*100), ($7/$2*100)}')"
}

coletar_disco() {
    DISCO_INFO=$(df -hT | awk 'NR==1 || $2=="ext4" || $2=="xfs"' | column -t)
}

coletar_uptime() {
    UPTIME_INFO=$(uptime)
}

definir_janela() {
    local MODO="$1"
    local HORAS="$2"

    if [ "$MODO" == "auto" ]; then
        local HORA_ATUAL
        HORA_ATUAL=$(date +%H)

        if [ "$HORA_ATUAL" == "07" ]; then
            DATA_INICIO=$(date -d "yesterday 20:00" +"%Y-%m-%d %H:%M:%S")
            DATA_FIM=$(date +"%Y-%m-%d %H:%M:%S")

        elif [ "$HORA_ATUAL" == "20" ]; then
            DATA_INICIO=$(date -d "today 07:00" +"%Y-%m-%d %H:%M:%S")
            DATA_FIM=$(date +"%Y-%m-%d %H:%M:%S")

        else
            echo "Execução fora do horário permitido (07h ou 20h)."
            exit 1
        fi

    elif [ "$MODO" == "manual" ]; then
        local delta=${HORAS:-1}

        DATA_INICIO=$(date -d "$delta hours ago" +"%Y-%m-%d %H:%M:%S")
        DATA_FIM=$(date +"%Y-%m-%d %H:%M:%S")

    else
        echo "Modo inválido."
        exit 1
    fi
}

gerar_relatorio() {

    RELATORIO_PATH="/tmp/relatorio_vm_$(date +"%Y-%m-%d_%H-%M").txt"
    SSH_LOG_PATH="/tmp/ssh_logs_$(date +"%Y-%m-%d_%H-%M").txt"

    > "$RELATORIO_PATH"

    # ===============================
    # CABEÇALHO
    # ===============================

    HOST_INFO=$(hostnamectl | awk -F': ' '/Static hostname|Operating System/ {print $2}')
    IP_PRIVADO=$(hostname -I | awk '{print $1}')
    DATA_GERACAO=$(date +"%Y-%m-%d %H:%M:%S")

    {
        echo "======================================="
        echo "RELATÓRIO DA VM"
        echo "Data de geração: $DATA_GERACAO"
        echo "Hostname / SO:"
        echo "$HOST_INFO"
        echo "IP Privado: $IP_PRIVADO"
        echo "Janela analisada:"
        echo "Início: $DATA_INICIO"
        echo "Fim:    $DATA_FIM"
        echo "======================================="
        echo ""
    } >> "$RELATORIO_PATH"

    # ===============================
    # UPTIME
    # ===============================

    coletar_uptime

    {
        echo "=== UPTIME ==="
        echo "$UPTIME_INFO"
        echo ""
    } >> "$RELATORIO_PATH"

    # ===============================
    # MEMÓRIA
    # ===============================

    coletar_memoria

    {
        echo "=== MEMÓRIA ==="
        echo "Total:      ${MEM_TOTAL} MB"
        echo "Usado:      ${MEM_USADO} MB (${MEM_PERC_USADO}%)"
        echo "Disponível: ${MEM_DISP} MB (${MEM_PERC_DISP}%)"
        echo ""
    } >> "$RELATORIO_PATH"

    # ===============================
    # DISCO
    # ===============================

    coletar_disco

    {
        echo "=== DISCO ==="
        echo "$DISCO_INFO"
        echo ""
    } >> "$RELATORIO_PATH"

    # ===============================
    # SSH - RESUMO DE ACESSOS
    # ===============================

    SSH_LOGS=$(journalctl -u ssh \
        --since "$DATA_INICIO" \
        --until "$DATA_FIM" \
        | grep -E "Failed|Accepted|Invalid")

    if [ -z "$SSH_LOGS" ]; then
        echo "=== SSH ===" >> "$RELATORIO_PATH"
        echo "Nenhuma tentativa de acesso registrada na janela analisada." >> "$RELATORIO_PATH"
        echo "" >> "$RELATORIO_PATH"
    else

        echo "$SSH_LOGS" > "$SSH_LOG_PATH"

        TOTAL_FALHAS=$(echo "$SSH_LOGS" | grep -c -E "Failed|Invalid")
        TOTAL_SUCESSOS=$(echo "$SSH_LOGS" | grep -c "Accepted")

        USUARIOS=$(echo "$SSH_LOGS" | awk '
        /Invalid user/ {print $8}
        /Accepted/ {for(i=1;i<=NF;i++) if($i=="for") print $(i+1)}
        ' | sort -u)

        IPS=$(echo "$SSH_LOGS" | awk '
        /from/ {for(i=1;i<=NF;i++) if($i=="from") print $(i+1)}
        ' | sort -u)

        {
            echo "=== SSH ==="
            echo "Tentativas falhas: $TOTAL_FALHAS"
            echo "Logins aceitos:    $TOTAL_SUCESSOS"
            echo ""
            echo "Usuários envolvidos:"
            echo "$USUARIOS"
            echo ""
            echo "IPs envolvidos:"
            echo "$IPS"
            echo ""
            echo "Arquivo bruto salvo em: $SSH_LOG_PATH"
            echo ""
        } >> "$RELATORIO_PATH"
    fi

    echo "Relatório gerado em: $RELATORIO_PATH"
}

# ===============================
# FLUXO PRINCIPAL
# ===============================

if [ -z "$1" ]; then
    definir_janela auto
    gerar_relatorio

elif [ "$1" == "manual" ]; then

    if [ -z "$2" ]; then
        echo "Erro: informe a quantidade de horas. Ex: $0 manual 6"
        exit 1
    fi

    definir_janela manual "$2"
    gerar_relatorio

else
    echo "Erro: parâmetro inválido."
    echo "Uso:"
    echo "  $0            → modo automático"
    echo "  $0 manual X   → últimas X horas"
    exit 1
fi

# ===============================
# COMPACTAÇÃO DOS ARQUIVOS
# ===============================

PASTA_LOGS="$LOG_DIR"
mkdir -p "$PASTA_LOGS"

ARQUIVO_TAR="$PASTA_LOGS/logs_vm_$(date +"%Y-%m-%d_%H-%M").tar.gz"

tar -czf "$ARQUIVO_TAR" "$RELATORIO_PATH" "$SSH_LOG_PATH"

# ===============================
# CRIPTOGRAFIA DO ARQUIVO
# ===============================

ARQUIVO_GPG="${ARQUIVO_TAR}.gpg"

gpg --batch --yes --passphrase "$GPS_PASS" -c "$ARQUIVO_TAR"

if [ $? -eq 0 ]; then
    rm -f "$ARQUIVO_TAR"
    echo "Arquivo criptografado criado em: $ARQUIVO_GPG"
else
    echo "Erro na criptografia."
    exit 1
fi    

# ===============================
# RETENÇÃO DE ARQUIVOS ANTIGOS
# ===============================

find "$LOG_DIR" -type f -name "*.gpg" -mtime +$RETENTION_DAYS -exec rm -f {} \;

echo "Limpeza de arquivos antigos concluída (>$RETENTION_DAYS dias)."

# ===============================
# ENVIO DE E-MAIL
# ===============================

ASSUNTO="Relatório Auditoria VM - $(date +"%Y-%m-%d %H:%M")"

echo "EMAIL_DEST=$EMAIL_DEST" >> /tmp/debug_email.txt

echo -e "Subject: $ASSUNTO\n\n$(cat "$RELATORIO_PATH")" | /usr/bin/msmtp "$EMAIL_DEST"

if [ $? -eq 0 ]; then
    echo "E-mail enviado para: $EMAIL_DEST"
else
    echo "Erro ao enviar e-mail."
fi


echo "Destino configurado: $EMAIL_DEST" >> /opt/auditoria_vm/debug_env.txt
