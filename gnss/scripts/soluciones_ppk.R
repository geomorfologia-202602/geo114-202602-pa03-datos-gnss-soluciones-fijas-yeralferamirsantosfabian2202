#!/usr/bin/env bash
# PA03 GEO-114 - Flujo completo que generó las soluciones PPK
# Ejecutar desde: ~/pa03_yeral/

cd ~/pa03_yeral

# ============================================================
# 0. INSTALAR HERRAMIENTAS (RTKLIB-EX: convbin + rnx2rtkp)
# ============================================================
mkdir -p ~/bin ~/tools
cd ~/tools
[ ! -d ~/tools/RTKLIB ] && git clone --depth 1 https://github.com/rtklibexplorer/RTKLIB.git

cd ~/tools/RTKLIB/app/consapp/convbin/gcc && make
cd ~/tools/RTKLIB/app/consapp/rnx2rtkp/gcc && make

cp ~/tools/RTKLIB/app/consapp/convbin/gcc/convbin ~/bin/
  cp ~/tools/RTKLIB/app/consapp/rnx2rtkp/gcc/rnx2rtkp ~/bin/
  chmod +x ~/bin/convbin ~/bin/rnx2rtkp

# ============================================================
# 1. UNIR LOS 23 .bin DE LA BASE Y CONVERTIR A RINEX 3.04
# ============================================================
cd ~/pa03_yeral

