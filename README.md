# Domyos 500B — Web Bluetooth Monitor

Aplicación web para conectar al remo Domyos 500B (Decathlon) vía Bluetooth Low Energy (BLE) y mostrar datos en tiempo real mientras remas.

## El problema

El Domyos 500B **no expone el servicio FTMS estándar** (`0x1826`) por Bluetooth. Aunque el modelo se anuncia como "Domyos FTMS" en el servicio Device Information, al conectar vía Web Bluetooth solo aparece el servicio Device Information (`0x180a`) con 5 características de solo lectura:

| Característica | UUID | Valor |
|---|---|---|
| System ID | `0x2A23` | `7a c2 0e 00 00 19 9e 68` |
| Model Number | `0x2A24` | "Domyos FTMS" |
| Firmware Revision | `0x2A26` | "3221_V1.0 21051101" |
| Software Revision | `0x2A28` | "1.0.0" |
| Manufacturer Name | `0x2A29` | "EW. Inc" |

Esto ocurre tanto si la máquina está en modo emparejamiento BT (logo BT en pantalla) como en modo entrenamiento activo (remando con datos en pantalla).

## La solución

El Domyos 500B utiliza un **protocolo propietario ISSC** (basado en el módulo BLE UART transparente de Microchip/ISSC), no FTMS estándar. Los UUIDs propietarios son:

| Tipo | UUID |
|---|---|
| **Servicio** | `49535343-fe7d-4ae5-8fa9-9fafd205e455` |
| **Notify (datos del remo)** | `49535343-1e4d-4bd9-ba61-23c647249616` |
| **Write (comandos)** | `49535343-8841-43f4-a8d4-ecbe34729bb3` |

El prefijo `49535343` corresponde a ASCII "ISC" — es un módulo BLE UART comercial de Microchip/ISSC sobre el que Domyos capa su propio protocolo binario.

## Formato del paquete de datos (26 bytes, big-endian)

Los datos llegan como notificaciones en la característica Notify. Cada paquete tiene 26 bytes:

| Offset | Tamaño | Campo | Notas |
|---|---|---|---|
| 0 | uint8 | Header `0xF0` | Siempre `0xF0` |
| 1 | uint8 | Command code | Código de respuesta |
| 2-3 | uint16 BE | **Stroke count** (remadas) | `(byte[2]<<8) \| byte[3]` |
| 6-7 | uint16 BE | **Pace** (seg/500m) | Velocidad = `(60/pace) * 30` km/h |
| 9 | uint8 | **Cadencia** (remadas/min) | |
| 10-11 | uint16 BE | **Calorías** (kcal) | |
| 12-13 | uint16 BE | **Distancia** | `/10` = km |
| 14 | uint8 | **Resistencia** (1-15) | |
| 18 | uint8 | **Heart rate** (bpm) | 0 si no hay banda |
| 21 | uint8 | **Inclinación** (0-15) | |
| 22 | uint8 | Button event | `0x06`=inclinación+, `0x07`=inclinación- |
| Último byte | uint8 | Checksum | Suma de todos los bytes anteriores `& 0xFF` |

## Comandos de control

Todos los comandos empiezan con `0xF0` y terminan con checksum (suma de bytes anteriores `& 0xFF`):

| Comando | Bytes | Función |
|---|---|---|
| Init 1 | `F0 A3 93` | Secuencia de inicialización |
| Init 2 | `F0 A4 94` | |
| Init 3 | `F0 A5 95` | |
| Init 4 | `F0 AB 9B` | |
| Keepalive | `F0 AC 9C` | Enviar cada ~300ms |
| Stop | `F0 C8 00 B8` | Detener cinta |

La app envía automáticamente la secuencia de init al conectar y luego un keepalive cada 300ms para mantener la conexión activa.

## Estructura de la app

### `index.html`

App de una sola página con Web Bluetooth API:

- **Botón Conectar**: llama a `navigator.bluetooth.requestDevice()` con `acceptAllDevices: true` y `optionalServices` incluyendo el UUID propietario ISSC
- **Botón Rediscover**: redescubre servicios sin reconectar
- **Panel izquierdo**: datos parseados del remo (remadas, velocidad, cadencia, calorías, distancia, resistencia, pulsaciones, inclinación, checksum)
- **Panel derecho**: log crudo con timestamps de todos los eventos BLE (TX/RX, servicios, características, notificaciones)

### `start.sh`

```bash
python3 -m http.server 8000  # desde el directorio del proyecto
```

Sirve la app en `http://localhost:8000`. Web Bluetooth requiere HTTPS o localhost.

## Cómo usar

1. Ejecutar `./start.sh`
2. Abrir `http://localhost:8000` en Chrome (macOS)
3. Poner el remo en modo BT (logo BT en pantalla)
4. Pulsar "Conectar a la máquina"
5. Seleccionar el dispositivo en el selector de Chrome
6. La app envía la secuencia de init automáticamente y empieza a recibir datos

## Requisitos

- **Chrome** (Web Bluetooth solo funciona en Chrome/Edge/Opera; no Firefox ni Safari)
- **macOS** o Windows o ChromeOS (Web Bluetooth no funciona en iOS)
- El remo debe estar en modo BT antes de conectar

## Investigación

La investigación se basó principalmente en el proyecto [qdomyos-zwift](https://github.com/cagnulein/qdomyos-zwift) (814 estrellas), que es la implementación comunitaria de referencia del protocolo Domyos. El código del remo está en `src/devices/domyosrower/domyosrower.cpp`.

Otros recursos:
- [Palantir555/domyos-el500-hack](https://github.com/Palantir555/domyos-el500-hack) — reverse engineering de la elíptica EL500 (mismo protocolo ISSC)
- [Decathlon/domyos-developers](https://github.com/Decathlon/domyos-developers) — repo oficial de Decathlon; lista dispositivos compatibles con FTMS (el 500B **no** está en la lista)
- [Blog: Reversing Domyos EL500](https://jcjc-dev.com/2023/03/19/reversing-domyos-el500-elliptical/)

### Dos modos de protocolo

Los dispositivos Domyos soportan dos protocolos dependiendo del modelo/firmware:
1. **Propietario ISSC** (dispositivos antiguos como el 500B) — usa el servicio `49535343-*`
2. **FTMS estándar** (dispositivos nuevos) — usa `0x1826`

QZ (qdomyos-zwift) detecta cuál usar en runtime: si encuentra el servicio `49535343-fe7d-...` usa el protocolo propietario; si solo encuentra `0x1826`, usa FTMS.

El Domyos 500B pertenece al primer grupo: usa el protocolo propietario ISSC.

### Sub-variantes

Dentro del protocolo propietario existen dos sub-variantes:
- **ChangYow** — dirección MAC no empieza por `57`
- **Telink** — dirección MAC empieza por `57`

La secuencia de init puede variar entre variantes. Esta app usa la secuencia ChangYow.

## Limitaciones actuales

- Web Bluetooth solo funciona en Chrome/Edge/Opera (no Safari, no Firefox)
- No funciona en iOS (ni siquiera en Chrome para iOS)
- El formato de paquete podría variar según firmware; el parser asume 26 bytes
- No se ha implementado control de resistencia/inclinación desde la app (solo lectura de datos)
