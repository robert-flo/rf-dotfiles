---
name: terminal-dark-theme-standard
description: "Single Source of Truth (SSoT) y especificación de diseño ergonómico para el tema oscuro en terminales (Kitty, Alacritty, Ghostty) y herramientas CLI/TUI (agy, Cursor CLI, OpenCode, Yazi, Elio, Bat, Glow). Usar siempre que se configure, agregue o depure la legibilidad de herramientas de terminal en modo oscuro."
---

# Estándar de Diseño y Ergonomía para Terminales (Modo Oscuro)

Este documento es la **Fuente Única de Verdad (SSoT)** para configurar cualquier emulador de terminal o herramienta de línea de comandos en **Modo Oscuro** en esta estación de trabajo.

---

## 1. Principios Fundamentales

1. **Fondo reposado (`#1e1e2e` / `#0f1417`):**
   * Prohibido el negro puro (`#000000`). Se requiere `#1e1e2e` (Catppuccin Mocha) o el fondo adaptativo de Matugen.
2. **Tipografía nítida anti-halo (`#cdd6f4` / `#dfe3e7`):**
   * Prohibido el blanco puro (`#ffffff`) sobre fondos oscuros.
3. **Acentos vibrantes con contraste > 6:1:**
   * Directorios y primario: `#89b4fa` (Azul zafiro)
   * Éxito, código y datos: `#a6e3a1` (Verde menta)
   * Advertencias y comprimidos: `#fab387` / `#f9e2af` (Melocotón / Dorado)
   * Errores y ejecutables: `#f38ba8` (Coral / Rojo)
   * Multimedia e imágenes: `#cba6f7` / `#f5c2e7` (Malva / Rosa)
   * Enlaces y symlinks: `#89dceb` / `#94e2d5` (Sky / Teal)
4. **Regla de Contenedores y Modales (Elio / Yazi):**
   * `accent_text` debe ser claro (`#eff1f5` / `#cdd6f4`) sobre superficies oscuras.

---

## 2. Paleta Oficial ANSI (0 - 15)

| ID | Nombre | Hex | Caso de Uso |
| :---: | :--- | :---: | :--- |
| `0` | Black | `#45475a` | Superficie visible (distinta del fondo) |
| `1` | Red | `#f38ba8` | Errores, git deletions |
| `2` | Green | `#a6e3a1` | Tests passing, git additions |
| `3` | Yellow | `#f9e2af` | Advertencias, parámetros |
| `4` | Blue | `#89b4fa` | Carpetas, comandos principales |
| `5` | Magenta | `#cba6f7` | Tipos, constantes |
| `6` | Cyan | `#89dceb` | Operadores, symlinks |
| `7` | White | `#bac2de` | Texto secundario |
| `8` | Bright Black | `#585b70` | Comentarios |
| `9` | Bright Red | `#eba0ac` | Errores críticos |
| `10` | Bright Green | `#94e2d5` | Módulos activos |
| `11` | Bright Yellow | `#fab387` | Avisos de build |
| `12` | Bright Blue | `#74c7ec` | Enlaces vivos |
| `13` | Bright Magenta | `#f5c2e7` | Multimedia |
| `14` | Bright Cyan | `#b4befe` | Keywords |
| `15` | Bright White | `#a6adc8` | Resaltado máximo |

---

## 3. Contrato por Terminal (`RF_TERM_THEME`) y Guía de Aplicación

### Contrato de Polaridad por Proceso
La polaridad de las terminales está **desacoplada de Clavis** (`~/.config/clavis/config.json`) y se propaga por proceso:

* **Ghostty (Dark fijo):** mantiene `theme = "Solarized Dark - Patched"` en `~/.config/ghostty/config` y exporta:
  ```ini
  env = RF_TERM_THEME=dark
  env = COLORFGBG=15;0
  env = BAT_THEME=ansi
  env = GLAMOUR_STYLE=dark
  ```
* **Kitty (Light fijo):** usa `current-theme-light.conf` y exporta `RF_TERM_THEME=light`, `COLORFGBG=0;15`, `BAT_THEME=ansi`, `GLAMOUR_STYLE=light`.
* **Helper SSoT (`~/.local/bin/rf-term-theme`):** imprime `light` o `dark` con precedencia `RF_TERM_THEME` → emulador (`GHOSTTY_RESOURCES_DIR`/`TERM_PROGRAM`/`TERM`/`KITTY_PID`) → `COLORFGBG` → fallback (`clavis/config.json` o `dark`).
* **Override por sesión:** usar `term-dark` o `term-light` (disponibles en Fish y Bash).

### Herramientas CLI / TUI

* **Antigravity CLI (`agy`):** el wrapper `~/.local/bin/agy` consulta `rf-term-theme` y pasa `--settings "{\"colorScheme\": \"$MODE\"}"` solo a la sesión actual, **sin mutar `~/.gemini/antigravity-cli/settings.json`**.
* **Elio:** el wrapper `~/.local/bin/elio` consulta `rf-term-theme` y selecciona `~/.config/elio/theme-{light,dark}.toml` (desacoplado de Matugen, gestionado vía Chezmoi).
* **Yazi:** usa **Flavors nativos** (`clavis-dark` y `clavis-light` en `~/.config/yazi/flavors/`) con autodetección OSC 11 desde `~/.config/yazi/theme.toml`.
* **Lazygit / Delta:** `diffRenderers` consulta `rf-term-theme` y pasa `--dark --syntax-theme=ansi --paging=never` en terminales oscuras (`--light` en claras).
* **Cursor CLI / OpenCode:** heredan `COLORFGBG=15;0` y `GLAMOUR_STYLE=dark` en Ghostty.
* **Alacritty (referencia):** asignar `background = "#1e1e2e"` y la tabla ANSI de §2.
