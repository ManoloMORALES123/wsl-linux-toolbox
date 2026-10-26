#!/bin/bash
# ============================
# Python Version Manager (pymgr)
# ============================
# Gestor de versiones de Python compiladas desde código fuente
# Soporta Linux (Debian/Ubuntu, RHEL/Fedora, Arch, openSUSE), WSL y macOS
#
# Uso:
#   pymgr install <version>     Instala Python en $PYTHON_HOME/python-<version>
#   pymgr use <version>         Usa esa versión en la terminal actual (requiere función de shell)
#   pymgr default <version>     Establece la versión por defecto (permanente)
#   pymgr list                  Lista versiones instaladas
#   pymgr uninstall <version>   Elimina una versión
#   pymgr current               Muestra la versión activa
#   pymgr --help                Muestra la ayuda
#
# Variables de entorno:
#   PYTHON_HOME     Directorio base (defecto: ~/.local/python-versions)
#   PYMGR_LINK_DIR  Dónde crear python<X.Y.Z> y pip<X.Y.Z> (defecto: ~/.local/bin)
#   PYMGR_NO_OPT    Si vale 1, desactiva --enable-optimizations (compila más rápido)
# ============================
set -e

# === Configuración ===
BASE_DIR="${PYTHON_HOME:-$HOME/.local/python-versions}"
LINK_DIR="${PYMGR_LINK_DIR:-$HOME/.local/bin}"
NO_OPT="${PYMGR_NO_OPT:-0}"
VERSION_PATTERN='^[0-9]+\.[0-9]+\.[0-9]+$'

# === sed -i compatible con Linux y macOS ===
sed_inplace() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# === Detección de shell ===
detect_shell_config() {
    case "$(basename "${SHELL:-}")" in
        zsh)  SHELL_CONFIG="$HOME/.zshrc" ;;
        bash) SHELL_CONFIG="$HOME/.bashrc" ;;
        *)    SHELL_CONFIG="$HOME/.profile" ;;
    esac
}

# === Detección del sistema operativo ===
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt &>/dev/null; then
            PKG_MANAGER="apt"
            PKG_UPDATE="sudo apt update"
            PKG_INSTALL="sudo apt install -y"
            DEPENDENCIES="build-essential libssl-dev zlib1g-dev \
                libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
                libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
                libffi-dev liblzma-dev"
        elif command -v dnf &>/dev/null; then
            PKG_MANAGER="dnf"
            PKG_UPDATE="sudo dnf check-update || true"
            PKG_INSTALL="sudo dnf install -y"
            DEPENDENCIES="gcc gcc-c++ make openssl-devel bzip2-devel \
                libffi-devel readline-devel sqlite-devel tk-devel \
                xz-devel zlib-devel libxml2-devel libxslt-devel wget curl"
        elif command -v yum &>/dev/null; then
            PKG_MANAGER="yum"
            PKG_UPDATE="sudo yum check-update || true"
            PKG_INSTALL="sudo yum install -y"
            DEPENDENCIES="gcc gcc-c++ make openssl-devel bzip2-devel \
                libffi-devel readline-devel sqlite-devel tk-devel \
                xz-devel zlib-devel libxml2-devel libxslt-devel wget curl"
        elif command -v pacman &>/dev/null; then
            PKG_MANAGER="pacman"
            PKG_UPDATE="sudo pacman -Sy"
            PKG_INSTALL="sudo pacman -S --needed --noconfirm"
            DEPENDENCIES="base-devel openssl zlib bzip2 readline sqlite \
                tk libxml2 xz libffi wget curl"
        elif command -v zypper &>/dev/null; then
            PKG_MANAGER="zypper"
            PKG_UPDATE="sudo zypper refresh"
            PKG_INSTALL="sudo zypper install -y"
            DEPENDENCIES="gcc gcc-c++ make openssl-devel zlib-devel \
                libbz2-devel readline-devel sqlite3-devel tk-devel \
                libxml2-devel xz-devel libffi-devel wget curl"
        else
            echo "❌ No se pudo detectar el gestor de paquetes. Instala las dependencias manualmente." >&2
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &>/dev/null; then
            PKG_MANAGER="brew"
            PKG_UPDATE="brew update"
            PKG_INSTALL="brew install"
            DEPENDENCIES="openssl readline sqlite3 xz zlib tcl-tk wget"
        else
            echo "❌ Homebrew no instalado. Instálalo desde https://brew.sh" >&2
            exit 1
        fi
    else
        echo "❌ Sistema operativo no soportado: $OSTYPE" >&2
        exit 1
    fi
}

