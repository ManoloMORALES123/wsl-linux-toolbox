# pymgr

Gestor ligero de versiones de Python compiladas desde el código fuente oficial de python.org.
Sin shims y sin dependencias externas: solo bash.

## ¿Por qué pymgr y no pyenv?

- Es un único script, fácil de leer y modificar.
- No intercepta comandos con shims: cambia el `PATH` de forma explícita.
- Crea comandos con la versión completa (`python3.8.20`), útiles para `venv`.

## Requisitos

- Bash 4+
- `sudo` (para instalar dependencias de compilación)
- Conexión a internet
- Espacio en disco: ~500 MB por versión durante la compilación

En WSL, instala siempre dentro del sistema de archivos de Linux (`~/`), no en `/mnt/c`,
porque compilar ahí es mucho más lento.

## Instalación

### Opción A: script de instalación (recomendada)

```bash
git clone git@github.com:ManoloMORALES123/wsl-linux-toolbox.git ~/toolbox
cd ~/toolbox
./install.sh
source ~/.bashrc
```

### Opción B: manual

1. Enlaza el script al `PATH`:

   ```bash
   mkdir -p ~/.local/bin
   ln -sf ~/toolbox/pymgr/pymgr.sh ~/.local/bin/pymgr
   ```

2. Asegúrate de que `~/.local/bin` esté en tu `PATH` (en `~/.bashrc`):

   ```bash
   export PATH="$HOME/.local/bin:$PATH"
   ```

3. Agrega esta función a `~/.bashrc` (o `~/.zshrc`). Es necesaria para que `pymgr use`
   pueda modificar el `PATH` de tu terminal actual:

   ```bash
   pymgr() {
     if [[ "$1" == "use" ]]; then eval "$(command pymgr "$@")"
     else command pymgr "$@"; fi
   }
   ```

4. Recarga la configuración:

   ```bash
   source ~/.bashrc
   ```

### Verificar

```bash
pymgr --help
```

## Uso

```bash
pymgr install 3.12.10     # compila e instala
pymgr list                # lista versiones instaladas
pymgr use 3.12.10         # activa la versión SOLO en esta terminal
pymgr default 3.12.10     # activa la versión en todas las terminales nuevas
pymgr current             # muestra la versión activa
pymgr uninstall 3.12.10   # elimina la versión
```

### Crear entornos virtuales

Tras instalar una versión se crean los comandos `python<versión>` y `pip<versión>`,
así que no necesitas activar nada:

```bash
python3.12.10 -m venv .venv
source .venv/bin/activate
```

## Variables de entorno

| Variable | Defecto | Descripción |
|----------|---------|-------------|
| `PYTHON_HOME` | `~/.local/python-versions` | Directorio donde se instalan las versiones |
| `PYMGR_LINK_DIR` | `~/.local/bin` | Dónde se crean `python<X.Y.Z>` y `pip<X.Y.Z>` |
| `PYMGR_NO_OPT` | `0` | Con `1` desactiva `--enable-optimizations` (compila mucho más rápido) |

Ejemplo de compilación rápida:

```bash
PYMGR_NO_OPT=1 pymgr install 3.11.9
```

## Estructura de instalación

```
~/.local/python-versions/
├── python-3.8.20/
└── python-3.12.10/

~/.local/bin/
├── python3.8.20  -> ~/.local/python-versions/python-3.8.20/bin/python3
└── pip3.8.20     -> ~/.local/python-versions/python-3.8.20/bin/pip3
```

## Solución de problemas

**`pymgr: command not found`**
`~/.local/bin` no está en tu `PATH`. Revisa el paso 2 de la instalación manual.

**`pymgr use` muestra un aviso en lugar de cambiar la versión**
Falta la función de shell del paso 3. Mientras tanto puedes usar:
`eval "$(pymgr use 3.12.10)"`.

**Errores de módulos faltantes (`_ssl`, `_ctypes`, `_sqlite3`...)**
Faltaron librerías de desarrollo al compilar. Ejecuta de nuevo `pymgr install <versión>`
y acepta reinstalar; el script reinstala las dependencias.

**La compilación es muy lenta**
Usa `PYMGR_NO_OPT=1` o verifica que estás compilando fuera de `/mnt/c`.

## Desinstalar pymgr

```bash
rm ~/.local/bin/pymgr
rm -rf ~/.local/python-versions     # elimina TODAS las versiones instaladas
# Quita también la función pymgr() y los bloques "# >>> pymgr" de tu ~/.bashrc
```

## Licencia

MIT