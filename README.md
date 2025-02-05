# <img src="https://raw.githubusercontent.com/SagerNet/sing-box/refs/heads/dev-next/docs/assets/icon.svg" width="32"/> [sing-box](http://localhost:2080/)

<details><summary><code>/etc/sing-box/config.json</code></summary><br><blockquote>

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
    - [ ] `Behavior`
      - [ ] `Language`
        - [ ] `User Interface Language:` -> `Russian`
    - [ ] `Downloads`
      - [ ] `When adding a torrent`
        - [ ] `Torrent content layout:` -> `Create subfolder`
      - [ ] `Saving Management`
        - [ ] `Default Save Path:` -> `/data/downloads`
        - [ ] `Copy .torrent files to:` -> `/data/torrents`
      - [ ] `Automatically add torrents from:` -> `/data/torrents`
    - [ ] `Connection`
      - [ ] `Connections Limits`
        - [ ] `Global maximum number of connections:` -> `Off`
        - [ ] `Maximum number of connections per torrent:` -> `Off`
        - [ ] `Global maximum number of upload slots:` -> `Off`
        - [ ] `Maximum number of upload slots per torrent:` -> `Off`
      - [ ] `Proxy Server`
        - [ ] `Type:` -> `HTTP`
        - [ ] `Host:` -> `sing-box`
        - [ ] `Port:` -> `2080`
        - [ ] `Perform hostname lookup via proxy` -> `On`
        - [ ] `Use proxy for BitTorrent purposes` -> `On`
          - [ ] `Use proxy for peer connections` -> `Off`/`On`
        - [ ] `Use proxy for RSS purposes` -> `On`
        - [ ] `Use proxy for general purposes` -> `On`
    - [ ] `Speed`
      - [ ] `Global Rate Limits`
        - [ ] `Upload:` -> `0`
        - [ ] `Download:` -> `0`
      - [ ] `Alternative Rate Limits`
        - [ ] `Upload:` -> `0`
        - [ ] `Download:` -> `0`
      - [ ] `Rate Limits Settings`
        - [ ] `Apply rate limit to µTP protocol` -> `Off`
        - [ ] `Apply rate limit to transport overhead` -> `Off`
        - [ ] `Apply rate limit to peers on LAN` -> `Off`
    - [ ] `BitTorrent`
      - [ ] `Max active checking torrents:` -> `-1`
      - [ ] `Torrent Queueing` - > `Off`
    - [ ] `WebUI`
      - [ ] `Authentication`
        - [ ] `Username:` -> `admin`
        - [ ] `Password:` -> `adminadmin`
    - [ ] `Advanced`
      - [ ] `libtorrent Section`
        - [ ] `Hashing threads:` -> `32`

# <img src="https://raw.githubusercontent.com/Radarr/Radarr/refs/heads/develop/Logo/Radarr.svg" width="32"/> [Radarr](http://localhost:7878/)

# <img src="https://raw.githubusercontent.com/Sonarr/Sonarr/refs/heads/develop/Logo/Sonarr.svg" width="32"/> [Sonarr](http://localhost:8989/)

- [ ] `Settings` -> `Show Advanced`
  - [ ] `General`
    - [ ] `Security`
      - [ ] `Authentication` -> `Forms (Login Page)`
      - [ ] `Username` -> `admin`
      - [ ] `Password` -> `adminadmin`
    - [ ] `Proxy`
      - [ ] `Use Proxy` -> `On`
      - [ ] `Proxy Type` -> `HTTP(S)`
      - [ ] `Hostname` -> `sing-box`
      - [ ] `Port` -> `2080`
      - [ ] `Bypass Proxy for Local Addresses` -> `On`
  - [ ] `UI`
    - [ ] `Calendar`
      - [ ] `First Day of Week` -> `Monday`
      - [ ] `Week Column Header` -> `Tue 25/03`
    - [ ] `Dates`
      - [ ] `Short Date Format` -> `25 Mar 2014`
      - [ ] `Long Date Format` -> `Tuesday, 25 March, 2014`
      - [ ] `Time Format` -> `17:00/17:30`
      - [ ] `Show Relative Dates` -> `On`
    - [ ] `Language`
      - [ ] `UI Language` -> `Russian`

# <img src="https://raw.githubusercontent.com/Prowlarr/Prowlarr/refs/heads/develop/Logo/Prowlarr.svg" width="32"/> [Prowlarr](http://localhost:9696/)

# <img src="https://raw.githubusercontent.com/jellyfin/jellyfin-ux/refs/heads/master/branding/SVG/icon-transparent.svg" width="32"/> [Jellyfin](http://localhost:8096/)

# <img src="https://raw.githubusercontent.com/Fallenbagel/jellyseerr/refs/heads/develop/public/os_icon.svg" width="32"/> [Jellyseerr](http://localhost:5055/)
