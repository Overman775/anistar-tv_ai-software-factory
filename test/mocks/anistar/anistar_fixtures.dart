const catalogHtml = '''
<div class="news"><div class="title_left"><a href="/9493-ad.html">Реклама</a></div></div>
<div class="news"><div class="title_left"><a href="/10938-test.html">Тестовое аниме</a></div>
<img itemprop="image" src="/uploads/posters/10938/original.jpg"></div>
<div class="pages"><span>1</span><a href="/anime/page/2/">2</a><a href="/anime/page/690/">690</a></div>
''';

const detailHtml = '''
<h1 itemprop="name">Тестовое аниме &amp; друзья</h1>
<p class="tags">Категория: Новинки(онгоинги)</p>
<div class="news_avatar"><img itemprop="image" src="/poster.jpg"></div>
<ul class="head"><li><b>Год выпуска: </b><a>2026</a></li>
<li><b>Жанр: </b><a>Приключения</a>, <a>Комедия</a></li>
<li><b>Озвучка: </b>AniStar</li><li><b>Серии: </b>14 эп., 25 мин.</li></ul>
<div class="descripts">Описание <b>аниме</b>.</div>
''';

const signed720 = 'https://sfv.an-media.org/key=a+b/c==,end=1893456000/referer=/media=hls5/video/hash/720.mp4';

const playerHtml =
    '''
var playlst = [
  {title:'Серия 2',image:'/preview.jpg',files:[{title:'360',file:'https://sf2.an-media.org/second/index.m3u8'}],files_mp4:[]},
  // Keys, comments and trailing commas are JavaScript data, not strict JSON.
  {title:'Серия 1',image:'/preview.jpg',extra:[[1,2]],files:[
    {title:'720',file:'$signed720'},
    {title:'360',file:'https://sf2.an-media.org/first/index.m3u8'},
  ],files_mp4:[],},
]; doNotExecuteThis();
''';
