# <img src="https://raw.githubusercontent.com/Victor-Y-Fadeev/synology-jellyfin/refs/heads/master/icons/xray-core.svg" width="32"/> Xray-core

`./config/xray/02_dns.json`:
```json
{
  "dns": {
    "https://cloudflare-dns.com/dns-query"
  }
}
```

`./config/xray/03_routing.json`:
```json
{
}
```

`./config/xray/05_inbounds.json`:
```json
{
  "inbounds": [
    {
      "protocol": "socks",
      "port": 2080,
      "tag": "proxy"
    }
  ]
}
```

`./config/xray/06_outbounds.json`:
```json
{
  "outbounds": [
    {
      "tag": "vpn",
      "protocol": "vless",
      "settings": {
        "id": "",
        "port": 443,
        "address": "",
        "encryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "tls",
        "tlsSettings": {
          "alpn": [
            "h2"
          ],
          "serverName": "",
          "fingerprint": "chrome"
        },
        "xhttpSettings": {
          "mode": "stream-up",
          "path": ""
        }
      }
    }
  ]
}
```
