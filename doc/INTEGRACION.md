# Guía de integración — `zebra_bt_printer`

Esta guía está dirigida a equipos que van a agregar `zebra_bt_printer` a una
**app de Flutter existente**. Cubre la instalación, la configuración de Android,
los permisos en tiempo de ejecución, cada llamada de la API con ejemplos listos
para copiar, y la solución de problemas.

> **Resumen rápido**
> 1. Agrega la dependencia. 2. Define el `minSdk` de Android en 24+. 3. Llama a
> `requestPermissions()` y luego a `isBluetoothEnabled()`. 4. Llama a un método
> `print…` y revisa `result.isSuccess`. En iOS compila pero siempre falla de
> forma controlada.

---

## 1. Requisitos

| Requisito | Valor |
| --- | --- |
| Flutter SDK | `>=3.3.0` |
| Dart SDK | `>=3.0.0 <4.0.0` |
| `minSdk` de Android | **24** o superior |
| `compileSdk` de Android | 34+ (se recomienda 35/36) |
| Java / Kotlin (JVM target) | 17 |
| Dispositivos objetivo | Solo Android (con Bluetooth Clásico) |

El SDK Link-OS de Zebra **no tiene equivalente para iOS** en este plugin. En iOS
el plugin es un stub: las llamadas de impresión devuelven `PrintResult.failure`
con `PrintErrorCode.unsupportedPlatform`, y `requestPermissions()` /
`isBluetoothEnabled()` devuelven `false`. Tu código no necesita lógica especial
para iOS, basta con revisar `isSuccess`.

---

## 2. Agregar la dependencia

En el `pubspec.yaml` de tu app:

```yaml
dependencies:
  zebra_bt_printer:
    git:
      url: https://github.com/OsmarM/zebra_bt_printer.git
      ref: v1.4.0        # fija un tag/commit para builds reproducibles
```

Alternativa local / monorepo:

```yaml
dependencies:
  zebra_bt_printer:
    path: ../packages/zebra_bt_printer
```

Luego:

```bash
flutter pub get
```

Los archivos `.jar` del SDK de Zebra vienen **incluidos dentro del plugin**
(`android/libs`) y los configura el propio Gradle del plugin. **No** necesitas
descargar ni agregar el SDK de Zebra manualmente.

---

## 3. Configuración de Android

### 3.1 `minSdk`

En `android/app/build.gradle` (o `build.gradle.kts`):

```groovy
android {
    defaultConfig {
        minSdk = 24   // o superior
    }
}
```

### 3.2 Permisos

El plugin **ya declara** los permisos de Bluetooth en su propio manifiesto, y se
fusionan automáticamente en tu app:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />            <!-- < Android 12 -->
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />      <!-- < Android 12 -->
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />    <!-- Android 12+ -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />       <!-- Android 12+ -->
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

Normalmente no necesitas agregar nada. Si tu app apunta a Android 12+ y quieres
declarar que la ubicación **no** se usa para derivar la ubicación física, puedes
agregar `android:usesPermissionFlags="neverForLocation"` al permiso
`BLUETOOTH_SCAN` en el manifiesto de tu app.

### 3.3 Empaquetado (solo si aparece un error de merge)

El SDK de Zebra incluye librerías de Apache Commons que contienen entradas
`META-INF` duplicadas. El plugin ya lo maneja internamente, pero si tu build
falla con un error del tipo *"More than one file was found with OS independent
path…"*, replica el bloque `packaging` del plugin en
`android/app/build.gradle`:

```groovy
android {
    packaging {
        resources {
            excludes += [
                'META-INF/DEPENDENCIES', 'META-INF/LICENSE', 'META-INF/LICENSE.txt',
                'META-INF/NOTICE', 'META-INF/NOTICE.txt',
                'META-INF/*.RSA', 'META-INF/*.SF', 'META-INF/*.DSA',
            ]
            pickFirsts += ['org/apache/commons/**', 'org/apache/**']
        }
    }
}
```

---

## 4. Permisos en tiempo de ejecución (Android 12+)

En Android 12+ los permisos de Bluetooth son permisos de **tiempo de ejecución**.
Siempre solicítalos antes de conectar, y verifica que el Bluetooth esté
encendido:

