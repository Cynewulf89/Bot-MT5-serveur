FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV WINEPREFIX=/root/.wine
ENV WINEARCH=win64
ENV WINEDEBUG=-all
ENV DISPLAY=:0

# 1. Dépendances système, Wine et serveur graphique virtuel (Xvfb + X11VNC + noVNC)
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y --no-install-recommends \
    wine \
    wine64 \
    wine32 \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    fluxbox \
    wget \
    curl \
    cabextract \
    ca-certificates \
    procps \
    python3 \
    python3-pip \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# 2. Téléchargement de l'installateur officiel MetaTrader 5
WORKDIR /root
RUN wget -q -O mt5setup.exe https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe

# 3. Copie des Experts Advisors (SpotHYPE_Gold)
COPY Experts /root/Experts

# 4. Script de démarrage de l'environnement MT5 + VNC Web
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Ports : 5900 (VNC), 6080 (noVNC Web GUI), 18812 (RPyC / mt5linux bridge si nécessaire)
EXPOSE 5900 6080 18812

ENTRYPOINT ["/entrypoint.sh"]
