# Reglas y Estándar Operativo para Agentes en rf-dotfiles

Este repositorio (`robert-flo/rf-dotfiles`) es el **Monorepo Canónico y Única Fuente de la Verdad (SSoT)** para la configuración de usuario (dotfiles), temas y manifiesto de paquetes de toda la flota de usuarios de la estación de trabajo multiusuario (`rollo`, `niri`, `niri-test`, `omarchy-test`, `nyxuri`, `nyxuri-test`) gestionado con **[Chezmoi](https://www.chezmoi.io/)**.

Rige de forma vinculante junto a las decisiones arquitectónicas formalizadas en el vault principal (ver `ADR 0001` y `ADR 0003`).

---

## 🎯 Principios Innegociables de Arquitectura

1. **Cero Re-pensamiento (Zero-Guesswork Policy):**
   - Toda configuración tiene un destino canónico predeterminado en la jerarquía de directorios. Ningún agente debe reinventar la rueda ni crear rutas alternativas o ad-hoc.
2. **Cero Contaminación Cruzada entre Perfiles:**
   - Las configuraciones específicas de un entorno de escritorio (ej. Clavis / MacTahoe) **NUNCA** deben invadir otros entornos (ej. Omarchy / Hyprland). Esto se gobierna estrictamente mediante `.chezmoiignore.tmpl`.
3. **Prohibición Absoluta de Rutas Hardcodeadas (`/home/<user>`):**
   - **NUNCA** hardcodear rutas como `/home/niri`, `/home/rollo` o `/home/omarchy` en archivos versionados.
   - **SIEMPRE** crear archivos de plantilla con sufijo `.tmpl` y utilizar la variable de Chezmoi `{{ .chezmoi.homeDir }}`.
   - Si un script auxiliar realiza transformaciones con `sed`, **DEBE** incluir obligatoriamente la barra final `/` (ej. `s|/home/niri/|$HOME/|g`) para evitar colisiones catastróficas como `/home/niri-test-test`.
4. **Manifiesto Único de Paquetes (`.chezmoidata/packages.json`):**
   - Ningún script de shell debe contener listas estáticas duplicadas de paquetes. Toda adición, remoción o actualización de paquetes del sistema se declara en `.chezmoidata/packages.json`.

---

## 🗂️ Taxonomía Canónica: Dónde Direccionar Cada Cosa

Cualquier cambio o incorporación debe ubicarse estrictamente según esta matriz:

### 1. Herramientas Comunes (Compartidas por TODOS los Usuarios)
Archivos y enlaces que deben existir idénticos en todos los perfiles del sistema:
- `dot_config/lazygit/config.yml`: Configuración canónica de Craftzdog (Delta diff renderer + Commitizen en tecla `C`).
- `dot_config/fish/`: Configuración global de la shell interactiva Fish.
- `dot_config/fish/conf.d/android.fish`: Variables globales de ruta para Android SDK y herramientas de consola.
- `dot_config/alacritty/alacritty.toml`: Emulador de terminal común de referencia.
- `dot_config/btop/`, `dot_config/fastfetch/`: Diagnóstico y visualización CLI.
- `dot_config/mpv/`: Reproductor multimedia con interfaz `uosc` Cupertino, botones MacTahoe y aceleración GPU.
- `dot_config/obsidian/obsidian.json.tmpl`: Registro y apertura automática de la bóveda de notas (`Documents/Notas`).
- `Documents/Notas/`: Bóveda de notas con tema Violet nativo y snippets de difuminado Glass.
- `dot_config/thunderbird/`: Perfil de correo con tema translúcido LiquidBird.
- `dot_bashrc.tmpl`: Entorno interactivo común (incluye exports de Android) + bloque condicional `{{ if eq .chezmoi.username "rollo" }}` para herramientas de administración (DiscoSeguro y Bóveda LUKS).
- `dot_Android/symlink_Sdk`: Enlace simbólico declarativo hacia `/opt/android-sdk`.
- `symlink_Cloud`: Enlace declarativo hacia `/z-drive/cloud`.
- `symlink_Vaughan`: Enlace declarativo hacia `/z-drive/vaughan`.
- `symlink_Idalia`: Enlace declarativo hacia `/z-drive/idalia`.
- `symlink_Uploads-Gracie`: Enlace declarativo hacia `/z-drive/uploads-gracie`.
- `symlink__boveda`: Enlace declarativo hacia `/z-drive/boveda`.
- `dot_Work/symlink_tries`: Enlace declarativo hacia `/z-drive/tries`.
- `dot_config/rclone/symlink_rclone.conf`: Enlace declarativo hacia `/etc/rclone/rclone.conf`.

### 2. Perfil Clavis (`niri`, `niri-test`, `sura`)
Archivos de la experiencia Wayland Clavis Shell (Quickshell) y Niri:
- `dot_config/niri/`: `config.kdl`, atajos de teclado, reglas de ventana, acciones y esquinas.
- `dot_config/clavis/config.json.tmpl`: Configuración central de Clavis Shell (con `{{ .chezmoi.homeDir }}`).
- `dot_config/gtk-3.0/`, `dot_config/gtk-4.0/`: Temas visuales MacTahoe Dark GTK.
- `dot_config/fcitx5/`: Tema visual Matugen para métodos de entrada.
- `dot_config/environment.d/clavis-mpvpaper.conf.tmpl`: Variables de sesión Wayland.
- `dot_config/systemd/user/niri.service.wants/`: Enlaces declarativos a `clavis-shell.service` y `clavis-clipboard.service`.
- `dot_config/waybar/`, `dot_config/mako/`, `dot_config/fuzzel/`: Barras y notificaciones auxiliares.
- `dot_local/bin/`: Scripts de postinstalación y optimización (`executable_niri-dotfiles-postinstall`).
- `dot_local/share/`: Perfiles Matugen, paletas de colores y fuentes.

### 3. Perfil Omarchy (`rollo`, `omarchy-test`, `omarchy`)
Archivos de la experiencia Hyprland bajo Omarchy Quattro (4.6):
- `dot_config/omarchy/shell.json`: Barra de estado superior, reloj mundial (`elsewhen`), dock inferior con aplicaciones ancladas (`dock.pinned`) y control de energía.
- `dot_local/state/omarchy/workspace-layouts/1.lua`: Layout `o.workspace_mode({ workspace = "1", mode = "floating" })`. **Obligatorio para que Omarchy 4.6 muestre el dock en el primer workspace**.

### 4. Perfil Nyxuri (`nyxuri`, `nyxuri-test`, `nyxuri-legacy`)
- Recibe exclusivamente las **Herramientas Comunes** (lazygit, fish, alacritty, bashrc).
- Su motor de escritorio se gestiona de forma autónoma mediante la CLI `nyxuri` vinculada a `/z/nyxuri`.

---

## 🛡️ Gobernanza de `.chezmoiignore.tmpl`

Toda nueva ruta agregada que no pertenezca a la categoría **Común** debe estar registrada en `.chezmoiignore.tmpl` dentro de su respectivo bloque de exclusión:

```text
# Excluir dotfiles de Clavis para otros perfiles
{{ if ne $profile "clavis" }}
.config/niri/**
.config/clavis/**
.config/gtk-3.0/**
.config/gtk-4.0/**
.config/fcitx5/**
.config/mpv/**
.config/obsidian/**
.config/environment.d/**
.config/waybar/**
.config/mako/**
.config/fuzzel/**
.config/thunderbird/**
.icons/**
.local/bin/**
.local/share/**
Documents/**
clavis-postinstall.sh
{{ end }}

# Excluir dotfiles de Omarchy para otros perfiles
{{ if ne $profile "omarchy" }}
.config/hypr/**
.config/omarchy/**
.local/state/omarchy/**
{{ end }}
```

---

## 📦 Manifiesto de Paquetes (`.chezmoidata/packages.json`)

El archivo `.chezmoidata/packages.json` estructura los paquetes en 3 arrays JSON:
1. `"official"`: Paquetes del repositorio oficial de Arch Linux (`pacman`).
2. `"personal"`: Paquetes empaquetados por `pj-omarchy` y servidos por `omarchy-personal-repo` (`herdr`, suite `ravn-*`).
3. `"aur"`: Paquetes de Arch User Repository (`yay`).

### Ciclo de Sincronización Automática
El script de plantilla `run_onchange_before_01-install-packages.sh.tmpl` contiene la directiva:
```text
# packages.json hash: {{ include ".chezmoidata/packages.json" | sha256sum }}
```
Al modificar `.chezmoidata/packages.json`, Chezmoi detecta el cambio de hash en la siguiente ejecución de `chezmoi apply` e invoca automáticamente la reconciliación de paquetes faltantes.

---

## 🔄 Protocolo de Modificación y Despliegue Seguro

1. **Área de Trabajo y Ubicaciones:**
   - Repositorio de trabajo local: `/home/rollo/Work/tries/rf-dotfiles`
   - Repositorio compartido central: `/z/rf-dotfiles` (permisos `2775`, propietario `rollo:wheel`, `git config core.fileMode false`).
2. **Validación en Testbench:**
   - Probar siempre los cambios en cuentas desechables antes de tocar producción:
     ```bash
     # Para cambios en Clavis:
     sudo -u niri-test -H chezmoi diff --source=/z/rf-dotfiles
     sudo -u niri-test -H chezmoi apply --source=/z/rf-dotfiles --force
     sudo -u niri-test niri validate

     # Para cambios en Omarchy:
     sudo -u omarchy-test -H chezmoi diff --source=/z/rf-dotfiles
     sudo -u omarchy-test -H chezmoi apply --source=/z/rf-dotfiles --force
     ```
3. **Aplicación a Producción:**
   - Una vez validado en el testbench:
     ```bash
     sudo -u niri -H chezmoi apply --source=/z/rf-dotfiles --force
     chezmoi apply --source=/z/rf-dotfiles --force   # Para usuario administrador rollo
     ```
4. **Git:**
   - Rama principal: `master`.
   - Cero trailers de `Co-authored-by` o atribución a IAs.
   - Tras pushear cambios a GitHub (`origin master`), actualizar de inmediato el clon central en `/z/rf-dotfiles`:
     ```bash
     git -C /z/rf-dotfiles pull --ff-only origin master
     ```
   - Ejecutar `make converge` en el vault de workstation para certificar que el playbook reporta `Cambios aplicados en capas 01-07: 0`.
