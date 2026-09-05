# <img src="https://raw.githubusercontent.com/Victor-Y-Fadeev/synology-jellyfin/refs/heads/master/icons/xray-core.svg" width="32"/> Xray-core

```shell
lsmod | grep "^tun " || sudo insmod /lib/modules/tun.ko
```

`./config/xray/02_dns.json`:
```json
{
  "dns": {
    "servers": [
      "https://cloudflare-dns.com/dns-query"
    ]
  }
}
```

`./config/xray/03_routing.json`:
```json
{
  "routing": {
    "rules": [
      {
        "inboundTag": [
          "dns-in"
        ],
        "outboundTag": "dns-out"
      }
    ]
  }
}
```

`./config/xray/05_inbounds.json`:
```json
{
  "inbounds": [
    {
      "tag": "proxy",
      "protocol": "socks",
      "port": 2080
    },
    {
      "tag": "dns-in",
      "protocol": "tunnel",
      "port": 53,
      "settings": {
        "allowedNetwork": "tcp,udp"
      }
    },
    {
      "tag": "tun",
      "protocol": "tun",
      "settings": {
        "name": "tun0",
        "gateway": [
          "169.254.10.1/30"
        ]
      }
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
    },
    {
      "tag": "dns-out",
      "protocol": "dns"
    }
  ]
}
```
