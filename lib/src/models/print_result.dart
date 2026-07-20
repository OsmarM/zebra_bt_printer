import 'print_error_code.dart';

/// Resultado de una operación de impresión.
///
/// En uso normal no lanza excepciones: revisa [isSuccess].
///
/// En fallo hay dos capas de mensaje:
/// - [userMessage]: texto estable para UI (viene de [PrintErrorCode]).
/// - [errorMessage]: detalle técnico nativo, útil para logs.
class PrintResult {
  final bool isSuccess;

  /// Código tipado del error. `null` si [isSuccess] es `true`.
  final PrintErrorCode? errorCode;

  /// Detalle técnico proveniente de la capa nativa (logs/diagnóstico).
  final String? errorMessage;

  /// Código string original del nativo, por si [errorCode] es [PrintErrorCode.unknown].
  final String? rawErrorCode;

  const PrintResult._({
    required this.isSuccess,
    this.errorCode,
    this.errorMessage,
    this.rawErrorCode,
  });

  const PrintResult.success()
      : isSuccess = true,
        errorCode = null,
        errorMessage = null,
        rawErrorCode = null;

  const PrintResult.failure({
    required PrintErrorCode errorCode,
    this.errorMessage,
    this.rawErrorCode,
  })  : isSuccess = false,
        errorCode = errorCode;

  /// Mensaje listo para UI. `null` si la operación fue exitosa.
  String? get userMessage => errorCode?.userMessage;

  @override
  String toString() => isSuccess
      ? 'PrintResult(success)'
      : 'PrintResult(failure: [${errorCode?.name}] $userMessage'
          '${errorMessage != null ? ' | $errorMessage' : ''})';
}
