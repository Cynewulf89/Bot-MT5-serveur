#!/bin/bash
set -e

# Démarrage du serveur d'affichage virtuel Xvfb
Xvfb :0 -screen 0 1280x1024x24 &
sleep 2

# Démarrage du gestionnaire de fenêtres léger
fluxbox &
sleep 1

# Démarrage de x11vnc et noVNC pour visualiser l'interface MT5 dans le navigateur
x11vnc -display :0 -nopw -listen 0.0.0.0 -xkb -forever -shared &
websockify --web /usr/share/novnc 6080 localhost:5900 &

# Initialisation du préfixe Wine si non existant
wineboot --init || true

# Installation de MetaTrader 5 si non installé
MT5_PATH="/root/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe"
if [ ! -f "$MT5_PATH" ]; then
    echo "Installation de MetaTrader 5 en cours..."
    wine /root/mt5setup.exe /auto &
    sleep 30
fi

# Copie automatique de l'Expert Advisor SpotHYPE_Gold dans le terminal MT5
MQL5_EXPERTS_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts"
if [ -d "$MQL5_EXPERTS_DIR" ] && [ -d "/root/Experts" ]; then
    cp -u /root/Experts/* "$MQL5_EXPERTS_DIR/" 2>/dev/null || true
fi

# Lancement du terminal MT5 en mode standard (non-portable pour charger les serveurs en ligne)
if [ -f "$MT5_PATH" ]; then
    echo "Démarrage de MetaTrader 5..."
    wine "$MT5_PATH" &
else
    echo "Terminal MT5 introuvable, relance de l'installateur..."
    wine /root/mt5setup.exe /auto &
fi

# Maintien du conteneur en vie et journalisation
tail -f /dev/null
