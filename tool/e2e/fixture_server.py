"""Loopback-only HTTPS AniStar/HLS fixture. No external network or dependencies."""
import argparse
import json
from pathlib import Path
import re
import ssl
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit

ROOT = Path(__file__).resolve().parents[2]
CERT = ROOT / 'android/app/src/debug/res/raw/e2e_localhost.pem'
MEDIA = ROOT / 'tool/e2e/media'
GUEST = '<form method="post" action=""><input name="login_name"><input name="login_password" type="password"><input type="hidden" name="formtoken" value="fixture"></form>'
SETTINGS = '<script>var dle_skin="new36";</script>'
MEMBER = '<a href="/index.php?action=logout">Выход</a>'


class FixtureServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, port=0, event_log=None):
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
                state = {'events': list(self.server.events), 'player_pages': self.server.player_pages, 'favorites': sorted(self.server.favorites), 'favorite_writes': self.server.favorite_writes}
            self.reply(200, json.dumps(state).encode(), 'application/json', record=False)
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
        elif path == '/index.php' and query.get('do') == ['favorites']:
            body = (MEMBER if self.authenticated() else GUEST) + SETTINGS
            if self.authenticated() and self.server.favorites:
                body += ''.join(self.card(anime_id) for anime_id in sorted(self.server.favorites))
            else:
                body += '<div id="dle-content">Вы еще ничего не добавляли в свои закладки.</div>'
            self.reply(200, body.encode('cp1251'), 'text/html; charset=windows-1251')
        elif path in ('/anime/', '/anime/page/2/'):
            if self.server.catalog_error and self.authenticated():
                self.reply(403, b'Forbidden', 'text/plain')
            else:
                start = 10938 if path == '/anime/' else 10950
                cards = (MEMBER if self.authenticated() else GUEST) + SETTINGS + '<div class="news"><a href="/9493-ad.html">Реклама</a></div>'
                for anime_id in range(start, start + 12):
                    cards += self.card(anime_id)
                if path == '/anime/':
                    cards += '<a href="/anime/page/2/">2</a>'
                self.reply(200, cards.encode('cp1251'), 'text/html; charset=windows-1251')
        elif re.fullmatch(r'/\d+-test.html', path):
            body = (MEMBER if self.authenticated() else GUEST) + '<h1 itemprop="name">Тестовое аниме</h1><ul class="head"><li>Год выпуска: 2026</li><li>Жанр: Комедия</li><li>Серии: 2 эп.</li></ul><div class="descripts">Локальный E2E fixture.</div>'
            body += SETTINGS + self.favorite_control(int(path.split('-')[0][1:]))
            self.reply(200, body.encode('cp1251'), 'text/html; charset=windows-1251')
        elif path == '/test/player2/videoas_p2p_new.php':
            with self.server.lock:
                self.server.player_pages += 1
                # Details fetch page 1; first playback fetch is page 2.
                stale = self.server.video_mode == 'refresh_once' and self.server.player_pages == 2
                epoch = 'expired' if stale or self.server.video_mode == 'always_expired' else 'fresh'
            episodes = []
            for episode in (2, 1):
                files = ','.join(f"{{title:'{quality}',file:'{self.server.origin}/hls/{epoch}/{episode}/{quality}.mp4'}}" for quality in (720, 360))
                episodes.append(f"{{title:'Серия {episode}',files:[{files}],files_mp4:[],}}")
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
                event = {'path': self.path, 'status': status, 'referer': self.headers.get('Referer'), 'method': self.command, 'authenticated': self.authenticated()}
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
    args = parser.parse_args()
    with FixtureServer(args.port, args.event_log) as server:
        args.ready_file.write_text(str(server.server_port))
        server.serve_forever()


if __name__ == '__main__':
    main()
