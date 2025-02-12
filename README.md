# <img src="https://upload.wikimedia.org/wikipedia/commons/9/94/Cloudflare_Logo.png" width="32"/> [Cloudflare](https://one.dash.cloudflare.com/)

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

- [ ] `Tools` -> `Options...`
  - [ ] `Behavior`
    - [ ] `Language`
      - [ ] `User Interface Language:` -> `Russian`
  - [ ] `Downloads`
    - [ ] `When adding a torrent`
      - [ ] `Torrent content layout:` -> `Create subfolder`
      - [ ] `When duplicate torrent is being added`
        - [ ] `Merge trackers to existing torrent` -> `On`
    - [ ] `Saving Management`
      - [ ] `Default Torrent Management Mode:` -> `Automatic`
      - [ ] `When Torrent Category changed:` -> `Relocate torrent`
      - [ ] `When Default Save Path changed:` -> `Relocate affected torrents`
      - [ ] `When Category Save Path changed:` -> `Relocate affected torrents`
      - [ ] `Default Save Path:` -> `/data/downloads`
      - [ ] `Copy .torrent files to:` -> `/data/torrents`
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

- [ ] `Settings` -> `Show Advanced`
  - [ ] `Media Management`
    - [ ] `Movie Naming`
      - [ ] `Rename Movies` -> `On`
      - [ ] `Replace Illegal Characters` -> `On`
      - [ ] `Colon Replacement` -> `Smart Replace`
      - [ ] `Standard Movie Format` -> `{Movie Title} ({Release Year})`
      - [ ] `Movie Folder Format` -> `{Movie Title} ({Release Year}) [tmdbid-{TmdbId}]`
    - [ ] `Folders`
      - [ ] `Create empty movie folders` - > `Off`
      - [ ] `Delete empty Folders` - > `On`
    - [ ] `Importing`
      - [ ] `Use Hardlinks instead of Copy` - > `On`
      - [ ] `Import Extra Files` - > `On`
    - [ ] `File Management`
      - [ ] `Unmonitor Deleted Movies` - > `On`
      - [ ] `Propers and Repacks` -> `Do not Prefer`
    - [ ] `Root Folders`
      - [ ] `/data/movies/anime`
      - [ ] `/data/movies/cartoons`
      - [ ] `/data/movies/films`
  - [ ] `Download Clients`
    - [ ] `qBittorrent`
      - [ ] `Name` -> `qBittorrent`
      - [ ] `Host` -> `qbittorrent`
      - [ ] `Port` -> `8080`
      - [ ] `Username` -> `admin`
      - [ ] `Password` -> `adminadmin`
      - [ ] `Category` -> `radarr`
      - [ ] `Completed Download Handling`
        - [ ] `Remove Completed` -> `Off`
  - [ ] `Metadata`
    - [ ] `Options`
      - [ ] `Certification Country` -> `United States`
  - [ ] `General`
    - [ ] `Security`
      - [ ] `Authentication` -> `Forms (Login Page)`
      - [ ] `Authentication Required` -> `Enabled`
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
    - [ ] `Movies`
      - [ ] `Runtime Format` -> `1h 15m`
    - [ ] `Dates`
      - [ ] `Short Date Format` -> `25 Mar 2014`
      - [ ] `Long Date Format` -> `Tuesday, 25 March, 2014`
      - [ ] `Time Format` -> `17:00/17:30`
      - [ ] `Show Relative Dates` -> `On`
    - [ ] `Language`
      - [ ] `Movie Info Language` -> `Russian`
      - [ ] `UI Language` -> `Russian`

# <img src="https://raw.githubusercontent.com/Sonarr/Sonarr/refs/heads/develop/Logo/Sonarr.svg" width="32"/> [Sonarr](http://localhost:8989/)

