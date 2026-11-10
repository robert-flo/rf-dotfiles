# ==============================================================================
# rf-common.fish - Configuración universal de estación de trabajo (Fish)
# Compartida entre todos los perfiles (Clavis, Nyxuri, Omarchy) vía Chezmoi
# ==============================================================================

# 1. Rutas locales prioritarias
fish_add_path -g $HOME/.local/bin

# 2. Alias de Google Antigravity CLI
alias agy="$HOME/.local/bin/agy"

# 3. Integración de tries colaborativos (/zt) y proyectos personales (~/Work)
set -gx TRY_PATH /zt
set -gx TRY_PROJECTS $HOME/Work

if status is-interactive
    command -q try; and env SHELL=fish try init /zt | source
end

# 4. API Key de Cursor (si existe localmente)
if test -r $HOME/.config/cursor/api-key
    set -gx CURSOR_API_KEY (string trim < $HOME/.config/cursor/api-key)
end
