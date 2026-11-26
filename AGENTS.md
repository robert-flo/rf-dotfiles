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
- `dot_config/agy/executable_statusline.sh`: Statusline de agy (sesión, cuota Gemini y la de Claude/GPT). Chezmoi la deja en `~/.config/agy/statusline.sh`. Las claves del JSON siguen siendo `3p-5h` y `3p-weekly`; la línea visible dice «Claude y GPT». El hook `run_onchange_after_configure-agy-statusline.sh.tmpl` escribe `statusLine` en `~/.gemini/antigravity-cli/settings.json` sin borrar el resto.
- `dot_config/cursor/executable_statusline.sh`: Statusline de Cursor. Chezmoi la deja en `~/.config/cursor/statusline.sh`. Dos cubetas del plan, más la de grok.com: `autoPercentUsed` es Auto, Composer y Grok («Auto, Composer y Grok queda N%»); `apiPercentUsed` es Claude, GPT, Gemini y el resto («Claude y otros»). Si la cubeta que gasta el modelo de la sesión está agotada, esa frase va primero. Rojo desde el 80% usado. El total combinado no se muestra. Prueba: `scripts/tests/test-cursor-statusline.sh`.
- `dot_local/bin/executable_rf-stack-update`: trae lo último de `agy` (`mise upgrade antigravity-cli`), `cursor-agent` y `opencode` (mise; lo instala si falta), y los paquetes `cursor-bin`, `antigravity`, `grok-bot`, `monocode-git` (pacman; lo instala si falta) y `antigravity-ide` (AUR si no está en los repos). Si el PKGBUILD pide `openssl-3` y el `openssl` instalado es 3.x, se construye renombrando esa dependencia a `openssl`. Cualquier otra dependencia ausente no se intenta y el comando sigue. Se invoca a mano con `rf-stack-update` o `make stack-update`. En el perfil clavis, `rf-stack-update.timer` lo corre cada hora (`OnCalendar=hourly`, `OnBootSec=2min`, `Persistent=true`); notifica solo si algo cambió o falló. `make apply` no actualiza estas versiones: este comando sí. El hook `run_onchange_after_enable-rf-stack-update.sh.tmpl` hace `daemon-reload` y `enable` del timer.
- OpenCode y MonoCode, en cualquier máquina: `run_before_00-linuxmobile-repo.sh.tmpl` deja el repo pacman `[linuxmobile]` (no duplica la sección). `monocode-git` está en `packages.personal` y el apply lo instala con pacman si falta. `run_onchange_after_install-opencode.sh.tmpl` instala `opencode` con `mise use -g opencode@latest` (node primero, igual que oxfmt y hunk). `run_after_monocode-opencode.sh.tmpl` corre en cada apply y, si MonoCode ya creó su base, fija `default_provider` en `opencode` y `binary_paths.opencode` en el shim de mise. El login de OpenCode no se versiona: vive en `~/.local/share/opencode/opencode.db`.
- `dot_config/environment.d/t3code.conf` y `run_onchange_after_t3code-telemetry.sh.tmpl`: t3code sin telemetría. Las variables `T3CODE_TELEMETRY_ENABLED=false` y `T3CODE_OTEL_SDK_DISABLED=true` van en la sesión (`environment.d`), en `/etc/environment.d/99-t3code.conf` (todos los usuarios al próximo login) y en bash, fish y `~/.zshenv`. El script agrega `0.0.0.0 ingest.t3.codes` a `/etc/hosts` solo si todavía no está.
- `dot_config/btop/`, `dot_config/fastfetch/`: Diagnóstico y visualización CLI.
- `dot_config/mpv/`: Reproductor multimedia con interfaz `uosc` Cupertino, botones MacTahoe y aceleración GPU.
- `dot_config/{chrome,chrome-beta,brave-origin,microsoft-edge-stable}-flags.conf` y `dot_config/chromium-flags.conf.tmpl`: flags de la familia Chromium (Intel HD 530). **Una sola base** (la de `chrome-flags.conf`), idéntica en los cinco; `scripts/tests/test-browser-flag-files.sh` lo exige. Única diferencia: `chromium-flags.conf.tmpl` añade `--load-extension` con las extensiones de Omarchy solo en el perfil `omarchy` y solo si las rutas existen (con una ruta ausente Chromium 155 se queda en el diálogo «Error Loading Extension» y no abre ventana). `--process-per-site` se rechazó: ahorra solo ~15 MiB (PSS 512→497 en Chrome, 637→621 en Edge; mediana de 3) y la caída de una pestaña tumba todas las del mismo sitio (sobreviven 0/2 frente a 2/2, las 3 veces). `--ozone-platform-hint`, `CanvasOopRasterization` y `WaylandWindowDecorations` no existen en ningún binario instalado y se quitaron. Verificación: `make browser-flags-check-all`; evidencia: `scripts/browser-flags-bench` (`run` y `process-model`).
- `dot_config/obsidian/obsidian.json.tmpl`: Registro y apertura automática de la bóveda de notas (`Documents/Notas`).
- `dot_config/spicetify/`: Configuración declarativa de Spicetify (`Themes/Sleek` con esquema `Catppuccin`, extensión `adblock.js` y `modify_config-xpui.ini.tmpl` preservando `[Backup]`), aplicada vía `run_onchange_after_install-spicetify.sh.tmpl`.
- `dot_config/spotify-flags.conf`: Flags nativos de Wayland (`--ozone-platform=wayland`) leídos automáticamente por el wrapper `/usr/bin/spotify` en Arch. **Solo Spotify lleva archivo de flags** (CEF ignora `ELECTRON_OZONE_PLATFORM_HINT`: sin `--ozone-platform=wayland` corre en XWayland; `spicetify` lo repite en `spotify_launch_flags`). VS Code, Antigravity IDE y el Electron del sistema (wrappers `/usr/bin/{code,antigravity-ide,electron}`, que leerían `~/.config/<app>-flags.conf`) no necesitan archivo: ya son Wayland nativo con la variable de sesión (`dot_config/environment.d/30-wayland-toolkits.conf`) y también sin ella. Rechazados con evidencia (`make electron-bench`, `scripts/electron-flags-bench`; `scripts/tests/test-electron-flags-bench.sh` los mantiene fuera): `--enable-wayland-ime`, `--no-sandbox`, `--disable-gpu`, `--disable-gpu-sandbox`, `--ozone-platform=wayland` y `--ozone-platform-hint=auto` en los Electron. La tabla con números y su razón está en el PR de robert-flo/HR-CLAVIS#199.
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
- Suite global `yt-*` en `/usr/local/bin/` (`scripts/yt-audio`, `scripts/yt-audio-playlist`, `scripts/yt-video`, `scripts/yt-video-playlist`, `scripts/yt-x`): Utilidades globales del sistema para descarga de audio Opus, video 1080p MP4 (horizontal/vertical con subtítulos EN opcionales) y videos de X/Twitter con cookies de Chrome, organizadas bajo `/zt/yt-downloads/{audio,audio-playlist,video,video-playlist,x}` (fallback `~/yt-downloads/`) y dejando `/usr/bin/yt-dlp` 100% nativo; gestionadas vía `run_onchange_after_02-install-system-tools.sh.tmpl`.

