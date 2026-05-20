#!/bin/bash

PORT=$1
PROXY_MODE=$2

if [ -z "$PORT" ] || [ -z "$PROXY_MODE" ]; then
  echo "Usage: ./test_complete.sh <PORT> <on|off>"
  echo "Proxy protected:      ./test_complete.sh 8000 on"
  echo "Proxy unprotected:    ./test_complete.sh 8000 off"
  echo "Direct server test:   ./test_complete.sh 8001 on"
  exit 1
fi

echo "=========================================="
echo " STARTING TEST ON PORT $PORT (PROTECTION: $PROXY_MODE)"
echo "=========================================="

#To ensure a clean state, we clear any previous setup on the server
curl -X DELETE http://localhost:8001/clear

# If protection is off, we bypass the proxy for the setup phase
if [ "$PROXY_MODE" == "off" ]; then
    SETUP_PORT=8001
else
    SETUP_PORT=$PORT
fi

# --- TECHNIQUE 1: DEDICATED HEADER ---
echo -e "\n[*] Test 1: Dedicated Header (Sending: 'tec1' -> dGVjMQ==)"
curl -s -X POST http://localhost:$SETUP_PORT/setup -H "Content-Type: application/json" -d '{"entrypoint": "test_dh", "type": "dedicatedheader"}'

curl -s -X PUT http://localhost:$SETUP_PORT/test_dh -H "X-dataleak: dGVjMQ=="
RES1=$(curl -s -X GET http://localhost:$SETUP_PORT/test_dh)
echo "Result obtained: '$RES1'"

if [ "$PROXY_MODE" == "on" ] && [ "$PORT" != "8001" ]; then
    EXPECTED=""
else
    EXPECTED="dGVjMQ=="
fi

if [ "$RES1" == "$EXPECTED" ]; then
    echo "✅ OUTCOME: Behaved as expected for PROXY_MODE=$PROXY_MODE"
else
    echo "❌ OUTCOME: Unexpected result '$RES1' (expected '$EXPECTED')"
fi

# --- TECHNIQUE 2: HEADERS ORDER ---
echo -e "\n[*] Test 2: Headers Order (Sending: 'tec2')"
curl -s -X POST http://localhost:$SETUP_PORT/setup -H "Content-Type: application/json" -d '{"entrypoint": "test_ho", "type": "headersorder"}'

BITS="0111010001100101011000110011001000000000"

echo -n "Sending 40 HTTP requests for individual bits: "
for (( i=0; i<${#BITS}; i++ )); do
    bit="${BITS:$i:1}"
    if [ "$bit" == "0" ]; then
        curl -s -X PUT http://localhost:$SETUP_PORT/test_ho -H "User-Agent:" -H "Accept:" -H "Header-A: 1" -H "Header-B: 1"
    else
        curl -s -X PUT http://localhost:$SETUP_PORT/test_ho -H "User-Agent:" -H "Accept:" -H "Header-B: 1" -H "Header-A: 1"
    fi
    echo -n "."
done
echo ""

RES2=$(curl -s -X GET http://localhost:$SETUP_PORT/test_ho)
echo "Result obtained: '$RES2'"

if [ "$PROXY_MODE" == "on" ] && [ "$PORT" != "8001" ]; then
    EXPECTED_2=""
else
    EXPECTED_2="tec2"
fi

if [ "$PROXY_MODE" == "on" ] && [ "$PORT" != "8001" ]; then
    if [ "$RES2" != "tec2" ]; then
        echo "✅ OUTCOME: Behaved as expected for PROXY_MODE=$PROXY_MODE"
    else
        echo "❌ OUTCOME: Leak succeeded despite protection being on"
    fi
else
    if [ "$RES2" == "tec2" ]; then
        echo "✅ OUTCOME: Behaved as expected for PROXY_MODE=$PROXY_MODE"
    else
        echo "❌ OUTCOME: Unexpected result '$RES2' (expected 'tec2')"
    fi
fi

echo -e "\n=========================================="
echo " TEST COMPLETED"
echo "=========================================="