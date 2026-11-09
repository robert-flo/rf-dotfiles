# rf-dotfiles

Repositorio canónico unificado de dotfiles para la estación de trabajo multiusuario (Omarchy, Niri, Clavis y Nyxuri) gestionado con **[chezmoi](https://www.chezmoi.io/)**.

## Estructura por Capas

- **Común (`dot_config/lazygit/`, git, fish, etc.)**: Compartido por todos los perfiles del sistema.
- **Perfil Clavis (`niri`, `niri-test`, `sura`)**: Escritorio Wayland con Niri Edge, Clavis Quickshell, temas MacTahoe y Matugen.
- **Perfil Omarchy (`rollo`, `omarchy`, `omarchy-test`)**: Escritorio Hyprland con Omarchy 4.6 (Dock, workspace flotante, menús).
- **Hooks idempotentes (`run_onchange_*.sh`)**: Ejecutan post-instalación y regeneración de temas automáticamente ante cambios de configuración.

## Uso

```bash
# Aplicación directa
chezmoi init --apply robert-flo/rf-dotfiles

# Forzar perfil específico
CHEZMOI_PROFILE=clavis chezmoi apply
```