cat gnss/raw/base/*.bin > /tmp/base_completa.bin

~/bin/convbin -r unicore -v 3.04 -od -os -f 3 \
-o gnss/rinex/base/base_completa.obs \
-n gnss/rinex/base/base_completa.nav \
/tmp/base_completa.bin

# ============================================================
# 2. DIEZMAR LA BASE A 30 s (para enviar a CSRS-PPP)
# ============================================================
~/bin/convbin -r rinex -v 3.04 -ti 30 \
-o gnss/ppp/base_unida_30s.obs \
gnss/rinex/base/base_completa.obs

# >>> ENVIAR base_unida_30s.obs A CSRS-PPP (manual, por navegador) <<<
# URL: https://webapp.csrs-scrs.nrcan-rncan.gc.ca/geod/tools-outils/ppp.php
# Modo: Static | Marco: ITRF | Email: yeralferamirsantosfabian@gmail.com
# Coordenada recibida (ITRF2020/IGc20, época 2026.7):
#   X = 2078167.0251
#   Y = -5683987.2712
#   Z = 2006702.5967

# ============================================================
# 3. CONVERTIR ROVER U-BLOX (doble frecuencia)
# ============================================================
~/bin/convbin -r ubx -v 3.04 -od -os -f 2 \
-o gnss/rinex/rover/rover_ublox.obs \
-n gnss/rinex/rover/rover_ublox.nav \
gnss/raw/rover/20260830-122740-ubx-nmea-data-YERAL.ubx

# ============================================================
# 4. ROVER UNICORE: convertir con UPrecise/UnicoreConverter
# ============================================================
# El .log de Unicore NO se convierte con convbin.
# Se convierte en Windows con UPrecise/UnicoreConverter a:
#   gnss/rinex/rover/rover_unicore.obs
#   gnss/rinex/rover/rover_unicore.nav
# Y luego se suben al servidor con el panel Files de RStudio.

# ============================================================
# 5. DIEZMAR ROVERS A 1 Hz (para alinear con la base)
# ============================================================
~/bin/convbin -r rinex -v 3.04 -ti 1 \
-o gnss/rinex/rover/rover_ublox_1s.obs \
gnss/rinex/rover/rover_ublox.obs

~/bin/convbin -r rinex -v 3.04 -ti 1 \
-o gnss/rinex/rover/rover_unicore_1s.obs \
gnss/rinex/rover/rover_unicore.obs

# ============================================================
# 6. CREAR ppk.conf CON LA COORDENADA PPP DE LA BASE
# ============================================================
cat > gnss/scripts/ppk.conf << 'FINCONF'
pos1-posmode       =kinematic
pos1-frequency     =l1+l2
pos1-soltype       =forward
pos1-elmask        =15
pos1-dynamics      =off
pos1-tidecorr      =off
pos1-ionoopt       =brdc
pos1-tropopt       =saas
pos1-sateph        =brdc
pos1-navsys        =31
pos2-armode        =fix-and-hold
pos2-arthres       =3.0
pos2-arminfix      =10
pos2-gloarmode     =on
pos2-galarmode     =on
pos2-bdsarmode     =on
pos2-slipthres     =0.05
out-solformat      =llh
out-outhead        =on
out-outopt         =on
out-timesys        =gpst
out-timeform       =hms
out-timendec       =3
out-degform        =deg
out-height         =ellipsoidal
out-outstat        =residual
ant1-postype       =llh
ant1-pos1          =0
ant1-pos2          =0
ant1-pos3          =0
ant2-postype       =xyz
ant2-pos1          =2078167.0251
ant2-pos2          =-5683987.2712
ant2-pos3          =2006702.5967
misc-timeinterp    =on
FINCONF

# ============================================================
# 7. EJECUTAR EL PPK (rnx2rtkp) — genera los 4 .pos
# ============================================================
FECHA=2026/08/30
CONF=gnss/scripts/ppk.conf
BASE=gnss/rinex/base/base_completa.obs
NAV=gnss/rinex/base/base_completa.nav
OUT=gnss/ppk

# --- u-blox: ventana 16:27:58 → 16:29:58 GPST ---
~/bin/rnx2rtkp -k $CONF -p 3 -f 2 \
-ts $FECHA 16:27:58 -te $FECHA 16:29:58 \
-o $OUT/rover_ublox_fijo.pos \
gnss/rinex/rover/rover_ublox_1s.obs $BASE $NAV

~/bin/rnx2rtkp -k $CONF -p 2 -f 2 \
-ts $FECHA 16:27:58 -te $FECHA 16:29:58 \
-o $OUT/rover_ublox_epocas.pos \
gnss/rinex/rover/rover_ublox_1s.obs $BASE $NAV

# --- Unicore: ventana 16:19:29 → 16:21:29 GPST ---
~/bin/rnx2rtkp -k $CONF -p 3 -f 3 \
-ts $FECHA 16:19:29 -te $FECHA 16:21:29 \
-o $OUT/rover_unicore_fijo.pos \
gnss/rinex/rover/rover_unicore_1s.obs $BASE $NAV

~/bin/rnx2rtkp -k $CONF -p 2 -f 3 \
-ts $FECHA 16:19:29 -te $FECHA 16:21:29 \
-o $OUT/rover_unicore_epocas.pos \
gnss/rinex/rover/rover_unicore_1s.obs $BASE $NAV

# ============================================================
# 8. VERIFICAR LOS 4 PRODUCTOS
# ============================================================
echo "=== Resultados ==="
ls -lh gnss/ppk/*.pos

for f in gnss/ppk/rover_ublox_fijo.pos gnss/ppk/rover_ublox_epocas.pos \
gnss/ppk/rover_unicore_fijo.pos gnss/ppk/rover_unicore_epocas.pos; do
echo ""
echo "--- $f ---"
echo "Total       : $(grep -vc '^%' $f)"
echo "Q=1 (FIX)   : $(awk '!/^%/{if($6==1)c++}END{print c+0}' $f)"
echo "Q=2 (FLOAT) : $(awk '!/^%/{if($6==2)c++}END{print c+0}' $f)"
echo "Ratio prom  : $(awk '!/^%/{s+=$15;n++}END{if(n>0)printf "%.2f\n",s/n}' $f)"
done

echo ""
echo ">>> FIN. Los 4 archivos .pos están en gnss/ppk/"