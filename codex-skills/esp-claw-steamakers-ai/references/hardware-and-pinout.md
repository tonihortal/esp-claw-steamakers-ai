# Hardware and pinout

Use the live board YAML and board README as final authority. These values are the
physically validated baseline from the project.

## Main peripherals

| Function | Device | Connections |
| --- | --- | --- |
| TFT | KS0606/MSP1541, ST7789, 240×240 | SCK GPIO20, MOSI GPIO21, RESET GPIO38, DC/Data GPIO40, CS GPIO41, backlight GPIO42 |
| Microphone | INMP441 | WS GPIO4, BCLK GPIO5, DOUT GPIO6; connect L/R to GND for the left channel |
| Speaker | MAX98357A | DIN GPIO7, BCLK GPIO15, LRC GPIO16; SD powered with VCC |
| Console | CH340/UART0 | GPIO43 TX, GPIO44 RX; use the board's PROG connector |
| Storage | Internal FATFS | 3 MB `storage` partition mounted through the DATA root, currently `/fatfs` |

The MAX98357A output path uses 24 kHz, 16-bit PCM duplicated into both I2S
slots. The INMP441 input path uses 16 kHz mono, 16 bit. The TFT has been
validated with a 240×240 geometry and vertical offset 0.

## Generic GPIO policy

The firmware-owned `steamakers_gpio` wrapper enforces the allowlist. Use it
instead of calling raw `gpio`, `adc`, or `mcpwm` modules.

| Class | GPIO |
| --- | --- |
| Safe digital | 2, 8, 9, 10, 11, 12, 13, 14, 17, 18, 47, 48 |
| Safe ADC1 while Wi-Fi is active | 2, 8, 9, 10 |
| Conditional | 3/A1 (boot strapping, ADC1), 19/A3 (USB D-, digital only) |
| Reserved | 0 boot; 4-7 and 15-16 audio; 20-21, 38, 40-42 TFT; 35-37 and 39 PSRAM/SD; 43-44 console |

GPIO3 and GPIO19 require explicit acknowledgement of their boot/USB impact.
PWM tone and servo operations are finite and release the pin. A LED on GPIO12
with correct polarity and a series resistor has been physically validated.

Header labels mean `G` = ground, `S` = 3.3 V logic signal, and `V` = 5 V power
from the onboard converter. Motors, servos, relays, solenoids, and substantial
buzzers need a suitable driver and sometimes an external supply with common
ground; never power them from `S`.

## microSD and PSRAM

The slot cannot be electrically disconnected, but leaving it empty is enough.
Do not insert a card while this firmware runs. GPIO35-37 belong to octal PSRAM
on the N16R8 module, so the microSD driver is excluded. PSRAM runs at the
conservative 40 MHz setting and ESP-IDF performs its memory test at boot. This
arrangement avoids the repeated crashes seen when a card or SD initialization
contended with PSRAM.
