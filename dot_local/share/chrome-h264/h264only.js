// Oculta VP9 y AV1 a YouTube para que su reproductor adaptativo elija H.264 (AVC).
// Mismo principio que h264ify, sin permisos ni red: solo parchea tres APIs de media.
(() => {
  const blocked = /(vp9|vp09|av01|av1)/i;

  const isTypeSupported = MediaSource.isTypeSupported.bind(MediaSource);
  MediaSource.isTypeSupported = (type) => !blocked.test(type || "") && isTypeSupported(type);

  const canPlayType = HTMLMediaElement.prototype.canPlayType;
  HTMLMediaElement.prototype.canPlayType = function (type) {
    return blocked.test(type || "") ? "" : canPlayType.call(this, type);
  };

  if (navigator.mediaCapabilities && navigator.mediaCapabilities.decodingInfo) {
    const decodingInfo = navigator.mediaCapabilities.decodingInfo.bind(navigator.mediaCapabilities);
    navigator.mediaCapabilities.decodingInfo = (config) => {
      const contentType = (config && config.video && config.video.contentType) || "";
      if (blocked.test(contentType)) {
        return Promise.resolve({ supported: false, smooth: false, powerEfficient: false });
      }
      return decodingInfo(config);
    };
  }
})();
