---
name: terminal-light-theme-standard
description: Single Source of Truth (SSoT) y especificación de diseño ergonómico para el tema claro en terminales (Kitty, Alacritty, Ghostty) y herramientas CLI/TUI (agy, Cursor CLI, OpenCode, Bat, Glow). Usar siempre que se configure, agregue o depure la legibilidad de herramientas de terminal en modo claro.
---

# 🎨 Estándar de Diseño de Terminal para Modo Claro (Clavis / Omarchy)

Este documento y skill define la **Fuente Única de Verdad (SSoT)** para la configuración, paleta y ergonomía visual de aplicaciones de terminal y herramientas CLI interactivas cuando se utiliza el **Tema Claro**.

Fue calibrado para largas jornadas de trabajo eliminando la fatiga visual, los halos agresivos y los textos ilegibles por falta de contraste.

---

## 1. Principios Fundamentales de Ergonomía

1. **Fondo Papel Reposado (`#eff1f5`):**
   * *Anti-resplandor:* Nunca usar blanco puro (`#ffffff`) en la terminal, ya que produce deslumbramiento y fatiga ocular tras sesiones prolongadas.
   * *Calidez:* El tono `#eff1f5` emula el papel satinado de alta calidad, filtrando el exceso de luz azul.

2. **Texto Base Carbón Pizarra (`#3a3d52`):**
   * *Anti-halo:* Evita el negro absoluto (`#000000`). El contraste del negro puro sobre blanco genera un efecto de aberración o halo en los bordes tipográficos. `#3a3d52` ofrece nitidez 100% legible con bordes suaves.

3. **Tonos Joya de Alto Contraste (Regla de Oro en Modo Claro):**
   * En modo oscuro, los colores pasteles o claros destacan bien. **En modo claro, los pasteles son letales**: un celeste suave o un verde menta sobre fondo claro se vuelven invisibles.
   * En modo claro se deben emplear **tonos joya profundos y saturados**:
     * Azul Zafiro (`#0969da` / `#1e66f5`) en lugar de celeste.
     * Verde Bosque (`#2e7d32` / `#15803d`) en lugar de verde pastel.
     * Ámbar Tostado (`#b45309`) en lugar de amarillo pálido.
     * Rojo Rubí (`#d20f39` / `#b91c1c`) en lugar de rosa claro.

4. **Margen y Respiración Visual:**
   * Las terminales deben contar con padding interno (`12px` - `14px`) para evitar que el texto quede pegado a los bordes de la pantalla.
   * `dim_opacity` calibrado al `0.85` para que los textos atenuados no desaparezcan.

---

## 2. Paleta Oficial Acordada (Especificación HEX)

### Colores Principales de la Ventana

| Elemento | Valor HEX | Descripción |
| :--- | :--- | :--- |
| **Background** | `#eff1f5` | Fondo papel suave anti-fatiga |
| **Foreground** | `#3a3d52` | Texto base carbón pizarra |
| **Cursor** | `#1e66f5` | Azul real de alta visibilidad |
| **Cursor Text** | `#eff1f5` | Fondo invertido para el cursor |
| **Selection Background** | `#ccd0da` | Gris medio suave visible sin tapar texto |
| **Selection Foreground** | `#3a3d52` | Mantiene el texto carbón nítido |
| **URL Underline** | `#0969da` | Azul zafiro de enlace estándar |
| **Active Border** | `#1e66f5` | Azul real para foco activo |
| **Inactive Border** | `#bcc0cc` | Gris neutro para ventanas sin foco |
| **Active Tab Bg/Fg** | `#1e66f5` / `#eff1f5` | Pestaña activa azul con texto blanco |
| **Inactive Tab Bg/Fg**| `#e6e9ef` / `#4c4f69` | Pestaña inactiva integrada con texto medio |

---

### Mapeo de la Tabla ANSI (0 al 15)

```text
=============================================================================
ID   NOMBRE                   HEX        CASO DE USO HABITUAL
=============================================================================
 0   Negro / Pizarra Base     #3a3d52    Texto plano, separadores base
 1   Rojo Rubí                #d20f39    Errores, eliminaciones (git diff -)
 2   Verde Bosque             #2e7d32    Éxitos, adiciones (git diff +)
 3   Ámbar Tostado            #b45309    Advertencias, etiquetas (auto, warn)
 4   Azul Real                #1e66f5    Palabras clave, funciones, enlaces
 5   Violeta Malva            #7c3aed    Constantes, tipos, identificadores
 6   Teal Pino Oscuro         #0f766e    Rutas de archivos, directorios
 7   Gris Pizarra             #4c4f69    Texto secundario, cabeceras de tablas
-----------------------------------------------------------------------------
 8   Gris Secundario / Border #5c5f77    Comentarios, texto de ayuda
 9   Rojo Carmesí Brillante   #b91c1c    Errores críticos, badges
10   Verde Hoja Brillante     #15803d    Estado activo, tests aprobados
11   Ámbar Cálido             #92400e    Avisos de atención, parámetros CLI
12   Azul Zafiro / Código     #0969da    Comandos ejecutables, código inline
13   Púrpura Profundo         #6d28d9    Clases, decoradores, macros
14   Teal Océano Brillante    #0e7490    Módulos, URLs activas
15   Carbón Neutro Oscuro     #181926    Texto enfatizado de máxima densidad
=============================================================================
```

