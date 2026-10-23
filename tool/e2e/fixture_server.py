"""Loopback-only HTTPS AniStar/HLS fixture. No external network or dependencies."""
import argparse
import json
from http.cookies import SimpleCookie
from pathlib import Path
import re
import ssl
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit

from native_ime import NativeImeSnapshot, read_native_ime

ROOT = Path(__file__).resolve().parents[2]
CERT = ROOT / 'android/app/src/debug/res/raw/e2e_localhost.pem'
MEDIA = ROOT / 'tool/e2e/media'
GUEST = '<form method="post" action=""><input name="login_name"><input name="login_password" type="password"><input type="hidden" name="formtoken" value="fixture"></form>'
SETTINGS = '<script>var dle_skin="new36";</script>'
SEARCH_FORM = '<form method="post" action="/" accept-charset="windows-1251"><input type="hidden" name="do" value="search"><input type="hidden" name="subaction" value="search"><input name="story"></form>'
MEMBER = '<a href="javascript:void(0)">Профиль</a><a href="/index.php?action=logout">Выход</a>'


class FixtureServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, port=0, event_log=None, native_ime_reader=None):
        super().__init__(('127.0.0.1', port), Handler)
        self.origin = f'https://localhost:{self.server_port}'
        self.lock = threading.Lock()
        self.events = []
        self.event_log = event_log
        self.catalog_error = False
        self.video_mode = 'normal'
        self.player_pages = 0
        self.session_active = False
        self.favorites = set()
        self.favorite_writes = 0
        self.favorite_error = False
        self.watched = set()
        self.native_ime_reader = native_ime_reader
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(CERT, ROOT / 'tool/e2e/tls/localhost.key')
        self.socket = context.wrap_socket(self.socket, server_side=True)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def authenticated(self):
        return self.server.session_active and 'dle_password=fixture-session' in self.headers.get('Cookie', '')

    def favorite_control(self, anime_id):
        if not self.authenticated():
            return ''
        action = 'minus' if anime_id in self.server.favorites else 'plus'
        return f'<span id="fav-id-{anime_id}"><img onclick="doFavorites(\'{anime_id}\',\'{action}\');return false;"></span>'

    def card(self, anime_id):
        return f'<div class="news"><div class="title_left"><a href="/{anime_id}-test.html">Аниме {anime_id}</a></div>{self.favorite_control(anime_id)}</div>'

    def do_POST(self):
        length = int(self.headers.get('Content-Length', '0'))
        fields = parse_qs(self.rfile.read(length).decode('ascii'), encoding='cp1251')
        if fields.get('do') == ['search']:
            page = int(fields.get('search_start', ['1'])[0])
            body = (MEMBER if self.authenticated() else GUEST) + SEARCH_FORM.replace('<form ', '<form id="fullsearch" ', 1).replace('action="/"', 'action="/index.php?do=search"', 1)
            body = body.replace('<input name="story">', f'<input type="hidden" name="full_search" value="0"><input type="hidden" name="search_start" value="{page}"><input type="hidden" name="result_from" value="{(page - 1) * 12 + 1}"><input name="story" value="Наруто">')
            body += '<div id="dle-content">' + ''.join(self.card(anime_id).replace('class="news"', 'class="short news"') for anime_id in range(10938 + (page - 1) * 12, 10938 + page * 12)) + '</div>'
            if page == 1:
                body += '<div class="pagenav"><a href="#" onclick="list_submit(2); return false;">2</a></div>'
            self.reply(200, body.encode('cp1251'), 'text/html; charset=windows-1251')
            return
        valid = fields.get('login_name') == ['тест'] and fields.get('login_password') == ['пароль'] and fields.get('formtoken') == ['fixture']
        if valid:
            self.server.session_active = True
        body = MEMBER if valid else GUEST + 'Ошибка авторизации'
        self.reply(200, body.encode('cp1251'), 'text/html; charset=windows-1251', session_cookie=valid)

    def do_GET(self):
        parsed = urlsplit(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)
        if path == '/__test/reset':
            with self.server.lock:
                self.server.events.clear()
                self.server.catalog_error = query.get('catalog_error') == ['true']
                self.server.video_mode = query.get('video_mode', ['normal'])[0]
                self.server.player_pages = 0
                self.server.session_active = False
                self.server.favorites.clear()
                self.server.watched.clear()
                self.server.favorite_writes = 0
                self.server.favorite_error = query.get('favorite_error') == ['true']
            self.reply(200, b'{}', 'application/json', record=False)
        elif path == '/__test/expire':
            self.server.session_active = False
            self.reply(200, b'{}', 'application/json', record=False)
        elif path == '/__test/config':
            with self.server.lock:
                self.server.catalog_error = query.get('catalog_error') == ['true']
                self.server.video_mode = query.get('video_mode', ['normal'])[0]
                self.server.favorite_error = query.get('favorite_error') == ['true']
                if 'favorites' in query:
                    self.server.favorites = {int(item) for item in query['favorites'][0].split(',') if item.isdigit()}
            self.reply(200, b'{}', 'application/json', record=False)
        elif path == '/__test/state':
            with self.server.lock:
                state = {'events': list(self.server.events), 'player_pages': self.server.player_pages, 'favorites': sorted(self.server.favorites), 'favorite_writes': self.server.favorite_writes, 'watched': sorted(self.server.watched)}
            self.reply(200, json.dumps(state).encode(), 'application/json', record=False)
        elif path == '/__test/native-ime':
            try:
                snapshot = self.server.native_ime_reader() if self.server.native_ime_reader else NativeImeSnapshot.unavailable()
            except Exception:
                snapshot = NativeImeSnapshot.error()
            self.reply(200, json.dumps(snapshot.as_json()).encode(), 'application/json', record=False)
        elif path == '/engine/ajax/favorites.php':
            with self.server.lock:
                self.server.favorite_writes += 1
                valid = self.authenticated() and query.get('skin') == ['new36'] and query.get('action') in (['plus'], ['minus']) and query.get('fav_id', [''])[0].isdigit()
                if not valid or self.server.favorite_error:
                    body = 'error'
                else:
                    anime_id = int(query['fav_id'][0])
                    if query['action'] == ['plus']:
                        self.server.favorites.add(anime_id)
                    else:
                        self.server.favorites.discard(anime_id)
                    body = self.favorite_control(anime_id)
            self.reply(200, body.encode('cp1251'), 'text/html; charset=windows-1251')
        elif path == '/engine/ajax/ns.php':
            valid = self.authenticated() and query.get('vid', [''])[0] in ('fixture-1', 'fixture-2')
            if valid:
                self.server.watched.add(int(query['vid'][0].split('-')[1]))
            self.reply(200, b'OK' if valid else b'NO', 'text/html; charset=windows-1251')
        elif path == '/index.php' and query.get('do') == ['favorites']:
            body = (MEMBER if self.authenticated() else GUEST) + SETTINGS
            body += f'<title>Мои закладки &raquo; AniStar</title><link rel="canonical" href="{self.server.origin}/index.php?do=favorites&amp;cstart=1"><div id="dle-content">'
            if self.authenticated() and self.server.favorites:
                body += ''.join(self.card(anime_id) for anime_id in sorted(self.server.favorites))
            else:
                body += ''
            body += '</div>'
            self.reply(200, body.encode('cp1251'), 'text/html; charset=windows-1251')
        elif path == '/':
            body = (MEMBER if self.authenticated() else GUEST) + SEARCH_FORM
            self.reply(200, body.encode('cp1251'), 'text/html; charset=windows-1251')
        elif path in ('/anime/', '/anime/page/2/', '/anime/comedy/', '/anime/comedy/page/2/', '/new/', '/new/page/2/'):
            if self.server.catalog_error and self.authenticated():
                self.reply(403, b'Forbidden', 'text/plain')
            else:
                cards = (MEMBER if self.authenticated() else GUEST) + SETTINGS + '<div class="news"><a href="/9493-ad.html">Реклама</a></div>'
                cookies = SimpleCookie(self.headers.get('Cookie', ''))
                sort = cookies['dle_sort_cat'].value if 'dle_sort_cat' in cookies else 'date'
                direction = cookies['dle_direction_cat'].value if 'dle_direction_cat' in cookies else 'desc'
                opposite = 'desc' if direction == 'asc' else 'asc'
                cards += f'''<form id="news_set_sort"><a class="sort-actv" onclick="dle_change_sort('{sort}','{opposite}'); return false;">sort</a></form>'''
                ids = list(range(10938, 10962))
                if sort == 'title':
                    ids.sort(reverse=direction == 'desc')
                offset = 12 if path.endswith('/page/2/') else 0
                for anime_id in ids[offset:offset + 12]:
                    cards += self.card(anime_id)
                cards += '<div class="block-janrs"><a href="/anime/comedy/">Комедия</a><a href="/anime/drama/">Драма</a></div>'
                if not path.endswith('/page/2/'):
                    cards += f'<div class="pages"><a href="{path}page/2/">2</a></div>'
                self.reply(200, cards.encode('cp1251'), 'text/html; charset=windows-1251')
        elif re.fullmatch(r'/\d+-test.html', path):
            body = (MEMBER if self.authenticated() else GUEST) + '<h1 itemprop="name">Тестовое аниме</h1><p class="tags"><a href="/new/">Онгоинги</a><a href="/anime/comedy/">Комедия</a></p><ul class="head"><li>Год выпуска: 2026</li><li>Жанр: Комедия</li><li>Серии: 2 эп.</li></ul><div class="descripts">Локальный E2E fixture.</div>'
            body += SETTINGS + self.favorite_control(int(path.split('-')[0][1:]))
            self.reply(200, body.encode('cp1251'), 'text/html; charset=windows-1251')
        elif path == '/test/player2/videoas_p2p_new.php':
            with self.server.lock:
                self.server.player_pages += 1
                # Details fetch page 1; first playback fetch is page 2.
                stale = self.server.video_mode == 'refresh_once'
                epoch = 'expired' if stale or self.server.video_mode == 'always_expired' else 'fresh'
            episodes = []
            for episode in (2, 1):
                files = ','.join(f"{{title:'{quality}',file:'{self.server.origin}/hls/{epoch}/{episode}/{quality}.mp4'}}" for quality in (720, 360))
                watched = self.authenticated() and episode in self.server.watched
                episodes.append(f"{{title:'Серия {episode}',media_id:'fixture-{episode}',viewing:{str(watched).lower()},files:[{files}],files_mp4:[],}}")
            body = 'var playlst = [' + ','.join(episodes) + '];'
            self.reply(200, body.encode(), 'text/html; charset=utf-8')
        elif path.startswith('/hls/'):
            self.media(path)
        else:
            self.reply(404, b'Not found', 'text/plain')

    def media(self, path):
        referer = self.headers.get('Referer')
        expected = f'{self.server.origin}/test/player2/videoas_p2p_new.php?id=10938'
        if referer != expected or '/expired/' in path:
            if '/expired/' in path and self.server.video_mode == 'refresh_once':
                self.server.video_mode = 'normal'
            self.reply(403, b'Forbidden', 'text/plain')
            return
        match = re.fullmatch(r'/hls/fresh/([12])/(360|720)\.mp4(?:/(variant\.m3u8|segment-\d+\.ts))?', path)
        if not match:
            self.reply(404, b'Not found', 'text/plain')
            return
        episode, quality, suffix = match.groups()
        if suffix is None:
            manifest = '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=500000\n' + f'{quality}.mp4/variant.m3u8\n'
            self.reply(200, manifest.encode(), 'application/vnd.apple.mpegurl')
        elif suffix == 'variant.m3u8':
            manifest = (MEDIA / quality / 'index.m3u8').read_text()
            # Exercise both relative and absolute segment references.
            manifest = manifest.replace('segment-01.ts', f'{self.server.origin}/hls/fresh/{episode}/{quality}.mp4/segment-01.ts')
            self.reply(200, manifest.encode(), 'application/vnd.apple.mpegurl')
        else:
            file = MEDIA / quality / suffix
            if not file.is_file():
                self.reply(404, b'Not found', 'text/plain')
                return
            body = file.read_bytes()
            range_header = self.headers.get('Range')
            if range_header:
                match = re.fullmatch(r'bytes=(\d+)-(\d*)', range_header)
                if not match:
                    self.reply(416, b'', 'video/mp2t')
                    return
                start = int(match[1])
                end = min(int(match[2]) if match[2] else len(body) - 1, len(body) - 1)
                if start > end:
                    self.reply(416, b'', 'video/mp2t')
                    return
                self.reply(206, body[start:end + 1], 'video/mp2t', content_range=f'bytes {start}-{end}/{len(body)}')
            else:
                self.reply(200, body, 'video/mp2t')

    def reply(self, status, body, content_type, *, record=True, content_range=None, session_cookie=False):
        if record:
            with self.server.lock:
                event = {'path': self.path, 'status': status, 'referer': self.headers.get('Referer'), 'method': self.command, 'authenticated': self.authenticated(), 'sort': {key: value.value for key, value in SimpleCookie(self.headers.get('Cookie', '')).items() if key.startswith(('dle_sort_', 'dle_direction_'))}}
                self.server.events.append(event)
                if self.server.event_log:
                    with self.server.event_log.open('a') as stream:
                        stream.write(json.dumps(event) + '\n')
        self.send_response(status)
        if session_cookie:
            self.send_header('Set-Cookie', 'dle_password=fixture-session; Secure; HttpOnly; Path=/')
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Accept-Ranges', 'bytes')
        if content_range:
            self.send_header('Content-Range', content_range)
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError, ssl.SSLError):
            pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=0)
    parser.add_argument('--ready-file', type=Path, required=True)
    parser.add_argument('--event-log', type=Path)
    parser.add_argument('--native-ime-adb')
    parser.add_argument('--native-ime-device')
    parser.add_argument('--native-ime-package')
    args = parser.parse_args()
    configured = (args.native_ime_adb, args.native_ime_device, args.native_ime_package)
    native_ime_reader = None
    if all(configured):
        native_ime_reader = lambda: read_native_ime(*configured)
    with FixtureServer(args.port, args.event_log, native_ime_reader) as server:
        args.ready_file.write_text(str(server.server_port))
        server.serve_forever()


if __name__ == '__main__':
    main()
