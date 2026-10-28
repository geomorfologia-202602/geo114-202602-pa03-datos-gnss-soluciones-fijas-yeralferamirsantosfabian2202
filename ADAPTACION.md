# Adaptación del cuaderno PPK a la PA03

El cuaderno `ppk-guia-para-solucion-UM980-OBSVMB-yeral.Rmd` se adaptó mediante `gnss/scripts/soluciones_ppk.sh` con los nombres reales de la base, los rovers y la coordenada PPP.

## Nombres reales usados

| Elemento | Archivo / valor |
|---|---|
| Base | 23 `.bin` en `gnss/raw/base/` unidos con `cat` en `gnss/raw/base_unida.bin` |
| Rover u-blox | `gnss/raw/rover/20260830-122740-ubx-nmea-data-YERAL.ubx` |
| Rover Unicore | `gnss/rinex/rover/rover_unicore.obs` (pre-convertido con UPrecise) |
| Coordenada PPP de la base | X = 2078167.0251, Y = -5683987.2712, Z = 2006702.5967 (CSRS-PPP, ITRF2020/IGc20, época 2026.7) |
| Ventana u-blox | 16:27:58 → 16:29:58 GPST |
| Ventana Unicore | 16:19:29 → 16:21:29 GPST |

## Estructura respetada

gnss/raw/base/     23 .bin de la base (ignorados por git)
gnss/raw/rover/    .ubx del u-blox y .log del Unicore
gnss/rinex/base/   base_completa.obs + .nav
gnss/rinex/rover/  rover_unicore.obs pre-convertido
gnss/scripts/      soluciones_ppk.sh + ppk.conf
gnss/ppk/          4 soluciones .pos entregables

## Resultados

- u-blox:  120 epocas, 0 FIX, 100 FLOAT, ratio 0.91
- Unicore: 121 epocas, 0 FIX, 100 FLOAT, ratio 0.98

Iguales al informe PA03_GNSS.pdf.

## Reproducir

    bash gnss/scripts/soluciones_ppk.sh
