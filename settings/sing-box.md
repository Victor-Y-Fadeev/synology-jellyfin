# <img src="https://raw.githubusercontent.com/SagerNet/sing-box/refs/heads/dev-next/docs/assets/icon.svg" width="32"/> [sing-box](http://localhost:2080/)

```json
{
  "dns": {
    "servers": [
      {
        "type": "local",
        "tag": "local"
      },
      {
        "type": "udp",
        "tag": "dns",
        "server": "1.1.1.1",
        "server_port": 53,
        "detour": "proxy"
      }
    ],
    "rules": [
      {
        "inbound": "proxy",
        "server": "dns"
      }
    ]
  },
  "services": [
    {
      "type": "resolved",
      "tag": "resolved",
      "listen": "::",
      "listen_port": 53
    }
  ],
  "inbounds": [
    {
      "type": "mixed",
      "tag": "mixed",
      "listen": "::",
      "listen_port": 2080
    }
  ],
  "outbounds": [
    {
      "type": "vless",
      "tag": "proxy",
      "server": "",
      "server_port": 443,
      "uuid": "",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
        "reality": {
          "enabled": true,
          "public_key": "",
          "short_id": ""
        }
      }
    },
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "rules": [
      {
        "ip_is_private": true,
        "outbound": "direct"
      },
      {
        "rule_set": "geoip",
        "outbound": "direct"
      },
      {
        "rule_set": "geosite",
        "outbound": "direct"
      }
    ],
    "rule_set": [
      {
        "tag": "geoip",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-ru.srs",
        "download_detour": "proxy"
      },
      {
        "tag": "geosite",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ru.srs",
        "download_detour": "proxy"
      }
    ],
    "final": "proxy"
  }
}
```
