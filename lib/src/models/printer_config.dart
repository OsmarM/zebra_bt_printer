/// Marca/tipo de impresora a utilizar.
enum PrinterType {
  /// Zebra (requiere ZSDK_ANDROID_API.jar)
  zebra,

  /// Honeywell portable (requiere printer_sdk.jar)
  honeywell,
}

/// Tipo de detección de fin de etiqueta (comando ZPL ^MN).
enum LabelMediaType {
  /// ^MNA — Detecta el espacio/gap entre etiquetas (die-cut labels).
  /// Opción más común para etiquetas estándar sin marcas negras.
  gap,

  /// ^MNB — Detecta marcas negras impresas en el reverso del rollo.
  /// Usar solo si el rollo tiene marcas negras físicas.
  mark,

  /// ^MNN — Sin detección de media; la longitud la controla únicamente ^LL.
  none,
}

/// Configuración de la etiqueta y comportamiento de impresión.
class PrinterConfig {
  /// Ancho de la etiqueta en dots (puntos).
  /// Para impresoras de 3 pulgadas a 200 DPI → 600 dots.
  final int labelWidthDots;

  /// Alto de la etiqueta en dots.
  /// - 3" × 1.2" a 200 DPI → 240 dots
  /// - 3" × 3"   a 200 DPI → 600 dots
  final int labelHeightDots;

  /// Aplica escalado suave (anti-aliasing) al redimensionar la imagen.
  final bool useSmoothScaling;

  /// Tipo de impresora destino.
  final PrinterType printerType;

  /// Tipo de detección de fin de etiqueta.
  /// Usa [LabelMediaType.gap] para etiquetas die-cut estándar (recomendado).
  /// Usa [LabelMediaType.mark] solo si el rollo tiene marcas negras físicas.
  final LabelMediaType mediaType;

  /// Permite escalar la imagen hacia arriba cuando es más pequeña que el área
  /// de la etiqueta. Útil para etiquetas grandes (p. ej. 3" × 3").
  final bool allowUpscale;

  const PrinterConfig({
    this.labelWidthDots = 600,
    this.labelHeightDots = 240,
    this.useSmoothScaling = true,
    this.printerType = PrinterType.zebra,
    this.mediaType = LabelMediaType.gap,
    this.allowUpscale = false,
  });

  Map<String, dynamic> toMap() => {
        'labelWidthDots': labelWidthDots,
        'labelHeightDots': labelHeightDots,
        'useSmoothScaling': useSmoothScaling,
        'printerType': printerType.name,
        'mediaType': mediaType.name,
        'allowUpscale': allowUpscale,
      };
}