- [ ] `Settings` -> `Show Advanced`
  - [ ] `Media Management`
    - [ ] `Episode Naming`
      - [ ] `Rename Episodes` -> `On`
      - [ ] `Replace Illegal Characters` -> `On`
      - [ ] `Colon Replacement` -> `Smart Replace`
      - [ ] `Standard Episode Format` -> `s{season:00}e{episode:00} {Episode Title}`
      - [ ] `Daily Episode Format` -> `{Air.Date} {Episode Title}`
      - [ ] `Anime Episode Format` -> `s{season:00}e{episode:00} {Episode Title}`
      - [ ] `Series Folder Format` -> `{Series TitleYear} [tvdbid-{TvdbId}]`
      - [ ] `Season Folder Format` -> `Season {season:00}`
      - [ ] `Specials Folder Format` -> `Specials`
      - [ ] `Multi Episode Style` -> `Range`
    - [ ] `Folders`
      - [ ] `Create Empty Series Folders` - > `Off`
      - [ ] `Delete Empty Folders` - > `On`
    - [ ] `Importing`
      - [ ] `Use Hardlinks instead of Copy` - > `On`
      - [ ] `Import Extra Files` - > `On`
    - [ ] `File Management`
      - [ ] `Unmonitor Deleted Episodes` - > `On`
      - [ ] `Propers and Repacks` -> `Do not Prefer`
    - [ ] `Root Folders`
      - [ ] `/data/series/anime`
      - [ ] `/data/series/cartoons`
      - [ ] `/data/series/tv`
  - [ ] `Download Clients`
    - [ ] `qBittorrent`
      - [ ] `Name` -> `qBittorrent`
      - [ ] `Host` -> `qbittorrent`
      - [ ] `Port` -> `8080`
      - [ ] `Username` -> `admin`
      - [ ] `Password` -> `adminadmin`
      - [ ] `Category` -> `tv-sonarr`
      - [ ] `Completed Download Handling`
        - [ ] `Remove Completed` -> `Off`
  - [ ] `General`
    - [ ] `Security`
      - [ ] `Authentication` -> `Forms (Login Page)`
      - [ ] `Authentication Required` -> `Enabled`
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

