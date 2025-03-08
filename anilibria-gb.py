import json
import requests
import re


GIST_URL='https://gist.githubusercontent.com/Victor-Y-Fadeev/6b804186461c3d4272c0eea53e9546f5/raw/anime.md'


def save_json(path: str, obj):
    with open(path, 'w', encoding='utf-8') as file:
        file.write(json.dumps(obj, indent=4))


def load_json(path: str):
    with open(path, 'r', encoding='utf-8') as file:
        return json.loads(file.read())


def anilibria_links_from_gist(url: str) -> list[str]:
    response = requests.get(url)
    gist = response.text
    links = re.findall(r'https://www.anilibria.tv/release/[^\s\(\)]*', gist)
    return list(links)


def anilibria_torrent_size(url: str) -> list[str]:
    response = requests.get(url, proxies={'http': 'http://localhost:2080', 'https': 'http://localhost:2080'})
    page = response.text
    sizes = re.findall(r'\s\d+\.?\d*\s\w[bB]\s', page)
    return list(sizes)


def main():
    # links = anilibria_links_from_gist(GIST_URL)
    # save_json('links.json', links)
    # links = load_json('links.json')

    # sizes = dict()
    # for i, link in enumerate(links, start=1):
    #     print(f'[{i}/{len(links)}]', link)
    #     sizes[link] = anilibria_torrent_size(link)

    # save_json('sizes.json', sizes)
    sizes = load_json('sizes.json')

    min_size = 0
    max_size = 0
    for link, value in sizes.items():
        size_bytes = list()
        for size in value:
            if size[-3] == 'G':
                size_bytes.append(int(float(size[1:-4]) * (1 << 30)))
            elif size[-3] == 'M':
                size_bytes.append(int(float(size[1:-4]) * (1 << 20)))

        if size_bytes:
            min_size += min(size_bytes)
            max_size += max(size_bytes)

    print('Min:', min_size >> 30, 'GB')
    print('Max:', max_size >> 30, 'GB')


if __name__ == '__main__':
    main()
