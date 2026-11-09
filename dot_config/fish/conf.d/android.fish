# --- ANDROID & JAVA ENVIRONMENT (FISH) ---
set -gx ANDROID_HOME "/opt/android-sdk"
set -gx ANDROID_USER_HOME "$HOME/.android"
set -gx ANDROID_PROJECTS_DIR "/z/android-projects"

fish_add_path -a $ANDROID_HOME/emulator $ANDROID_HOME/platform-tools $ANDROID_HOME/cmdline-tools/latest/bin $HOME/.local/bin
# --- FIN ANDROID & JAVA ENVIRONMENT ---
