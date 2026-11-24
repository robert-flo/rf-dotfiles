# Guía del Makefile (`rf-dotfiles`)

Esta guía explica **cómo se trabaja con el `Makefile` de `rf-dotfiles`**. Si acabas de llegar al repositorio, empieza por el flujo diario y usa la tabla de referencia al final como consulta rápida.

---

## 1. Dos ideas clave antes de ejecutar nada

1. **Dónde lee `chezmoi` vs. desde dónde corres `make`:**
   - Muchos comandos diarios (`morning`, `status`, `diff`, `lose`, `pull`, `safe`, `root`) operan sobre la **copia de producción que `chezmoi` lee** (`chezmoi source-path`, normalmente `/z/rf-dotfiles`).
   - Otros comandos (`apply`, `apply-*`, `managed`, `ignored`, `verify`) usan el **directorio actual** (`-S $(CURDIR)`), pensado para probar o verificar cambios en tu clon/rama antes de llevarlos a producción.
2. **Perfiles y `DRY_RUN=1`:**
   - El perfil activo (`clavis`, `nyxuri`, `omarchy`) se detecta automáticamente según el usuario del sistema, o puedes forzarlo con `CHEZMOI_PROFILE=<perfil>`.
   - Los targets que modifican estado soportan `DRY_RUN=1` para previsualizar qué comandos se ejecutarían sin cambiar nada.

---

## 2. Flujo de trabajo diario

### Paso 1: Revisar el estado al iniciar (`make morning`)
```bash
make morning
```
Te da un tablero de solo lectura con:
- Si la copia de `chezmoi` está al día con `origin/master` (`behind` / `ahead`).
- Qué perfil se resolvió (`profile`) y si tienes `sudo` sin contraseña (`sudo: yes|no`).
- **`lose:`** archivos de tu `$HOME` que un `chezmoi apply` modificaría o borraría.
- **`scripts:`** scripts de `chezmoi` (`run_onchange_*`) que se volverían a ejecutar.

### Paso 2: Ver exactamente qué cambiaría (`make status` / `make diff` / `make lose`)
```bash
make status   # Resumen corto de drift (M, D, A, R)
make diff     # Diff completo contra la copia de producción
make lose     # Solo la lista de archivos del $HOME que se pisarían (sale != 0 si hay alguno)
```

### Paso 3: Traer cambios del remoto sin tocar tu `$HOME` (`make pull`)
```bash
make pull DRY_RUN=1   # Previsualizar
make pull             # Hace pull --rebase --autostash en la copia de chezmoi y en tu clon actual
```

### Paso 4: Aplicar cambios de forma segura (`make safe` o `make root`)
- **Aplicar al `$HOME` solo si no pierdes nada:**
  ```bash
  make safe
  ```
  Ejecuta `lose` primero. Si hay archivos modificados localmente en `$HOME`, se detiene sin aplicar para que no pierdas trabajo. Si `lose` está vacío, aplica con el perfil resuelto.
- **Aplicar solo scripts de sistema (paquetes y herramientas en `/usr/local/bin/`):**
  ```bash
  make root DRY_RUN=1   # Previsualizar
  make root             # Requiere sudo -n; no toca archivos del $HOME
  ```

---

## 3. Flujo al hacer cambios en el repositorio

Cuando editas dotfiles, scripts o `.chezmoidata/packages.json` en tu rama:

1. **Diagnostica el entorno:**
   ```bash
   make doctor
   ```
   Verifica que existan `chezmoi`, `jq`, `shellcheck`, `git`, `.chezmoidata/packages.json` y que los destinos de `symlink_*` existan en el host.

2. **Corre la suite completa de verificación:**
   ```bash
   make check
   ```
   Ejecuta en orden:
   - `make verify` — valida `.chezmoiignore.tmpl` en `clavis`, `nyxuri` y `omarchy` y asegura que `Makefile` y `make/*` no se filtren al `$HOME`.
   - `make packages-check` — valida la estructura JSON (`official`, `personal`, `aur`) y busca paquetes duplicados en `.chezmoidata/packages.json`.
   - `make lint` — pasa `shellcheck` sobre `scripts/yt-*`, `scripts/rf-make-daily.sh` y `scripts/tests/*.sh`.
   - `make test` — ejecuta las suites de pruebas en `scripts/tests/*.sh`.

