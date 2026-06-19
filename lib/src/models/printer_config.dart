/// Marca/tipo de impresora a utilizar.
enum PrinterType {
  /// Zebra (requiere ZSDK_ANDROID_API.jar)
  zebra,

  /// Honeywell portable (requiere printer_sdk.jar)
  honeywell,
}

/// Configuración de la etiqueta y comportamiento de impresión.
class PrinterConfig {
  /// Ancho de la etiqueta en dots (puntos).
  /// Para impresoras de 3 pulgadas a 200 DPI → 600 dots.
  final int labelWidthDots;

  /// Alto de la etiqueta en dots.
  final int labelHeightDots;

  /// Aplica escalado suave (anti-aliasing) al redimensionar la imagen.
  final bool useSmoothScaling;

  /// Tipo de impresora destino.
  final PrinterType printerType;

  const PrinterConfig({
    this.labelWidthDots = 600,
    this.labelHeightDots = 250,
    this.useSmoothScaling = true,
    this.printerType = PrinterType.zebra,
  });

  Map<String, dynamic> toMap() => {
        'labelWidthDots': labelWidthDots,
        'labelHeightDots': labelHeightDots,
        'useSmoothScaling': useSmoothScaling,
        'printerType': printerType.name,
      };
}
