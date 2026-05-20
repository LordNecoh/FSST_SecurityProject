#!/bin/bash

echo "=== TEST SERVER DIRETTO (PORTA 8001) ==="

#To ensure a clean state, we clear any previous setup on the server
curl -X DELETE http://localhost:8001/clear

echo "1. Setup entrypoint..."
curl -s -X POST http://localhost:8001/setup -H "Content-Type: application/json" -d '{"entrypoint": "leak_server", "type": "dedicatedheader"}'
echo -e "\n"

echo "2. Invio dati leak..."
curl -s -X PUT http://localhost:8001/leak_server -H "X-dataleak: Y2lhbw=="

echo "3. Recupero dati..."
RESULT=$(curl -s -X GET http://localhost:8001/leak_server)
echo -e "Dati ricevuti: $RESULT\n"

if [ "$RESULT" == "Y2lhbw==" ]; then
    echo "✅ SUCCESSO: Il server ha memorizzato i dati."
else
    echo "❌ ERRORE: Il data leak è fallito."
fi