/// Códigos de error tipados del plugin.
///
/// Cada valor mapea el código nativo (`nativeCode`) y un [userMessage]
/// estable para mostrar en UI. El detalle técnico del sistema queda en
/// [PrintResult.errorMessage].
enum PrintErrorCode {
  invalidArgs(
    'INVALID_ARGS',
    'Revisa los datos enviados a la impresora.',
  ),
  permissionDenied(
    'PERMISSION_DENIED',
    'Se requieren permisos de Bluetooth. Actívalos e inténtalo de nuevo.',
  ),
  printError(
    'PRINT_ERROR',
    'No se pudo imprimir. Verifica que la impresora esté encendida y en rango.',
  ),
  connectError(
    'CONNECT_ERROR',
    'No se pudo conectar con la impresora. Verifica que esté encendida y en rango.',
  ),
  calibrateError(
    'CALIBRATE_ERROR',
    'No se pudo calibrar la impresora. Verifica la conexión e inténtalo de nuevo.',
  ),
  disconnectError(
    'DISCONNECT_ERROR',
    'No se pudo cerrar la conexión con la impresora.',
  ),
  noActivity(
    'NO_ACTIVITY',
    'No hay una pantalla activa para solicitar permisos.',
  ),
  permissionRequestInProgress(
    'PERMISSION_REQUEST_IN_PROGRESS',
    'Ya hay una solicitud de permisos en curso. Espera a que termine.',
  ),
  unsupportedPlatform(
    'UNSUPPORTED_PLATFORM',
    'La impresión solo está disponible en Android.',
  ),
  unknown(
    'UNKNOWN',
    'Ocurrió un error al imprimir. Inténtalo de nuevo.',
  );

  const PrintErrorCode(this.nativeCode, this.userMessage);

  /// Código string que envía la capa nativa (`PlatformException.code`).
  final String nativeCode;

  /// Mensaje fijo y predecible para mostrar al usuario.
  final String userMessage;

  /// Convierte un código nativo al enum correspondiente.
  ///
  /// Códigos no reconocidos (o `null`) se mapean a [unknown].
  static PrintErrorCode fromNative(String? code) {
    if (code == null || code.isEmpty) return PrintErrorCode.unknown;
    for (final value in PrintErrorCode.values) {
      if (value.nativeCode == code) return value;
    }
    return PrintErrorCode.unknown;
  }
}