### 2. Perfil Clavis (`niri`, `niri-test`, `sura`)
Archivos de la experiencia Wayland Clavis Shell (Quickshell) y Niri:
- `dot_config/niri/`: `config.kdl`, atajos de teclado, reglas de ventana, acciones y esquinas.
- `dot_config/clavis/config.json.tmpl`: Configuración central de Clavis Shell (con `{{ .chezmoi.homeDir }}`). Si `make diff` lo marca, la sección de drift de abajo dice qué mecanismo usar.
- `dot_config/gtk-3.0/`, `dot_config/gtk-4.0/`: Temas visuales MacTahoe Dark GTK.
- `dot_config/fcitx5/`: Tema visual Matugen para métodos de entrada.
- `dot_config/environment.d/clavis-mpvpaper.conf.tmpl`: Variables de sesión Wayland.
- `dot_config/environment.d/40-xdg-menu.conf` + `run_onchange_after_03-rebuild-ksycoca.sh.tmpl`: **Dolphin conviviendo con Nautilus** (Nautilus sigue siendo el gestor de `inode/directory`; Dolphin se usa a mano). Sus paquetes (`dolphin`, `kde-cli-tools`, `ffmpegthumbs`, `kdegraphics-thumbnailers`, `breeze-icons`, `archlinux-xdg-menu`) viven solo en `.chezmoidata/packages.json`. El submenú «Abrir con» de Dolphin ya lista aplicaciones por tipo MIME sin nada extra; lo que fuera de Plasma sale vacío es el diálogo «Otra aplicación…» (árbol de aplicaciones), porque falta el menú de aplicaciones: `archlinux-xdg-menu` instala `/etc/xdg/menus/arch-applications.menu` y `XDG_MENU_PREFIX=arch-` (solo perfil `clavis`; `systemd --user` lo lee de `environment.d` y entra en la sesión al volver a iniciarla) hace que KDE lo use. Un caché `ksycoca` creado antes de eso no lo incluye (Dolphin no lo regenera solo), así que el script (inerte fuera de `clavis`) lo reconstruye con el prefijo; bajo `sudo -u niri-test` heredando el entorno de otro usuario `kbuildsycoca6` devuelve 255 («changing ownership of database»; con `env -i` y en una sesión real sale con 0) y el script lo avisa con el código y el error, sin fallar. `ffmpegthumbs` (miniaturas de video de KIO) no sustituye a `ffmpegthumbnailer` (otras apps) y `breeze-icons` se declara aunque `ark` lo traiga, para que no desaparezca como dependencia huérfana. No se toca `QT_QPA_PLATFORMTHEME=gtk3` (`qt-gtk3.conf`). Los programas de terminal lanzados desde Dolphin (p. ej. Helix) fallan con «Terminal konsole not found» hasta fijar `TerminalApplication` en `kdeglobals`; queda fuera de este alcance. Prueba: `scripts/tests/test-dolphin-integration.sh`.
- `dot_config/create_dolphinrc`: preferencias de Dolphin **sembradas una sola vez** (`create_` de chezmoi: se crea si no existe y nunca se sobrescribe, porque Dolphin reescribe su propio `dolphinrc`; si Dolphin ya corrió antes en ese perfil, no se siembra). Solo lo portable: `[MainWindow] MenuBar=Disabled` (en 26.08 el menú ya nace oculto; se fija para que no dependa del valor por defecto), `[General] ShowStatusBar=Disabled`, iconos de 16 px (`[PlacesPanel]` y la barra de herramientas) y `[PreviewSettings] Plugins` (la lista del origen más `gsthumbnail` para PDF, que aporta `kdegraphics-thumbnailers`). Origen: el `dolphinrc` del usuario `hyde` (Rollo); se descartó `2560x1080 screen: Window-Maximized` (pantalla de ese equipo) y cualquier clave de colores de HyDE. **`ShowStatusBar=false` del origen es obsoleto**: desde que `ShowStatusBar` es un enum (`Small|FullWidth|Disabled`) un `false` se ignora y la barra sigue visible; verificado con Dolphin 26.08. Solo perfil `clavis` (`.chezmoiignore.tmpl`). Tema: Dolphin hereda el GTK `MacTahoe-Dark` por `QT_QPA_PLATFORMTHEME=gtk3`; en la captura de la ventana principal y del diálogo «Otra aplicación…» (tema oscuro, selección, botones) no se vio nada roto, así que no se abre ticket de Kvantum (sigue instalado, sin cablear); el veredicto cubre solo esas vistas. Prueba: `scripts/tests/test-dolphin-integration.sh` (incluye el doble `chezmoi apply` en un destino temporal).
- `dot_config/systemd/user/niri.service.wants/`: Enlaces declarativos a `clavis-shell.service` y `clavis-clipboard.service`.
- `dot_config/waybar/`, `dot_config/mako/`, `dot_config/fuzzel/`: Barras y notificaciones auxiliares. En el perfil clavis el servidor de notificaciones es el de Clavis Shell (`qs`). `mako`, `swaync` y `dunst` publican los tres `org.freedesktop.Notifications`; dbus-broker se queda con el primero (`fr.emersion.mako.service`) e ignora los otros como duplicados. Cualquier `notify-send` anterior a que Quickshell termine de cargar arranca `mako.service` por activación D-Bus y Clavis registra «already registered». Por eso `dot_config/systemd/user/symlink_{mako,swaync,dunst}.service` apuntan a `/dev/null` (máscara de usuario, solo clavis: `.config/systemd/**` no se aplica en omarchy). `run_onchange_after_mask-notification-daemons.sh.tmpl` hace `daemon-reload` y los para; al soltar el nombre, `qs` lo vuelve a tomar sin reiniciar la shell. `swaync` y `dunst` no están en `packages.json` (en esta máquina se instalaron el 22 Nov 2026); la máscara cubre el caso igual. Prueba: `scripts/tests/test-notification-daemon-mask.sh`.
- `dot_local/bin/`: Scripts de postinstalación y optimización (`executable_niri-dotfiles-postinstall`).
- `dot_local/share/`: Perfiles Matugen, paletas de colores y fuentes.
- `dot_local/bin/executable_chrome-h264` + `dot_local/share/chrome-h264/h264only.js`: **opt-in** para H.264 en YouTube con Chrome estable, Beta, Chromium y Edge (`chrome-h264 -b stable|beta|chromium|edge`; un perfil dedicado por navegador; Brave Origin 158 no sirve: su binario rechaza `--remote-debugging-pipe`) (la HD 530 decodifica H.264 por VA-API, no VP9/AV1). Activar: `chrome-h264 [URL]`; desactivar: abrir Chrome normal; limpiar: `chrome-h264 --clean`. Perfiles dedicados en `~/.local/state/chrome-h264/<navegador>`; el perfil normal no se toca. Mecanismos probados:
  - `--load-extension`: **descartado**. Chrome de marca 158 (estable y Beta) lo ignora; Chromium 155 sí lo carga.
  - Depuración remota sobre el perfil por defecto: bloqueada por Chrome de marca; por eso el perfil dedicado.
  - Inyección CDP por `--remote-debugging-pipe` (sin puerto TCP) con `Page.addScriptToEvaluateOnNewDocument`: **elegido**; sin extensión ni cambios en `/`.
  - Medido con `scripts/browser-flags-bench -u <YouTube> [-i h264only.js]` (1080p60, tres ventanas, mediana): VP9 por software (`VpxVideoDecoder`) 106–127 % de un núcleo y 40–53 % de CPU del sistema; AV1 por software (Dav1d) 98–126 % y 62–68 %; con H.264 (`VaapiVideoDecoder`) 39–53 % y 49–52 %. Los frames perdidos dependen de la carga puntual de la máquina (0 a ~300 en los tres casos), no del códec.

