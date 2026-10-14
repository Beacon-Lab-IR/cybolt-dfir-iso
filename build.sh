#!/usr/bin/env bash
# build.sh - Baja los ultimos releases de los proyectos CyboltDFIR y los mete
# en un ISO booteable. El ISO no compila nada, solo empaqueta.
#
# Uso:
#   ./build.sh                       # ISO con los ultimos releases (auto version)
#   ./build.sh 5.3.1                 # version personalizada del ISO
#   ./build.sh --pin triage=5.3.1    # fija version de un proyecto especifico
#
# Output:
#   dist/CyboltDFIR-ISO-v<VERSION>.iso
#
# Requiere:
#   - gh CLI autenticado en GitHub
#   - macOS (hdiutil makehybrid) o Linux (genisoimage)
#
# El ISO es self-contained: incluye wizard de Triage + uploader + KAPE +
# Targets/ + Tools/. Se monta como CD-ROM y se ejecuta desde ahi.

set -euo pipefail

# Parse args (soporta --pin proyecto=version)
PINS=()
ISO_VERSION=""
while [ $# -gt 0 ]; do
    case "$1" in
        --pin)
            shift
            PINS+=("$1")
            shift
            ;;
        *)
            ISO_VERSION="$1"
            shift
            ;;
    esac
done

if [ -z "$ISO_VERSION" ]; then
    ISO_VERSION="0.1.0"
    echo ">>> ISO version no especificada, usando $ISO_VERSION"
fi

# Cargar pins
declare -A PINNED
for p in "${PINS[@]:-}"; do
    if [ -n "$p" ]; then
        KEY="${p%=*}"
        VAL="${p#*=}"
        PINNED["$KEY"]="$VAL"
    fi
done

echo "==================================================================="
echo "  Building CyboltDFIR ISO v$ISO_VERSION"
echo "==================================================================="
echo ""

# Helper: human-readable size
human_size() {
    local bytes=$1
    if [ -z "$bytes" ] || [ "$bytes" = "0" ]; then echo "0B"
    elif [ "$bytes" -lt 1024 ]; then echo "${bytes}B"
    elif [ "$bytes" -lt 1048576 ]; then echo "$(echo "scale=2; $bytes/1024" | bc)KB"
    else echo "$(echo "scale=2; $bytes/1048576" | bc)MiB"
    fi
}

# 1) Verificar gh CLI
if ! command -v gh >/dev/null 2>&1; then
    echo "ERROR: gh CLI no encontrado. Instalar con 'brew install gh'."
    exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
    echo "ERROR: gh CLI no autenticado. Correr 'gh auth login'."
    exit 1
fi

# 2) Cargar projects.json
if [ ! -f projects.json ]; then
    echo "ERROR: projects.json no encontrado"
    exit 1
fi

# Parsear projects.json con python (jq puede no estar)
PROJECTS=$(python3 -c "import json; print(' '.join([p['name'] for p in json.load(open('projects.json'))['projects']]))" 2>/dev/null)
REPOS=$(python3 -c "import json; print(' '.join([p['repo'] for p in json.load(open('projects.json'))['projects']]))" 2>/dev/null)
ASSET_PATTERNS=$(python3 -c "import json; print(' '.join([p['asset_pattern'] for p in json.load(open('projects.json'))['projects']]))" 2>/dev/null)

if [ -z "$PROJECTS" ]; then
    echo "ERROR: projects.json no parseable o vacio"
    exit 1
fi

echo ">>> Proyectos a incluir:"
i=0
for p in $PROJECTS; do
    repo=$(echo "$REPOS" | cut -d' ' -f$((i+1)))
    pattern=$(echo "$ASSET_PATTERNS" | cut -d' ' -f$((i+1)))
    echo "    - $p  (repo: $repo, pattern: $pattern)"
    i=$((i+1))
done
echo ""

# 3) Staging
rm -rf staging
mkdir -p staging

# 4) Bajar cada release y extraer
echo ">>> [1/2] Bajando releases..."
i=0
for p in $PROJECTS; do
    repo=$(echo "$REPOS" | cut -d' ' -f$((i+1)))
    pattern=$(echo "$ASSET_PATTERNS" | cut -d' ' -f$((i+1)))

    # Determinar tag: pinned o latest
    if [ -n "${PINNED[$p]:-}" ]; then
        tag="${PINNED[$p]}"
        echo "    $p: pin a v$tag"
    else
        tag=$(gh release view --repo "$repo" --json tagName -q .tagName 2>/dev/null | sed 's/^v//')
        echo "    $p: latest = v$tag"
    fi

    if [ -z "$tag" ]; then
        echo "    ERROR: no se pudo resolver tag para $p en $repo"
        exit 1
    fi

    # Bajar el ZIP
    echo "    Descargando $repo v$tag ($pattern)..."
    TMPDIR=$(mktemp -d)
    gh release download "v$tag" --repo "$repo" --pattern "$pattern" --dir "$TMPDIR" 2>&1 | tail -3

    # Encontrar el ZIP bajado y extraer en staging/
    zipfile=$(find "$TMPDIR" -name "$pattern" -type f | head -1)
    if [ -z "$zipfile" ]; then
        echo "    ERROR: no se encontro el ZIP bajado en $TMPDIR"
        exit 1
    fi

    echo "    Extrayendo $(basename "$zipfile") -> staging/"
    unzip -qo "$zipfile" -d staging/

    # Limpiar tmpdir
    rm -rf "$TMPDIR"
    i=$((i+1))
done

echo ""
echo ">>> Contenido del staging/ (top-level):"
ls staging/ | head -15
echo ""

# 5) Build ISO
echo ">>> [2/2] Construyendo ISO..."
ISO_PATH="$(pwd)/dist/CyboltDFIR-ISO-v$ISO_VERSION.iso"
ISO_VOLID="CYBOLT-DFIR-v$ISO_VERSION"
rm -f "$ISO_PATH"
mkdir -p dist
if [ "$(uname)" = "Darwin" ]; then
    hdiutil makehybrid -joliet -iso -no-emul-boot -no-boot \
        -iso-volume-name "$ISO_VOLID" \
        -joliet-volume-name "$ISO_VOLID" \
        -o "$ISO_PATH" staging/ >/dev/null
elif [ "$(uname)" = "Linux" ]; then
    genisoimage -R -J -joliet-long \
        -V "$ISO_VOLID" \
        -o "$ISO_PATH" staging/
else
    echo "ERROR: OS no soportado ($(uname))"
    exit 1
fi

ISO_SIZE=$(stat -f%z "$ISO_PATH" 2>/dev/null || stat -c%s "$ISO_PATH")
ISO_SHA=$( (sha256sum "$ISO_PATH" 2>/dev/null || shasum -a 256 "$ISO_PATH") | awk '{print $1}')

cat <<EOF

===================================================================
  BUILD OK: CyboltDFIR ISO v$ISO_VERSION
===================================================================

  File : dist/CyboltDFIR-ISO-v$ISO_VERSION.iso
  Size : $ISO_SIZE bytes ($(echo "scale=2; $ISO_SIZE/1048576" | bc) MiB)
  SHA  : $ISO_SHA

  Crea el GitHub Release:
    gh release create v$ISO_VERSION \\
      dist/CyboltDFIR-ISO-v$ISO_VERSION.iso \\
      --repo Beacon-Lab-IR/cybolt-dfir-iso \\
      --title "CyboltDFIR ISO v$ISO_VERSION" \\
      --notes-file RELEASE-NOTES.md
EOF