3. **Prueba en seco y revisa Git** (`make apply` usa `--force`: pisa sin preguntar lo que difiera del repo; mira antes `make lose`):
   ```bash
   make apply DRY_RUN=1
   make git-status
   ```
   Si trabajas sobre un perfil específico, puedes probar con `make apply-clavis DRY_RUN=1`, `make apply-nyxuri DRY_RUN=1` o `make apply-omarchy DRY_RUN=1`.

4. **Despliegue:**
   Valida en el usuario testbench correspondiente (`niri-test` u `omarchy-test`), haz merge a `master`, actualiza la copia de producción (`make pull`) y aplica (`make safe` o `chezmoi apply`).

---

## 4. Referencia rápida de targets

Puedes ver esta lista en la terminal en cualquier momento con `make help`.

### Día a día (`make/daily.mk`)
| Target | Qué hace | ¿Muta? |
| :--- | :--- | :--- |
| `make morning` | Tablero completo: git vs `origin/master`, perfil, `sudo`, `lose` y `scripts` | No (hace `git fetch`) |
| `make lose` | Lista archivos del `$HOME` que `apply` pisaría; sale `1` si hay alguno | No |
| `make pull` | `git pull --rebase --autostash` en `source-path` y clon actual | Sí (`DRY_RUN=1`) |
| `make safe` | Corre `lose` y aplica el `$HOME` solo si `lose` está vacío; nunca pasa `--force` | Sí (`DRY_RUN=1`) |
| `make root` | Ejecuta solo los scripts de raíz (paquetes y herramientas); no toca `$HOME` | Sí (`DRY_RUN=1`) |

### Ciclo de vida Chezmoi (`make/chezmoi.mk`)
| Target | Qué hace | ¿Muta? |
| :--- | :--- | :--- |
| `make status` | Muestra `chezmoi status` contra la copia de producción | No |
| `make diff` | Muestra `chezmoi diff` completo contra la copia de producción | No |
| `make apply` | Ejecuta `chezmoi apply --force -S $(CURDIR)`: **sobrescribe sin preguntar** los archivos del `$HOME` que difieran del repo (míralos antes con `make lose`) | Sí (`DRY_RUN=1`) |
| `make apply-<perfil>` | Igual que `apply` (con `--force`), forzando `CHEZMOI_PROFILE` (`clavis`, `nyxuri`, `omarchy`) | Sí (`DRY_RUN=1`) |
| `make managed` | Lista rutas gestionadas para el perfil activo en `$(CURDIR)` | No |
| `make ignored` | Lista rutas ignoradas para el perfil activo en `$(CURDIR)` | No |
| `make verify` | Verifica `.chezmoiignore.tmpl` y exclusión de `Makefile`/`make/*` | No (`DRY_RUN=1`) |

### Paquetes SSoT (`make/packages.mk`)
| Target | Qué hace | ¿Muta? |
| :--- | :--- | :--- |
| `make packages-check` | Valida esquema y duplicados en `.chezmoidata/packages.json` | No |
| `make packages-summary` | Cuenta paquetes por canal (`official`, `personal`, `aur`, total) | No |
| `make packages-missing` | Compara `.chezmoidata/packages.json` contra `pacman -Qq` | No |

### Calidad, diagnóstico y Git (`make/lint.mk`, `make/doctor.mk`, `make/git.mk`)
| Target | Qué hace | ¿Muta? |
| :--- | :--- | :--- |
| `make lint` | Ejecuta `shellcheck` en los scripts del repo | No |
| `make test` | Ejecuta las pruebas en `scripts/tests/*.sh` | No |
| `make check` | Corre `verify`, `packages-check`, `lint` y `test` | No |
| `make doctor` | Comprueba herramientas, manifiesto de paquetes y symlinks declarativos | No |
| `make git-status` | Muestra rama, drift vs `origin/master`, árbol y últimos commits | No |

---

## 5. Variables útiles

- `DRY_RUN=1`: Previsualiza comandos sin modificar archivos ni ejecutar cambios.
- `CHEZMOI_PROFILE=clavis|nyxuri|omarchy`: Fuerza el perfil en lugar de autodetectarlo por usuario.
- `CHEZMOI_BIN=/ruta/a/chezmoi`: Permite usar otro binario de `chezmoi` (no usar `CHEZMOI`, ya que `chezmoi` exporta `CHEZMOI=1` en sus subshells).
