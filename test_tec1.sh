#!/bin/bash

echo "=== TEST PROXY (PORTA 8000) ==="

#To ensure a clean state, we clear any previous setup on the server
curl -X DELETE http://localhost:8001/clear

echo "1. Setup entrypoint..."
curl -s -X POST http://localhost:8000/setup -H "Content-Type: application/json" -d '{"entrypoint": "leak_proxy", "type": "dedicatedheader"}'
echo -e "\n"

echo "2. Invio dati leak (attraverso il proxy)..."
curl -s -X PUT http://localhost:8000/leak_proxy -H "X-dataleak: Y2lhbw=="

echo "3. Recupero dati..."
RESULT=$(curl -s -X GET http://localhost:8000/leak_proxy)
echo -e "Dati ricevuti: '$RESULT'\n"

if [ -z "$RESULT" ]; then
    echo "✅ SUCCESSO: Il proxy ha neutralizzato il data leak."
else
    echo "❌ ERRORE: Il proxy NON ha bloccato i dati."
fi