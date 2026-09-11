# Bot-MT5-serveur 🚀

Serveur Docker Linux exécutant MetaTrader 5 (MT5) 64-bit sous Wine avec interface graphique accessible via navigateur (noVNC).

## 🖥️ Démarrage

```bash
docker compose up -d --build
```

## 🌐 Accès à l'interface graphique MT5

Ouvrez simplement votre navigateur sur :
- **http://localhost:6080/vnc.html** (ou `http://IP_DE_VOTRE_SERVEUR:6080/vnc.html`)
- Cliquez sur **Connect** pour voir le terminal MT5 tourner en direct.
