#!/bin/bash

PORT=$1
PROXY_MODE=$2

if [ -z "$PORT" ] || [ -z "$PROXY_MODE" ]; then
  echo "Uso: ./test_faq.sh <PORTA> <on|off>"
  echo "Test con Proxy: ./test_faq.sh 8000 on"
  echo "Test su Server: ./test_faq.sh 8001 off"
  exit 1
fi

# Pulizia cache iniziale
curl -s -X DELETE http://localhost:8001/clear > /dev/null

SETUP_PORT=$PORT
if [ "$PROXY_MODE" == "off" ]; then
    SETUP_PORT=8001
fi

echo "=========================================="
echo " TEST REQUISITI FAQ (PORTA: $PORT, PROXY: $PROXY_MODE)"
echo "=========================================="

# --- TEST 1: DEDICATED HEADER (SOVRASCRITTURA) ---
echo -e "\n[*] Test 1: Dedicated Header (Invio 'OLD', poi 'NEW')"
curl -s -X POST http://localhost:$SETUP_PORT/setup -H "Content-Type: application/json" -d '{"entrypoint": "faq_dh", "type": "dedicatedheader"}'

# Invia prima T0xE (OLD), poi TkVX (NEW)
curl -s -X PUT http://localhost:$PORT/faq_dh -H "X-dataleak: T0xE"
curl -s -X PUT http://localhost:$PORT/faq_dh -H "X-dataleak: TkVX"

RES1=$(curl -s -X GET http://localhost:$PORT/faq_dh)
echo "Risultato ottenuto: '$RES1'"

if [ "$PROXY_MODE" == "off" ]; then
    if [ "$RES1" == "TkVX" ]; then
        echo "✅ OK: Ha tenuto solo l'ultimo dato ('NEW')."
    else
        echo "❌ ERRORE: Comportamento errato (Server vulnerabile)."
    fi
else
    if [ -z "$RES1" ]; then
        echo "🛡️ OK: Dati neutralizzati dal proxy."
    else
        echo "❌ ERRORE: Il proxy non ha bloccato i dati."
    fi
fi

# --- TEST 2: HEADERS ORDER (SOVRASCRITTURA DOPO 8 ZERI) ---
echo -e "\n[*] Test 2: Headers Order (Invio 'A', STOP, poi 'B', STOP)"
curl -s -X POST http://localhost:$SETUP_PORT/setup -H "Content-Type: application/json" -d '{"entrypoint": "faq_ho", "type": "headersorder"}'

# 'A' (01000001), STOP (00000000), 'B' (01000010), STOP (00000000)
BITS="01000001000000000100001000000000"

echo -n "Invio richieste HTTP: "
for (( i=0; i<${#BITS}; i++ )); do
    bit="${BITS:$i:1}"
    if [ "$bit" == "0" ]; then
        curl -s -X PUT http://localhost:$PORT/faq_ho -H "User-Agent:" -H "Accept:" -H "Header-A: 1" -H "Header-B: 1"
    else
        curl -s -X PUT http://localhost:$PORT/faq_ho -H "User-Agent:" -H "Accept:" -H "Header-B: 1" -H "Header-A: 1"
    fi
    echo -n "."
done
echo ""

RES2=$(curl -s -X GET http://localhost:$PORT/faq_ho)
echo "Risultato ottenuto: '$RES2'"

if [ "$PROXY_MODE" == "off" ]; then
    if [ "$RES2" == "B" ]; then
        echo "✅ OK: La lettera 'B' ha sostituito la 'A' dopo lo STOP."
    else
        echo "❌ ERRORE: Non ha sovrascritto correttamente (Server vulnerabile)."
    fi
else
    if [ "$RES2" != "B" ]; then
        echo "🛡️ OK: Sequenza corrotta dal proxy."
    else
        echo "❌ ERRORE: Il proxy non ha bloccato i dati."
    fi
fi

echo -e "\n=========================================="