```dart
Future<bool> _verificarListo() async {
  final concedido = await ZebraBtPrinter.requestPermissions();
  if (!concedido) return false;
  return ZebraBtPrinter.isBluetoothEnabled();
}
```

- `requestPermissions()` muestra el diálogo del sistema y devuelve `true` solo
  cuando **todos** los permisos requeridos fueron concedidos.
- Si el usuario rechaza, devuelve `false` — muestra un mensaje pidiéndole que
  habilite los permisos de Bluetooth en los ajustes del sistema.

---

## 5. Configuración de etiqueta (`PrinterConfig`)

Todos los métodos de impresión aceptan un `PrinterConfig` opcional:

```dart
const PrinterConfig({
  int    labelWidthDots  = 600,                  // ancho en dots
  int    labelHeightDots = 240,                  // alto en dots
  bool   useSmoothScaling = true,                // anti-aliasing al escalar
  PrinterType    printerType  = PrinterType.zebra,
  LabelMediaType mediaType    = LabelMediaType.gap,
  bool   allowUpscale        = false,
  int?   maxLabelLengthDots,                     // ^ML (default: labelHeightDots × 2)
  int    labelTopOffset      = 0,                // ^LT offset vertical en dots
})
```

### 5.1 Dimensiones (dots)

`dots = pulgadas × DPI`. La mayoría de las impresoras portátiles Zebra son de
**203 DPI** (llamado frecuentemente "200 DPI").

| Etiqueta | Ancho | Alto | Dots ancho | Dots alto |
| --- | --- | --- | --- | --- |
| 3" × 1.2" | 3 pulg | 1.2 pulg | 600 | 240 |
| 3" × 3" | 3 pulg | 3 pulg | 600 | 600 |
| 4" × 6" | 4 pulg | 6 pulg | 812 | 1218 |

### 5.2 Tipo de media (`LabelMediaType`)

Controla cómo la impresora detecta el final de cada etiqueta:

| Valor | Comando ZPL | Cuándo usarlo |
| --- | --- | --- |
| `LabelMediaType.gap` | `^MNA` | Etiquetas die-cut con espacio/gap entre ellas (**default**) |
| `LabelMediaType.mark` | `^MNB` | Etiquetas con marca negra impresa en el reverso del rollo |
| `LabelMediaType.none` | `^MNN` | Sin detección física; la longitud la controla solo `^LL` |