### Drift entre `$HOME` y la fuente

`make diff` compara el `$HOME` con la copia de producción (`chezmoi source-path`; aquí `/z/rf-dotfiles`). `make apply-clavis` aplica el directorio desde el que se corre. Un cambio sin commit no está en `origin`: `make pull` no lo publica. Hecho cuando `chezmoi diff -S /z/rf-dotfiles -- <ruta del $HOME>` sale vacío.

Tres mecanismos. El criterio es quién escribe el archivo después del apply.

1. **Chezmoi es el dueño del archivo entero.** Caso: `dot_config/niri/statindet-colors.kdl`. Se copia tal cual. El anillo de foco que ya corría en el home (`active-color "#4b5c92"`, gradiente hacia `"#745470"`) reemplazó al de la fuente (`"#156683"` hacia `"#5e5a7d"`). Copiar el archivo del home sobre la fuente. `statindet-animations.kdl` y `statindet-windowrule.kdl` ya coincidían y no se tocaron.

2. **La app reescribe el archivo y chezmoi solo fija unas claves, aunque el archivo ya exista.** Caso: `~/.config/clavis/ui-preferences.json`, vía `dot_config/clavis/modify_ui-preferences.json`. La fuente solo aporta cuatro rutas en `/zt`: `recordingVideoDirectory`, `recordingGifDirectory`, `recordingMicrophoneDirectory`, `recordingSystemAudioDirectory`. El resto (reloj, clima, grilla, tarjetas, nube) lo guarda Clavis. Un template normal en el apply sustituye el archivo por esas cuatro claves. `create_` (el de `create_dolphinrc`) siembra una vez y no vuelve a escribir: sirve cuando la app no crea el archivo antes. Clavis lo crea primero, sin las rutas, así que el mecanismo es `modify_`: lee el JSON por stdin, pone esas cuatro claves en `/zt` y, si ya valen `/zt`, devuelve la entrada sin cambiar un byte. Así el diff queda vacío con el estado vivo intacto. El `modify_` de Spicetify es otro caso: reescribe su config y solo conserva `[Patch]` y `[Backup]`.

3. **El template es la config y el home trae la clave que la app ya migró.** Caso: `dot_config/clavis/config.json.tmpl`, `keystone.dimensions`. El home tenía `"clockPadding": 20`; el template tenía `"compactLength": 220`. Se dejó `clockPadding`. El home no termina en salto de línea; el template cierra con `{{- end -}}` para que el render tampoco.

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
