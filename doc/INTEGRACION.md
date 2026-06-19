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
con el código `UNSUPPORTED_PLATFORM`, y `requestPermissions()` /
`isBluetoothEnabled()` devuelven `false`. Tu código no necesita lógica especial
para iOS, basta con revisar `isSuccess`.

---

## 2. Agregar la dependencia

En el `pubspec.yaml` de tu app:

```yaml
dependencies:
  zebra_bt_printer:
    git:
      url: https://github.com/<org>/zebra_bt_printer.git
      ref: v1.0.0        # fija un tag/commit para builds reproducibles
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
  if (!concedido) return false;             // el usuario rechazó el diálogo
  return ZebraBtPrinter.isBluetoothEnabled(); // el adaptador debe estar encendido
}
```

- `requestPermissions()` muestra el diálogo del sistema y devuelve `true` solo
  cuando **todos** los permisos requeridos fueron concedidos.
- Si el usuario rechaza, devuelve `false` — muestra un mensaje pidiéndole que
  habilite los permisos de Bluetooth en los ajustes del sistema.
- Si lo llamas otra vez mientras una solicitud previa sigue pendiente, devuelve
  una falla con el código `PERMISSION_REQUEST_IN_PROGRESS` (el `Future` original
  igual se resuelve cuando se responde el primer diálogo).

---

## 5. Impresión

Todos los métodos de impresión devuelven un `PrintResult`. En uso normal nunca
lanzan excepciones — revisa `result.isSuccess`.

### 5.1 Imprimir una imagen por Bluetooth

```dart
final result = await ZebraBtPrinter.printImageBluetooth(
  mac: '48:A4:93:DB:04:6F',          // dirección MAC de la impresora
  imageBase64: imagenBase64,         // JPG o PNG en base64 (sin prefijo data:)
  config: const PrinterConfig(
    labelWidthDots: 600,             // 3 pulgadas a 200 DPI
    labelHeightDots: 250,
    useSmoothScaling: true,
  ),
);
```

La imagen se decodifica, se escala para caber dentro de
`labelWidthDots × labelHeightDots` (nunca se agranda) y se centra en la etiqueta.

### 5.2 Imprimir una imagen por TCP/IP

```dart
final result = await ZebraBtPrinter.printImageIP(
  ip: '192.168.0.50',                // IP de la impresora, puerto ZPL por defecto (9100)
  imageBase64: imagenBase64,
);
```

### 5.3 Imprimir una etiqueta de texto por Bluetooth

```dart
final result = await ZebraBtPrinter.printLabelBluetooth(
  mac: '48:A4:93:DB:04:6F',
  zplText: 'Pedido #12345',
);
```

El texto se envuelve en una plantilla ZPL mínima. Para tener control total del
diseño, genera tu propia etiqueta como imagen y usa `printImageBluetooth`.

---

## 6. Generar la imagen en base64

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

---

## 7. Elegir las dimensiones de la etiqueta

Dots = pulgadas × DPI. La mayoría de las impresoras portátiles Zebra son de
**203 DPI** (a menudo llamado "200 DPI").

| Ancho de etiqueta | 203 DPI | 300 DPI |
| --- | --- | --- |
| 2 pulg | 406 dots | 600 dots |
| 3 pulg | 609 dots | 900 dots |
| 4 pulg | 812 dots | 1200 dots |

Define `labelWidthDots` / `labelHeightDots` según el tamaño físico de tu etiqueta
en dots. El valor por defecto `600 × 250` corresponde a una etiqueta tipo recibo
de ~3 pulgadas de ancho a 203 DPI.

---

## 8. Patrón de uso recomendado (verificado)

Este es el flujo probado en varias versiones de Android. La clave en Android 12+
es **siempre `await requestPermissions()` e imprimir solo cuando devuelve
`true`** — imprimir antes de que `BLUETOOTH_SCAN`/`BLUETOOTH_CONNECT` estén
concedidos es lo que dispara la SecurityException de `cancelDiscovery`.

```dart
Future<void> imprimirEtiqueta(String mac, String imagenBase64) async {
  // 1. Solicita permisos y ESPERA la respuesta del usuario.
  //    En Android 12+ esto muestra el diálogo de "Dispositivos cercanos".
  final concedido = await ZebraBtPrinter.requestPermissions();
  if (!concedido) {
    _mostrarError('Se requieren permisos de Bluetooth. Actívalos en Ajustes.');
    return;
  }

  // 2. Asegúrate de que el adaptador Bluetooth esté encendido.
  if (!await ZebraBtPrinter.isBluetoothEnabled()) {
    _mostrarError('Por favor enciende el Bluetooth.');
    return;
  }

  // 3. Imprime (el plugin abre la conexión, imprime y la cierra).
  final result = await ZebraBtPrinter.printImageBluetooth(
    mac: mac,
    imageBase64: imagenBase64,
  );

  // 4. Maneja el resultado tipado.
  if (result.isSuccess) {
    _mostrarExito('Impreso.');
  } else {
    switch (result.errorCode) {
      case 'PERMISSION_DENIED':
        // Los permisos se revocaron entre el paso 1 y la impresión.
        _mostrarError('Concede los permisos de Bluetooth e inténtalo de nuevo.');
        break;
      case 'UNSUPPORTED_PLATFORM':
        _mostrarError('La impresión solo está disponible en Android.');
        break;
      case 'PRINT_ERROR':
        // Impresora apagada, fuera de rango u ocupada con otro teléfono.
        _mostrarError('No se pudo alcanzar la impresora: ${result.errorMessage}');
        break;
      default:
        _mostrarError('Falló la impresión: ${result.errorMessage}');
    }
  }
}
```

