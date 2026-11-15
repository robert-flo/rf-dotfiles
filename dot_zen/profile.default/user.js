// Preferences for Zen Browser under rf-dotfiles / MacTahoe workstation
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// Hardware Acceleration (Intel Skylake HD 530 / Wayland / VA-API iHD)
user_pref("gfx.webrender.all", true);
user_pref("widget.dmabuf.force-enabled", true);
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("media.rdd-ffmpeg.enabled", true);
user_pref("media.av1.enabled", false); // HD 530 no tiene AV1 por hardware; fuerza VP9/H.264
