#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"

case "$(basename "${SHELL:-}")" in
    zsh)  RC_FILE="$HOME/.zshrc" ;;
    bash) RC_FILE="$HOME/.bashrc" ;;
    *)    RC_FILE="$HOME/.profile" ;;
esac

mkdir -p "$BIN_DIR"
chmod +x "$REPO_DIR/pymgr/pymgr.sh"
ln -sf "$REPO_DIR/pymgr/pymgr.sh" "$BIN_DIR/pymgr"
echo "🔗 pymgr enlazado en $BIN_DIR/pymgr"

# PATH
if ! grep -q 'HOME/.local/bin' "$RC_FILE" 2>/dev/null; then
    {
        echo ""
        echo '# >>> toolbox: PATH >>>'
        echo 'export PATH="$HOME/.local/bin:$PATH"'
        echo '# <<< toolbox: PATH <<<'
    } >> "$RC_FILE"
    echo "✅ PATH añadido a $RC_FILE"
fi

# Función de shell para 'pymgr use'
if ! grep -q '# >>> toolbox: pymgr function >>>' "$RC_FILE" 2>/dev/null; then
    cat >> "$RC_FILE" << 'EOF'

# >>> toolbox: pymgr function >>>
pymgr() {
  if [[ "$1" == "use" ]]; then eval "$(command pymgr "$@")"
  else command pymgr "$@"; fi
}
# <<< toolbox: pymgr function <<<
EOF
    echo "✅ Función pymgr() añadida a $RC_FILE"
fi

echo ""
echo "🔄 Ejecuta: source $RC_FILE"