# === Verificar herramientas necesarias ===
check_required_tools() {
    local missing=()
    for cmd in wget make gcc; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "❌ Faltan herramientas necesarias: ${missing[*]}" >&2
        echo "   Instálalas con: $PKG_INSTALL ${missing[*]}" >&2
        exit 1
    fi
}

# === Verificar formato de versión ===
validate_version() {
    if [[ ! "$1" =~ $VERSION_PATTERN ]]; then
        echo "❌ Formato de versión inválido: $1" >&2
        echo "   Debe ser X.Y.Z (ejemplo: 3.12.10)" >&2
        exit 1
    fi
}

# === Ayuda ===
help_msg() {
    cat << EOF
pymgr - Python Version Manager

USO:
  pymgr install <version>    Instala Python en $BASE_DIR/python-<version>
  pymgr use <version>        Usa esa versión en la terminal actual
  pymgr default <version>    Establece la versión por defecto (permanente)
  pymgr list                 Lista versiones instaladas
  pymgr uninstall <version>  Elimina una versión instalada
  pymgr current              Muestra la versión activa
  pymgr --help               Muestra esta ayuda

VARIABLES DE ENTORNO:
  PYTHON_HOME     Directorio base (defecto: ~/.local/python-versions)
  PYMGR_LINK_DIR  Directorio de los comandos python<X.Y.Z> (defecto: ~/.local/bin)
  PYMGR_NO_OPT    1 = desactiva --enable-optimizations (compilación más rápida)

NOTA SOBRE 'use':
  Un script no puede modificar el PATH de la terminal que lo invoca.
  Agrega esta función a tu ~/.bashrc o ~/.zshrc:

    pymgr() {
      if [[ "\$1" == "use" ]]; then eval "\$(command pymgr "\$@")"
      else command pymgr "\$@"; fi
    }

EJEMPLOS:
  pymgr install 3.12.10
  pymgr use 3.12.10
  pymgr default 3.11.9
  python3.12.10 -m venv .venv
EOF
}

# === Comandos con versión completa (python3.8.20, pip3.8.20) ===
link_versioned_bins() {
    local version="$1"
    local install_path="$BASE_DIR/python-$version"

    mkdir -p "$LINK_DIR"
    ln -sf "$install_path/bin/python3" "$LINK_DIR/python$version"
    ln -sf "$install_path/bin/pip3"    "$LINK_DIR/pip$version"

    echo "🔗 Comandos creados en $LINK_DIR:"
    echo "   - python$version"
    echo "   - pip$version"

    if [[ ":$PATH:" != *":$LINK_DIR:"* ]]; then
        echo "⚠️  $LINK_DIR no está en tu PATH. Agrégalo a $SHELL_CONFIG:"
        echo "   export PATH=\"$LINK_DIR:\$PATH\""
    fi
}

unlink_versioned_bins() {
    local version="$1"
    local install_path="$BASE_DIR/python-$version"
    local name link

    for name in "python$version" "pip$version"; do
        link="$LINK_DIR/$name"
        # Solo borra si es un symlink que apunta a esta instalación
        if [[ -L "$link" && "$(readlink "$link")" == "$install_path/"* ]]; then
            rm -f "$link"
        fi
    done
}

