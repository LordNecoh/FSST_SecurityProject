#!/bin/bash

#To ensure a clean state, we clear any previous setup on the server
curl -X DELETE http://localhost:8001/clear

# Funzione per inviare bit:
# Se Header-A precede Header-B alfabeticamente -> 0
# Se Header-B precede Header-A alfabeticamente -> 1
send_0() { curl -s -X PUT http://localhost:$1/$2 -H "Header-A: 1" -H "Header-B: 1"; }
send_1() { curl -s -X PUT http://localhost:$1/$2 -H "Header-B: 1" -H "Header-A: 1"; }

test_headers_order() {
    PORT=$1
    ENTRYPOINT=$2
    
    echo "1. Setup entrypoint sulla porta $PORT..."
    curl -s -X POST http://localhost:$PORT/setup -H "Content-Type: application/json" -d "{\"entrypoint\": \"$ENTRYPOINT\", \"type\": \"headersorder\"}"
    
    echo -e "\n2. Invio lettera 'a' (01100001)..."
    send_0 $PORT $ENTRYPOINT; send_1 $PORT $ENTRYPOINT; send_1 $PORT $ENTRYPOINT; send_0 $PORT $ENTRYPOINT
    send_0 $PORT $ENTRYPOINT; send_0 $PORT $ENTRYPOINT; send_0 $PORT $ENTRYPOINT; send_1 $PORT $ENTRYPOINT
    
    echo "3. Invio terminatore (00000000)..."
    for i in {1..8}; do send_0 $PORT $ENTRYPOINT; done
    
    echo "4. Recupero dati..."
    RESULT=$(curl -s -X GET http://localhost:$PORT/$ENTRYPOINT)
    echo -e "Dati ricevuti: '$RESULT'\n"
}

echo "=== TEST SERVER DIRETTO (PORTA 8001) ==="
test_headers_order 8001 leak_ho_server

echo "=== TEST PROXY (PORTA 8000) ==="
test_headers_order 8000 leak_ho_proxy