- [ ] `Settings` -> `Show Advanced`
  - [ ] `Apps`
    - [ ] `Applications`
      - [ ] `Radarr`
        - [ ] `Name` -> `Radarr`
        - [ ] `Sync Level` -> `Full Sync`
        - [ ] `Prowlarr Server` -> `http://prowlarr:9696`
        - [ ] `Radarr Server` -> `http://radarr:7878`
        - [ ] [`API Key`](http://localhost:7878/settings/general)
      - [ ] `Sonarr`
        - [ ] `Name` -> `Sonarr`
        - [ ] `Sync Level` -> `Full Sync`
        - [ ] `Prowlarr Server` -> `http://prowlarr:9696`
        - [ ] `Sonarr Server` -> `http://sonarr:8989`
        - [ ] [`API Key`](http://localhost:8989/settings/general)
        - [ ] `Sync Anime Standard Format Search` -> `On`
    - [ ] `Sync Profiles`
      - [ ] `Standard`
        - [ ] `Enable RSS` -> `Off`
        - [ ] `Enable Automatic Search` -> `Off`
        - [ ] `Enable Interactive Search` -> `Off`
  - [ ] `Download Clients`
    - [ ] `qBittorrent`
      - [ ] `Name` -> `qBittorrent`
      - [ ] `Host` -> `qbittorrent`
      - [ ] `Port` -> `8080`
      - [ ] `Username` -> `admin`
      - [ ] `Password` -> `adminadmin`
      - [ ] `Category` -> `prowlarr`
  - [ ] `General`
    - [ ] `Security`
      - [ ] `Authentication` -> `Forms (Login Page)`
      - [ ] `Authentication Required` -> `Enabled`
      - [ ] `Username` -> `admin`
      - [ ] `Password` -> `adminadmin`
    - [ ] `Proxy`
      - [ ] `Use Proxy` -> `On`
      - [ ] `Proxy Type` -> `HTTP(S)`
      - [ ] `Hostname` -> `sing-box`
      - [ ] `Port` -> `2080`
      - [ ] `Bypass Proxy for Local Addresses` -> `On`
  - [ ] `UI`
    - [ ] `Dates`
      - [ ] `Short Date Format` -> `25 Mar 2014`
      - [ ] `Long Date Format` -> `Tuesday, 25 March, 2014`
      - [ ] `Time Format` -> `17:00/17:30`
      - [ ] `Show Relative Dates` -> `On`
    - [ ] `Language`
      - [ ] `UI Language` -> `Russian`

# <img src="https://raw.githubusercontent.com/jellyfin/jellyfin-ux/refs/heads/master/branding/SVG/icon-transparent.svg" width="32"/> [Jellyfin](http://localhost:8096/)

- [ ] `Administration` -> `Dashboard`
  - [ ] `Server`
    - [ ] `General`
      - [ ] `Settings`
        - [ ] `Server name` -> `DS723+`
        - [ ] `Preferred display language` -> `Russian`
    - [ ] `Users`
      - [ ] `Users` -> `Edit user`
        - [ ] `Allow ...` -> `On`
        - [ ] `Hide this user from login screens` -> `On`
    - [ ] `Libraries`
      - [ ] `Libraries` -> `Add Media Library`
        - [ ] `Anime`
          - [ ] `Content type` -> `Mixed Movies and Shows`
          - [ ] `Display name` -> `Anime`
          - [ ] `Folders`
            - [ ] `/data/movies/anime`
            - [ ] `/data/series/anime`
        - [ ] `Cartoons`
          - [ ] `Content type` -> `Mixed Movies and Shows`
          - [ ] `Display name` -> `Cartoons`
          - [ ] `Folders`
            - [ ] `/data/movies/cartoons`
            - [ ] `/data/series/cartoons`
        - [ ] `Movies`
          - [ ] `Content type` -> `Movies`
          - [ ] `Display name` -> `Movies`
          - [ ] `Folders`
            - [ ] `/data/movies/films`
        - [ ] `Shows`
          - [ ] `Content type` -> `Shows`
          - [ ] `Display name` -> `Shows`
          - [ ] `Folders`
            - [ ] `/data/series/tv`
      - [ ] `Metadata`
        - [ ] `Preferred Metadata Language`
          - [ ] `Language` -> `Russian`
          - [ ] `Country/Region` -> `United States`
  - [ ] `Plugins`
    - [ ] `Catalog`
      - [ ] `Metadata`
        - [ ] `TheTVDB` -> `Install`

# <img src="https://raw.githubusercontent.com/Fallenbagel/jellyseerr/refs/heads/develop/public/os_icon.svg" width="32"/> [Jellyseerr](http://localhost:5055/)

- [ ] `Settings`
  - [ ] `General`
    - [ ] `Enable Image Caching` -> `On`
    - [ ] `Display Language` -> `Russian`
    - [ ] `Streaming Region` -> `United States`
    - [ ] `Hide Available MediaExperimental` -> `On`
    - [ ] `Allow Partial Series Requests` -> `On`
    - [ ] `Allow Special Episodes Requests` -> `On`
    - [ ] `HTTP(S) Proxy` -> `On`
      - [ ] `Proxy Hostname` -> `sing-box`
      - [ ] `Proxy Port` -> `2080`
      - [ ] `Proxy Ignored Addresses` -> `jellyfin, radarr, sonarr`
      - [ ] `Bypass Proxy for Local Addresses` -> `On`
  - [ ] `Jellyfin`
    - [ ] `Jellyfin Libraries` -> `Sync Libraries`
      - [ ] `Anime` -> `On`
      - [ ] `Cartoons` -> `On`
      - [ ] `Movies` -> `On`
      - [ ] `Shows` -> `On`
    - [ ] `Jellyfin Settings`
      - [ ] `Hostname or IP Address` -> `jellyfin`
      - [ ] `Port` -> `8096`
      - [ ] [`API key`](http://localhost:8096/web/#/dashboard/keys)
  - [ ] `Services`
    - [ ] `Radarr Settings` -> `Add Radarr Server`
      - [ ] `Default Server` -> `On`
      - [ ] `Server Name` -> `Radarr`
      - [ ] `Hostname or IP Address` -> `radarr`
      - [ ] `Port` -> `7878`
      - [ ] [`API Key`](http://localhost:7878/settings/general)
      - [ ] `Quality Profile` -> `Any`
      - [ ] `Root Folder` -> `/data/movies/films`
      - [ ] `Minimum Availability` -> `Released`
      - [ ] `Enable Automatic Search` -> `On`
    - [ ] `Sonarr Settings` -> `Add Sonarr Server`
      - [ ] `Default Server` -> `On`
      - [ ] `Server Name` -> `Sonarr`
      - [ ] `Hostname or IP Address` -> `sonarr`
      - [ ] `Port` -> `8989`
      - [ ] [`API Key`](http://localhost:8989/settings/general)
      - [ ] `Series Type` -> `Standard`
      - [ ] `Quality Profile` -> `Any`
      - [ ] `Root Folder` -> `/data/series/tv`
      - [ ] `Anime Series Type` -> `Standard`
      - [ ] `Anime Quality Profile` -> `Any`
      - [ ] `Anime Root Folder` -> `/data/series/anime`
      - [ ] `Season Folders` -> `On`
      - [ ] `Enable Automatic Search` -> `On`
