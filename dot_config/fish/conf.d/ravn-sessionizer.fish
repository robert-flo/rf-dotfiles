# Atajo interactivo para lanzar el selector de sesiones de ravn-sessionizer
# Funciona tanto fuera como dentro de herdr (Alt+s).
if status is-interactive; and command -q ravn-sessionizer
    function __ravn_sessionizer_pick
        ravn-sessionizer
        commandline -f repaint
    end

    bind \es __ravn_sessionizer_pick
    bind -M insert \es __ravn_sessionizer_pick 2>/dev/null
end
