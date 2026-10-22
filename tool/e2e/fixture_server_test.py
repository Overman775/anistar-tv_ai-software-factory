import json
import ssl
import threading
import unittest
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from fixture_server import CERT, FixtureServer


class FixtureServerTest(unittest.TestCase):
    def setUp(self):
        self.server = FixtureServer()
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.context = ssl.create_default_context(cafile=str(CERT))
        self.addCleanup(self.stop)

    def stop(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)

    def get(self, path, headers=None):
        request = Request(self.server.origin + path, headers=headers or {})
        return urlopen(request, context=self.context, timeout=3)

    def headers(self):
        return {'Referer': self.server.origin + '/test/player2/videoas_p2p_new.php?id=10938'}

    def test_desktop_charset_and_pagination(self):
        with self.get('/anime/') as response:
            self.assertEqual(response.headers.get_content_charset(), 'windows-1251')
            html = response.read().decode('cp1251')
            self.assertIn('Аниме 10938', html)
            self.assertIn('/anime/page/2/', html)
            self.assertIn('/9493-ad.html', html)
        with self.get('/anime/page/2/') as response:
            self.assertNotIn('/anime/page/2/', response.read().decode('cp1251'))

    def test_public_search_uses_home_post_then_confirmed_continuation(self):
        with self.get('/') as response:
            self.assertEqual(response.headers.get_content_charset(), 'windows-1251')
            self.assertTrue('action="/"' in response.read().decode('cp1251'))
        fields = {'do': 'search', 'subaction': 'search', 'story': 'Наруто'}
        for page, path in ((1, '/'), (2, '/index.php?do=search')):
            if page == 2:
                fields.update(full_search='0', search_start='2', result_from='13')
            request = Request(self.server.origin + path,
                              data=urlencode(fields, encoding='cp1251').encode('ascii'),
                              headers={'Content-Type': 'application/x-www-form-urlencoded; charset=windows-1251'})
            with urlopen(request, context=self.context, timeout=3) as response:
                html = response.read().decode('cp1251')
                self.assertTrue('id="fullsearch"' in html)
                self.assertTrue('action="/index.php?do=search"' in html)
                self.assertTrue('name="full_search" value="0"' in html)
                self.assertTrue('name="story" value="Наруто"' in html)
                self.assertTrue(f'name="search_start" value="{page}"' in html)
                self.assertTrue(f'Аниме {10938 + (page - 1) * 12}' in html)
                self.assertEqual('list_submit(2)' in html, page == 1)
        self.assertEqual(self.server.favorite_writes, 0)
        self.assertEqual(self.server.watched, set())

    def test_favorites_are_authenticated_site_state(self):
        root = '/engine/ajax/favorites.php?fav_id=10938&skin=new36&alert=0&action='
        with self.get(root + 'plus') as response:
            self.assertEqual(response.read(), b'error')
        self.server.session_active = True
        headers = {'Cookie': 'dle_password=fixture-session'}
        with self.get(root + 'plus', headers) as response:
            self.assertIn("'minus'", response.read().decode('cp1251'))
        with self.get('/index.php?do=favorites&cstart=1', headers) as response:
            self.assertIn('Аниме 10938', response.read().decode('cp1251'))
        with self.get('/10938-test.html', headers) as response:
            self.assertIn("'minus'", response.read().decode('cp1251'))
        self.get(root + 'minus', headers).close()
        with self.get('/index.php?do=favorites&cstart=1', headers) as response:
            self.assertIn('<div id="dle-content"></div>', response.read().decode('cp1251'))
        self.assertEqual(self.server.favorites, set())

    def test_hls_chain_requires_referer_and_supports_range(self):
        root = '/hls/fresh/1/720.mp4'
        for path in (root, root + '/variant.m3u8', root + '/segment-00.ts'):
            with self.assertRaises(HTTPError) as error:
                self.get(path)
            self.assertEqual(error.exception.code, 403)
            error.exception.close()
        with self.get(root, self.headers()) as response:
            self.assertEqual(response.headers['Content-Type'], 'application/vnd.apple.mpegurl')
            self.assertTrue(response.read().startswith(b'#EXTM3U'))
        with self.get(root + '/variant.m3u8', self.headers()) as response:
            manifest = response.read().decode()
            self.assertIn(self.server.origin + root + '/segment-01.ts', manifest)
            self.assertIn('\nsegment-00.ts\n', manifest)
        for quality in ('360', '720'):
            headers = {**self.headers(), 'Range': 'bytes=0-4095'}
            with self.get(f'/hls/fresh/1/{quality}.mp4/segment-00.ts', headers) as response:
                self.assertEqual(response.status, 206)
                data = response.read()
                self.assertEqual(len(data), 4096)
                self.assertEqual(data[0], 0x47)
                self.assertEqual(data[188], 0x47)

    def test_refresh_once_rotates_playlist_url(self):
        self.get('/__test/reset?video_mode=refresh_once').close()
        bodies = []
        for _ in range(3):
            with self.get('/test/player2/videoas_p2p_new.php?id=10938') as response:
                bodies.append(response.read().decode())
        self.assertTrue(all('/expired/' in body for body in bodies))
        with self.assertRaises(HTTPError) as error:
            self.get('/hls/expired/1/720.mp4', self.headers())
        self.assertEqual(error.exception.code, 403)
        error.exception.close()
        with self.get('/test/player2/videoas_p2p_new.php?id=10938') as response:
            self.assertIn('/fresh/', response.read().decode())

    def test_watched_marks_require_login_and_return_in_new_player_html(self):
        path = '/test/player2/videoas_p2p_new.php?id=10938'
        self.get('/engine/ajax/ns.php?vid=fixture-1').close()
        self.assertEqual(self.server.watched, set())
        self.server.session_active = True
        headers = {'Cookie': 'dle_password=fixture-session'}
        self.get('/engine/ajax/ns.php?vid=fixture-2', headers).close()
        with self.get(path, headers) as response:
            self.assertIn("media_id:'fixture-2',viewing:true", response.read().decode())
        with self.get(path) as response:
            self.assertNotIn('viewing:true', response.read().decode())

    def test_recovery_does_not_reset_attempt_history(self):
        self.get('/__test/reset?video_mode=always_expired').close()
        self.get('/test/player2/videoas_p2p_new.php?id=10938').close()
        self.get('/__test/config').close()
        self.get('/test/player2/videoas_p2p_new.php?id=10938').close()
        with self.get('/__test/state') as response:
            state = json.load(response)
        self.assertEqual(state['player_pages'], 2)
        self.assertEqual(len(state['events']), 2)

    def test_bad_range_and_unknown_file_are_errors(self):
        with self.assertRaises(HTTPError) as error:
            self.get('/hls/fresh/1/360.mp4/segment-00.ts', {**self.headers(), 'Range': 'bytes=9999999-'})
        self.assertEqual(error.exception.code, 416)
        error.exception.close()
        with self.assertRaises(HTTPError) as error:
            self.get('/hls/fresh/1/360.mp4/segment-99.ts', self.headers())
        self.assertEqual(error.exception.code, 404)
        error.exception.close()


if __name__ == '__main__':
    unittest.main()