# === Agregar al PATH del shell (modo "default") ===
add_to_path() {
    local version="$1"
    local python_dir="$BASE_DIR/python-$version/bin"

    if ! grep -q "# >>> pymgr: Python $version >>>" "$SHELL_CONFIG" 2>/dev/null; then
        {
            echo ""
            echo "# >>> pymgr: Python $version >>>"
            echo "export PATH=\"$python_dir:\$PATH\""
            echo "# <<< pymgr: Python $version <<<"
        } >> "$SHELL_CONFIG"
        echo "✅ Configuración añadida a $SHELL_CONFIG"
    else
        echo "ℹ️  La configuración para Python $version ya existe en $SHELL_CONFIG"
    fi
}

# === Eliminar del PATH del shell ===
remove_from_path() {
    local version="$1"
    if [[ -f "$SHELL_CONFIG" ]]; then
        sed_inplace "/# >>> pymgr: Python $version >>>/,/# <<< pymgr: Python $version <<</d" "$SHELL_CONFIG"
        sed_inplace '/^$/N;/^\n$/D' "$SHELL_CONFIG"
        echo "✂️  Configuración de Python $version eliminada de $SHELL_CONFIG"
    fi
}

# === Instalar dependencias del sistema ===
install_system_dependencies() {
    echo "🔧 Instalando dependencias del sistema ($PKG_MANAGER)..."
    eval "$PKG_UPDATE" || true
    # shellcheck disable=SC2086
    $PKG_INSTALL $DEPENDENCIES
}

# === Instalar Python ===
install_python() {
    local version="$1"
    local install_path="$BASE_DIR/python-$version"

    validate_version "$version"

    if [[ -d "$install_path" ]]; then
        echo "⚠️  Python $version ya está instalado en $install_path"
        read -r -p "¿Reinstalar? [y/N]: " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "❎ Cancelado."
            return
        fi
        rm -rf "$install_path"
    fi

    install_system_dependencies
    check_required_tools

    # Directorio temporal que se limpia al terminar (incluso si falla)
    local workdir
    workdir="$(mktemp -d)"
    trap 'rm -rf "$workdir"' EXIT

    echo "⬇️  Descargando Python $version..."
    cd "$workdir"
    wget -q --show-progress "https://www.python.org/ftp/python/$version/Python-$version.tgz"
    tar -xf "Python-$version.tgz"
    cd "Python-$version"

    echo "⚙️  Configurando compilación..."
    local configure_opts="--prefix=$install_path"
    if [[ "$NO_OPT" == "0" ]]; then
        configure_opts="$configure_opts --enable-optimizations"
        echo "   (optimizaciones activadas - puede tomar más tiempo)"
    else
        echo "   (optimizaciones desactivadas - compilación más rápida)"
    fi
    # shellcheck disable=SC2086
    ./configure $configure_opts

    echo "🛠️  Compilando e instalando (esto puede tomar varios minutos)..."
    make -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1)"
    make install

    # Symlinks genéricos dentro de la instalación
    ln -sf "$install_path/bin/python3" "$install_path/bin/python"
    ln -sf "$install_path/bin/pip3"    "$install_path/bin/pip"

    # Comandos con versión completa
    link_versioned_bins "$version"

    echo ""
    echo "✅ Python $version instalado correctamente en $install_path"
    echo ""
    echo "📝 Para usarlo:"
    echo "   - Directo:   python$version -m venv .venv"
    echo "   - Temporal:  pymgr use $version"
    echo "   - Permanente: pymgr default $version"
}

# === Usar versión en la terminal actual ===
# Los mensajes van a stderr y el 'export' a stdout, para usarse con eval.
use_version() {
    local version="$1"
    local python_dir="$BASE_DIR/python-$version/bin"

    validate_version "$version"

    if [[ ! -d "$BASE_DIR/python-$version" ]]; then
        echo "❌ Python $version no está instalado." >&2
        echo "   Versiones disponibles:" >&2
        list_versions >&2
        exit 1
    fi

    # Si stdout es una terminal, no se está usando eval: explicar cómo
    if [[ -t 1 ]]; then
        echo "ℹ️  Un script no puede cambiar el PATH de tu terminal." >&2
        echo "   Usa:  eval \"\$(pymgr use $version)\"" >&2
        echo "   o agrega la función 'pymgr' de 'pymgr --help' a tu ~/.bashrc" >&2
        exit 1
    fi

    echo "export PATH=\"$python_dir:\$PATH\""
    echo "🔁 Python $version activado en esta terminal: $("$python_dir/python" --version)" >&2
}

