
# <img src="https://raw.githubusercontent.com/SagerNet/sing-box/refs/heads/dev-next/docs/assets/icon.svg" width="32"/> [sing-box](http://localhost:2080/)

<details><summary><h3>/etc/sing-box/config.json</h3></summary><blockquote>

```json
{
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
        "rule_set": "geoip-ru",
        "outbound": "direct"
      },
      {
        "rule_set": "geosite-category-ru",
        "outbound": "direct"
      }
    ],
    "rule_set": [
      {
        "tag": "geoip-ru",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-ru.srs",
        "download_detour": "proxy"
      },
      {
        "tag": "geosite-category-ru",
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

</blockquote></details>

# <img src="https://raw.githubusercontent.com/qbittorrent/qBittorrent/refs/heads/master/src/icons/qbittorrent-tray.svg" width="32"/> [qBittorrent](http://localhost:8080/)

- [ ] `Tools`
  - [ ] `Options...`
    - [ ] `Downloads`
      - [ ] `Saving Management`
        - [ ] `Default Save Path:` -> `/data/downloads`
        - [ ] `Copy .torrent files to:` -> `/data/torrents`
        - [ ] `Copy .torrent files for finished downloads to:` -> `/data/torrents`
      - [ ] `Automatically add torrents from:` -> `/data/torrents`
    - [ ] `Connection`
      - [ ] `Proxy Server`
        - [ ] `Type:` -> `HTTP`
        - [ ] `Host:` -> `host.docker.internal`
        - [ ] `Port:` -> `2080`
        - [ ] `Perform hostname lookup via proxy` -> `On`
    - [ ] `WebUI`
      - [ ] `Authentication`
        - [ ] `Username:` -> `admin`
        - [ ] `Password:` -> `adminadmin`

# <img src="https://raw.githubusercontent.com/Radarr/Radarr/refs/heads/develop/Logo/Radarr.svg" width="32"/> [Radarr](http://localhost:7878/)

# <img src="https://raw.githubusercontent.com/Sonarr/Sonarr/refs/heads/develop/Logo/Sonarr.svg" width="32"/> [Sonarr](http://localhost:8989/)

# <img src="https://raw.githubusercontent.com/Prowlarr/Prowlarr/refs/heads/develop/Logo/Prowlarr.svg" width="32"/> [Prowlarr](http://localhost:9696/)

# <img src="https://raw.githubusercontent.com/jellyfin/jellyfin-ux/refs/heads/master/branding/SVG/icon-transparent.svg" width="32"/> [Jellyfin](http://localhost:8096/)

# <img src="https://raw.githubusercontent.com/Fallenbagel/jellyseerr/refs/heads/develop/public/os_icon.svg" width="32"/> [Jellyseerr](http://localhost:5055/)
