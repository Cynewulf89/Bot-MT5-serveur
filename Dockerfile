FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV WINEPREFIX=/root/.wine
ENV WINEARCH=win64
ENV WINEDEBUG=-all
ENV DISPLAY=:0

# 1. Outils de base et certificats
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y --no-install-recommends \
    wget \
    curl \
    ca-certificates \
    gnupg2 \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    fluxbox \
    procps \
    cabextract \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# 2. Installation officielle WineHQ (dernière version Wine 10 / Staging)
RUN mkdir -pm755 /etc/apt/keyrings && \
    wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && \
    wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources && \
    apt-get update && apt-get install -y --install-recommends \
    winehq-staging \
    && rm -rf /var/lib/apt/lists/*

# 3. Téléchargement de l'installateur officiel MetaTrader 5
WORKDIR /root
RUN wget -q -O mt5setup.exe https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe

# 4. Copie des Experts Advisors (SpotHYPE_Gold)
COPY Experts /root/Experts

# 5. Script de démarrage de l'environnement MT5 + VNC Web
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Ports : 5900 (VNC), 6080 (noVNC Web GUI), 18812 (Bridge RPyC)
EXPOSE 5900 6080 18812

ENTRYPOINT ["/entrypoint.sh"]