---

## 3. Guía de Aplicación por Emulador de Terminal

### A. Kitty (`~/.config/kitty/current-theme.conf`)

```ini
foreground              #3a3d52
background              #eff1f5
selection_foreground    #3a3d52
selection_background    #ccd0da
cursor                  #1e66f5
cursor_text_color       #eff1f5
url_color               #0969da

active_border_color     #1e66f5
inactive_border_color   #bcc0cc
bell_border_color       #b45309

active_tab_foreground   #eff1f5
active_tab_background   #1e66f5
inactive_tab_foreground #4c4f69
inactive_tab_background #e6e9ef
tab_bar_background      #dce0e8

# ANSI 0 - 7
color0                  #3a3d52
color1                  #d20f39
color2                  #2e7d32
color3                  #b45309
color4                  #1e66f5
color5                  #7c3aed
color6                  #0f766e
color7                  #4c4f69

# ANSI 8 - 15
color8                  #5c5f77
color9                  #b91c1c
color10                 #15803d
color11                 #92400e
color12                 #0969da
color13                 #6d28d9
color14                 #0e7490
color15                 #181926
```

---

### B. Alacritty (`~/.config/alacritty/alacritty.toml`)

```toml
[colors.primary]
background = "#eff1f5"
foreground = "#3a3d52"

[colors.cursor]
text = "#eff1f5"
cursor = "#1e66f5"

[colors.selection]
text = "#3a3d52"
background = "#ccd0da"

[colors.normal]
black   = "#3a3d52"
red     = "#d20f39"
green   = "#2e7d32"
yellow  = "#b45309"
blue    = "#1e66f5"
magenta = "#7c3aed"
cyan    = "#0f766e"
white   = "#4c4f69"

[colors.bright]
black   = "#5c5f77"
red     = "#b91c1c"
green   = "#15803d"
yellow  = "#92400e"
blue    = "#0969da"
magenta = "#6d28d9"
cyan    = "#0e7490"
white   = "#181926"
```

---

### C. Ghostty (`~/.config/ghostty/config`)

En la estación de trabajo, **Ghostty tiene polaridad fija Dark** (`theme = "Solarized Dark - Patched"`) y **Kitty tiene polaridad fija Light** (contrato `RF_TERM_THEME`, ver §4). Si en algún entorno externo se necesitara un tema claro para Ghostty, usar la paleta de §2:

```ini
# Definición de referencia para un perfil claro externo de Ghostty:
background = #eff1f5
foreground = #3a3d52
cursor-color = #1e66f5
cursor-text = #eff1f5
selection-background = #ccd0da
selection-foreground = #3a3d52

palette = 0=#3a3d52
palette = 1=#d20f39
palette = 2=#2e7d32
palette = 3=#b45309
palette = 4=#1e66f5
palette = 5=#7c3aed
palette = 6=#0f766e
palette = 7=#4c4f69
palette = 8=#5c5f77
palette = 9=#b91c1c
palette = 10=#15803d
palette = 11=#92400e
palette = 12=#0969da
palette = 13=#6d28d9
palette = 14=#0e7490
palette = 15=#181926
```

---

## 4. Contrato por Terminal (`RF_TERM_THEME`) y Herramientas CLI/TUI

### Contrato de Polaridad por Proceso
La polaridad de las terminales está **desacoplada de Clavis** (`~/.config/clavis/config.json`) y se propaga por proceso mediante variables de entorno:

| Terminal | Polaridad fija | Variables exportadas |
| :--- | :--- | :--- |
| **Kitty** | `light` (`current-theme-light.conf`) | `RF_TERM_THEME=light`, `COLORFGBG=0;15`, `BAT_THEME=ansi`, `GLAMOUR_STYLE=light` |
| **Ghostty** | `dark` (`Solarized Dark - Patched`) | `RF_TERM_THEME=dark`, `COLORFGBG=15;0`, `BAT_THEME=ansi`, `GLAMOUR_STYLE=dark` |

