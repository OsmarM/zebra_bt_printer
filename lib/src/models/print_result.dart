/// Resultado de una operación de impresión.
class PrintResult {
  final bool isSuccess;
  final String? errorMessage;
  final String? errorCode;

  const PrintResult._({
    required this.isSuccess,
    this.errorMessage,
    this.errorCode,
  });

  const PrintResult.success()
      : isSuccess = true,
        errorMessage = null,
        errorCode = null;

  const PrintResult.failure({
    required String errorMessage,
    String? errorCode,
  })  : isSuccess = false,
        errorMessage = errorMessage,
        errorCode = errorCode;

  @override
  String toString() => isSuccess
      ? 'PrintResult(success)'
      : 'PrintResult(failure: [$errorCode] $errorMessage)';
}
