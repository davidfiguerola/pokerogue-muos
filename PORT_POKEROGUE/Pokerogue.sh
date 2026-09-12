#!/bin/bash
# ==============================================================================
# PokéRogue Port para muOS (Anbernic RG35XX-H / Chip H700 aarch64)
# ==============================================================================

DIR="$(dirname "$(readlink -f "$0")")"
cd "$DIR" || exit 1

LOG="$DIR/pokerogue.log"
exec > >(tee -a "$LOG") 2>&1

echo "========================================="
echo "Iniciando PokeRogue en muOS..."
echo "Fecha: $(date)"
echo "========================================="

# 1. Configurar SWAP (CRUCIAL para consolas de 1GB de RAM)
SWAP_FILE="$DIR/swapfile"
if [ ! -f "$SWAP_FILE" ]; then
    echo "[1/4] Creando archivo SWAP de 1GB (solo la primera vez)..."
    dd if=/dev/zero of="$SWAP_FILE" bs=1M count=1024
    mkswap "$SWAP_FILE"
fi

echo "[2/4] Activando SWAP..."
swapon "$SWAP_FILE" 2>/dev/null

# 2. Configurar entorno grafico y bibliotecas
export LD_LIBRARY_PATH="$DIR/libs:$LD_LIBRARY_PATH"
export SDL_VIDEODRIVER=kmsdrm
export WPE_BACKEND=fdo
export COG_PLATFORM_FDO_VIEW_BACKEND=drm

# 3. Servidor web local ligero para cargar los assets estaticos
echo "[3/4] Iniciando micro-servidor local..."
PORT=8089
python3 -m http.server $PORT --directory "$DIR/game" &
SERVER_PID=$!

sleep 1

# 4. Lanzar el runtime web optimizado
echo "[4/4] Lanzando PokeRogue..."
if [ -f "$DIR/bin/cog" ]; then
    "$DIR/bin/cog" --platform=drm "http://127.0.0.1:$PORT" &
    GAME_PID=$!
elif [ -f "$DIR/bin/wpe-launcher" ]; then
    "$DIR/bin/wpe-launcher" "http://127.0.0.1:$PORT" &
    GAME_PID=$!
else
    echo "ERROR: No se encontro el binario del runtime en $DIR/bin/"
    kill "$SERVER_PID" 2>/dev/null
    swapoff "$SWAP_FILE" 2>/dev/null
    exit 1
fi

wait "$GAME_PID"

echo "Cerrando PokeRogue y liberando recursos..."
kill "$SERVER_PID" 2>/dev/null
swapoff "$SWAP_FILE" 2>/dev/null
echo "Completado."
