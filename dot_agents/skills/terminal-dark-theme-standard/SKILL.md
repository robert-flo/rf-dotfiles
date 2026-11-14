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

## 3. Guía de Aplicación para Nuevas Herramientas

* **Cursor CLI / OpenCode:** Usar fondo `#1e1e2e`, texto `#cdd6f4` y tokens de sintaxis Catppuccin Mocha.
* **Ghostty / Alacritty:** Asignar `background = "#1e1e2e"` y la tabla ANSI de arriba.
* **Yazi / Elio:** Usar las plantillas registradas en Chezmoi (`.upstream/*/theme-dark.toml`).
