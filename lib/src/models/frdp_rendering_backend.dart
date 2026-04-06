/// Rendering backend to use for the connection.
enum FrdpRenderingBackend {
  /// Legacy GDI framebuffer path.
  ///
  /// This is the most widely supported and compatible rendering backend, working
  /// on all FreeRDP-supported platforms and servers.  It uses the traditional GDI
  /// framebuffer-based rendering pipeline, which is stable and well-tested, but
  /// may have higher latency and lower performance compared to the modern GFX path.
  ///
  /// Use cases:
  /// - Connecting to older RDP servers that do not support the GFX pipeline.
  /// - Maximum compatibility across all platforms and server versions.
  /// - When low latency and high performance are not critical, such as for casual
  ///   remote desktop usage, basic administration tasks, or when connecting to
  ///   servers with limited graphics capabilities.
  gdi,

  /// Modern RDP graphics pipeline (GFX) path.
  ///
  /// This backend uses the modern GFX pipeline introduced in FreeRDP 3.0, which
  /// provides improved performance and lower latency by leveraging modern graphics
  /// acceleration features of the server and client.  However, it requires both the
  /// client and server to support the GFX pipeline, which may not be the case for
  /// older servers or certain platforms.  The GFX backend may also have some
  /// compatibility issues with certain server configurations or graphics drivers.
  ///
  /// Use cases:
  /// - Connecting to modern RDP servers that support the GFX pipeline, especially
  ///   those running Windows 10/11 or recent Windows Server versions.
  /// - When low latency and high performance are important, such as for gaming, video
  ///   streaming, or graphics-intensive applications.
  gfx,
}
