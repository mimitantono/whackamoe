// Conditionally exports the native ML Kit implementation on mobile,
// or a no-op stub on web (dart:io and ML Kit don't compile for web).
export 'segmentation_service_native.dart'
    if (dart.library.html) 'segmentation_service_web.dart';