> **Importante al usar `mark`:** cada vez que cambies a un rollo de diferente
> tamaño debes llamar a `calibratePrinter()` para que la impresora mida el nuevo
> espaciado de las marcas. Ver [§8](#8-cambio-de-rollo-y-calibración).

### 5.3 Parámetros avanzados

| Parámetro | Descripción |
| --- | --- |
| `allowUpscale` | Permite ampliar la imagen si es más pequeña que la etiqueta. Default `false`. |
| `maxLabelLengthDots` | Distancia máxima que avanza la impresora buscando la siguiente marca/gap (`^ML`). Default: `labelHeightDots × 2`. |
| `labelTopOffset` | Desplaza verticalmente el área de impresión en dots (`^LT`). Positivo = imagen más abajo; negativo = más arriba. |

---

## 6. Impresión

Todos los métodos de impresión devuelven un `PrintResult`. En uso normal nunca
lanzan excepciones — revisa `result.isSuccess`.

### 6.1 Imprimir una imagen por Bluetooth

```dart
final result = await ZebraBtPrinter.printImageBluetooth(
  mac: '48:A4:93:DB:04:6F',
  imageBase64: imagenBase64,
  config: const PrinterConfig(
    labelWidthDots:  600,
    labelHeightDots: 240,
    mediaType: LabelMediaType.gap,
  ),
  copies: 1,  // número de copias en una sola conexión BT
);
```

El parámetro `copies` imprime N copias **dentro de la misma conexión Bluetooth**,
lo cual es mucho más eficiente que llamar el método N veces (ver [§9](#9-rendimiento--impresión-en-lote)).

### 6.2 Imprimir una imagen por TCP/IP

```dart
final result = await ZebraBtPrinter.printImageIP(
  ip: '192.168.0.50',
  imageBase64: imagenBase64,
  config: const PrinterConfig(
    labelWidthDots:  600,
    labelHeightDots: 240,
  ),
);
```

### 6.3 Imprimir texto ZPL por Bluetooth

```dart
final result = await ZebraBtPrinter.printLabelBluetooth(
  mac: '48:A4:93:DB:04:6F',
  zplText: 'Pedido #12345',
);
```

---

## 7. Generar la imagen en base64

`imageBase64` es un JPG/PNG codificado en base64 **sin** el prefijo `data:`.

### Desde un asset

```dart
import 'package:flutter/services.dart';
import 'dart:convert';

final bytes = await rootBundle.load('assets/etiqueta.png');
final imagenBase64 = base64Encode(bytes.buffer.asUint8List());
```

### Desde un archivo

```dart
import 'dart:io';
import 'dart:convert';

final imagenBase64 = base64Encode(await File(ruta).readAsBytes());
```

### Desde un widget de Flutter renderizado

Usa `RepaintBoundary` + `RenderRepaintBoundary.toImage()` para rasterizar un
widget, codifícalo a bytes PNG y luego aplica `base64Encode`. Es la forma
recomendada para imprimir etiquetas ricas y dinámicas (logos, códigos de barras,
texto con formato).

> **Tip de resolución:** genera la imagen al tamaño exacto en píxeles que usarás
> en `labelWidthDots × labelHeightDots`. Por ejemplo, para una etiqueta 3×3" a
> 200 DPI genera un canvas de 600×600 píxeles. Así el plugin no necesita escalar
> y la calidad es máxima.

---

## 8. Cambio de rollo y calibración

Cuando el operador carga un rollo de **diferente tamaño o tipo** debe calibrar
la impresora una sola vez para que aprenda el espaciado de las nuevas etiquetas.

```dart
// Configs para cada tipo de rollo
const configChica = PrinterConfig(
  labelWidthDots:  600,
  labelHeightDots: 240,
  mediaType: LabelMediaType.gap,   // etiqueta die-cut estándar
);

const configGrande = PrinterConfig(
  labelWidthDots:  600,
  labelHeightDots: 600,
  mediaType: LabelMediaType.mark,  // rollo con marca negra en el reverso
);

/// Llamar UNA VEZ al cargar un nuevo rollo.
/// La impresora avanza 1-2 etiquetas midiendo las marcas (~3 seg).
Future<void> calibrarImpresora(String mac) async {
  final ok = await ZebraBtPrinter.calibratePrinter(mac: mac);
  if (!ok) throw Exception('No se pudo calibrar la impresora');
}

/// Flujo completo al cambiar al rollo grande con marca negra.
Future<void> cambiarAEtiquetaGrande(String mac, String imagenBase64) async {
  await calibrarImpresora(mac);      // ← solo la primera vez por rollo
  final result = await ZebraBtPrinter.printImageBluetooth(
    mac: mac,
    imageBase64: imagenBase64,
    config: configGrande,
  );
  if (!result.isSuccess) throw Exception(result.errorMessage);
}

/// Flujo completo al cambiar al rollo chico (gap, sin calibración necesaria).
Future<void> cambiarAEtiquetaChica(String mac, String imagenBase64) async {
  // Las etiquetas gap normalmente no requieren recalibración
  final result = await ZebraBtPrinter.printImageBluetooth(
    mac: mac,
    imageBase64: imagenBase64,
    config: configChica,
  );
  if (!result.isSuccess) throw Exception(result.errorMessage);
}
```

> La calibración se **guarda en la impresora**. No se repite en cada impresión,
> solo cuando se carga un rollo diferente.

---

## 9. Rendimiento — impresión en lote

Abrir y cerrar la conexión Bluetooth toma ~4-6 segundos. Para imprimir varias
etiquetas seguidas usa `copies` o la conexión persistente:

### Opción A — `copies` (mismo diseño, N copias)

```dart
await ZebraBtPrinter.printImageBluetooth(
  mac: mac,
  imageBase64: imagenBase64,
  config: configChica,
  copies: 5,   // 5 copias, 1 sola conexión BT
);
```

### Opción B — conexión persistente (diseños distintos)

```dart
await ZebraBtPrinter.connectBluetooth(mac: mac);
try {
  for (final etiqueta in lote) {
    await ZebraBtPrinter.printImageBluetooth(
      mac: mac,
      imageBase64: etiqueta.base64,
      config: configChica,
    );
  }
} finally {
  await ZebraBtPrinter.disconnectBluetooth(mac: mac);
}
```

| Escenario | Tiempo aprox. |
| --- | --- |
| 1 etiqueta (sin conexión previa) | ~6-8 s |
| 5 etiquetas con `copies: 5` | ~9-11 s |
| 5 etiquetas con conexión persistente | ~11-13 s |
| 5 etiquetas sin optimización (5 llamadas) | ~30-40 s |

---

## 10. Patrón de uso recomendado (verificado)

```dart
Future<void> imprimirEtiqueta(String mac, String imagenBase64) async {
  // 1. Solicita permisos y ESPERA la respuesta del usuario.
  final concedido = await ZebraBtPrinter.requestPermissions();
  if (!concedido) {
    _mostrarError('Se requieren permisos de Bluetooth. Actívalos en Ajustes.');
    return;
  }

  // 2. Verifica que el Bluetooth esté encendido.
  if (!await ZebraBtPrinter.isBluetoothEnabled()) {
    _mostrarError('Por favor enciende el Bluetooth.');
    return;
  }

  // 3. Imprime.
  final result = await ZebraBtPrinter.printImageBluetooth(
    mac: mac,
    imageBase64: imagenBase64,
    config: const PrinterConfig(
      labelWidthDots:  600,
      labelHeightDots: 240,
      mediaType: LabelMediaType.gap,
    ),
  );

  // 4. Maneja el resultado tipado.
  if (result.isSuccess) {
    _mostrarExito('Impreso.');
  } else {
    // userMessage: mensaje estable para UI
    _mostrarError(result.userMessage!);
    // errorMessage / rawErrorCode: detalle técnico para logs
    debugPrint('[${result.rawErrorCode}] ${result.errorMessage}');

    // Opcional: ramificar por código tipado
    switch (result.errorCode) {
      case PrintErrorCode.permissionDenied:
        // redirigir a Ajustes, etc.
        break;
      case PrintErrorCode.paperOut:
        // pedir recarga de rollo
        break;
      case PrintErrorCode.printTimeout:
        // verificar impresora / reintentar
        break;
      case PrintErrorCode.printError:
        // reintentar, etc.
        break;
      default:
        break;
    }
  }
}
```

---

## 11. Referencia de errores

Los métodos de impresión mapean el código nativo a un [PrintErrorCode] tipado.
Usa `result.userMessage` en la UI y `result.errorMessage` en logs.

| `PrintErrorCode` | Código nativo | Cuándo ocurre | Manejo sugerido |
| --- | --- | --- | --- |
| `invalidArgs` | `INVALID_ARGS` | Un argumento requerido (mac/ip/imagen/texto) fue nulo o vacío. | Valida las entradas antes de llamar. |
| `permissionDenied` | `PERMISSION_DENIED` | Se intentó imprimir sin `BLUETOOTH_CONNECT`/`BLUETOOTH_SCAN` concedidos. | Llama a `requestPermissions()` y reintenta. |
| `printError` | `PRINT_ERROR` | Impresora inalcanzable, apagada, fuera de rango u ocupada. | Reintenta; revisa energía/emparejamiento/rango. |
| `connectError` | `CONNECT_ERROR` | `connectBluetooth()` no pudo abrir la conexión persistente. | Verifica que la impresora esté encendida y en rango. |
| `calibrateError` | `CALIBRATE_ERROR` | `calibratePrinter()` falló al enviar `~JC`. | Verifica la conexión e inténtalo de nuevo. |
| `disconnectError` | `DISCONNECT_ERROR` | Falló al cerrar la conexión persistente. | Reintenta el cierre; ignora si ya estaba cerrada. |
| `noActivity` | `NO_ACTIVITY` | Se llamó a `requestPermissions()` sin una Activity en primer plano. | Llámalo desde una pantalla activa. |
| `permissionRequestInProgress` | `PERMISSION_REQUEST_IN_PROGRESS` | Una segunda solicitud de permisos se superpuso con la primera. | Espera a que termine la primera. |
| `unsupportedPlatform` | `UNSUPPORTED_PLATFORM` | Cualquier llamada en iOS. | Limita la función a Android. |
| `paperOut` | `PAPER_OUT` | La impresora reportó sin papel en el pre-check o al confirmar el fin del lote. | Recarga el rollo y reintenta. |
| `printTimeout` | `PRINT_TIMEOUT` | El lote se envió pero la impresora no confirmó el fin a tiempo. | Verifica rollo/estado; reintenta. |
| `unknown` | *(código no reconocido)* | Código nativo nuevo o inesperado. | Muestra `userMessage`; registra `rawErrorCode`. |

> **Nota — confirmación al final del lote:** tras enviar todas las copias (`write`×N),
> el plugin espera con poll de status hasta que la impresora esté lista o falle.
> `isSuccess` significa que el lote **terminó de procesarse**, no solo que se
> encoló. No se reporta “k de N” (no hay confirmación etiqueta por etiqueta).
> Deadline: `min(120s, 8s + copies × 4s)`. En algunas móviles en error, el SDK
> puede fallar al consultar status y eso se reporta como `printError`.

---

## 12. Solución de problemas

**El build falla con "More than one file was found with OS independent path META-INF/…"**
→ Agrega el bloque `packaging` de la [§3.3](#33-empaquetado-solo-si-aparece-un-error-de-merge).

**`Need android.permission.BLUETOOTH_SCAN permission … cancelDiscovery`**
→ Imprimiste antes de que se concediera `BLUETOOTH_SCAN`. Asegúrate de hacer
`await ZebraBtPrinter.requestPermissions()` y que devuelva `true` *antes* de
imprimir. Ver [§10](#10-patrón-de-uso-recomendado-verificado).

**`PRINT_ERROR` de inmediato**
→ Verifica que la impresora esté encendida, emparejada en los ajustes de
Bluetooth de Android y dentro de rango.

**La etiqueta se corta antes de tiempo con `LabelMediaType.mark`**
→ La impresora tiene calibración del rollo anterior. Llama a
`calibratePrinter()` con el nuevo rollo cargado. Ver [§8](#8-cambio-de-rollo-y-calibración).

**La imagen se imprime completa pero se extiende entre dos etiquetas**
→ Usa `LabelMediaType.mark` (con calibración previa) o `LabelMediaType.gap`
en lugar de `none`. Verifica también que `labelHeightDots` coincida con el
tamaño físico del rollo.

**La imagen se imprime pequeña / centrada con espacio en blanco**
→ La imagen en base64 tiene menos píxeles que los dots de la etiqueta. Genera
la imagen al tamaño exacto (`labelWidthDots × labelHeightDots` píxeles) o activa
`allowUpscale: true`.

**No imprime nada pero `isSuccess` es `true`**
→ El trabajo se envió correctamente; revisa el medio/calibración de la
impresora y que el formato de etiqueta coincida con el papel cargado.

---

## 13. Preguntas frecuentes

**¿Descubre/escanea impresoras cercanas?** No. Tú proporcionas la dirección MAC
(o IP). Usa los ajustes de Bluetooth del sistema o un paquete de descubrimiento
aparte para obtenerla.

**¿Soporta iOS?** No. Las llamadas fallan de forma controlada para que las apps
multiplataforma sigan compilando y ejecutándose.

**¿Qué impresoras soporta?** Impresoras Zebra Link-OS por Bluetooth/red (familias
ZQ, ZD y similares).

**¿Puedo imprimir ZPL crudo?** `printLabelBluetooth` envía una etiqueta de texto
básica. Para control total de ZPL, renderiza tu etiqueta como imagen y usa
`printImageBluetooth`.

**¿Qué DPI tiene mi impresora?** Las impresoras Zebra ZQ y ZD portable suelen
ser 203 DPI. Puedes confirmar en la etiqueta de configuración que imprime al
encender la impresora.

---

## 14. Ciclo de vida de la conexión

### Conexión automática (default)

Sin llamar a `connectBluetooth`, cada impresión sigue el ciclo corto:

```
open() ─► cancelDiscovery ─► write ZPL ─► close()
```

### Conexión persistente

Con `connectBluetooth` / `disconnectBluetooth` la conexión permanece abierta
entre impresiones. Ver [§9](#9-rendimiento--impresión-en-lote).

### Liberar una impresora ocupada

Si recibes `PRINT_ERROR` porque otro teléfono está conectado:

1. **Esperar y reintentar** — el plugin ya reintenta automáticamente.
2. **Que el otro teléfono termine** — la conexión se cierra sola al terminar el trabajo.
3. **Apagar y encender la impresora** — último recurso para sesiones atascadas.
