# ESP32 STEAMakers AI

Definició d'ESP Board Manager per executar ESP-Claw a la placa ESP32
STEAMakers AI, basada en la Keyestudio KS5034 (ESP32-S3-WROOM-1-N16R8).

## Maquinari compatible

| Funció | Component | Senyals |
| --- | --- | --- |
| Pantalla | KS0606/MSP1541, ST7789, 240x240 | SCLK 20, MOSI 21, RST 38, DC 40, CS 41, BL 42 |
| Micròfon | INMP441 | WS 4, BCLK 5, DOUT 6 |
| Altaveu | MAX98357A + altaveu | DIN 7, BCLK 15, LRC 16 |
| Emmagatzematge | FATFS intern (3 MB) | Partició `storage` de la flash |
| Consola | CH340 / UART0 | GPIO43 TX, GPIO44 RX |

## GPIO genèrics

El firmware inclou la skill `steamakers_gpio`, que permet a l'agent controlar
sortides i entrades digitals, llegir ADC1 i generar polsos PWM temporitzats per
a LEDs, brunzidors i servomotors. La capa valida una llista blanca per evitar
que una ordre de l'agent reconfiguri la TFT, l'àudio, la PSRAM o la consola.

| Categoria | GPIO |
| --- | --- |
| Digitals segurs | 2, 8, 9, 10, 11, 12, 13, 14, 17, 18, 47, 48 |
| ADC1 segurs amb Wi-Fi | 2, 8, 9, 10 |
| Condicionals | 3 (strap d'arrencada), 19 (USB D-) |
| Reservats | 0, 4-7, 15-16, 20-21, 35-44 excepte els condicionals indicats |

GPIO3 i GPIO19 només s'accepten amb confirmació explícita. Els PWM de brunzidor
i servo són finits i alliberen el pin en acabar. Els servos, motors, relés i
càrregues semblants no s'han d'alimentar mai des del senyal GPIO. Els connectors
genèrics de tres pins exposen `G` (massa), `S` (senyal) i `V` (alimentació): el
convertidor intern de la placa permet disposar de 5 V al pin `V` de tots aquests
connectors, dins del pressupost de corrent compartit de la placa. El pin `S`,
però, continua connectat a la lògica de 3,3 V de l'ESP32-S3; un nivell alt no és
una sortida de 5 V i no s'hi ha d'aplicar una entrada de 5 V. Les càrregues de
més corrent necessiten un driver i, si escau, una font externa amb GND comú.

### Control local per UART

La consola del connector USB **PROG** permet provar el GPIO sense Telegram ni
cap LLM. Obre un monitor a 115200 bit/s i executa el wrapper de la skill; no
cridis directament els mòduls `gpio`, `adc` o `mcpwm`, perquè el wrapper és qui
protegeix els pins reservats.

```text
lua --run --path /system/skills/steamakers_gpio/scripts/gpio_control.lua --timeout-ms 10000
lua --run --path /system/skills/steamakers_gpio/scripts/gpio_control.lua --args-json "{\"action\":\"write\",\"pin\":12,\"level\":1}" --timeout-ms 10000
lua --run --path /system/skills/steamakers_gpio/scripts/gpio_control.lua --args-json "{\"action\":\"read\",\"pin\":8,\"pull\":\"up\"}" --timeout-ms 10000
lua --run --path /system/skills/steamakers_gpio/scripts/gpio_control.lua --args-json "{\"action\":\"analog\",\"pin\":2,\"samples\":8}" --timeout-ms 10000
lua --run --path /system/skills/steamakers_gpio/scripts/gpio_control.lua --args-json "{\"action\":\"tone\",\"pin\":12,\"frequency_hz\":880,\"duration_ms\":500}" --timeout-ms 10000
lua --run --path /system/skills/steamakers_gpio/scripts/gpio_control.lua --args-json "{\"action\":\"servo\",\"pin\":12,\"angle\":90,\"hold_ms\":750}" --timeout-ms 10000
lua --run --path /system/skills/steamakers_gpio/scripts/gpio_control.lua --args-json "{\"action\":\"release\",\"pin\":12}" --timeout-ms 10000
```

La primera ordre, sense `args-json`, només enumera el mapa permès. Les ordres de
sortida s'han d'executar únicament després de comprovar el circuit, la polaritat,
la resistència o etapa de potència i la tensió d'alimentació.

La TFT ocupa GPIO20, que també és el senyal USB D+ de l'ESP32-S3. Amb la TFT
connectada s'ha d'utilitzar el connector USB **PROG** (CH340/UART0), no el
connector USB OTG, per gravar i monitorar el firmware.

Quan la connexió Wi-Fi està preparada, la pantalla mostra l'adreça IPv4
assignada per la xarxa just sota `WIFI ON`. Aquesta és l'adreça que s'ha
d'introduir al navegador per obrir la consola web si el nom
`http://esp-claw.local/` no es resol al mòbil o a l'ordinador.

El perfil ESP-Claw no utilitza la ranura microSD perquè el seu bus comparteix
GPIO35-37 amb la PSRAM octal del mòdul N16R8. La targeta ha d'estar retirada i
no s'ha d'inserir mentre s'executa aquest firmware. La ranura buida pot continuar
físicament connectada: el controlador microSD no es compila ni configura.

Els 8 MB de PSRAM funcionen a 40 MHz i passen el test de memòria d'ESP-IDF durant
l'arrencada. La freqüència conservadora tolera millor les pistes obertes que van
fins a la ranura buida. ESP-Claw desa configuració, tokens, memòria, sessions,
regles, tasques i skills a la partició FATFS interna `/fatfs`. La TFT, l'àudio,
els canals local/Web i Telegram continuen habilitats; QQ, Feishu, WeChat i MCP
romanen desactivats.

## Connexions d'àudio

Al micròfon INMP441, connecta `L/R` a GND per seleccionar el canal esquerre.
Al MAX98357A, alimenta `SD` juntament amb `VCC` i segueix el pont de guany del
mòdul STEAMakers. La sortida envia el mateix PCM als dos slots I2S perquè
funcioni amb qualsevol selecció física de canal del MAX98357A. Tots dos
connectors del kit estan alimentats a 3,3 V.

## Generació i compilació

ESP-Claw requereix ESP-IDF 5.5.4 i `esp-bmgr-assist`:

```bash
cd application/edge_agent
idf.py bmgr -c ./boards -b esp32_steamakers_ai
idf.py build
idf.py -p /dev/cu.usbserial-* flash monitor
```

La comanda `bmgr` genera `components/gen_bmgr_codes/` a partir dels fitxers
YAML d'aquesta carpeta. No modifiquis directament els fitxers generats.

## Instal·lació del firmware precompilat

La [versió v0.1.3](https://github.com/tonihortal/esp-claw-steamakers-ai/releases/tag/v0.1.3)
inclou el fitxer únic
[`esp-claw-steamakers-ai-v0.1.3.bin`](https://github.com/tonihortal/esp-claw-steamakers-ai/releases/download/v0.1.3/esp-claw-steamakers-ai-v0.1.3.bin).
La seva suma SHA-256 verificada és
`301a6a586a3cb59c37c0c1cd095f5996db635e8929af86487180bc1a2801cfcf` i també
està publicada a
[`SHA256SUMS.txt`](https://github.com/tonihortal/esp-claw-steamakers-ai/releases/download/v0.1.3/SHA256SUMS.txt).
Retira la microSD, connecta el cable de dades al port **PROG/CH340** i instal·la
`esptool`:

```bash
python -m pip install --upgrade esptool
```

Després substitueix `PORT` pel port real (`COM5` a Windows,
`/dev/ttyUSB0` a GNU/Linux o `/dev/cu.usbserial-XXXX` a macOS) i executa:

```bash
python -m esptool --chip esp32s3 --port PORT --baud 460800 \
  write-flash --flash-mode dio --flash-freq 80m --flash-size 16MB \
  0x0 esp-claw-steamakers-ai-v0.1.3.bin
```

La imatge és una instal·lació neta: substitueix l'aplicació, el sistema i la
partició de dades. Cal tornar a configurar la Wi-Fi i les claus després de
gravar-la. Verifica abans la suma publicada a `SHA256SUMS.txt`.

## Comprovacions en maquinari

1. Arrencada i consola UART a 115200 bit/s.
2. TFT encesa, imatge completa de 240x240 i colors correctes.
3. Reproducció d'àudio sense distorsió al MAX98357A.
4. Captura de veu a 16 kHz des de l'INMP441.
5. Muntatge de la partició interna a `/fatfs` i lectura/escriptura d'un fitxer.

El firmware inclou l'skill `steamakers_hardware_test`, que automatitza aquestes
comprovacions. Amb la microSD retirada, obre el xat d'ESP-Claw i demana:
**«Executa la prova completa de maquinari STEAMakers»**. La prova
dibuixa quatre quadrants RGBW, reprodueix tres tons i mesura el micròfon. Cada
bloc s'executa en un procés Lua independent per limitar el pic de RAM, i acaba
amb el seu propi marcador `ALL PASS`. El 26 d'agost de 2026 es va validar
físicament que la imatge ocupa tota la TFT amb colors correctes, que els tres
tons són audibles i que el micròfon detecta veu. El perfil actual afegeix una
prova d'escriptura, lectura i esborrat sobre la flash interna i valida la PSRAM
durant cada arrencada.

La pantalla connectada s'ha validat físicament amb
`STEAMAKERS_LCD_OFFSET_Y` igual a `0` a `setup_device.c`.

L'skill `steamakers_display` permet substituir temporalment la pantalla d'estat
per una composició de fins a 64 operacions: franges o graelles regulars,
rectangles, línies, píxels, cercles, el·lipses, triangles, arcs i text ASCII.
Les operacions es dibuixen en ordre sobre un fons configurable i admeten colors
amb nom, codis hexadecimals o components RGB(A). El controlador antic de color
sòlid i quatre quadrants es manté per compatibilitat.

## Referències de maquinari

- [Keyestudio KS5034](https://docs.keyestudio.com/projects/KS5034/en/latest/docs/KS5034%20Keyestudio%20ESP32%20S3%20PRO%20Development%20Board.html)
- [Keyestudio KS0606](https://docs.keyestudio.com/projects/KS0606/en/latest/docs/KS0606%20Keyestudio%201.54-inch%20TFT%20Display.html)
- [Keyestudio KS5027 (INMP441 i MAX98357A)](https://docs.keyestudio.com/projects/ESP32S3_LCD154/en/latest/LCD154/LCD154.html)