> ⚠️ **No imprimas antes de que `requestPermissions()` se resuelva.** En
> Android 12+ el SDK de Zebra llama a `cancelDiscovery()` al abrir la conexión
> Bluetooth, lo cual requiere `BLUETOOTH_SCAN`. Si imprimes antes, obtienes el
> error *"Need android.permission.BLUETOOTH_SCAN permission … AdapterService
> cancelDiscovery"*.

---

## 9. Referencia de errores

| `errorCode` | Cuándo ocurre | Manejo sugerido |
| --- | --- | --- |
| `INVALID_ARGS` | Un argumento requerido (mac/ip/imagen/texto) fue nulo o vacío. | Valida las entradas antes de llamar. |
| `PERMISSION_DENIED` | Se intentó imprimir por Bluetooth sin `BLUETOOTH_CONNECT`/`BLUETOOTH_SCAN` concedidos (Android 12+). | Llama a `requestPermissions()`, que el usuario acepte, y reintenta. |
| `PRINT_ERROR` | Impresora inalcanzable, apagada, fuera de rango u ocupada con otro teléfono. | Reintenta; revisa energía/emparejamiento/rango. |
| `NO_ACTIVITY` | Se llamó a `requestPermissions()` sin una Activity en primer plano. | Llámalo desde una pantalla activa. |
| `PERMISSION_REQUEST_IN_PROGRESS` | Una segunda solicitud de permisos se superpuso con la primera. | Espera a que termine la primera antes de reintentar. |
| `UNSUPPORTED_PLATFORM` | Cualquier llamada en iOS. | Limita la función a Android. |

---

## 10. Solución de problemas

**El build falla con "More than one file was found with OS independent path
META-INF/…"** → Agrega el bloque `packaging` de la [§3.3](#33-empaquetado-solo-si-aparece-un-error-de-merge).

**`Need android.permission.BLUETOOTH_SCAN permission … AdapterService
cancelDiscovery`** → Imprimiste antes de que se concediera `BLUETOOTH_SCAN`.
Asegúrate de hacer `await ZebraBtPrinter.requestPermissions()` y que devuelva
`true` *antes* de llamar a cualquier `printImageBluetooth`/`printLabelBluetooth`.
Es más común en Android 12+ (no ocurre en Android 11 o anterior). Ver
[§8](#8-patrón-de-uso-recomendado-verificado).

**`requestPermissions()` devuelve `false` aun después de conceder** → En algunas
ROMs de fabricantes el usuario también debe conceder "Dispositivos cercanos".
Envía al usuario a los Ajustes de la app.

**`PRINT_ERROR` de inmediato** → Verifica que la impresora esté encendida,
emparejada en los ajustes de Bluetooth de Android y dentro de rango. Para
Bluetooth, la MAC debe ser la de la impresora (formato `AA:BB:CC:DD:EE:FF`). Para
TCP/IP, confirma que el dispositivo y la impresora estén en la misma red y que el
puerto 9100 sea alcanzable.

**La imagen se imprime muy pequeña / descentrada** → Ajusta `labelWidthDots` /
`labelHeightDots` al tamaño físico de tu etiqueta según el DPI de la impresora
(ver [§7](#7-elegir-las-dimensiones-de-la-etiqueta)).

**No imprime nada pero `isSuccess` es `true`** → El trabajo se envió
correctamente; revisa el medio/calibración de la impresora y que el formato de
etiqueta coincida con el papel cargado.

---

## 11. Preguntas frecuentes

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

---

## 12. Ciclo de vida de la conexión y desconectar un dispositivo

### El plugin se desconecta automáticamente

**No hay una conexión persistente** que administrar y **no se necesita ninguna
llamada `disconnect()`**. Cada método de impresión sigue el mismo ciclo de vida
corto:

```
open() ─► (cancelDiscovery) ─► write/printImage ─► close()
```

La conexión **siempre se cierra** al terminar el trabajo —con éxito o con
error— (mediante un `safeClose` interno). Por lo tanto, después de cada
impresión tu teléfono ya está desconectado de la impresora. Esto es intencional:
las impresoras Bluetooth Clásico (SPP) aceptan **una sola conexión a la vez**, así
que mantener la conexión abierta bloquearía a cualquier otro teléfono.

### Liberar una impresora "ocupada" por otro teléfono

Si recibes `PRINT_ERROR` porque otro teléfono está conectado en ese momento,
tienes tres opciones:

1. **Esperar y reintentar** — el plugin ya reintenta varias veces con una breve
   espera. En cuanto el trabajo del otro teléfono termina (y su conexión se
   cierra), el tuyo tiene éxito.
2. **Que el otro teléfono termine su impresión** — como cada trabajo se cierra
   solo, el bloqueo se libera en segundos.
3. **Apagar y encender la impresora** — para soltar una sesión atascada (último
   recurso, p. ej. una app que se cerró a mitad de la impresión).

### Desemparejar por completo una impresora del teléfono

"Desconectar" a nivel del sistema (eliminar el emparejamiento/bond) es una
**acción del sistema**, no algo que haga este plugin. Indica al usuario:

**Ajustes de Android → Dispositivos conectados / Bluetooth → toca la impresora →
Olvidar / Desvincular.**

Tras desemparejar, la siguiente impresión Bluetooth a esa MAC volverá a
establecer el emparejamiento (el sistema puede pedirlo). No existe una API a
nivel de app para forzar el desemparejamiento de un dispositivo vinculado en
Android moderno sin permisos privilegiados.

### Prefiere TCP/IP para impresoras compartidas

Si varios teléfonos deben imprimir en la **misma** impresora con frecuencia, usa
una impresora **conectada a la red** y `printImageIP`. La impresora encola los
trabajos y atiende a múltiples clientes, así que no hay un bloqueo de conexión
única de Bluetooth por el que competir.
