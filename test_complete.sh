#!/bin/bash

MODE=$1

if [ -z "$MODE" ]; then
  echo "Usage: ./test_complete.sh <mode>"
  echo "  protected    - Through proxy, protection enabled  (port 8000)"
  echo "  unprotected  - Through proxy, protection disabled (port 8000)"
  echo "  direct       - Direct to server, no proxy         (port 8001)"
  exit 1
fi

case "$MODE" in
  protected)
    PORT=8000
    SETUP_PORT=8000
    EXPECT_BLOCKED=true
    ;;
  unprotected)
    PORT=8000
    SETUP_PORT=8001
    EXPECT_BLOCKED=false
    ;;
  direct)
    PORT=8001
    SETUP_PORT=8001
    EXPECT_BLOCKED=false
    ;;
  *)
    echo "✘ Invalid mode '$MODE'. Use: protected | unprotected | direct"
    exit 1
    ;;
esac

echo "=========================================="
echo " STARTING TEST IN MODE: $MODE (PORT: $PORT)"
echo "=========================================="

# To ensure a clean state, we clear any previous setup on the server AND proxy
curl -X DELETE http://localhost:8001/clear
curl -X DELETE http://localhost:8000/clear

# --- TECHNIQUE 1: DEDICATED HEADER ---
echo -e "\n[*] Test 1: Dedicated Header (Sending: 'tec1' -> dGVjMQ==)"
curl -s -X POST http://localhost:$SETUP_PORT/setup -H "Content-Type: application/json" -d '{"entrypoint": "test_dh", "type": "dedicatedheader"}'

curl -s -X PUT http://localhost:$PORT/test_dh -H "X-dataleak: dGVjMQ=="
RES1=$(curl -s -X GET http://localhost:$PORT/test_dh)
echo "Result obtained: '$RES1'"

echo ""
if [ "$EXPECT_BLOCKED" == "true" ]; then
    if [ "$RES1" == "" ]; then
        echo "✔  PASSED: Header blocked as expected"
    else
        echo "✘  FAILED: Leak succeeded despite protection being on (got '$RES1')"
    fi
else
    if [ "$RES1" == "dGVjMQ==" ]; then
        echo "✔  PASSED: Data leaked as expected"
    else
        echo "✘  FAILED: Unexpected result '$RES1' (expected 'dGVjMQ==')"
    fi
fi

# --- TECHNIQUE 2: HEADERS ORDER ---
echo ""
echo -e "\n[*] Test 2: Headers Order (Sending: 'tec2')"
curl -s -X POST http://localhost:$SETUP_PORT/setup -H "Content-Type: application/json" -d '{"entrypoint": "test_ho", "type": "headersorder"}'

BITS="0111010001100101011000110011001000000000"

echo -n "Sending 40 HTTP requests for individual bits: "
for (( i=0; i<${#BITS}; i++ )); do
    bit="${BITS:$i:1}"
    if [ "$bit" == "0" ]; then
        curl -s -X PUT http://localhost:$PORT/test_ho -H "User-Agent:" -H "Accept:" -H "Header-A: 1" -H "Header-B: 1"
    else
        curl -s -X PUT http://localhost:$PORT/test_ho -H "User-Agent:" -H "Accept:" -H "Header-B: 1" -H "Header-A: 1"
    fi
    echo -n "."
done
echo ""

RES2=$(curl -s -X GET http://localhost:$PORT/test_ho)
echo "Result obtained: '$RES2'"

echo ""
if [ "$EXPECT_BLOCKED" == "true" ]; then
    if [ "$RES2" != "tec2" ]; then
        echo "✔  PASSED: Header order neutralized as expected"
    else
        echo "✘  FAILED: Leak succeeded despite protection being on"
    fi
else
    if [ "$RES2" == "tec2" ]; then
        echo "✔  PASSED: Data leaked as expected"
    else
        echo "✘  FAILED: Unexpected result '$RES2' (expected 'tec2')"
    fi
fi

echo -e "\n=========================================="
echo " TEST COMPLETED"
echo "=========================================="