* **Helper SSoT:** `~/.local/bin/rf-term-theme` resuelve `light` o `dark` con precedencia estricta:
  1. `RF_TERM_THEME` explícito (`light` o `dark`).
  2. Emulador detectado (`GHOSTTY_RESOURCES_DIR` / `TERM_PROGRAM=ghostty` / `TERM=xterm-ghostty` → `dark`; `KITTY_PID` / `TERM=xterm-kitty` → `light`).
  3. `COLORFGBG` (segundo valor numérico `< 8` → `dark`, `>= 8` → `light`).
  4. Fallback: `~/.config/clavis/config.json` (`.theme.mode`) o `dark`.
* **Override por sesión:** funciones `term-light` y `term-dark` en Fish (`rf-common.fish`) y Bash (`~/.bashrc`).

### El Problema de las Herramientas CLI con Markdown y Código
La mayoría de herramientas CLI modernas (Antigravity CLI, Cursor CLI, OpenCode, Aider, Glow, Bat) utilizan renderizadores de sintaxis como **Chroma**, **Pygments** o **Glamour**.
Por defecto, casi todas asumen una terminal oscura y renderizan el texto plano y los comandos en color **blanco/gris claro (`#f8f8f2`)**, volviéndose invisibles sobre fondo claro.

### Reglas de Configuración para Cualquier Nueva Herramienta

1. **Antigravity CLI (`agy`):**
   * Wrapper `~/.local/bin/agy`: resuelve `MODE="$("$HOME/.local/bin/rf-term-theme")"` e inyecta `--settings "{\"colorScheme\": \"$MODE\"}"` **solo para la sesión actual**.
   * **Prohibido mutar `~/.gemini/antigravity-cli/settings.json`** desde el wrapper para permitir sesiones simultáneas en Kitty (light) y Ghostty (dark).

2. **Bat / Delta / Lazygit (Paginadores de sintaxis y git diff):**
   * `BAT_THEME="ansi"` en ambos emuladores para heredar los colores ANSI calibrados del terminal.
   * En `lazygit` (`~/.config/lazygit/config.yml`), `diffRenderers` consulta `rf-term-theme` y ejecuta `delta --light --syntax-theme=ansi --paging=never` en terminales claras y `--dark` en oscuras.

3. **Glow / Glamour (Renderizadores de Markdown):**
   * Variable de entorno `GLAMOUR_STYLE="light"` en Kitty y `GLAMOUR_STYLE="dark"` en Ghostty.

4. **Cursor CLI / OpenCode / Aider:**
   * Asegurar `COLORFGBG="0;15"` en Kitty (ya exportado en `kitty.conf`) para que las herramientas basadas en terminfo detecten fondo claro.

5. **Yazi (`~/.config/yazi/theme.toml` + `flavors/`):**
   * Usa **Flavors nativos** con autodetección OSC 11 (`[flavor] light = "clavis-light"`, `dark = "clavis-dark"`).
   * Los flavors se despliegan en `~/.config/yazi/flavors/clavis-{light,dark}.yazi/flavor.toml` desde `.upstream/yazi/theme-{light,dark}.toml`.
   * Prevenir colores `_fixed` o pasteles en `[filetype].rules`: imágenes en violeta joya (`#7c3aed`), media en teal (`#0e7490`), archivos en ámbar (`#b45309`), documentos en azul zafiro (`#0969da`), ejecutables en rojo rubí (`#d20f39`) y carpetas en azul real en negrita (`#1e66f5`).

6. **Elio File Manager (`~/.config/elio/` + `~/.local/bin/elio`):**
   * **Desacoplado de Matugen:** utiliza las paletas estáticas SSoT desplegadas vía Chezmoi en `~/.config/elio/theme-light.toml` y `~/.config/elio/theme-dark.toml` (más `theme.toml` como fallback light).
   * El wrapper `~/.local/bin/elio` consulta `rf-term-theme` y pasa `--theme "$HOME/.config/elio/theme-${MODE}.toml"`, dejando pasar intactos `shell`, `portal`, `-h`, `--help`, `-V`, `--version` y `--theme`.
   * `[palette]` light: fondo cálido `bg = "#eff1f5"`, paneles `panel = "#eff1f5"`, texto carbón `text = "#3a3d52"`, selección `selected_bg = "#ccd0da"`, borde seleccionado `selected_border = "#1e66f5"`, acento `accent = "#1e66f5"`.

---

## 5. Verificación Rápida

Para verificar el contrato de polaridad en la sesión actual:

```bash
rf-term-theme
env | grep -E '^(RF_TERM_THEME|COLORFGBG|BAT_THEME|GLAMOUR_STYLE)='
```
