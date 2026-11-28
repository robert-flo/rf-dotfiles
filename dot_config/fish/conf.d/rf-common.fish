# ==============================================================================
# rf-common.fish - Configuración universal de estación de trabajo (Fish)
# Compartida entre todos los perfiles (Clavis, Nyxuri, Omarchy) vía Chezmoi
# ==============================================================================

# t3code: sin telemetría. Mismas variables que bash, zsh y environment.d.
set -gx T3CODE_TELEMETRY_ENABLED false
set -gx T3CODE_OTEL_SDK_DISABLED true

# 1. Entorno base y editor
set -g fish_greeting ""
set -gx XDG_CONFIG_HOME $HOME/.config
set -gx GOPATH $HOME/go

if command -q rvim
    set -gx EDITOR rvim
    alias vim rvim
else if command -q nvim
    set -gx EDITOR nvim
    alias vim nvim
end

# 2. Rutas locales prioritarias (incluye shims de mise por si fish arranca directo desde la terminal sin bash)
fish_add_path -g $HOME/.local/bin $GOPATH/bin $HOME/.cargo/bin node_modules/.bin
if test -d $HOME/.local/share/mise/shims
    fish_add_path -ga $HOME/.local/share/mise/shims
end
if test -d $HOME/.local/share/mise/command-wrappers/bin
    fish_add_path -gp $HOME/.local/share/mise/command-wrappers/bin
end

# 3. Aliases (Craftzdog + estación)
alias agy="$HOME/.local/bin/agy"
alias cursor-agent="$HOME/.local/bin/cursor-agent"
alias claude-yolo="claude --dangerously-skip-permissions"
alias pn pnpm
alias cz chezmoi
alias la "ls -A"

if command -q eza
    alias ll "eza -l -g --icons=auto"
    alias lla "ll -a"
else
    alias ll "ls -l"
    alias lla "ll -A"
end

# 4. Integración de tries colaborativos (/zt) y proyectos personales (~/Work)
set -gx TRY_PATH /zt
set -gx TRY_PROJECTS $HOME/Work

if status is-interactive
    command -q try; and env SHELL=fish try init /zt | source
end

# 5. API Key de Cursor (si existe localmente)
if test -r $HOME/.config/cursor/api-key
    set -gx CURSOR_API_KEY (string trim < $HOME/.config/cursor/api-key)
end

# 6. Helpers de polaridad de terminal por sesión (contrato RF_TERM_THEME)
function term-light --description "Forzar polaridad clara (RF_TERM_THEME=light) en esta sesión"
    set -gx RF_TERM_THEME light
    set -gx COLORFGBG "0;15"
    set -gx BAT_THEME ansi
    set -gx GLAMOUR_STYLE light
end

function term-dark --description "Forzar polaridad oscura (RF_TERM_THEME=dark) en esta sesión"
    set -gx RF_TERM_THEME dark
    set -gx COLORFGBG "15;0"
    set -gx BAT_THEME ansi
    set -gx GLAMOUR_STYLE dark
end
