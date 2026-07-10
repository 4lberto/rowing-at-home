#!/bin/bash
# Arranca un servidor HTTP local para la app de remo
PORT=8000
DIR="$(cd "$(dirname "$0")" && pwd)"

# Mata cualquier servidor previo en el puerto
lsof -ti:$PORT 2>/dev/null | xargs kill 2>/dev/null

echo "Arrancando servidor en http://localhost:$PORT"
echo "Sirviendo ficheros desde: $DIR"
echo "Pulsa Ctrl+C para parar"
echo ""

python3 -m http.server $PORT --directory "$DIR"