# === Establecer versión por defecto ===
default_version() {
    local version="$1"

    validate_version "$version"

    if [[ ! -d "$BASE_DIR/python-$version" ]]; then
        echo "❌ Python $version no está instalado." >&2
        echo "   Versiones disponibles:" >&2
        list_versions >&2
        exit 1
    fi

    # Elimina configuraciones anteriores de pymgr (todas las versiones)
    if [[ -f "$SHELL_CONFIG" ]]; then
        sed_inplace '/# >>> pymgr: Python /,/# <<< pymgr: Python /d' "$SHELL_CONFIG"
        sed_inplace '/^$/N;/^\n$/D' "$SHELL_CONFIG"
    fi

    add_to_path "$version"

    echo "✅ Python $version establecido como versión por defecto"
    echo "🔄 Ejecuta 'source $SHELL_CONFIG' o reinicia la terminal para aplicar los cambios"
}

# === Obtener versión actual ===
get_current_version() {
    local python_path
    python_path="$(command -v python3 2>/dev/null || true)"
    if [[ "$python_path" == "$BASE_DIR/python-"* ]]; then
        echo "$python_path" | sed "s|$BASE_DIR/python-\([^/]*\)/.*|\1|"
    fi
}

# === Listar versiones instaladas ===
list_versions() {
    local dirs=("$BASE_DIR"/python-*)

    if [[ ! -d "${dirs[0]}" ]]; then
        echo "📦 No hay versiones instaladas en $BASE_DIR"
        return
    fi

    echo "📦 Versiones de Python instaladas:"
    local current v
    current="$(get_current_version)"
    for d in "${dirs[@]}"; do
        v="${d##*/python-}"
        if [[ "$v" == "$current" ]]; then
            echo "  * $v (activa)"
        else
            echo "    $v"
        fi
    done
}

# === Mostrar versión actual ===
show_current() {
    local current
    current="$(get_current_version)"
    if [[ -n "$current" ]]; then
        echo "✅ Versión activa: Python $current"
        echo "   Ruta: $(command -v python3)"
    else
        echo "ℹ️  No hay una versión de pymgr activa"
        echo "   Python del sistema: $(python3 --version 2>/dev/null || echo 'no encontrado')"
    fi
}

# === Desinstalar Python ===
uninstall_python() {
    local version="$1"
    local install_path="$BASE_DIR/python-$version"

    validate_version "$version"

    if [[ ! -d "$install_path" ]]; then
        echo "❌ Python $version no está instalado en $install_path"
        return
    fi

    echo "⚠️  Eliminarás completamente Python $version"
    echo "   Ruta: $install_path"
    read -r -p "¿Estás seguro? [y/N]: " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "❎ Cancelado."
        return
    fi

    unlink_versioned_bins "$version"   # antes de borrar el directorio
    rm -rf "$install_path"
    echo "🗑️  Python $version eliminado de $install_path"

    remove_from_path "$version"
    echo "✅ Desinstalación completada"
}

# === Lógica principal ===
main() {
    detect_shell_config
    mkdir -p "$BASE_DIR"

    case "$1" in
        install)
            [[ -z "$2" ]] && help_msg && exit 1
            detect_os
            install_python "$2"
            ;;
        use)
            [[ -z "$2" ]] && help_msg && exit 1
            use_version "$2"
            ;;
        default)
            [[ -z "$2" ]] && help_msg && exit 1
            default_version "$2"
            ;;
        list|ls)
            list_versions
            ;;
        uninstall|remove)
            [[ -z "$2" ]] && help_msg && exit 1
            uninstall_python "$2"
            ;;
        current|active)
            show_current
            ;;
        --help|-h|help)
            help_msg
            ;;
        *)
            help_msg
            exit 1
            ;;
    esac
}

main "$@"