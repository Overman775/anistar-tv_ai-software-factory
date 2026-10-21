(() => {
'use strict';
// ИЗВЕСТНЫЙ БАГ / TODO для будущей разработки: выбор серии в кнопке «Смотреть».
// Если 1-я пропущена, а 2-я и 3-я просмотрены, нужно предложить 4-ю, а не 1-ю.
// Сейчас detail() ищет первый пробел с начала списка. Нужно продолжать после
// максимального номера просмотренной серии данного тайтла, учитывая доступность.
// Подробности и граничные случаи — рядом с const n в detail(). Баг пока не исправлен.
// Это заметка только в исходном коде: НЕ выводить её в пользовательский интерфейс.

const $=s=>document.querySelector(s);
const data=[
{id:'frieren',title:'Провожающая в последний путь Фрирен',year:2023,episodes:28,genre:['Фэнтези','Приключения','Драма'],h:318,desc:'После победы над королём демонов эльфийская волшебница Фрирен отправляется в новое путешествие. Для неё прошли лишь мгновения, а для её спутников — целая жизнь. Теперь ей предстоит понять людей и ценность времени рядом с ними.'},
{id:'jujutsu',title:'Магическая битва',year:2020,episodes:24,genre:['Экшен','Сверхъестественное'],h:318,desc:'Юдзи Итадори оказывается в мире проклятий и становится учеником Токийского магического колледжа. Вместе с новыми друзьями он учится защищать людей от невидимых угроз.'},
{id:'demon',title:'Клинок, рассекающий демонов',year:2019,episodes:26,genre:['Экшен','Фэнтези'],h:314,desc:'Тандзиро отправляется на поиски способа вернуть своей сестре Нэдзуко человеческий облик. Его путь лежит через мир охотников на демонов.'},
{id:'chainsaw',title:'Человек-бензопила',year:2022,episodes:12,genre:['Экшен','Сверхъестественное'],h:319,desc:'Дэндзи мечтает о простой жизни, но договор с демоном-бензопилой Почитой меняет его судьбу. Теперь он работает в особом подразделении охотников на демонов.'},
{id:'attack',title:'Атака титанов',year:2013,episodes:25,genre:['Экшен','Драма'],h:350,desc:'Остатки человечества укрываются за огромными стенами. Когда привычная жизнь рушится, Эрен Йегер и его друзья решают узнать, что скрывается за ними.'},
{id:'spy',title:'Семья шпиона',year:2022,episodes:12,genre:['Комедия','Экшен'],h:320,desc:'Для секретной миссии шпиону Лойду Форджеру нужна семья. Он ещё не знает, что его новая дочь читает мысли, а жена скрывает собственную тайну.'}
];
// Локальная карточка связанного сезона: доступна через порядок просмотра,
// не добавляется в главную выдачу. Данные и постер взяты со страницы /10686-.html.
const relatedTitles=[{id:'frieren2',sourceId:'10686',title:'Провожающая в последний путь Фрирен 2 сезон',year:2026,episodes:10,genre:['Приключения','Сёнен','Фэнтези','Драма'],w:400,h:572,desc:'Продолжение путешествия Фрирен и её спутников.',rating:8.9,director:'Китагава Томоя',voiceover:'Русская озвучка',seriesInfo:'(10 эп.), 25 мин.'}];
// UI Kit / AppIcon — единый компонент функциональных иконок ВСЕГО приложения.
// ОБЯЗАТЕЛЬНО ДЛЯ БУДУЩИХ ИИ: абсолютно ВСЕ иконки, которые рисует приложение,
// должны быть из Lucide и создаваться общим AppIcon (в прототипе — icon()).
// Это включает выход из аккаунта/приложения, закрытие, назад, подтверждение/отказ,
// системные действия, настройки, поиск, фильтры, навигацию, избранное, плеер,
// уведомления, загрузку, ошибки и пустые состояния — без исключений по типу экрана.
// Не использовать Material Icons, Cupertino Icons, emoji, символы текста вместо иконок
// или самодельные SVG. Для нового действия подобрать оригинальную иконку Lucide,
// добавить её в общую таблицу и указать соответствие LucideIcons.* для Flutter.
// Требование относится к UI приложения; нативные значки ОС приложение не подменяет.

// ОКОНЧАТЕЛЬНЫЙ ВЫБОР: Lucide https://lucide.dev/icons/ для всего приложения.
// Для будущих ИИ: это утверждённый единый набор, не временный вариант для сравнения.
// При разработке мигрировать ВСЕ функциональные иконки на lucide_icons_flutter,
// включая ТВ, будущую мобильную версию, плеер, диалоги и состояния ошибок.
// Переиспользовать AppIcon и соответствия ниже, не подключать другие семейства.
// В HTML используются SVG Lucide, во Flutter — иконочный шрифт указанного пакета.
// Прототип: оригинальные SVG lucide-static 1.60.0 (ISC), локально assets/lucide/.
// Геометрия включена в таблицу ниже: нет CDN, загрузки шрифта или runtime fetch.
// Для будущих ИИ: мигрировать все экраны ТВ и телефона на lucide_icons_flutter:
// https://pub.dev/packages/lucide_icons_flutter (4.0.1, набор Lucide 1.60.0).
// В pubspec.yaml подключить пакет; import 'package:lucide_icons_flutter/lucide_icons.dart';
// Использовать Icon(LucideIcons.house), Icon(LucideIcons.heart) и т.д.
// Поле flutter в таблице — проверенное имя LucideIcons.*, name — имя SVG на lucide.dev.
// Не возвращать другие иконпаки/Material/Cupertino и не рисовать похожие SVG вручную.
// Переиспользовать AppIcon во всём UI: меню, фильтры, карточки, окна, плеер, ошибки.
// В web толщина --app-icon-stroke:2 для viewBox 24×24, цвет currentColor,
// размер --od-icon-size. Во Flutter использовать общий AppIcon с согласованным весом.
// SVG декоративный (aria-hidden); доступное имя сохранять на кнопке с действием.
// Логотип AniStar — изображение бренда, не функциональная иконка.
// Flutter-проект здесь не меняется: это требования миграции и соответствия компонентов.
// Семантика избранного: heartPlus — добавить, heartMinus — удалить,
// heart — раздел/сохранённый статус, heartOff — пустое избранное.
// Не использовать heartCrack (разбитое сердце) для обычного удаления из коллекции.
// Фильтры года/жанра/режиссёра используют общую Lucide list-filter (Flutter: listFilter).
const lucideIcons={
  "rotateScreen": {
    "name":"rotate-cw-square",
    "flutter":"rotateCwSquare",
    "svg":'<path d="M12 5H6a2 2 0 0 0-2 2v3" /><path d="m9 8 3-3-3-3" /><path d="M4 14v4a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2" />'
  },
  "filter": {
    "name": "list-filter",
    "flutter": "listFilter",
    "svg": "<path d=\"M2 5h20\" />\n  <path d=\"M6 12h12\" />\n  <path d=\"M9 19h6\" />"
  },
  "star": {
    "name": "star",
    "flutter": "star",
    "svg": "<path d=\"M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z\" />"
  },
  "home": {
    "name": "house",
    "flutter": "house",
    "svg": "<path d=\"M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8\" />\n  <path d=\"M3 10a2 2 0 0 1 .709-1.528l7-6a2 2 0 0 1 2.582 0l7 6A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z\" />"
  },
  "heart": {
    "name": "heart",
    "flutter": "heart",
    "svg": "<path d=\"M2 9.5a5.5 5.5 0 0 1 9.591-3.676.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5c0 2.29-1.5 4-3 5.5l-5.492 5.313a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5\" />"
  },
  "grid": {
    "name": "layout-grid",
    "flutter": "layoutGrid",
    "svg": "<rect width=\"7\" height=\"7\" x=\"3\" y=\"3\" rx=\"1\" />\n  <rect width=\"7\" height=\"7\" x=\"14\" y=\"3\" rx=\"1\" />\n  <rect width=\"7\" height=\"7\" x=\"14\" y=\"14\" rx=\"1\" />\n  <rect width=\"7\" height=\"7\" x=\"3\" y=\"14\" rx=\"1\" />"
  },
  "back": {
    "name": "arrow-left",
    "flutter": "arrowLeft",
    "svg": "<path d=\"m12 19-7-7 7-7\" />\n  <path d=\"M19 12H5\" />"
  },
  "arrow": {
    "name": "chevron-right",
    "flutter": "chevronRight",
    "svg": "<path d=\"m9 18 6-6-6-6\" />"
  },
  "play": {
    "name": "play",
    "flutter": "play",
    "svg": "<path d=\"M5 5a2 2 0 0 1 3.008-1.728l11.997 6.998a2 2 0 0 1 .003 3.458l-12 7A2 2 0 0 1 5 19z\" />"
  },
  "pause": {
    "name": "pause",
    "flutter": "pause",
    "svg": "<rect x=\"14\" y=\"3\" width=\"5\" height=\"18\" rx=\"1\" />\n  <rect x=\"5\" y=\"3\" width=\"5\" height=\"18\" rx=\"1\" />"
  },
  "search": {
    "name": "search",
    "flutter": "search",
    "svg": "<path d=\"m21 21-4.34-4.34\" />\n  <circle cx=\"11\" cy=\"11\" r=\"8\" />"
  },
  "close": {
    "name": "x",
    "flutter": "x",
    "svg": "<path d=\"M18 6 6 18\" />\n  <path d=\"m6 6 12 12\" />"
  },
  "check": {
    "name": "check",
    "flutter": "check",
    "svg": "<path d=\"M20 6 9 17l-5-5\" />"
  },
  "refresh": {
    "name": "refresh-cw",
    "flutter": "refreshCw",
    "svg": "<path d=\"M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8\" />\n  <path d=\"M21 3v5h-5\" />\n  <path d=\"M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16\" />\n  <path d=\"M8 16H3v5\" />"
  },
  "rotate": {
    "name": "smartphone",
    "flutter": "smartphone",
    "svg": "<rect width=\"14\" height=\"20\" x=\"5\" y=\"2\" rx=\"2\" ry=\"2\" />\n  <path d=\"M12 18h.01\" />"
  },
  "rewind": {
    "name": "rewind",
    "flutter": "rewind",
    "svg": "<path d=\"M12 6a2 2 0 0 0-3.414-1.414l-6 6a2 2 0 0 0 0 2.828l6 6A2 2 0 0 0 12 18z\" />\n  <path d=\"M22 6a2 2 0 0 0-3.414-1.414l-6 6a2 2 0 0 0 0 2.828l6 6A2 2 0 0 0 22 18z\" />"
  },
  "forward": {
    "name": "fast-forward",
    "flutter": "fastForward",
    "svg": "<path d=\"M12 6a2 2 0 0 1 3.414-1.414l6 6a2 2 0 0 1 0 2.828l-6 6A2 2 0 0 1 12 18z\" />\n  <path d=\"M2 6a2 2 0 0 1 3.414-1.414l6 6a2 2 0 0 1 0 2.828l-6 6A2 2 0 0 1 2 18z\" />"
  },
  "list": {
    "name": "list",
    "flutter": "list",
    "svg": "<path d=\"M3 5h.01\" />\n  <path d=\"M3 12h.01\" />\n  <path d=\"M3 19h.01\" />\n  <path d=\"M8 5h13\" />\n  <path d=\"M8 12h13\" />\n  <path d=\"M8 19h13\" />"
  },
  "logout": {
    "name": "log-out",
    "flutter": "logOut",
    "svg": "<path d=\"m16 17 5-5-5-5\" />\n  <path d=\"M21 12H9\" />\n  <path d=\"M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4\" />"
  },
  "user": {
    "name": "user",
    "flutter": "user",
    "svg": "<path d=\"M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2\" />\n  <circle cx=\"12\" cy=\"7\" r=\"4\" />"
  },
  "info": {
    "name": "info",
    "flutter": "info",
    "svg": "<circle cx=\"12\" cy=\"12\" r=\"10\" />\n  <path d=\"M12 16v-4\" />\n  <path d=\"M12 8h.01\" />"
  },
  "heartPlus": {
    "name": "heart-plus",
    "flutter": "heartPlus",
    "svg": "<path d=\"m14.479 19.374-.971.939a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5a5.5 5.5 0 0 1 9.591-3.676.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5a5.2 5.2 0 0 1-.219 1.49\" />\n  <path d=\"M15 15h6\" />\n  <path d=\"M18 12v6\" />"
  },
  "heartMinus": {
    "name": "heart-minus",
    "flutter": "heartMinus",
    "svg": "<path d=\"m14.876 18.99-1.368 1.323a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5a5.5 5.5 0 0 1 9.591-3.676.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5a5.2 5.2 0 0 1-.244 1.572\" />\n  <path d=\"M15 15h6\" />"
  },
  "heartOff": {
    "name": "heart-off",
    "flutter": "heartOff",
    "svg": "<path d=\"M10.5 4.893a5.5 5.5 0 0 1 1.091.931.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5c0 1.872-1.002 3.356-2.187 4.655\" />\n  <path d=\"m16.967 16.967-3.459 3.346a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5a5.5 5.5 0 0 1 2.747-4.761\" />\n  <path d=\"m2 2 20 20\" />"
  },
  "previous": {
    "name": "skip-back",
    "flutter": "skipBack",
    "svg": "<path d=\"M17.971 4.285A2 2 0 0 1 21 6v12a2 2 0 0 1-3.029 1.715l-9.997-5.998a2 2 0 0 1-.003-3.432z\" />\n  <path d=\"M3 20V4\" />"
  },
  "next": {
    "name": "skip-forward",
    "flutter": "skipForward",
    "svg": "<path d=\"M21 4v16\" />\n  <path d=\"M6.029 4.285A2 2 0 0 0 3 6v12a2 2 0 0 0 3.029 1.715l9.997-5.998a2 2 0 0 0 .003-3.432z\" />"
  },
  "seekBack": {
    "name": "rotate-ccw",
    "flutter": "rotateCcw",
    "svg": "<path d=\"M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8\" />\n  <path d=\"M3 3v5h5\" />"
  },
  "seekForward": {
    "name": "rotate-cw",
    "flutter": "rotateCw",
    "svg": "<path d=\"M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8\" />\n  <path d=\"M21 3v5h-5\" />"
  },
  "episodeList": {
    "name": "list-video",
    "flutter": "listVideo",
    "svg": "<path d=\"M21 5H3\" />\n  <path d=\"M10 12H3\" />\n  <path d=\"M10 19H3\" />\n  <path d=\"M15 12.003a1 1 0 0 1 1.517-.859l4.997 2.997a1 1 0 0 1 0 1.718l-4.997 2.997a1 1 0 0 1-1.517-.86z\" />"
  },
  "eye": {
    "name": "eye",
    "flutter": "eye",
    "svg": "<path d=\"M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0\" />\n  <circle cx=\"12\" cy=\"12\" r=\"3\" />"
  },
  "eyeOff": {
    "name": "eye-off",
    "flutter": "eyeOff",
    "svg": "<path d=\"M10.733 5.076a10.744 10.744 0 0 1 11.205 6.575 1 1 0 0 1 0 .696 10.747 10.747 0 0 1-1.444 2.49\" />\n  <path d=\"M14.084 14.158a3 3 0 0 1-4.242-4.242\" />\n  <path d=\"M17.479 17.499a10.75 10.75 0 0 1-15.417-5.151 1 1 0 0 1 0-.696 10.75 10.75 0 0 1 4.446-5.143\" />\n  <path d=\"m2 2 20 20\" />"
  },
  "loading": {
    "name": "loader-circle",
    "flutter": "loaderCircle",
    "svg": "<path d=\"M21 12a9 9 0 1 1-6.219-8.56\" />"
  },
  "alert": {
    "name": "circle-alert",
    "flutter": "circleAlert",
    "svg": "<circle cx=\"12\" cy=\"12\" r=\"10\" />\n  <line x1=\"12\" x2=\"12\" y1=\"8\" y2=\"12\" />\n  <line x1=\"12\" x2=\"12.01\" y1=\"16\" y2=\"16\" />"
  }
};
const icon=n=>{
  const entry=lucideIcons[n]||lucideIcons.info;
  return `<svg class="od-icon lucide-icon" data-lucide="${entry.name}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">${entry.svg}</svg>`;
};
const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const read=(k,d)=>{try{return JSON.parse(localStorage.getItem(k))??d}catch{return d}};
let fav=new Set(read('anistar-tv-favorites',['frieren','spy'])),watched=new Set(read('anistar-tv-watched',[]));
function save(){try{localStorage.setItem('anistar-tv-favorites',JSON.stringify([...fav]));localStorage.setItem('anistar-tv-watched',JSON.stringify([...watched]))}catch{}}
let route={name:'home'},history=[],sort='default',playing=false,position=0,quality='480p',timer,toastTimer,lastContent='card-frieren',returnFromSheet=null,held=null;
const app=$('#app');
// UI Kit / AppMotion — общий слой анимации прототипа, переиспользовать на новых экранах.
// Источник кривых: Flutter Curves.easeOutCubic (вход) и Curves.easeInCubic (выход),
// переведённые в CSS cubic-bezier. Длительности — настройки этого прототипа, не Flutter defaults.
// Подход выбран по запросу пользователя с опорой на Impeccable: движение объясняет
// фокус и открытие/закрытие панели; без линейного движения и декоративных пружин.
// Источник значений — --motion-* в app.css; JS читает их, а CSS использует напрямую.
// Это общие правила для будущего переноса во Flutter, не импорт из Flutter-кода.
// MediaCard использует их на главной, в избранном, выдаче жанра и самих карточках жанров.
// Левое меню и правая панель используют одинаковые menuEnter/menuExit и enter/exit.
// Для новых JS-переходов вызывайте animateUI(), не создавайте локальные easing/duration.
// prefers-reduced-motion обязателен: animateUI() пропускает движение, CSS отключает transitions.
const reducedMotion=window.matchMedia('(prefers-reduced-motion: reduce)');
// AdaptiveLayout / UI Kit: это breakpoint HTML-прототипа, НЕ определение платформы Flutter.
// До 1024 CSS перестраивает тот же UI для касаний; >=1024 исходный ТВ-layout неизменен.
// В нативном приложении различать TV/handheld через возможности платформы + constraints,
// не превращать малое разрешение телевизора в телефон. Данные и действия общие.
const compactLayout=window.matchMedia('(max-width: 1023px)');
const phoneLayout=window.matchMedia('(max-width: 767px)');
const isCompactUI=()=>compactLayout.matches;
let playerFullscreenOwned=false,playerOrientationLocked=false,playerRotationBusy=false;

const motionStyle=getComputedStyle(document.documentElement);
// Цвет browser chrome также берём из AppColors, не дублируем значение в HTML.
document.querySelector('meta[name="theme-color"]')?.setAttribute('content',motionStyle.getPropertyValue('--color-base-bg').trim());
const motion={inspectorDelay:parseFloat(motionStyle.getPropertyValue('--motion-inspector-delay'))||150,
  fast:parseFloat(motionStyle.getPropertyValue('--motion-fast'))||160,
  standard:parseFloat(motionStyle.getPropertyValue('--motion-standard'))||240,
  menuEnter:parseFloat(motionStyle.getPropertyValue('--motion-menu-enter'))||240,
  menuExit:parseFloat(motionStyle.getPropertyValue('--motion-menu-exit'))||156,
  scrimOpacity:parseFloat(motionStyle.getPropertyValue('--motion-scrim-opacity'))||0.44,
  page:parseFloat(motionStyle.getPropertyValue('--motion-page'))||280,
  reverse:parseFloat(motionStyle.getPropertyValue('--motion-reverse'))||200,
  enter:motionStyle.getPropertyValue('--motion-enter').trim()||'cubic-bezier(0.215,0.61,0.355,1)',
  exit:motionStyle.getPropertyValue('--motion-exit').trim()||'cubic-bezier(0.55,0.055,0.675,0.19)'};
let menuExpanded=false,renderedRoute='',inspectorMotions=[],inspectorTransitions=[],inspectorUpdateTimer=null,pendingInspectorId=null;
function animateUI(el,frames,duration,easing=motion.enter){
  if(!el||reducedMotion.matches||typeof el.animate!=='function')return null;
  return el.animate(frames,{duration,easing,fill:'none'});
}
function setMenuExpanded(open){
  menuExpanded=!!open;
  const sidebar=$('.sidebar');
  sidebar?.classList.toggle('is-expanded',menuExpanded);
  sidebar?.closest('.shell')?.classList.toggle('menu-is-open',menuExpanded);
}
function syncMenuFocus(){setMenuExpanded(!isCompactUI()&&!!document.activeElement?.closest('.sidebar'));}
// TODO / HeroMagia (Flutter Hero shared-element transition), пока не реализован:
// При переходе из каталога на экран аниме со списком серий общий элемент — ПОСТЕР.
// Обернуть изображение карточки и постер detail() в Hero с одинаковым стабильным
// tag, основанным на id тайтла (например anime-poster:<id>), а не индексе или названии.
// Движение должно работать вперёд и обратно для главной, избранного и выдачи фильтров.
// На каждом маршруте только один Hero с данным tag: не размечать им картинки серий,
// логотип, миниатюру плеера или одновременно несколько копий постера.
// Общий элемент — изображение, не вся кнопка с подписью, сердечком и рамкой фокуса.
// Карточка каталога обрезает постер, detail показывает его целиком: согласовать clip,
// borderRadius и BoxFit в переходном представлении, чтобы не было растяжения/скачка.
// Hero-переход использует общие кривые AppMotion, не линейную отдельную анимацию.
// При возврате сохранить прокрутку и фокус исходной карточки; дождаться её появления
// после подгрузки/восстановления списка. Если элемент уже удалён, мягкий fallback без Hero.
// Respect reduced-motion: переход без полёта и масштаба при отключённой анимации.
// Нынешний animateRoute() — обычный fade, НЕ реализация Hero. В web-прототипе можно
// использовать shared-element View Transition; в приложении — Flutter Hero/HeroController.
function animateRoute(previous){
  const current=route.name+':'+(route.id||(route.filterType?route.filterType+':'+route.genre:route.genre)||'');
  if(!previous||previous===current)return;
  const el=$('#main')||$('.player')||$('.login');
  const isDetail=route.name==='detail';
  animateUI(el,isDetail?[{opacity:0,transform:'translateY(16px)'},{opacity:1,transform:'translateY(0)'}]:[{opacity:0},{opacity:1}],isDetail?motion.page:motion.fast);
}
reducedMotion.addEventListener('change',e=>{
  if(e.matches)document.getAnimations().forEach(a=>{try{a.finish()}catch{a.cancel()}});
});

const item=id=>[...data,...relatedTitles].find(a=>a.id===id)||data[0];
const poster=a=>`<img class="od-media" src="assets/${a.id}.jpg" width="${a.w||225}" height="${a.h}" alt="Постер аниме «${esc(a.title)}»">`;
function button(action,label,ic='',cls='btn',attrs=''){return `<button class="${cls}" data-action="${action}" data-focus="${action}" ${attrs}>${ic?icon(ic):''}<span>${label}</span></button>`;}
// ВРЕМЕННО / только тестирование прототипа: кликабельный логотип бокового меню
// открывает подтверждение закрытия приложения. НЕ переносить эту привязку
// в мобильное или ТВ Flutter-приложение: настоящий логотип не является кнопкой выхода.
function brand(testExit=false){
  // UI Kit / Brand: логотип скопирован без изменений из мобильного Flutter-приложения:
  // /Users/overman/Desktop/anistar_tv/anistar_tv/lib/packages/ui_kit/assets/images/anistar_logo.png
  // Локальная копия: assets/anistar-logo.png, исходный размер 1254 × 1254.
  // Для будущих ИИ: меню и форма входа переиспользуют этот общий brand(),
  // логотип и его прозрачный фон берём из Flutter UI Kit, не рисуем отдельные версии.
  const content='<img src="assets/anistar-logo.png?v=flutter-ui-kit-80" width="1254" height="1254" alt=""><span>AniStar <em>TV</em></span>';
  return testExit?`<button class="brand brand-exit-trigger" type="button" data-action="app-exit" data-focus="brand-exit" aria-label="Выйти из приложения">${content}</button>`:`<div class="brand">${content}</div>`;
}
// UI Kit / AccountSummary — информация о профиле, НЕ кнопка и не пункт навигации.
// Для будущих ИИ: аватар — ОДИН квадрат .account-picture, без «квадрата в квадрате».
// Инициалы строго по центру; при наличии фото оно занимает весь квадрат с object-fit:cover
// и тем же скруглением углов. Не добавлять вокруг фото padding, рамку или вторую подложку.
// .account-summary — прозрачный контейнер; имя в раскрытом меню располагается рядом.
// Использовать общие цвета меню и токены --account-avatar-size/--account-radius из app.css.
// TODO при подключении аккаунта: передать реальные displayName и avatarUrl из профиля.
// Фото загружается по avatarUrl; при отсутствии URL или ошибке загрузки видны инициалы.
// initials необязательны: если сервер их не отдаёт, вычисляем из имени пользователя.
const accountProfile={displayName:'Демо-аккаунт',initials:'AK',avatarUrl:null};
function accountSummary(profile){
  const name=profile.displayName?.trim()||'Аккаунт';
  const initials=profile.initials||name.split(/\s+/u).slice(0,2).map(part=>Array.from(part)[0]).join('').toLocaleUpperCase('ru');
  return `<div class="avatar account-summary" role="group" aria-label="${esc(name)}"><b class="account-picture" aria-hidden="true"><span class="account-initials">${esc(initials)}</span>${profile.avatarUrl?`<img data-account-photo src="${esc(profile.avatarUrl)}" width="48" height="48" alt="" decoding="async">`:''}</b><span class="account-name od-truncate">${esc(name)}</span></div>`;
}
// Ошибка фото возвращает инициалы, не оставляя битую картинку. Capture нужен для error img.
document.addEventListener('error',event=>{if(event.target.matches?.('[data-account-photo]'))event.target.remove();},true);
function menu(){return `<aside class="sidebar ${menuExpanded?'is-expanded':''}" aria-label="Основная навигация"><div class="menu-inner">${brand(true)}<nav class="menu">${[['home','Главная','home'],['favorites','Избранное','heart'],['genres','Жанры','grid']].map(([n,t,ic])=>`<button data-action="nav" data-name="${n}" data-focus="nav-${n}" aria-label="${t}" ${(route.name===n||(route.name==='browse'&&n==='genres'))?'aria-current="page"':''}>${icon(ic)}<span>${t}</span></button>`).join('')}</nav><div class="account">${accountSummary(accountProfile)}<div class="menu"><button data-action="signout" data-focus="nav-signout" aria-label="Выйти из аккаунта">${icon('logout')}<span>Выйти из аккаунта</span></button></div></div></div></aside>`;}
// AdaptiveNavigation: одна route и одна история для ТВ и телефона, без копии приложения.
// Скрытая навигация inert; одинаковые focus keys допустимы только у взаимоисключающих
// вариантов. focus() ниже выбирает видимый элемент. Логотип телефона НЕ запускает exit.
function compactHeader(){
  const nested=['detail','browse'].includes(route.name);
  // Handheld / ContextHeading: единый заголовок шапки карточки и любой выдачи.
  // Detail берёт title аниме; browse — route.genre (имя жанра, год или имя режиссёра).
  // route.genre — историческое имя поля выбранного значения для ВСЕХ filterType;
  // не заменять значение надписью «Каталог» и не определять его только по жанрам.
  // Одинаково для заполненной/пустой выдачи, ошибки и истёкшей сессии.
  // Дубли заголовков внутри контента скрыты ТОЛЬКО responsive.css до 1024px.
  // На ТВ исходные заголовки остаются; во Flutter переиспользовать ContextHeading UI Kit.
  const label=route.name==='detail'?item(route.id).title:route.name==='browse'?route.genre:({home:'Главная',favorites:'Избранное',genres:'Жанры'})[route.name]||'AniStar';
  // ContextHeading: максимум 2 строки с многоточием — только мобильная шапка.
  // Исходное имя в модели сохранять целиком; в шапке обычный текст, без действия по тапу.
  // Flutter: Text(maxLines:2, overflow:TextOverflow.ellipsis), без кнопки и дополнительной панели.
  const headingText=label||'Каталог';
  const heading=nested?`<h1 class="compact-heading compact-context-heading"><span class="compact-heading-text">${esc(headingText)}</span></h1>`:`<strong class="compact-heading"><span class="compact-heading-text">${esc(label)}</span></strong>`;
  return `<header class="compact-header" aria-label="${esc(label)}">${nested?button('back','Назад','back','btn compact-back','aria-label="Назад"'):brand()}${heading}<button type="button" class="btn compact-account" data-action="account" data-focus="compact-account" aria-label="Аккаунт">${icon('user')}</button></header>`;
}
function compactNavigation(){
  const active=route.name==='browse'?'genres':route.name;
  return `<nav class="compact-nav" aria-label="Основная навигация">${[['home','Главная','home'],['favorites','Избранное','heart'],['genres','Жанры','grid']].map(([name,label,ic])=>`<button type="button" data-action="nav" data-name="${name}" data-focus="nav-${name}" ${active===name?'aria-current="page"':''}>${icon(ic)}<span>${label}</span></button>`).join('')}</nav>`;
}
function compactAccount(){
  sheet('Аккаунт',`<div class="compact-profile">${accountSummary(accountProfile)}</div>${button('signout','Выйти из аккаунта','logout','btn')}`,{showClose:false});
}
function syncAdaptiveLayout(){
  const compact=isCompactUI();
  arrangePlayerControls();
  const sidebar=$('.sidebar');if(sidebar)sidebar.inert=compact;
  for(const node of document.querySelectorAll('.compact-header,.compact-nav'))node.inert=!compact;
  syncCompactHeader();
  syncMenuFocus();
  const main=$('#main'),inspector=$('#catalog-inspector');
  if(main)main.style.setProperty('--catalog-sticky-offset',compact?'16px':((inspector?.offsetHeight||0)+24)+'px');
  // Поворот/resize НЕ вызывает render(): пароль, позиция видео, скролл и запросы живут дальше.
  const active=document.activeElement;
  if(active&&active!==document.body&&!active.getClientRects().length){
    if($('.overlay'))focusables($('.overlay'))[0]?.focus({preventScroll:true});else if(main)main.focus({preventScroll:true});else $('.tv-player')?.focus({preventScroll:true});
  }
}
// FloatingHeader / UI Kit — источник: Flutter
// features/home/presentation/mobile/mobile_home_shell.dart, _onScroll/_showHeader.
// Вниз скрывает header; вверх/начало списка показывает. Короткий список не скрывает.
// Здесь тот же контракт применяется к home/favorites/genres/browse/detail, не player/login.
// Для будущих ИИ: скролл только #main активного экрана; панели и вложенные списки
// не управляют шапкой. При переходе показывать её заново, не наследовать hidden.
// Flutter использует TweenAnimationBuilder + ClipRect/Align(heightFactor) с AppMotion.fast.
// HTML: sticky header внутри scroll-контейнера и transform/opacity. Высота списка
// не анимируется и не меняется при hidden: нет циклов resize/scroll и пустой полосы.
// Sticky занимает своё место в начале normal flow; прокрутка уносит это место сама.
// Скрытый header inert + aria-hidden: аналог ExcludeFocus/ExcludeSemantics/IgnorePointer.
// Keyboard и reduced motion держат header видимым. Нижняя навигация не скрывается.
// На TV header возвращается в shell и остаётся скрыт CSS; TV inspector не затронут.
let compactChrome=null,compactChromeFrame=0,compactChromeObserver=null;
function setCompactHeaderVisible(visible){
  const state=compactChrome;if(!state)return;
  state.visible=visible;
  if(!visible&&state.header.contains(document.activeElement))state.main.focus({preventScroll:true});
  state.header.classList.toggle('is-scroll-hidden',!visible);
  state.header.inert=!visible;
  if(visible)state.header.removeAttribute('aria-hidden');else state.header.setAttribute('aria-hidden','true');
  state.main.style.setProperty('--compact-scroll-padding',visible?(state.height+16)+'px':'16px');
}
function syncCompactHeader(){
  cancelAnimationFrame(compactChromeFrame);compactChromeFrame=0;
  compactChromeObserver?.disconnect();compactChromeObserver=null;compactChrome=null;
  const shell=$('.shell'),header=$('.compact-header'),main=$('#main');
  if(!shell||!header||!main)return;
  header.classList.remove('is-scroll-hidden');header.removeAttribute('aria-hidden');
  main.style.removeProperty('--compact-scroll-padding');
  if(!isCompactUI()){
    shell.insertBefore(header,shell.querySelector('.menu-scrim'));
    header.inert=true;return;
  }
  // Перемещается тот же DOM-узел: нет копии title/account/back и дублирующих обработчиков.
  main.prepend(header);header.inert=false;
  compactChrome={main,header,lastY:Math.max(0,main.scrollTop),distance:0,direction:0,height:header.offsetHeight,visible:true,keyboard:false};
  const measure=()=>{
    if(compactChrome?.header!==header)return;
    compactChrome.height=header.offsetHeight;
    main.style.setProperty('--compact-scroll-padding',compactChrome.visible?(compactChrome.height+16)+'px':'16px');
  };
  measure();
  if(typeof ResizeObserver!=='undefined'){compactChromeObserver=new ResizeObserver(measure);compactChromeObserver.observe(header);}
}
function updateCompactHeaderFromScroll(){
  compactChromeFrame=0;
  const state=compactChrome;
  if(!state||!isCompactUI()||!state.main.isConnected)return;
  const y=Math.max(0,state.main.scrollTop),delta=y-state.lastY;
  state.lastY=y;
  // Не реагировать на открытие панели, фокус с клавиатуры или незначительную прокрутку.
  if($('.overlay')||state.keyboard||reducedMotion.matches){state.distance=0;setCompactHeaderVisible(true);return;}
  if(y<=16||state.main.scrollHeight-state.main.clientHeight<=state.height+16){
    state.distance=0;state.direction=0;setCompactHeaderVisible(true);return;
  }
  if(Math.abs(delta)<1)return;
  const direction=Math.sign(delta);
  state.distance=direction===state.direction?state.distance+Math.abs(delta):Math.abs(delta);
  state.direction=direction;
  if(state.distance<8)return;
  if(direction<0)setCompactHeaderVisible(true);
  else if(y>state.height+16)setCompactHeaderVisible(false);
  state.distance=0;
}
document.addEventListener('scroll',event=>{
  if(event.target!==compactChrome?.main||compactChromeFrame)return;
  // Один read/update за кадр; без render(), поиска карточек или пересоздания списка.
  compactChromeFrame=requestAnimationFrame(updateCompactHeaderFromScroll);
},{capture:true,passive:true});
document.addEventListener('keydown',event=>{
  if(!compactChrome||!isCompactUI()||event.key==='Escape')return;
  compactChrome.keyboard=true;setCompactHeaderVisible(true);
},true);
document.addEventListener('pointerdown',()=>{if(compactChrome)compactChrome.keyboard=false;},{capture:true,passive:true});
document.addEventListener('wheel',()=>{if(compactChrome)compactChrome.keyboard=false;},{passive:true});
reducedMotion.addEventListener('change',()=>{if(compactChrome)setCompactHeaderVisible(true);});
compactLayout.addEventListener('change',syncAdaptiveLayout);
phoneLayout.addEventListener('change',()=>{cancelInspectorUpdate();cancelInspectorAnimations();});
// Источник информации на телефоне — полная карточка; hover/TV-inspector не нужен.
// Ничего не удаляем из данных и не запускаем параллельный мобильный парсер.
function top(title,back=false){return `<header class="topbar">${back?button('back','Назад','back','back-btn'):`<strong>${title}</strong>`}<div class="right"><span>AniStar TV</span></div></header>`;}
// Expanded projection proposed for the site's catalog HTML. These are demo records,
// not a live snapshot. Optional ratings, release/update labels and voiceovers stay null
// unless supplied by a source; planned episode totals are never treated as availability.
const catalogRatings={frieren:9.2,jujutsu:9.5,demon:9.7,attack:9.7,spy:9.5};
// Additional fields transcribed from AniStar pages; unknown fields remain absent.
// TODO для будущих ИИ / Flutter-парсера: добавить watchOrder в модель полной карточки.
// Источник: .news_text .descripts .title_spoiler + .text_spoiler (даже display:none).
// Заголовки сайта: «В каком порядке лучше смотреть эту серию:» или «Серия состоит из:».
// Пример: https://v31.astar.bz/11072-o-moem-pererozhdenii-v-mech-2-sezon-tensei-shitara-ken-deshita-ii.html
// Сохранять порядок DOM, текст и href каждого пункта; это сезоны/части франшизы,
// НЕ эпизоды плеера. HTML декодировать с учётом Windows-1251, href разрешать от URL
// страницы. Не собирать список по названию и не подставлять его другим аниме.
// Ниже рабочий HTML-парсер прототипа; перенести аналогичную выборку в Flutter.
// В production подавать HTML страницы, без отдельного API; пустой список скрывает весь блок.
function parseWatchOrder(html,pageUrl){
  const doc=new DOMParser().parseFromString(html,'text/html');
  const result=[];
  for(const title of doc.querySelectorAll('.news_text .title_spoiler')){
    if(!/в каком порядке|серия состоит из/i.test(title.textContent))continue;
    const body=title.nextElementSibling;
    if(!body?.classList.contains('text_spoiler'))continue;
    for(const a of body.querySelectorAll('a[href]')){
      const label=a.textContent.replace(/\s+/g,' ').trim();
      try{
        const url=new URL(a.getAttribute('href'),pageUrl);
        if(label&&['https:','http:'].includes(url.protocol))result.push({label,url:url.href});
      }catch{} // Некорректную ссылку пропустить, не ронять карточку целиком.
    }
  }
  return result;
}
const catalogDetails={
  frieren:{watchOrder:[{"label": "Провожающая в последний путь Фрирен [TB-1]", "url": "https://v31.astar.bz/9576-.html"}, {"label": "Провожающая в последний путь Фрирен [TB-2]", "url": "https://v31.astar.bz/10686-.html"}],categories:['Аниме','Сёнен','Драма','Приключения','Фэнтези'],genres:['Приключения','Сёнен','Фэнтези','Драма'],voiceover:'Русская озвучка',director:'Кэйитиро Сайто',seriesInfo:'ТВ (28 эп.), 25 мин.',updateText:'Добавлена 28 (заключительная) серия с русской озвучкой',publishedAt:'22-03-2024, 19:05',publishedISO:'2024-03-22T19:05:00'},
  jujutsu:{categories:['Аниме','Демоны','Экшен','Сверхъестественное','Школа','Сёнен','Ужасы'],voiceover:'Русская озвучка',director:'Пак Сон Ху',seriesInfo:'ТВ (24 эп.), 25 мин.'},
  spy:{categories:['Аниме','Экшен','Сёнен','Комедия'],voiceover:'Русская озвучка',director:'Кадзухиро Фурухаси',seriesInfo:'ТВ (25 эп.), 25 мин.',updateText:'Добавлена 25 (заключительная) серия с русской озвучкой',publishedAt:'24.12.2022, 20:22',publishedISO:'2022-12-24T20:22:00'},
  attack:{categories:['Аниме','Приключения','Фантастика'],voiceover:'Русская озвучка',seriesInfo:'ТВ (25 эп.), 25 мин.'}
};
const catalogPages=[data.slice(0,4),data.slice(4)].map((items,i)=>({
  page:i+1,hasNext:i===0,
  items:items.map(a=>({id:a.id,title:a.title,posterUri:'assets/'+a.id+'.jpg',h:a.h,
    rating:catalogRatings[a.id]??null,year:a.year,genres:[...a.genre],description:a.desc,
    seriesInfo:'ТВ · '+a.episodes+' эпизодов',voiceover:null,updateText:null,categories:[],director:null,publishedAt:null,...(catalogDetails[a.id]||{})}))
}));
const homeFeed={items:[],page:0,hasNext:true,loading:false,error:null};
let selectedCatalogId='frieren',selectedFavoritesId=null,catalogObserver=null,pendingCatalogFocus=null,inspectorResizeObserver=null;
function catalogRecord(a){return homeFeed.items.find(x=>x.id===a.id)||catalogPages.flatMap(p=>p.items).find(x=>x.id===a.id)||(a.id==='frieren2'?{...a,watchOrder:catalogDetails.frieren.watchOrder}:a);}
/** UI Kit / MediaCard — единый компонент карточек главной, избранного и жанров.
 * Не копировать разметку и анимацию в новые экраны: вызывать mediaCard(options).
 * variant: poster | landscape | episode — готовые варианты; ratio: [w,h] переопределяет их.
 * frameHeight: положительное число px, если нужна фиксированная высота; по умолчанию
 * высота следует пропорциям и ширине сетки. fit: cover | contain, без растягивания.
 * imageWidth/imageHeight — реальные размеры файла; title — доступное имя и подпись.
 * action/id/genre/focusKey задают поведение; saved включает отметку избранного.
 * episodeNumber/status — номер и состояние серии; вариант episode не требует картинки.
 * Motion, focus, reduced-motion и подпись централизованы в CSS .ui-media-card.
 * Пример: mediaCard({title:'Жанр',image:'assets/genres/drama.jpg',imageWidth:219,
 * imageHeight:92,variant:'landscape',action:'genre',genre:'Драма',focusKey:'genre-3'}).
 */
// MediaCard / FavoriteRibbon: полупрозрачная закладка, свисающая от верхнего края.
// SVG ниже — декоративная форма подложки, не альтернативная функциональная иконка.
// Сверху прямой край без скруглений; только нижние кончики и вырез смягчены примерно на 4px.
// Верх должен прилегать к краю постера как закладка. Сердце остаётся непрозрачным.
// Скруглять нужно и нижние кончики/вырез в самом path: border-radius не меняет контур SVG.
// Сердце внутри всегда берём из общего Lucide AppIcon. Это статус, не отдельная кнопка.
function favoriteRibbon(){
  return `<span class="badge media-card-favorite" aria-label="В избранном"><svg class="favorite-ribbon-shape" viewBox="0 0 36 48" width="36" height="48" aria-hidden="true" focusable="false"><path d="M0 0h36v42q0 5-4 3l-12-6q-2-1-4 0L4 45q-4 2-4-3V0Z"/></svg>${icon('heart')}</span>`;
}
function mediaCard({title,image,imageWidth,imageHeight,variant='poster',ratio=null,frameHeight=null,fit=null,action='detail',id=null,genre=null,focusKey,saved=false,episodeNumber=null,status=''}){
  const landscape=variant==='landscape';
  const geometry=[];
  if(Array.isArray(ratio)&&ratio.length===2&&ratio.every(n=>Number.isFinite(n)&&n>0))geometry.push(`--media-card-ratio:${ratio[0]}/${ratio[1]}`);
  if(Number.isFinite(frameHeight)&&frameHeight>0)geometry.push(`--media-card-height:${frameHeight}px`);
  if(fit==='cover'||fit==='contain')geometry.push(`--media-card-fit:${fit}`);
  const attributes=[`data-action="${esc(action)}"`,`data-focus="${esc(focusKey)}"`];
  if(id!==null)attributes.push(`data-id="${esc(id)}"`);
  if(genre!==null)attributes.push(`data-genre="${esc(genre)}"`);
  if(episodeNumber!==null)attributes.push(`data-episode="${episodeNumber}"`);
  // Текстовый вариант сохраняет общую оболочку и motion MediaCard, без фальшивых кадров.
  if(variant==='episode')return `<button class="ui-media-card anime-card od-tile ui-media-card--episode" ${attributes.join(' ')} aria-label="${esc(title+(status?', '+status:''))}"${geometry.length?` style="${geometry.join(';')}"`:''}><span class="media-card-number" aria-hidden="true">${String(episodeNumber).padStart(2,'0')}</span><span class="media-card-copy od-field"><span class="media-card-label">${esc(title)}</span>${status?`<span class="media-card-status">${esc(status)}</span>`:''}</span>${icon(status?'check':'play')}</button>`;
  return `<button class="ui-media-card anime-card od-tile poster-card${landscape?' ui-media-card--landscape':''}" ${attributes.join(' ')} aria-label="${esc(title)}"${geometry.length?` style="${geometry.join(';')}"`:''}><span class="poster-wrap"><img class="od-media" src="${esc(image)}" width="${imageWidth}" height="${imageHeight}" alt="">${saved?favoriteRibbon():''}<span class="poster-title"><span class="od-clamp-2">${esc(title)}</span></span></span></button>`;
}
// HeroMagia: источник общего постера для detail(); использовать тот же id тайтла.
// Требования к tag, обратному переходу и обрезке описаны над animateRoute().
function card(a){
  // Адаптер данных аниме к MediaCard. Отметка на постере — нейтральный статус,
  // не отдельная кнопка: добавление/удаление доступно в панели действий.
  // В избранном сердечки не показывать:
  // сохранённый статус очевиден из раздела, на остальных экранах он полезен.
  return mediaCard({title:a.title,image:'assets/'+a.id+'.jpg',imageWidth:225,imageHeight:a.h,
    id:a.id,focusKey:'card-'+a.id,saved:route.name!=='favorites'&&fav.has(a.id)});
}
function grid(items){return `<div class="od-grid poster-grid" data-grid>${items.map(card).join('')}</div>`;}
function catalogSkeleton(){return `<div class="od-grid poster-grid home-grid" aria-hidden="true">${Array.from({length:4},()=>'<div class="catalog-skeleton"><div class="skeleton-poster"></div><div class="skeleton-line"></div><div class="skeleton-line short"></div></div>').join('')}</div>`;}
const selectedGenreIds=new Map();
// UI Kit / CatalogSort: общий механизм для CatalogFilter года/жанра/режиссёра.
// Источник Flutter: catalog_sort_sheet.dart + CatalogSortCriterion + CatalogSort.
// Фильтр задаёт состав каталога (path), сортировка — criterion/ascending. В production
// передавать оба в AnistarCatalogRepository/AnistarCatalogSort и заново грузить page 1.
// Сортировать только загруженную страницу большого каталога вместо запроса НЕЛЬЗЯ:
// местная сортировка ниже нужна только маленькой локальной подборке прототипа.
// Даты не переписывать: publishedAt остаётся исходной строкой; сравнение использует
// отдельное publishedISO. Нет даты — запись идёт после известных дат в любом порядке.
// Точное соответствие из AnistarCatalogRepository: popularity → rating,
// visits → views (HTML news_read), comments → comments (HTML comm_num).
// Ранее popularity ошибочно искал отдельное поле: рейтинг — верный источник,
// как в уже работающей мобильной реализации. Счётчики не выдумывать.
// ПЕРЕНОС ВО FLUTTER, не новый алгоритм: переиспользовать CatalogSortSheet,
// FilteredCatalogRepository и AnistarCatalogRepository.getFilteredPage(filter,page,sort).
// HtmlCatalogParameters.cookies(path): date/rating/news_read/comm_num/title;
// dle_sort_cat и dle_direction_cat=asc|desc, dle_no_cache=1. Для /filter/janrs/
// суффикс xfsearch вместо cat. Это cookies, НЕ произвольные query-параметры.
// verify(): form#news_set_sort a.sort-actv должен подтверждать поле/направление;
// при неподтверждённом ответе показывать ошибку, не считать сортировку успешной.
// ВАЖНО: текущий HtmlCatalogParameters.isValidPath допускает жанровые пути,
// но НЕ /filter/year/ и /filter/director/. Для поддержки этих фильтров расширить
// валидатор и проверить подтверждение сортировки на их HTML, сохраняя кодировку href.
// Прототип фильтрует локальные записи для всех трёх типов; это не проверка сервера.
const browseSorts=new Map();
const sortCriteria=[['date','По дате'],['popularity','По популярности'],['visits','По посещаемости'],['comments','По комментариям'],['title','По алфавиту']];
let browseSortDraft=null,browseSortOrigin=null;
function browseFilterKey(){return (route.filterType||'genre')+':'+route.genre;}
function currentBrowseSort(){return browseSorts.get(browseFilterKey())||{criterion:'date',ascending:false};}
function filteredCatalogRecords(){
  const records=data.map(catalogRecord);
  if(route.filterType==='year')return records.filter(a=>String(a.year)===route.genre);
  if(route.filterType==='director')return records.filter(a=>a.director===route.genre);
  const filter=siteGenres.find(g=>g.name===route.genre)?.filter||route.genre;
  return records.filter(a=>(a.genres||[]).includes(filter));
}
function sortValue(record,criterion){
  if(criterion==='title')return record.title;
  if(criterion==='date')return record.publishedISO||null;
  const value=record[{popularity:'rating',visits:'visits',comments:'commentCount'}[criterion]];
  return typeof value==='number'&&Number.isFinite(value)?value:null;
}
function canSortBy(criterion){return ['date','title'].includes(criterion)||filteredCatalogRecords().some(a=>sortValue(a,criterion)!==null);}
function sortedBrowseRecords(records){
  const settings=currentBrowseSort(),sign=settings.ascending?1:-1;
  return records.map((record,index)=>({record,index})).sort((a,b)=>{
    const av=sortValue(a.record,settings.criterion),bv=sortValue(b.record,settings.criterion);
    if(av===null&&bv===null)return a.index-b.index;
    if(av===null)return 1;if(bv===null)return -1;
    const comparison=typeof av==='number'?av-bv:String(av).localeCompare(String(bv),'ru',{numeric:true,sensitivity:'base'});
    return sign*comparison||a.index-b.index;
  }).map(entry=>entry.record);
}
function browseSortDirection(settings){
  return settings.criterion==='date'?(settings.ascending?'Сначала старые':'Сначала новые'):settings.criterion==='title'?(settings.ascending?'А → Я':'Я → А'):(settings.ascending?'По возрастанию':'По убыванию');
}
function browseSortLabel(){const settings=currentBrowseSort();return sortCriteria.find(([key])=>key===settings.criterion)[1]+' · '+browseSortDirection(settings);}
function browseSortControl(){
  return button('browse-sort',browseSortLabel(),'filter','btn browse-sort-button',`aria-label="Сортировка: ${esc(browseSortLabel())}" aria-haspopup="dialog" ${genreCatalogError()||genreSessionExpired()?'disabled':''}`);
}
// Один выбор = фиксированное место Lucide-check слева + подпись рядом.
// Не использовать space-between: он разносит галочку и текст по краям строки.
function browseSortChoice(action,label,selected,value,focusKey,disabled=false){
  return `<button class="sheet-option sort-choice" data-action="${action}" data-value="${value}" data-focus="${focusKey}" aria-pressed="${selected}" ${disabled?'disabled':''}><span class="sort-choice-mark" aria-hidden="true">${selected?icon('check'):''}</span><span class="sort-choice-label">${esc(label)}</span></button>`;
}
function browseSortPanel(){
  const draft=browseSortDraft;
  return `<div class="sort-criteria od-stack" role="group" aria-label="Сортировать">${sortCriteria.map(([key,label])=>browseSortChoice('draft-sort-criterion',label,draft.criterion===key,key,'criterion-'+key,!canSortBy(key))).join('')}</div><h3 class="sort-order-title" id="sort-order-title">Порядок</h3><div class="od-stack" role="group" aria-labelledby="sort-order-title">${[false,true].map(ascending=>browseSortChoice('draft-sort-direction',browseSortDirection({...draft,ascending}),draft.ascending===ascending,ascending,'direction-'+ascending)).join('')}</div><div class="sort-panel-actions od-stack">${button('apply-browse-sort','Применить','','btn primary')}${button('close','Отмена','','btn')}</div>`;
}
function openBrowseSort(){
  if(route.name!=='browse'||genreCatalogError()||genreSessionExpired())return;
  browseSortDraft={...currentBrowseSort()};browseSortOrigin=route;
  sheet('Сортировка','<div id="browse-sort-draft" class="browse-sort-draft">'+browseSortPanel()+'</div>',{showClose:false});
  // В button() default data-focus имеет приоритет над дополнительным атрибутом:
  // отдельные ключи назначаем на самих узлах, сохраняя единый renderer кнопки.
  syncBrowseSortKeys();focus('criterion-'+browseSortDraft.criterion,true);
}
function syncBrowseSortKeys(){
  document.querySelectorAll('#browse-sort-draft [data-action="draft-sort-criterion"]').forEach(b=>b.dataset.focus='criterion-'+b.dataset.value);
  document.querySelectorAll('#browse-sort-draft [data-action="draft-sort-direction"]').forEach(b=>b.dataset.focus='direction-'+b.dataset.value);
}
function changeBrowseSortDraft(action,value){
  if(!browseSortDraft||route!==browseSortOrigin)return;
  if(action==='draft-sort-criterion'){if(!canSortBy(value))return;browseSortDraft.criterion=value;}
  else browseSortDraft.ascending=value==='true';
  const panel=$('#browse-sort-draft');if(!panel)return;
  panel.innerHTML=browseSortPanel();syncBrowseSortKeys();
  focus((action==='draft-sort-criterion'?'criterion-':'direction-')+value,true);
}
function applyBrowseSort(){
  if(!browseSortDraft||route!==browseSortOrigin)return;
  const origin=route,previous=currentBrowseSort();
  if(previous.criterion===browseSortDraft.criterion&&previous.ascending===browseSortDraft.ascending){closeSheet();return;}
  browseSorts.set(browseFilterKey(),{...browseSortDraft});
  // Как Flutter _chooseSort(): сохранять фильтр, сбросить выдачу к началу,
  // оставить фокус на сортировке. Отмена/Back не меняют применённые настройки.
  selectedGenreIds.delete(browseFilterKey());
  closeSheet(true,()=>{if(route===origin)render('browse-sort',0);});
}
function activeCatalogItems(){
  if(route.name==='favorites')return [...data,...relatedTitles].filter(a=>fav.has(a.id)).map(catalogRecord);
  if(route.name==='browse')return sortedBrowseRecords(filteredCatalogRecords());
  return homeFeed.items;
}
function selectedInspectorId(){return route.name==='favorites'?selectedFavoritesId:route.name==='browse'?selectedGenreIds.get((route.filterType||'genre')+':'+route.genre):selectedCatalogId;}
function selectInspectorId(id){if(route.name==='favorites')selectedFavoritesId=id;else if(route.name==='browse')selectedGenreIds.set((route.filterType||'genre')+':'+route.genre,id);else selectedCatalogId=id;}
// Общий заголовок для избранного и выбранного жанра. Главная остаётся без заголовка раздела.
function catalogSectionHeading(){return route.name==='favorites'?'<h1 id="favorites-title" class="section-title">Избранное</h1>':route.name==='browse'?`<div class="browse-heading"><h1 id="browse-title" class="section-title">${esc(route.genre)}</h1>${browseSortControl()}</div>`:'';}
// UI Kit / AnimeTitle: .anime-title общий с detail(); меняется только уровень h1/h2.
// В списках текст ограничен двумя строками, на экране тайтла показывается полностью.
// Обновление из HTML сайта, без API: брать .reason.textContent и .date-icon.textContent
// соответствующего тайтла; trim() допустим только для внешних пробелов.
// В ленте и полной карточке эти строки выводятся ОДИНАКОВО через publicationText().
// Не выделять номер/«заключительная» regex-ом, не собирать новое сообщение из частей:
// сайт может написать диапазон серий, смену озвучки или произвольное обновление.
// Сохранять исходные формулировку, скобки и дату строкой. Не использовать Date/DateTime,
// не пересчитывать часовой пояс, не заменять дату на «сегодня» и не добавлять свой префикс.
// Отсутствующие поля скрывать. HTML сайта не вставлять: только извлечённый текст + esc().
function publicationText(c,messageClass,dateClass){
  return `${c.updateText?`<p class="${messageClass}">${esc(c.updateText)}</p>`:''}${c.publishedAt?`<span class="${dateClass}">${esc(c.publishedAt)}</span>`:''}`;
}
function inspectorContent(){
  const items=activeCatalogItems();
  const selectedId=selectedInspectorId();
  const c=items.find(x=>x.id===selectedId)||items[0];
  if(!c)return '';
  selectInspectorId(c.id);
  const rating=typeof c.rating==='number'&&Number.isFinite(c.rating)&&c.rating>=0&&c.rating<=10?c.rating:null;
  const facts=[c.year,...(c.genres||[]).slice(0,2)].filter(Boolean);
  return `${catalogSectionHeading()}<div class="inspector-copy od-stack"><h2 class="anime-title od-clamp-2">${esc(c.title)}</h2><div class="inspector-category-row od-row">${rating!==null?`<span class="inspector-rating" aria-label="Рейтинг ${rating.toFixed(1).replace('.',',')} из 10">${icon('star')}<strong>${rating.toFixed(1).replace('.',',')}</strong><span>/ 10</span></span>`:''}<span class="inspector-categories od-clamp-2">${facts.map(esc).join(' · ')}</span></div>${c.description?`<p class="inspector-description od-clamp-2">${esc(c.description)}</p>`:''}</div>${c.updateText||c.publishedAt?`<aside class="inspector-news od-stack" aria-label="Последнее обновление">${publicationText(c,'episode-news','publication-date')}</aside>`:''}`;
}
// UI Kit / InspectorMotion — одна реализация для главной, избранного и фильтров.
// Для будущих ИИ / Flutter: фокус карточки меняется СРАЗУ; данные описания — после
// 150 мс остановки. При повторном движении отменять таймер: показывать только последний
// выбранный тайтл, без очередей, сетевых запросов и перестроения сетки карточек.
// ОБЯЗАТЕЛЬНО ДЛЯ БУДУЩИХ ИИ: во Flutter реализовать замену через AnimatedCrossFade.
// Общий компонент для главной, избранного и выдачи фильтров. firstChild/secondChild —
// два буфера текста: заполнить скрытый новым тайтлом и переключить crossFadeState.
// Не менять содержимое видимого child до начала перехода. Разделить затухания:
// старый исчезает на интервале 0–0.5 (easeInCubic), новый проявляется на 0.5–1
// (easeOutCubic). Одновременно видимых текстов быть не должно. Без сдвига и scale.
// Flutter: при showSecond firstCurve=Interval(0,0.5,curve:AppMotion.exit),
// secondCurve=Interval(0.5,1,curve:AppMotion.enter). При showFirst поменять интервалы
// и кривые местами: secondChild уходит в первой половине, firstChild входит во второй.
// Обычная замена длится AppMotion.page (280 мс) для ОБОИХ текстов; общие кривые
// брать из AppMotion (easeOutCubic/easeInCubic). duration/reverseDuration при чередовании
// буферов одинаковы — AppMotion.page, чтобы направление toggle не меняло темп.
// firstCurve в AnimatedCrossFade инвертируется самим виджетом: не инвертировать дважды.
// Фон и блюр вне AnimatedCrossFade; анимируются только copy/news. Высоту панели
// не анимировать: при переносе предусмотреть стабильную текстовую область/layoutBuilder.
// Максимум два текстовых слоя; прерванные переходы не накапливать. Старый слой
// исключён из accessibility и фокуса (в HTML aria-hidden/inert).
// Производительность Flutter проверять в profile на слабом ТВ; HTML её не доказывает.
// Reduced motion: смена сразу без проявления. При уходе со страницы отменять всё.
function cancelInspectorUpdate(){
  clearTimeout(inspectorUpdateTimer);inspectorUpdateTimer=null;pendingInspectorId=null;
}
function cancelInspectorAnimations(){
  inspectorMotions.forEach(animation=>animation?.cancel());inspectorMotions=[];
  inspectorTransitions.forEach(finish=>finish());inspectorTransitions=[];
}
function updateInspector(id){
  if(isCompactUI())return; // На телефоне нет hover-панели и скрытых CrossFade-анимаций.
  if(!['home','favorites','browse'].includes(route.name)||!activeCatalogItems().some(a=>a.id===id))return;
  if(pendingInspectorId===id)return;
  cancelInspectorUpdate();
  // Повторный pointerover от дочерних узлов той же карточки НЕ обрывает fade.
  if(selectedInspectorId()===id)return;
  cancelInspectorAnimations();
  const el=$('#catalog-inspector'),origin=route;
  if(!el)return;
  const commit=()=>{
    inspectorUpdateTimer=null;pendingInspectorId=null;
    if(route!==origin||!el.isConnected||!activeCatalogItems().some(a=>a.id===id))return;
    const selectors=['.inspector-copy','.inspector-news'];
    const previous=selectors.map(selector=>el.querySelector(selector));
    selectInspectorId(id);
    el.innerHTML=inspectorContent();
    if(reducedMotion.matches)return;
    selectors.forEach((selector,index)=>{
      const incoming=el.querySelector(selector),outgoing=previous[index];
      if(!incoming&&!outgoing)return;
      const layer=document.createElement('div');
      layer.className='inspector-transition';
      if(incoming)incoming.replaceWith(layer);else el.append(layer);
      if(outgoing){outgoing.setAttribute('aria-hidden','true');outgoing.inert=true;layer.append(outgoing);}
      if(incoming)layer.append(incoming);
      let finished=false;
      const finish=()=>{
        if(finished)return;finished=true;
        if(incoming)layer.replaceWith(incoming);else layer.remove();
      };
      inspectorTransitions.push(finish);
      // linear здесь только общая шкала времени; видимые изменения идут по
      // общим нелинейным кривым внутри соответствующих половин перехода.
      const exit=animateUI(outgoing,[{opacity:1,offset:0,easing:motion.exit},{opacity:0,offset:0.5},{opacity:0,offset:1}],motion.page,'linear');
      if(exit)exit.effect.updateTiming({fill:'forwards'});
      const enter=animateUI(incoming,[{opacity:0,offset:0},{opacity:0,offset:0.5,easing:motion.enter},{opacity:1,offset:1}],motion.page,'linear');
      const animations=[exit,enter].filter(Boolean);
      inspectorMotions.push(...animations);
      Promise.all(animations.map(animation=>animation.finished.catch(()=>{}))).then(finish);
    });
  };
  if(reducedMotion.matches){commit();return;}
  pendingInspectorId=id;
  inspectorUpdateTimer=setTimeout(commit,motion.inspectorDelay);
}

function paginationContent(){
  if(homeFeed.loading)return '<p role="status" class="catalog-status">Загружаем следующую страницу…</p>';
  if(homeFeed.error)return `<div class="catalog-error compact" role="alert"><p>Не удалось загрузить следующую страницу. Открытые аниме остаются доступны.</p>${button('retry-catalog','Повторить','refresh')}</div>`;
  if(!homeFeed.hasNext)return '';
  return '';
}
function home(){
  let content=homeFeed.items.length?grid(homeFeed.items):catalogSkeleton();
  if(!homeFeed.items.length&&homeFeed.error)content=`<div class="catalog-error" role="alert"><h2>Не удалось загрузить каталог</h2><p>Попробуй ещё раз или вернись позже.</p>${button('retry-catalog','Повторить','refresh','btn primary')}</div>`;
  return `<section class="catalog home-catalog" aria-labelledby="catalog-title"><h1 id="catalog-title" class="sr-only">Главная — каталог аниме</h1><section id="catalog-inspector" class="catalog-inspector od-row-top" aria-label="О выбранном аниме">${inspectorContent()}</section><div class="home-grid-wrap" aria-busy="${homeFeed.loading}">${content}</div><div id="catalog-pagination" class="catalog-pagination">${paginationContent()}</div><div id="catalog-sentinel" aria-hidden="true"></div></section>`;
}
function syncCatalogStatus(){
  const el=$('#catalog-pagination');if(el)el.innerHTML=paginationContent();
  $('.home-grid-wrap')?.setAttribute('aria-busy',String(homeFeed.loading));
}
function setupCatalogObserver(){
  catalogObserver?.disconnect();catalogObserver=null;inspectorResizeObserver?.disconnect();inspectorResizeObserver=null;
  if(!['home','favorites','browse'].includes(route.name))return;
  const main=$('#main'),sentinel=$('#catalog-sentinel'),inspector=$('#catalog-inspector');
  if(main&&inspector){
    const reserve=()=>main.style.setProperty('--catalog-sticky-offset',isCompactUI()?'16px':(inspector.offsetHeight+24)+'px');
    reserve();
    if(typeof ResizeObserver!=='undefined'){inspectorResizeObserver=new ResizeObserver(reserve);inspectorResizeObserver.observe(inspector);}
  }
  if(route.name!=='home')return;
  if(main)main.addEventListener('scroll',()=>{
    if(main.scrollHeight-main.scrollTop-main.clientHeight<400)maybeLoadCatalog();
  },{passive:true});
  if(main&&sentinel&&typeof IntersectionObserver!=='undefined'){
    catalogObserver=new IntersectionObserver(entries=>{if(entries.some(e=>e.isIntersecting))maybeLoadCatalog();},{root:main,rootMargin:'0px 0px 400px 0px'});
    catalogObserver.observe(sentinel);
  }
}
function maybeLoadCatalog(){
  if(route.name==='home'&&homeFeed.hasNext&&!homeFeed.loading&&!homeFeed.error)void loadCatalog();
}
async function loadCatalog(){
  if(homeFeed.loading||(!homeFeed.hasNext&&!homeFeed.error))return;
  homeFeed.loading=true;homeFeed.error=null;syncCatalogStatus();
  try{
    // Replace this local asynchronous adapter with getPage(page) in the Flutter app.
    const next=await new Promise((resolve,reject)=>setTimeout(()=>{
      const page=catalogPages[homeFeed.page];
      if(!page||!Array.isArray(page.items))reject(new Error('Catalog page is unavailable'));
      else resolve(page);
    },450));
    const seen=new Set(homeFeed.items.map(a=>a.id));
    const added=next.items.filter(a=>!seen.has(a.id));
    homeFeed.items.push(...added);homeFeed.page=next.page;homeFeed.hasNext=next.hasNext;homeFeed.loading=false;
    if(route.name==='home'){
      const grid=$('.home-grid-wrap [data-grid]');
      if(grid)grid.insertAdjacentHTML('beforeend',added.map(card).join(''));
      else{const wrap=$('.home-grid-wrap');if(wrap)wrap.innerHTML=gridMarkupForLoaded();}
      syncCatalogStatus();
      const pending=pendingCatalogFocus;pendingCatalogFocus=null;
      if(pending&&currentKey()===pending.origin&&added.length){
        const cells=[...document.querySelectorAll('.home-grid-wrap .anime-card')];
        const origin=cells.findIndex(el=>el.dataset.focus===pending.origin);
        const target=cells[Math.min(origin+pending.cols,cells.length-1)];
        if(target)focus(target.dataset.focus);
      }else if(currentKey()==='retry-catalog'&&added.length){focus('card-'+added[0].id);}
    }
  }catch(error){
    homeFeed.loading=false;homeFeed.error=error instanceof Error?error.message:'Не удалось загрузить каталог';
    pendingCatalogFocus=null;
    if(route.name==='home'){syncCatalogStatus();toast('Следующая страница не загрузилась. Доступна кнопка повтора.');}
  }
}
function gridMarkupForLoaded(){return grid(homeFeed.items);}
function empty(){return `<div class="empty"><span class="empty-symbol">${icon('heartOff')}</span><h1>Твои любимые истории</h1><p>Пока здесь пусто. Добавь аниме в избранное из его карточки.</p><div class="actions">${button('home','Перейти на главную','home','btn primary')}</div></div>`;}
// Для будущих ИИ: дизайн заполненного «Избранного» идентичен главной.
// Визуальные отличия: заголовок «Избранное» над информацией об аниме и отсутствие сердечек.
// Не возвращайте сердечки на постеры в этом разделе: принадлежность к избранному уже очевидна.
// Сохраняйте общими grid/card, inspectorContent, стили home-shell/home-main,
// обновление информации при выборе постера, фокус и анимации; не создавайте отдельный дизайн.
// Отличается только источник списка: здесь сохранённые аниме, на главной — лента каталога.
function favorites(){
  const items=activeCatalogItems();
  return `<section class="catalog home-catalog favorites-catalog" aria-labelledby="favorites-title">${items.length?`<section id="catalog-inspector" class="catalog-inspector od-row-top" aria-label="О выбранном аниме">${inspectorContent()}</section><div class="home-grid-wrap">${grid(items)}</div>`:`<header class="section-header"><h1 id="favorites-title" class="section-title">Избранное</h1></header>${empty()}`}</section>`;
}
// Жанры и изображения: https://v31.astar.bz/thriller/, блок .block-janrs («Показать жанры»).
// source — исходная картинка; route — адрес категории сайта (не выводить из названия:
// /thriller/ у сайта означает «Боевики», а /horror/ — «Триллер»).
// Все изображения сохранены локально без изменения размера, исходная геометрия 219×92.
// filter связывает названия сайта с жанрами локальной подборки; это не полный каталог сайта.
const siteGenres=[
  {
    "name": "Боевики",
    "route": "/thriller/",
    "source": "https://v31.astar.bz/uploads/cat/boevik.jpg",
    "image": "assets/genres/boevik.jpg",
    "width": 219,
    "height": 92,
    "filter": "Экшен"
  },
  {
    "name": "Вампиры",
    "route": "/vampires/",
    "source": "https://v31.astar.bz/uploads/cat/vampiry.jpg",
    "image": "assets/genres/vampiry.jpg",
    "width": 219,
    "height": 92,
    "filter": "Вампиры"
  },
  {
    "name": "Детектив",
    "route": "/detective/",
    "source": "https://v31.astar.bz/uploads/cat/detektiv.jpg",
    "image": "assets/genres/detektiv.jpg",
    "width": 219,
    "height": 92,
    "filter": "Детектив"
  },
  {
    "name": "Драма",
    "route": "/drama/",
    "source": "https://v31.astar.bz/uploads/cat/drama.jpg",
    "image": "assets/genres/drama.jpg",
    "width": 219,
    "height": 92,
    "filter": "Драма"
  },
  {
    "name": "История",
    "route": "/history/",
    "source": "https://v31.astar.bz/uploads/cat/istoriya.jpg",
    "image": "assets/genres/istoriya.jpg",
    "width": 219,
    "height": 92,
    "filter": "История"
  },
  {
    "name": "Киберпанк",
    "route": "/cyberpunk/",
    "source": "https://v31.astar.bz/uploads/cat/kiberpank.jpg",
    "image": "assets/genres/kiberpank.jpg",
    "width": 219,
    "height": 92,
    "filter": "Киберпанк"
  },
  {
    "name": "Комедия",
    "route": "/comedy/",
    "source": "https://v31.astar.bz/uploads/cat/komediya.jpg",
    "image": "assets/genres/komediya.jpg",
    "width": 219,
    "height": 92,
    "filter": "Комедия"
  },
  {
    "name": "Махо-седзе",
    "route": "/maho-shoujo/",
    "source": "https://v31.astar.bz/uploads/cat/maho_sedze.jpg",
    "image": "assets/genres/maho_sedze.jpg",
    "width": 219,
    "height": 92,
    "filter": "Махо-седзе"
  },
  {
    "name": "Меха",
    "route": "/fur/",
    "source": "https://v31.astar.bz/uploads/cat/maho.jpg",
    "image": "assets/genres/maho.jpg",
    "width": 219,
    "height": 92,
    "filter": "Меха"
  },
  {
    "name": "Пародии",
    "route": "/parodies/",
    "source": "https://v31.astar.bz/uploads/cat/parodii.jpg",
    "image": "assets/genres/parodii.jpg",
    "width": 219,
    "height": 92,
    "filter": "Пародии"
  },
  {
    "name": "Сёнен",
    "route": "/senen/",
    "source": "https://v31.astar.bz/uploads/cat/senen.jpg",
    "image": "assets/genres/senen.jpg",
    "width": 219,
    "height": 92,
    "filter": "Сёнен"
  },
  {
    "name": "Спорт",
    "route": "/sports/",
    "source": "https://v31.astar.bz/uploads/cat/sport.jpg",
    "image": "assets/genres/sport.jpg",
    "width": 219,
    "height": 92,
    "filter": "Спорт"
  },
  {
    "name": "Мистика",
    "route": "/mysticism/",
    "source": "https://v31.astar.bz/uploads/cat/mistika.jpg",
    "image": "assets/genres/mistika.jpg",
    "width": 219,
    "height": 92,
    "filter": "Сверхъестественное"
  },
  {
    "name": "Музыкальное",
    "route": "/music/",
    "source": "https://v31.astar.bz/uploads/cat/musik.jpg",
    "image": "assets/genres/musik.jpg",
    "width": 219,
    "height": 92,
    "filter": "Музыкальное"
  },
  {
    "name": "Повседневность",
    "route": "/everyday-life/",
    "source": "https://v31.astar.bz/uploads/cat/povsednrvnost.jpg",
    "image": "assets/genres/povsednrvnost.jpg",
    "width": 219,
    "height": 92,
    "filter": "Повседневность"
  },
  {
    "name": "Приключения",
    "route": "/adventures/",
    "source": "https://v31.astar.bz/uploads/cat/priklucheniya.jpg",
    "image": "assets/genres/priklucheniya.jpg",
    "width": 219,
    "height": 92,
    "filter": "Приключения"
  },
  {
    "name": "Романтика",
    "route": "/romance/",
    "source": "https://v31.astar.bz/uploads/cat/romantika.jpg",
    "image": "assets/genres/romantika.jpg",
    "width": 219,
    "height": 92,
    "filter": "Романтика"
  },
  {
    "name": "Cедзе",
    "route": "/shoujo/",
    "source": "https://v31.astar.bz/uploads/cat/sedze.jpg",
    "image": "assets/genres/sedze.jpg",
    "width": 219,
    "height": 92,
    "filter": "Cедзе"
  },
  {
    "name": "Сёнен-ай",
    "route": "/senen-ay/",
    "source": "https://v31.astar.bz/uploads/cat/senen_ay.jpg",
    "image": "assets/genres/senen_ay.jpg",
    "width": 219,
    "height": 92,
    "filter": "Сёнен-ай"
  },
  {
    "name": "Триллер",
    "route": "/horror/",
    "source": "https://v31.astar.bz/uploads/cat/triller.jpg",
    "image": "assets/genres/triller.jpg",
    "width": 219,
    "height": 92,
    "filter": "Триллер"
  },
  {
    "name": "Ужасы",
    "route": "/horor/",
    "source": "https://v31.astar.bz/uploads/cat/uzhasy.jpg",
    "image": "assets/genres/uzhasy.jpg",
    "width": 219,
    "height": 92,
    "filter": "Ужасы"
  },
  {
    "name": "Фантастика",
    "route": "/fantasy/",
    "source": "https://v31.astar.bz/uploads/cat/fantastika.jpg",
    "image": "assets/genres/fantastika.jpg",
    "width": 219,
    "height": 92,
    "filter": "Фантастика"
  },
  {
    "name": "Фэнтeзи",
    "route": "/fentezi/",
    "source": "https://v31.astar.bz/uploads/cat/fentesy.jpg",
    "image": "assets/genres/fentesy.jpg",
    "width": 219,
    "height": 92,
    "filter": "Фэнтези"
  },
  {
    "name": "Школа",
    "route": "/school/",
    "source": "https://v31.astar.bz/uploads/cat/school.jpg",
    "image": "assets/genres/school.jpg",
    "width": 219,
    "height": 92,
    "filter": "Школа"
  },
  {
    "name": "Эччи",
    "route": "/echchi-erotic/",
    "source": "https://v31.astar.bz/uploads/cat/echi.jpg",
    "image": "assets/genres/echi.jpg",
    "width": 219,
    "height": 92,
    "filter": "Эччи"
  }
];
function genres(){
  // Тот же MediaCard, что на главной: меняется только preset landscape.
  // Исходные картинки жанров 219×92; фокус и анимацию здесь не дублировать.
  return `<section class="catalog home-catalog genres-catalog" aria-labelledby="genres-title"><header class="section-header"><h1 id="genres-title" class="section-title">Жанры</h1></header><div class="od-grid genre-card-grid" data-grid>${siteGenres.map((g,i)=>mediaCard({title:g.name,image:g.image,imageWidth:g.width,imageHeight:g.height,variant:'landscape',action:'genre',genre:g.name,focusKey:'genre-'+i})).join('')}</div></section>`;
}
// Для будущих ИИ: выдача жанра повторяет главную и «Избранное» один в один:
// те же card/grid, закреплённый inspectorContent, описание по фокусу и анимации.
// Отличаются от главной только фильтр списка и заголовок с названием жанра.
// Заголовок имеет тот же section-title, что «Избранное»; отдельный стиль не добавлять.
// Сердечки скрываются только в «Избранном», в выдаче жанра показывают сохранённый статус.
// UI Kit / CatalogFeedback: ошибка загрузки и пустая выдача — разные состояния.
// Для будущих ИИ: «Вампиры» намеренно показывают ошибку каталога в прототипе.
// «Повторить» имитирует запрос и снова показывает ошибку: реального API здесь нет.
// «Детектив» — пример пустой выдачи, НЕ ошибка сети. Не показывать retry для пустоты.
// В production брать состояние из репозитория, убрать привязку к названиям жанров.
// Все цвета/иконки/кнопки общие; заголовок раздела сохраняется, фокус — на действии.
// КАРТА ДЛЯ БУДУЩЕЙ РАЗРАБОТКИ:
// 1. Открыть «Жанры» → «Вампиры»: genreCatalogError() принудительно включает failed.
// 2. Открыть «Жанры» → «Детектив»: activeCatalogItems() возвращает пустой массив
//    локальных данных; browse() вызывает catalogFeedback(false). Это успешная пустая
//    выдача, а не подтверждение отсутствия аниме на настоящем сайте.
// 3. catalogFeedback(failed) — общий renderer обоих состояний; оформление в app.css
//    под CatalogFeedback / UI Kit. Не копировать отдельную разметку под каждый жанр.
// 4. retryGenreCatalog(): route.catalogRetrying блокирует повторные клики, 800 мс —
//    только имитация. Заменить задержку загрузкой исходной страницы выбранного жанра
//    через существующий репозиторий/HTML-парсер AniStar (отдельного API нет).
//    Не трактовать ошибку сети или парсинга как успешный пустой список.
// 5. При успехе показать общую grid(items) и inspectorContent(); при ошибке оставить
//    «Повторить», после успеха фокус на первой карточке. Сохранять жанр и прокрутку.
// 6. origin защищает от позднего ответа после перехода. Во Flutter дополнительно
//    отменять устаревшие запросы/использовать request ID и проверять mounted.
// 7. chooseAnotherGenre() возвращает в жанры с прежним фокусом, если они в history.
//    На ТВ доступны стрелки/OK/Back; сообщения озвучиваются через alert/status,
//    загрузка помечена aria-busy. Не переносить тестовую привязку «Вампиры» в production.
function genreCatalogError(){return route.name==='browse'&&(!route.filterType||route.filterType==='genre')&&route.genre==='Вампиры';}
function catalogFeedback(failed){
  const loading=failed&&!!route.catalogRetrying;
  return `<div class="catalog-feedback" ${failed?'role="alert"':'role="status"'} aria-busy="${loading}">${icon(loading?'loading':failed?'alert':'grid')}<h2>${loading?'Загружаем каталог…':failed?'Не удалось загрузить каталог':'Ничего не найдено'}</h2><p>${loading?'Подождите немного.':failed?'Не удалось получить список аниме. Проверьте подключение и попробуйте ещё раз.':'По этому фильтру пока нет аниме. Попробуйте выбрать другой жанр.'}</p><div class="catalog-feedback-actions od-cluster">${failed?button('retry-genre',loading?'Загружаем…':'Повторить',loading?'':'refresh','btn primary',`aria-disabled="${loading}" aria-busy="${loading}"`):''}${button('choose-genres','Выбрать другой жанр','','btn'+(failed?'':' primary'))}</div></div>`;
}
function retryGenreCatalog(){
  if(!genreCatalogError()||route.catalogRetrying)return;
  const origin=route;route.catalogRetrying=true;render('retry-genre');
  setTimeout(()=>{origin.catalogRetrying=false;if(route===origin)render('retry-genre');},800);
}
function chooseAnotherGenre(){
  if(history[history.length-1]?.route.name==='genres')back();else go({name:'genres'});
}
// ВРЕМЕННЫЙ СЦЕНАРИЙ для будущих ИИ: «Жанры» → «Драма» показывает истёкшую сессию.
// Это НЕ реальный ответ сайта и не обычная ошибка каталога. В production убрать
// привязку к жанру: состояние должно приходить из AuthController/AuthRepository.expired.
// Использовать единое событие истечения сессии, не показывать несколько экранов
// из параллельных запросов. Не удалять избранное и историю, не считать 403 всегда
// истёкшей сессией: брать категорию ошибки из существующего клиента AniStar.
// «Войти снова» открывает общую login(); Back возвращает к жанрам. После успешного
// реального входа можно повторить исходный запрос с восстановлением контекста.
// Здесь тестовый вход ведёт на главную. Демонстрация НЕ изменяет настоящую сессию.
function genreSessionExpired(){return route.name==='browse'&&(!route.filterType||route.filterType==='genre')&&route.genre==='Драма';}
function sessionExpiredFeedback(){
  return `<div class="catalog-feedback" role="alert">${icon('user')}<h2>Сессия истекла</h2><p>Войдите в аккаунт снова, чтобы продолжить.</p><div class="catalog-feedback-actions od-cluster">${button('session-login','Войти снова','user','btn primary')}${button('choose-genres','К жанрам','','btn')}</div></div>`;
}
function browse(){
  const items=activeCatalogItems(),failed=genreCatalogError(),expired=genreSessionExpired();
  return `<section class="catalog home-catalog browse-catalog ${expired||failed||!items.length?'catalog-state-page':''}" aria-labelledby="browse-title">${!expired&&!failed&&items.length?`<section id="catalog-inspector" class="catalog-inspector od-row-top" aria-label="О выбранном аниме">${inspectorContent()}</section><div class="home-grid-wrap">${grid(items)}</div>`:`<header class="section-header">${catalogSectionHeading()}</header>${expired?sessionExpiredFeedback():catalogFeedback(failed)}`}</section>`;
}
// UI Kit: серии используют тот же MediaCard landscape, что карточки жанров:
// изображение, нижнее затемнение и только подпись «Серия N», без номера слева и статуса.
// Для будущих ИИ: на ТВ обязательно ТРИ карточки в ряду (.episode-card-grid),
// не уменьшать сетку до двух на обычной ширине ТВ-превью.
// Эти локальные картинки AniStar из блока жанров — временные демонстрационные иллюстрации
// 219×92, НЕ кадры соответствующих серий. При подключении сервиса заменить реальными
// превью из данных эпизода; не выдавать эти иллюстрации за реальные сцены серии.
const episodeDemoImages=['assets/genres/priklucheniya.jpg','assets/genres/drama.jpg','assets/genres/fentesy.jpg'];
// UI Kit / EpisodeOrder — единый порядок отображения в карточке и выборе плеера.
// Для будущих ИИ: сначала ПОСЛЕДНЯЯ доступная серия, затем по убыванию до первой.
// В прототипе номера последовательные; в Flutter сортировать реальные доступные
// эпизоды по числовому номеру DESC на копии списка, не по тексту/индексу карточки.
// Сохранять исходные episode ID/номер/URL и ключи фокуса: порядок не меняет их.
// «Следующая/предыдущая», история и выбор продолжения работают по номеру серии,
// а не позиции в этой выдаче. Известный TODO кнопки «Смотреть» — отдельный алгоритм.
function episodeNumbersDescending(a){
  return Array.from({length:a.episodes},(_,i)=>a.episodes-i);
}
function episode(a,n){
  return mediaCard({title:'Серия '+n,image:episodeDemoImages[(n-1)%episodeDemoImages.length],
    imageWidth:219,imageHeight:92,variant:'landscape',action:'play',id:a.id,
    episodeNumber:n,focusKey:'episode-'+n});
}
// UI Kit / MetadataFilter: год, жанры и режиссёр — действия фильтрации, НЕ статичные теги.
// Для будущих ИИ: на сайте эти поля служат фильтрами. В приложении каждое значение
// должно быть достижимо фокусом ТВ-пульта и запускать соответствующую выдачу по OK.
// Использовать общие btn, focus и AppMotion, как у «В избранное»; не заменять на span.
// Прототип фильтрует локальные записи. При подключении парсера передавать реальные
// ссылки фильтров из сайта, а не конструировать адрес режиссёра/года по подписи.
// Проверенный пример источника (карточка Фрирен, 22.10.2026):
// https://v31.astar.bz/9576-provozhayuschaya-v-posledniy-put-friren-sousou-no-frieren.html
// Метаданные находятся в .news_text ul.head > li: подпись поля в <b>, фильтры в <a href>.
// • Год выпуска «2023» → /filter/year/2023/ (аниме за выбранный год).
// • Жанр «Драма» → /filter/janrs/%C4%F0%E0%EC%E0/ (аниме того же жанра).
// • Режиссёр «Кэйитиро Сайто» →
//   /filter/director/%CA%FD%E9%E8%F2%E8%F0%EE+%D1%E0%E9%F2%EE/ (работы режиссёра).
// Важно: janrs — фактическое написание пути на сайте. Проценты в этих href кодируют
// Windows-1251, а пробелы могут быть «+»: сохранять href, не пересобирать через UTF-8.
// Каждый жанр — самостоятельный фильтр; нажатие открывает отдельную выдачу,
// а не включает несколько условий сразу. После Back восстанавливать кнопку и прокрутку.
// Дополнительно на этой карточке есть ссылки /filter/manga/ и /filter/author/:
// это возможные будущие фильтры по манге и автору, сейчас в прототипе не реализованы.
// «Озвучка» и «Серии» в проверенной карточке — обычный текст без ссылки:
// не делать их фильтрами только из-за соседства с активными полями.
// Для парсера хранить type, value/label и исходный sourceUrl для каждого фильтра;
// относительный href разрешать относительно адреса карточки, не привязывать к v31 навсегда.
// Иконка Lucide list-filter слева — единая подсказка: это фильтр, а не статичная подпись.
// Сохранять её у года, жанра и режиссёра вместе с текстом и фокусом ТВ-пульта.
// Год/каждый жанр/режиссёр в карточке — именно CatalogFilter, а не сортировка.
// Они открывают browse с filterType/value, где доступна одна и та же CatalogSort.
// Сохранять исходный href как CatalogFilter.path и применять сортировку вместе с ним,
// не сбрасывать выбранный жанр/режиссёра/год при смене criterion/ascending.
// Один renderer metadataFilter() и один класс .metadata-chip для ВСЕХ типов фильтров.
// Не заводить отдельные стили кнопок года, жанра или режиссёра.
function metadataFilter(type,value,label,key){
  return button('filter',label,'filter','btn metadata-chip',`data-filter-type="${esc(type)}" data-filter-value="${esc(value)}" data-focus="${esc(key)}" aria-label="${esc('Показать аниме: '+label)}"`);
}
// Для будущих ИИ: в полной карточке избранное переключается прямым запросом,
// БЕЗ правой панели. Панель favoriteSheet — отдельный сценарий долгого нажатия
// на постер каталога. Не объединять эти действия при переносе во Flutter.
// Состояние, текст и Lucide-иконку менять только после успешного ответа;
// при ошибке сохранять прежнее состояние и разрешать повтор. Сейчас запрос имитируется.
const pendingFavorites=new Set();
function detailFavoriteButton(id){
  const busy=pendingFavorites.has(id),saved=fav.has(id);
  return button('favorite-toggle',busy?'Сохраняем…':saved?'В избранном':'В избранное',saved?'heartMinus':'heartPlus','btn',`data-id="${esc(id)}" aria-pressed="${saved}" aria-busy="${busy}" aria-disabled="${busy}"`);
}
function syncDetailFavorite(id){
  const b=document.querySelector('[data-action="favorite-toggle"]');
  if(!b||b.dataset.id!==id)return;
  const busy=pendingFavorites.has(id),saved=fav.has(id);
  b.innerHTML=icon(saved?'heartMinus':'heartPlus')+`<span>${busy?'Сохраняем…':saved?'В избранном':'В избранное'}</span>`;
  b.setAttribute('aria-pressed',String(saved));
  b.setAttribute('aria-busy',String(busy));
  b.setAttribute('aria-disabled',String(busy));
}
async function toggleDetailFavorite(id){
  if(pendingFavorites.has(id))return;
  const nextSaved=!fav.has(id);
  pendingFavorites.add(id);
  syncDetailFavorite(id); // Не заменять кнопку: фокус пульта остаётся на том же элементе.
  try{
    // При интеграции заменить задержку запросом добавления/удаления и проверить ответ.
    await new Promise(resolve=>setTimeout(resolve,650));
    nextSaved?fav.add(id):fav.delete(id);
    save();
    toast(nextSaved?'Добавлено в избранное':'Удалено из избранного');
  }catch{
    toast('Не удалось изменить избранное. Попробуйте ещё раз.');
  }finally{
    pendingFavorites.delete(id);
    syncDetailFavorite(id);
    if(['home','favorites','browse'].includes(route.name)&&!$('.overlay')){
      render(currentKey(),$('#main')?.scrollTop||0);
    }
  }
}
function detailFilters(a,c){
  // Иерархия: название → рейтинг/год → жанры → режиссёр → просмотр/избранное.
  // Год находится рядом с рейтингом; действия просмотра и избранного идут ниже режиссёра.
  // Это всё ещё MetadataFilter: доступность с пульта и поведение фильтра сохранять.
  return `<div class="detail-filters od-stack"><div class="detail-filter-row"><span class="detail-filter-label" id="detail-genres-label">Жанры</span><div class="od-cluster" role="group" aria-labelledby="detail-genres-label">${(c.genres||a.genre).map((g,i)=>metadataFilter('genre',g,g,'detail-genre-'+i)).join('')}</div></div>${c.director?`<div class="detail-filter-row"><span class="detail-filter-label" id="detail-director-label">Режиссёр</span><div class="od-cluster" role="group" aria-labelledby="detail-director-label">${metadataFilter('director',c.director,c.director,'detail-director')}</div></div>`:''}</div>`;
}
// Название тайтла расположено над постером и информацией; размер --home-title,
// как у выбранного аниме в информационной панели главной. Не возвращать display-размер.
// Публикация: сообщение о серии и дата идут отдельным блоком НИЖЕ описания.
// Для будущих ИИ/парсера: брать готовый текст даты из .date-icon на странице тайтла.
// Пример Фрирен: «22-03-2024, 19:05». Сохранять строку в publishedAt как есть.
// НЕ использовать Date/DateTime, локализацию, часовые пояса, «сегодня/вчера» или
// собственный пересчёт/форматирование. Это дата публикации сайта, не дата выхода серии.
// Выводить текст безопасно через esc(); отсутствующую дату скрывать, не вычислять.
function detailPublication(c){
  if(!c.updateText&&!c.publishedAt)return '';
  return `<aside class="detail-update od-stack" aria-label="Обновление и публикация">${publicationText(c,'detail-publication-message','detail-publication-date')}</aside>`;
}
// HeroMagia: .detail-poster — точка назначения постера из card(), с тем же Hero tag.
// Общий элемент — именно постер тайтла, а не демонстрационные изображения эпизодов.
// UI Kit: ссылки франшизы идут ПОСЛЕ описания, публикации и сведений, ПЕРЕД сериями.
// Нет ссылок — нет заголовка, пустой секции или лишнего отступа. Фокус обязателен.
// Пункты могут быть сезонами, частями, OVA/ONA, спецвыпусками и фильмами.
// Всегда показывать исходный label сайта целиком: НЕ сокращать ТВ-N до «N сезон».
// Пример /10911-.html: «Блич [ТВ-2] Часть 1» … «Блич [ТВ-2] Часть 4» —
// прежнее сокращение делало четыре разных пункта одинаковыми «2 сезон».
// Исходные label/url и порядок DOM сохранять; не определять формат по догадке.
// «Открыто» — только отметка текущей страницы по стабильному ID, не статус просмотра.
// Она не меняет историю эпизодов, не отправляет запрос и не создаёт повторный переход.
// Если ID неизвестен, не отмечать ни один пункт; не сравнивать названия.
// В Flutter переходить через загрузчик полной карточки по sourceUrl, не открывать браузер.
function detailWatchOrder(c){
  const links=(c.watchOrder||[]).filter(entry=>entry.label&&/^https?:\/\//i.test(entry.url));
  if(!links.length)return '';
  const sourceId=c.sourceId||(route.id==='frieren'?'9576':'');
  return `<section class="detail-watch-order" aria-labelledby="watch-order-title"><h2 id="watch-order-title">Порядок просмотра</h2><ol class="watch-order-list od-cluster">${links.map((entry,i)=>{
    const label=entry.label;
    let pageId;
    try{pageId=new URL(entry.url).pathname.match(/^\/(\d+)(?:-|\.html|\/|$)/)?.[1]}catch{return ''}
    const current=!!sourceId&&!!pageId&&pageId===String(sourceId);
    const id=pageId==='9576'?'frieren':relatedTitles.find(a=>a.sourceId===pageId)?.id;
    return `<li>${current?`<span class="btn watch-order-link is-current" aria-current="page">${icon('check')}<span>${esc(label)}</span><span class="watch-order-current">Открыто</span></span>`:id?button('detail',label,'','btn watch-order-link',`data-id="${esc(id)}" data-focus="watch-order-${i}" title="${esc(entry.label)}"`):`<a class="btn watch-order-link" href="${esc(entry.url)}" data-focus="watch-order-${i}">${esc(label)}</a>`}</li>`;
  }).join('')}</ol></section>`;
}
function detail(){
  const a=item(route.id),c=catalogRecord(a);
  // TODO / баг выбора продолжения (пока НЕ исправлен, отмечен по запросу пользователя).
  // Сейчас find() идёт от серии 1 и берёт первый пробел в watched: при пропущенной 1-й
  // и просмотренных 2-й, 3-й кнопка ошибочно предлагает «Смотреть серию 1».
  // Нужно искать максимальный номер просмотренной серии ЭТОГО аниме и предлагать
  // следующую доступную после него: {2,3} → 4, {1,3} → 4, пустая история → 1.
  // Ранние пропуски не должны возвращать кнопку к началу. Разбирать номера как числа,
  // не сортировать строковые ключи лексикографически (10 не должно идти перед 2).
  // В будущем брать реальные доступные эпизоды из парсера; не предлагать отсутствующую
  // серию или N+1 после финала — для конца списка предусмотреть «Посмотреть снова».
  // Сейчас watched пополняется при запуске play(), а не по факту просмотра:
  // при исправлении подключить настоящий прогресс, не приравнивать запуск к просмотру.
  // Один вычисленный эпизод должен задавать И текст кнопки, И её data-episode.
  const n=Array.from({length:a.episodes},(_,i)=>i+1).find(n=>!watched.has(a.id+':'+n))||1;
  const rating=typeof c.rating==='number'&&Number.isFinite(c.rating)?c.rating:null;
  // Эти поля уже присутствуют в данных каталога/страницы тайтла; отсутствующие не выдумывать.
  // seriesInfo — сведения о выпуске на сайте, a.episodes — длина списка прототипа.
  // Не выдавать число эпизодов в описании за фактическое число доступных видеоссылок.
  const facts=[['Выпуск',c.seriesInfo],['Озвучка',c.voiceover]].filter(([,v])=>v);
  return `<div class="detail-page"><h1 id="anime-title" class="anime-title detail-title">${esc(a.title)}</h1><section class="detail-intro" aria-labelledby="anime-title"><div class="detail-poster">${poster(a)}</div><div class="detail-overview od-stack"><div class="detail-meta od-cluster">${rating!==null?`<span class="detail-rating od-nowrap" aria-label="Рейтинг ${rating.toFixed(1)} из 10">${icon('star')}<strong>${rating.toFixed(1).replace('.',',')}</strong><span>/ 10</span></span>`:''}${metadataFilter('year',String(a.year),String(a.year),'detail-year')}</div>${detailFilters(a,c)}<div class="actions detail-actions">${button('play','Смотреть серию '+n,'play','btn primary',`data-id="${a.id}" data-episode="${n}"`)}${detailFavoriteButton(a.id)}</div></div></section><section class="detail-description" aria-labelledby="description-title"><h2 id="description-title">О сюжете</h2><p>${esc(c.description||a.desc)}</p></section>${detailPublication(c)}${facts.length?`<section class="detail-credits" aria-label="Сведения об аниме"><dl>${facts.map(([label,value])=>`<div class="od-field"><dt>${esc(label)}</dt><dd>${esc(value)}</dd></div>`).join('')}</dl></section>`:''}${detailWatchOrder(c)}<section class="detail-episodes" aria-labelledby="episodes-title"><div class="section-head"><h2 id="episodes-title">Серии</h2><span class="count od-nowrap">В списке: ${a.episodes}</span></div><div class="od-grid episode-card-grid" data-grid>${episodeNumbersDescending(a).map(n=>episode(a,n)).join('')}</div></section></div>`;
}
// TV Login / UI Kit: общий AppColors, AppMotion, радиусы controls и Lucide AppIcon.
// ТВ — основной сценарий: форма в безопасной области, крупный текст и явный фокус.
// Во Flutter OK на TextField открывает системную ТВ-клавиатуру; не рисовать свою
// клавиатуру в HTML. Up/Down перемещают фокус, Left/Right редактируют текст.
// Кнопка глаза меняет только видимость пароля; не перестраивать форму, не терять ввод.
// Важно: авторизация пока локальная имитация. Учётные данные НЕ отправлять/сохранять
// и не выводить в консоль. Подключение реального AuthRepository — отдельная работа.
// Технические пояснения остаются здесь, не возвращать их в пользовательский экран.
function login(){
  return `<main class="login tv-login"><section class="login-copy" aria-label="AniStar TV">${brand()}</section><form class="login-form" id="login" novalidate aria-labelledby="login-title"><h1 id="login-title">Вход в аккаунт</h1><div id="error-summary" role="alert"></div><div class="field"><label for="username">Логин</label><input id="username" data-focus="username" autocomplete="username" autocapitalize="none" spellcheck="false" required aria-describedby="username-error"><span id="username-error" class="error" aria-live="polite"></span></div><div class="field"><label for="password">Пароль</label><div class="password-field"><input id="password" data-focus="password" type="password" autocomplete="current-password" required aria-describedby="password-error"><button class="btn password-visibility" type="button" data-action="toggle-password" data-focus="toggle-password" aria-label="Показать пароль" aria-pressed="false" aria-controls="password">${icon('eye')}</button></div><span id="password-error" class="error" aria-live="polite"></span></div><div id="auth-error" class="auth-feedback" role="alert" aria-live="assertive"></div><div class="login-actions od-stack"><button class="btn primary" type="submit" data-focus="login-submit">Войти</button><button class="btn login-guest" type="button" data-action="home" data-focus="login-guest"><span>Продолжить без входа</span></button></div></form></main>`;
}
function togglePasswordVisibility(){
  const input=$('#password'),control=document.querySelector('[data-action="toggle-password"]');
  if(!input||!control)return;
  const reveal=input.type==='password';input.type=reveal?'text':'password';
  control.innerHTML=icon(reveal?'eyeOff':'eye');
  control.setAttribute('aria-label',reveal?'Скрыть пароль':'Показать пароль');
  control.setAttribute('aria-pressed',String(reveal));
}
// Однозначные вертикальные переходы пульта. Глаз доступен вправо в конце пароля
// или через Tab; в остальном стрелки Left/Right продолжают редактировать поле.
document.addEventListener('keydown',e=>{
  if(route.name!=='login'||$('.overlay'))return;
  const key=currentKey(),rows=['username','password','login-submit','login-guest'];
  if(e.key==='ArrowUp'||e.key==='ArrowDown'){
    const index=key==='toggle-password'?1:rows.indexOf(key);
    if(index<0)return;
    e.preventDefault();e.stopImmediatePropagation();
    focus(rows[Math.max(0,Math.min(rows.length-1,index+(e.key==='ArrowUp'?-1:1)))],true);
  }else if(e.key==='ArrowRight'&&key==='password'&&document.activeElement.selectionEnd===document.activeElement.value.length){
    e.preventDefault();e.stopImmediatePropagation();focus('toggle-password',true);
  }else if(e.key==='ArrowLeft'&&key==='toggle-password'){
    e.preventDefault();e.stopImmediatePropagation();focus('password',true);
  }
},true);

function fmt(n){n=Math.max(0,Math.floor(Number(n)||0));return Math.floor(n/60)+':'+String(n%60).padStart(2,'0')}
// TV Player / UI Kit. Компоновка из Flutter PlayerOverlay:
// lib/packages/features/player/presentation/widgets/player_overlay.dart.
// Название/серия сверху; timeline снизу; play, seek, prev/next, время слева,
// выбор серии/качество справа. Все иконки — общий AppIcon/Lucide.
// ОБЯЗАТЕЛЬНО: на ТВ НЕТ экранной кнопки «К сериям»/назад. Возврат — Back пульта.
// Такая кнопка нужна ТОЛЬКО мобильному плееру, не добавлять её по ширине окна.
// 4 секунды — таймер исходного Flutter player_screen.dart. На паузе/в панели
// управление не скрывать. Скрытые кнопки исключать из фокуса, OK/стрелки возвращают UI.
// Тестовый трейлер Big Buck Bunny: WebM VP8/Vorbis — основной формат,
// MP4 H.264/AAC — запасной. Не считать поддержку MP4 гарантированной в превью.
// По запросу пользователя не включать MP4 в ассеты проекта; нужен доступ в интернет.
// Источники: https://dl6.webmfiles.org/big-buck-bunny_trailer.webm
// и https://media.w3.org/2010/05/bunny/trailer.mp4 — Blender Foundation,
// Big Buck Bunny, CC BY 3.0. Только для теста UI; все серии запускают один этот ролик.
// Реальные currentTime/duration и события media управляют UI вместо таймера демо.
// При переносе во Flutter подключить нативный VideoPlayer и реальные URL серий.
// Качество тестового файла одно; не выдавать смену подписи за смену видеопотока.
// Для будущих ИИ: ссылки testSources ТОЛЬКО тестовые, не URL серий AniStar.
// При реальной интеграции заменить их данными PlaybackSession, не оставлять в production.
// Скрытие повторяет player_view.dart: AnimatedOpacity(AppMotion.fast), IgnorePointer,
// ExcludeSemantics и ExcludeFocus. Скрывается весь overlay с затемнением, не VideoPlayer.
// Таймер/пауза/scrubbing — player_screen.dart: _scheduleControlsHide/_onControlsTimer.
// Скрыть overlay ≠ закрыть плеер: видео продолжает играть. Back вызывает возврат
// к сериям (_backToEpisodes/maybePop), останавливает видео и удаляет таймер UI.
// На ТВ не добавлять экранную кнопку возврата; onVideoTap только показывает UI.
let playerControlsTimer=null,playerControlsVisible=true,playerTransportKey='toggle',playerScrubbing=false;
let mediaDuration=0,mediaEpisodeKey='';
const testVideo=document.createElement('video');
testVideo.className='player-video';
// HTTP 200 не означает поддержку кодека во встроенном браузере.
// Выбирать формат через canPlayType; запрет play не скрывать и не обходить.
const testSources=[
  {url:'https://dl6.webmfiles.org/big-buck-bunny_trailer.webm',type:'video/webm; codecs="vp8, vorbis"'},
  {url:'https://media.w3.org/2010/05/bunny/trailer.mp4',type:'video/mp4; codecs="avc1.4D401E, mp4a.40.2"'},
  {url:'https://media.w3.org/2010/05/bunny/trailer.ogv',type:'video/ogg; codecs="theora, vorbis"'}
];
let testSourceIndex=testSources.findIndex(source=>testVideo.canPlayType(source.type)!=='');
if(testSourceIndex<0)testSourceIndex=0;
testVideo.src=testSources[testSourceIndex].url;
let attemptedTestSources=new Set([testSourceIndex]);
// UI Kit / PlaybackFeedback: паттерн Flutter PlayerRetryView/TvStateView.
// Impeccable harden: понятная причина + действие, без кодов исключений на экране.
// Технические детали остаются в console.warn, не в пользовательском сообщении.
// loading — начальная загрузка; buffering — поверх текущего кадра без seek/reset.
// При ошибке фокус на «Повторить», Back пульта возвращает к сериям. Экранного Back нет.
// Только для просмотра макета: каждая новая сессия jujutsu («Магическая битва»)
// намеренно начинает с ошибки. «Повторить» отключает имитацию и запускает тестовый URL.
// Этот сценарий удалить при подключении реального PlaybackSession, не менять парсер.
let mediaState='ready',mediaFailureText='',simulatedVideoFailure=false,mediaStateTimer=null;
function renderPlaybackFeedback(){
  const main=$('.tv-player'),stage=$('#playback-feedback');
  if(route.name!=='player'||!main||!stage)return;
  const failed=mediaState==='error',busy=['loading','buffering'].includes(mediaState);
  main.classList.toggle('has-video-error',failed);
  main.dataset.mediaState=mediaState;
  const center=main.querySelector('.mobile-player-center');
  if(center){center.inert=failed||busy||!playerControlsVisible;center.setAttribute('aria-hidden',String(failed||busy));}
  stage.setAttribute('aria-busy',String(busy));
  stage.innerHTML=failed?`<section class="playback-feedback playback-failure" role="alert" aria-labelledby="video-error-title">${icon('alert')}<h2 id="video-error-title">Не удалось загрузить видео</h2><p>${esc(mediaFailureText)}</p>${button('retry-video','Повторить','refresh','btn primary')}</section>`:busy?`<div class="playback-feedback playback-wait" role="status">${icon('loading')}<p>${mediaState==='buffering'?'Буферизация…':'Загружаем видео…'}</p></div>`:'';
  const controls=main.querySelector('.playback');
  if(controls){controls.inert=failed;failed?controls.setAttribute('aria-hidden','true'):controls.removeAttribute('aria-hidden');}
  if(failed){clearTimeout(playerControlsTimer);showPlayerControls(false);focus('retry-video',true);}
}
function setMediaState(next,message=''){
  clearTimeout(mediaStateTimer);mediaStateTimer=null;
  if(simulatedVideoFailure&&next!=='error')return;
  mediaState=next;mediaFailureText=message;
  if(next!=='ready')clearTimeout(playerControlsTimer);
  renderPlaybackFeedback();
  if(next==='ready')armPlayerControls();
}
function scheduleMediaWait(next){
  if(route.name!=='player'||simulatedVideoFailure||mediaState==='error')return;
  clearTimeout(mediaStateTimer);
  mediaStateTimer=setTimeout(()=>{if(route.name==='player'&&!simulatedVideoFailure)setMediaState(next);},300);
}
function retryVideo(){
  if(route.name!=='player')return;
  simulatedVideoFailure=false;testVideo.pause();setMediaState('loading');
  if(testVideo.error){attemptedTestSources=new Set([testSourceIndex]);testVideo.src=testSources[testSourceIndex].url;testVideo.load();}
  if(testVideo.readyState>=2)setMediaState('ready');
  focus('toggle',true);
  toggleMedia();
}
function reportMediaFailure(error){
  if(route.name!=='player'||simulatedVideoFailure)return;
  const code=testVideo.error?.code;
  if(error?.name==='AbortError'||code===1)return;
  playing=false;syncMediaButton();showPlayerControls();
  let message;
  if(error?.name==='NotAllowedError')message='Браузер не разрешил запуск. Нажмите «Повторить», чтобы запустить видео.';
  else if(code===2)message='Проверьте подключение к интернету и попробуйте ещё раз.';
  else if(code===3)message='Не удалось прочитать видео. Попробуйте загрузить его ещё раз.';
  else if(code===4||error?.name==='NotSupportedError')message='Источник недоступен или формат не поддерживается. Попробуйте ещё раз.';
  else message='Не удалось начать воспроизведение. Попробуйте ещё раз.';
  console.warn('Test video playback',{source:testVideo.currentSrc||testVideo.src,mediaCode:code,detail:testVideo.error?.message||error?.message});
  testVideo.pause();setMediaState('error',message);
}
function tryAlternateTestSource(){
  const next=testSources.findIndex((source,i)=>!attemptedTestSources.has(i)&&testVideo.canPlayType(source.type)!=='');
  if(next<0)return false;
  attemptedTestSources.add(next);testSourceIndex=next;mediaDuration=0;position=0;
  testVideo.src=testSources[next].url;testVideo.load();
  if(route.name==='player'){syncPlayerPosition();setMediaState('loading');}
  return true;
}
testVideo.preload='metadata';testVideo.playsInline=true;testVideo.tabIndex=-1;
testVideo.setAttribute('aria-label','Тестовый трейлер Big Buck Bunny');
// Геометрию и качество брать из metadata самого тестового файла.
function syncMediaButton(){
  if(route.name!=='player')return;
  const b=document.querySelector('[data-action="toggle"]');if(!b)return;
  const label=playing?'Пауза':'Воспроизвести';
  b.innerHTML=icon(playing?'pause':'play')+`<span class="sr-only">${label}</span>`;
  b.setAttribute('aria-label',label);b.setAttribute('title',label);b.setAttribute('aria-pressed',String(playing));
}
function mountTestVideo(){
  if(route.name!=='player'){releasePlayerOrientation();clearTimeout(mediaStateTimer);mediaEpisodeKey='';testVideo.pause();return;}
  const key=route.id+':'+route.episode;
  const changed=mediaEpisodeKey!==key;
  if(changed){clearTimeout(mediaStateTimer);mediaEpisodeKey=key;testVideo.currentTime=0;position=0;simulatedVideoFailure=route.id==='jujutsu';mediaState=simulatedVideoFailure?'error':testVideo.readyState>=2?'ready':'loading';mediaFailureText=simulatedVideoFailure?'Не удалось подключиться к видео. Попробуйте загрузить серию ещё раз.':'';}
  if(simulatedVideoFailure)testVideo.pause();
  const host=$('.tv-player');if(host&&!host.contains(testVideo))host.prepend(testVideo);
  mediaDuration=Number.isFinite(testVideo.duration)?testVideo.duration:0;
  syncPlayerPosition();syncMediaButton();renderPlaybackFeedback();
}
function toggleMedia(){
  if(simulatedVideoFailure||mediaState==='error')return;
  if(testVideo.paused){
    if(testVideo.ended)testVideo.currentTime=0;
    if(testVideo.readyState<2)scheduleMediaWait('loading');
    const requestedSource=testVideo.src;
    testVideo.play().catch(error=>{if(requestedSource!==testVideo.src)return;if(error.name==='NotSupportedError'&&tryAlternateTestSource())return;reportMediaFailure(error);});
  }else testVideo.pause();
}
function seekMedia(value){
  if(!mediaDuration)return;
  position=Math.max(0,Math.min(mediaDuration,value));testVideo.currentTime=position;
  syncPlayerPosition();armPlayerControls();
}
testVideo.addEventListener('loadedmetadata',()=>{mediaDuration=testVideo.duration;quality=testVideo.videoHeight+'p';const b=document.querySelector('[data-action="quality"]');if(b){b.querySelector('span').textContent=quality;b.setAttribute('aria-label','Качество: '+quality);}syncPlayerPosition();});
testVideo.addEventListener('timeupdate',()=>{if(route.name==='player'){position=testVideo.currentTime;if(playerControlsVisible)syncPlayerPosition();}});
testVideo.addEventListener('play',()=>{if(simulatedVideoFailure){testVideo.pause();return;}playing=true;syncMediaButton();armPlayerControls();});
testVideo.addEventListener('pause',()=>{playing=false;syncMediaButton();if(route.name==='player')showPlayerControls();});
testVideo.addEventListener('ended',()=>{playing=false;syncMediaButton();showPlayerControls();});
testVideo.addEventListener('error',()=>{if(simulatedVideoFailure)return;if(!tryAlternateTestSource())reportMediaFailure(testVideo.error);});
testVideo.addEventListener('loadstart',()=>scheduleMediaWait('loading'));
testVideo.addEventListener('waiting',()=>scheduleMediaWait(testVideo.currentTime>0?'buffering':'loading'));
testVideo.addEventListener('stalled',()=>{if(playing)scheduleMediaWait('buffering');});
testVideo.addEventListener('canplay',()=>{if(route.name==='player')setMediaState('ready');});
testVideo.addEventListener('playing',()=>{if(route.name==='player')setMediaState('ready');});
// UI Kit / PlayerIcon: ВСЕ значки плеера — Lucide через общий icon()/AppIcon.
// play/pause → LucideIcons.play/pause; перемотка → rotateCcw/rotateCw;
// предыдущая/следующая серия → skipBack/skipForward; список серий → listVideo.
// Это те же AppIcon, stroke и currentColor, что в каталоге, меню и избранном.
// При смене play↔pause также вызывать icon(), не вставлять системный символ.
// Flutter: использовать lucide_icons_flutter; не возвращать Material/Cupertino
// иконки из прежнего PlayerOverlay. Кнопка качества остаётся текстовой меткой.
function playerControl(action,label,ic,attrs=''){
  return `<button class="btn player-control" data-action="${action}" data-focus="${action}" aria-label="${esc(label)}" title="${esc(label)}" ${attrs}>${icon(ic)}<span class="sr-only">${esc(label)}</span></button>`;
}
function player(){
  const a=item(route.id);
  return `<main class="player tv-player" tabindex="-1" data-focus="player-surface" aria-label="Видеоплеер"><div class="player-chrome"><header class="player-top">${button('back','К сериям','back','btn touch-only player-back','aria-label="К сериям"')}<div class="od-field"><h1 class="player-title">${esc(a.title)}</h1><span class="player-episode">Серия ${route.episode}</span></div><div class="mobile-player-tools touch-only" aria-label="Серия и качество"></div>${button('rotate-player','Повернуть экран','rotateScreen','btn touch-only player-rotate','aria-label="Повернуть экран"')}</header><div class="mobile-player-center touch-only" role="group" aria-label="Воспроизведение и перемотка"></div><div id="playback-feedback" class="player-stage" aria-live="polite"></div><section class="playback" aria-label="Управление воспроизведением"><label for="timeline" class="sr-only">Позиция воспроизведения</label><input class="timeline" data-focus="timeline" id="timeline" type="range" min="0" max="${mediaDuration||1}" step="0.1" value="${position}" aria-valuetext="${fmt(position)}"><div class="controls"><div class="transport player-transport">${playerControl('toggle',playing?'Пауза':'Воспроизвести',playing?'pause':'play',`aria-pressed="${playing}"`)}${playerControl('rewind','Назад на 10 секунд','seekBack')}${playerControl('forward','Вперёд на 10 секунд','seekForward')}${playerControl('previous','Предыдущая серия','previous',route.episode<=1?'disabled':'')}${playerControl('next','Следующая серия','next',route.episode>=a.episodes?'disabled':'')}<div class="player-time od-nowrap" aria-label="Время воспроизведения"><span id="position">${fmt(position)}</span><span class="player-time-total" id="duration"> / ${mediaDuration?fmt(mediaDuration):'—:—'}</span></div></div><div class="transport player-settings">${playerControl('episodes','Выбрать серию','episodeList')}${button('quality',quality,'','btn player-quality',`aria-label="Качество: ${quality}"`)}</div></div></section></div></main>`;
}
// HandheldPlayer / источник компоновки и размеров:
// Flutter features/player/presentation/widgets/mobile_player_controls.dart:
// MobilePlayerControlButton = 48×48, glyph 26; центральный Play = 64×64, glyph 36.
// В прототипе все glyph — Lucide/AppIcon; шапка содержит серии, качество и поворот.
// Для будущих ИИ: команды/узлы кнопок общие с ТВ. Перемещаем реальные элементы,
// НЕ создаём вторую копию toggle/quality/episodes и не монтируем видео заново.
// Центр — rewind / play / forward, низ — timeline + previous/next/time.
// Поворот/fullscreen не вызывает render(), не сбрасывает позицию или PlaybackSession.
function arrangePlayerControls(){
  const main=$('.tv-player');
  if(!main){document.body.classList.remove('handheld-playback');return;}
  const handheld=isCompactUI()||playerFullscreenOwned;
  main.classList.toggle('handheld-player',handheld);
  document.body.classList.toggle('handheld-playback',handheld);
  const center=main.querySelector('.mobile-player-center'),tools=main.querySelector('.mobile-player-tools');
  const transport=main.querySelector('.player-transport'),settings=main.querySelector('.player-settings');
  if(!center||!tools||!transport||!settings)return;
  const control=action=>main.querySelector(`[data-action="${action}"]`);
  const centerOrder=handheld?['rewind','toggle','forward']:['toggle','rewind','forward'];
  if(handheld){
    for(const action of centerOrder)center.append(control(action));
    for(const action of ['episodes','quality'])tools.append(control(action));
  }else{
    const previous=control('previous');
    for(const action of centerOrder)transport.insertBefore(control(action),previous);
    for(const action of ['episodes','quality'])settings.append(control(action));
  }
  syncRotateLabel();
}
function syncRotateLabel(){
  const button=$('[data-action="rotate-player"]');if(!button)return;
  const landscape=window.matchMedia('(orientation: landscape)').matches;
  const label=landscape?'Повернуть вертикально':'Повернуть горизонтально';
  button.setAttribute('aria-label',label);button.setAttribute('title',label);
  button.disabled=playerRotationBusy;
}
// Flutter: _rotateScreen() в screens/player_screen.dart использует
// SystemChrome.setPreferredOrientations(portraitUp / landscapeLeft, landscapeRight).
// onRotate передаётся только mobile (_isTv ? null : _rotateScreen).
// WEB: screen.orientation.lock обычно требует fullscreen и поддерживается не везде.
// Используем только реальный API, НЕ имитируем поворот CSS rotate/пересозданием плеера.
// Если превью/браузер запрещает API, сохраняем видео и предлагаем повернуть устройство.
// Полноэкранный режим запрашивается у documentElement: общие панели не исчезают
// за fullscreen-элементом. При выходе из плеера освобождаем только свой lock/fullscreen.
async function rotatePlayer(){
  if(route.name!=='player'||!$('.handheld-player')||playerRotationBusy)return;
  if(typeof screen.orientation?.lock!=='function'){
    toast('Поверните устройство вручную — браузер не поддерживает поворот кнопкой.');return;
  }
  const landscape=window.matchMedia('(orientation: landscape)').matches;
  const origin=route;
  playerRotationBusy=true;syncRotateLabel();
  try{
    if(!document.fullscreenElement){
      if(!document.documentElement.requestFullscreen)throw new Error('Fullscreen unavailable');
      // Удерживаем handheld-layout при изменении ширины fullscreen; роль не становится ТВ.
      playerFullscreenOwned=true;
      await document.documentElement.requestFullscreen();
    }
    if(route!==origin||route.name!=='player'){releasePlayerOrientation();return;}
    await screen.orientation.lock(landscape?'portrait-primary':'landscape');
    playerOrientationLocked=true;
    if(route!==origin||route.name!=='player'){releasePlayerOrientation();return;}
    showPlayerControls(false);
  }catch{
    releasePlayerOrientation();
    if(route===origin)toast('Не удалось повернуть экран. Поверните устройство вручную.');
  }finally{
    playerRotationBusy=false;arrangePlayerControls();syncRotateLabel();
  }
}
function releasePlayerOrientation(){
  if(playerOrientationLocked){try{screen.orientation?.unlock();}catch{}playerOrientationLocked=false;}
  const exit=playerFullscreenOwned&&document.fullscreenElement;
  playerFullscreenOwned=false;
  if(exit)document.exitFullscreen?.().catch(()=>{});
}
document.addEventListener('fullscreenchange',()=>{
  if(!document.fullscreenElement){
    if(playerOrientationLocked){try{screen.orientation?.unlock();}catch{}playerOrientationLocked=false;}
    // В процессе requestFullscreen fullscreenElement ещё может быть пустым.
    if(!playerRotationBusy)playerFullscreenOwned=false;
  }
  arrangePlayerControls();
});
window.addEventListener('resize',()=>{if(route.name==='player')syncRotateLabel();},{passive:true});
function armPlayerControls(){
  clearTimeout(playerControlsTimer);
  if(route.name!=='player'||!playing||!playerControlsVisible||playerScrubbing||mediaState!=='ready'||document.hidden||$('.overlay'))return;
  playerControlsTimer=setTimeout(hidePlayerControls,4000);
}
function hidePlayerControls(){
  if(route.name!=='player'||!playing||playerScrubbing||mediaState!=='ready'||document.hidden||$('.overlay'))return;
  playerTransportKey=document.activeElement?.closest('.controls')?currentKey():playerTransportKey;
  playerControlsVisible=false;
  const main=$('.tv-player');if(!main)return;
  for(const region of main.querySelectorAll('.player-top,.mobile-player-center,.playback')){region.inert=true;region.setAttribute('aria-hidden','true');}
  main.classList.add('controls-hidden');main.focus({preventScroll:true});
}
function showPlayerControls(restore=true){
  if(route.name!=='player')return;
  const wasHidden=!playerControlsVisible;playerControlsVisible=true;syncPlayerPosition();
  const main=$('.tv-player');if(!main)return;
  main.classList.remove('controls-hidden');
  for(const region of main.querySelectorAll('.player-top,.mobile-player-center,.playback')){region.inert=false;region.removeAttribute('aria-hidden');}
  const center=main.querySelector('.mobile-player-center');if(center)center.inert=mediaState!=='ready';
  if(mediaState==='error'){const playback=main.querySelector('.playback');playback.inert=true;playback.setAttribute('aria-hidden','true');}
  if(wasHidden&&restore&&!focus(playerTransportKey,true))focus('toggle',true);
  armPlayerControls();
}
function syncPlayerPosition(){
  const range=$('#timeline');
  if(range){range.max=mediaDuration||1;range.disabled=!mediaDuration;range.value=position;range.setAttribute('aria-valuetext',fmt(position)+' из '+fmt(mediaDuration));}
  if($('#duration'))$('#duration').textContent=' / '+(mediaDuration?fmt(mediaDuration):'—:—');
  if($('#position'))$('#position').textContent=fmt(position);
}
// Явные ряды навигации как в Flutter: timeline ↔ транспорт. Без геометрического
// поиска, который может перескочить через кнопки. Уход вверх/вниз возвращает видео.
document.addEventListener('keydown',e=>{
  if(route.name!=='player'||$('.overlay'))return;
  if($('.handheld-player'))return; // На touch-layout доступны обычные Tab/геометрическая навигация.
  if(mediaState==='error'){if(e.key.startsWith('Arrow')||e.key==='Tab'){e.preventDefault();e.stopImmediatePropagation();focus('retry-video',true);}return;}
  const ok=['Enter',' ','Select','Accept'].includes(e.key),arrow=e.key.startsWith('Arrow');
  if(!ok&&!arrow)return;
  if(!playerControlsVisible){e.preventDefault();e.stopImmediatePropagation();held=null;showPlayerControls();return;}
  armPlayerControls();
  if(!arrow)return;
  e.preventDefault();e.stopImmediatePropagation();
  const current=document.activeElement;
  if(current?.id==='timeline'){
    if(['ArrowLeft','ArrowRight'].includes(e.key)){seekMedia(position+(e.key==='ArrowLeft'?-10:10));}
    else if(e.key==='ArrowDown'){if(!focus(playerTransportKey,true))focus('toggle',true);}
    else hidePlayerControls();
    return;
  }
  const controls=[...document.querySelectorAll('.controls button:not(:disabled)')];
  const index=controls.indexOf(current);
  if(e.key==='ArrowUp'){playerTransportKey=currentKey();focus('timeline',true);}
  else if(e.key==='ArrowDown')hidePlayerControls();
  else controls[Math.max(0,Math.min(controls.length-1,index+(e.key==='ArrowLeft'?-1:1)))]?.focus();
},true);
document.addEventListener('pointermove',e=>{if(route.name==='player'&&e.target.closest('.tv-player')&&!$('.overlay'))showPlayerControls();});
document.addEventListener('click',e=>{if(route.name==='player'&&!$('.overlay')&&e.target.closest('.tv-player')&&!e.target.closest('button,input'))showPlayerControls();});
document.addEventListener('pointerdown',e=>{
  if(route.name!=='player'||$('.overlay'))return;
  if(e.target.id==='timeline'){playerScrubbing=true;clearTimeout(playerControlsTimer);}
  else if(e.target.closest('.tv-player'))showPlayerControls();
});
function finishPlayerScrubbing(){if(!playerScrubbing)return;playerScrubbing=false;if(route.name==='player')showPlayerControls();}
document.addEventListener('pointerup',finishPlayerScrubbing);
document.addEventListener('pointercancel',finishPlayerScrubbing);
document.addEventListener('visibilitychange',()=>{
  if(document.hidden){clearTimeout(playerControlsTimer);playerScrubbing=false;if(route.name==='player')testVideo.pause();}
});

// Выбирать видимый вариант навигации: скрытый sidebar не получает фокус на телефоне.
function focus(key,prevent=false){const el=[...document.querySelectorAll('[data-focus]')].find(b=>b.dataset.focus===key&&!b.disabled&&b.getClientRects().length&&getComputedStyle(b).visibility!=='hidden');if(el){el.focus({preventScroll:true});if(!prevent)el.scrollIntoView({block:'nearest',inline:'nearest',behavior:'instant'});return true}return false;}
function currentKey(){return document.activeElement?.dataset.focus||''}
function render(key='',scroll=0){clearTimeout(playerControlsTimer);playerScrubbing=false;playerControlsVisible=true;cancelInspectorUpdate();cancelInspectorAnimations();const previousRoute=renderedRoute;clearInterval(timer);closeSheet(false);const view=({home,favorites,genres,browse,detail,login,player}[route.name]||home)();app.innerHTML=['login','player'].includes(route.name)?view:`<div class="shell ${['home','favorites','genres','browse','detail'].includes(route.name)?'home-shell':''} ${menuExpanded?'menu-is-open':''}">${menu()}${compactHeader()}<div class="menu-scrim" aria-hidden="true"></div><main class="main ${['home','favorites','genres','browse','detail'].includes(route.name)?'home-main':''} ${route.name==='favorites'?'favorites-main':route.name==='genres'?'genres-main':route.name==='detail'?'detail-main':''}" id="main" tabindex="-1">${view}</main>${compactNavigation()}</div>`;if($('#main'))$('#main').scrollTop=scroll;const initial=route.name==='detail'?'play':route.name==='player'?'toggle':route.name==='login'?'username':route.name==='genres'?'genre-0':'card-'+(['favorites','browse'].includes(route.name)?activeCatalogItems()[0]?.id||'':data[0].id);syncAdaptiveLayout();if(isCompactUI()&&!key){($('#main')||$('.tv-player'))?.focus({preventScroll:true});}else if(!focus(key||initial,!!scroll)){focusables(app)[0]?.focus({preventScroll:true});}if(route.name==='browse'&&(genreCatalogError()||!activeCatalogItems().length))focus(genreCatalogError()?'retry-genre':'choose-genres',true);if(genreSessionExpired())focus('session-login',true);mountTestVideo();armPlayerControls();setupCatalogObserver();syncMenuFocus();animateRoute(previousRoute);renderedRoute=route.name+':'+(route.id||(route.filterType?route.filterType+':'+route.genre:route.genre)||'');}
function go(next,push=true){if(push)history.push({route:{...route},key:currentKey(),scroll:$('#main')?.scrollTop||0});playing=false;position=0;route=next;render();}
function back(){if($('.overlay')){closeSheet();return}if(document.activeElement?.closest('.sidebar')){focus(lastContent);return}if(route.name==='home'){focus('nav-home');return}const old=history.pop();playing=false;route=old?.route||{name:'home'};render(old?.key,old?.scroll||0);}
function toast(message){$('.toast')?.remove();clearTimeout(toastTimer);const el=document.createElement('div');el.className='toast';el.setAttribute('role','status');el.textContent=message;document.body.append(el);toastTimer=setTimeout(()=>el.remove(),2800);}
function closeSheet(restore=true,onClosed=null){
  const el=$('.overlay');if(!el)return;
  if(el.dataset.closing==='true'&&restore)return;
  const target=returnFromSheet||lastContent;
  const finish=()=>{
    if(!el.isConnected)return;
    el.remove();app.inert=false;armPlayerControls();
    if(restore){if(!focus(target))document.querySelector('#main button:not(:disabled),.sidebar button,.player button,.login input')?.focus();syncMenuFocus();}
    onClosed?.();
  };
  if(!restore||reducedMotion.matches){el.getAnimations({subtree:true}).forEach(a=>a.cancel());finish();return;}
  el.dataset.closing='true';
  const panel=el.querySelector('.side-sheet'),scrim=el.querySelector('.panel-scrim'),state=getComputedStyle(panel),opacity=getComputedStyle(scrim).opacity;
  const transform=state.transform==='none'?'translate(0,0)':state.transform;
  const destination=isCompactUI()&&phoneLayout.matches?'translateY(100%)':'translateX(100%)';
  el.getAnimations({subtree:true}).forEach(a=>a.cancel());
  animateUI(scrim,[{opacity},{opacity:0}],motion.menuExit,motion.exit);
  const animation=animateUI(panel,[{transform},{transform:destination}],motion.menuExit,motion.exit);
  if(animation)animation.finished.then(finish,()=>{if(el.isConnected&&el.dataset.closing==='true')finish()});else finish();
}
function sheet(title,content,options={}){
  clearTimeout(playerControlsTimer);
  const target=$('.overlay')?returnFromSheet:currentKey();closeSheet(false);returnFromSheet=target;
  const el=document.createElement('div');el.className='overlay';
  const menuStyle=getComputedStyle($('.sidebar')||document.documentElement);
  el.style.setProperty('--menu-bg',menuStyle.getPropertyValue('--menu-bg').trim()||motionStyle.getPropertyValue('--color-menu-bg-base').trim());
  el.style.setProperty('--menu-control-focus',menuStyle.getPropertyValue('--menu-control-focus').trim()||motionStyle.getPropertyValue('--color-control-focus').trim());
  el.innerHTML=`<div class="panel-scrim" aria-hidden="true"></div><section class="side-sheet ${options.favorite?'favorite-panel':''}" role="dialog" aria-modal="true" aria-labelledby="sheet-title"><div class="sheet-head"><h2 id="sheet-title">${esc(title)}</h2><button type="button" class="btn icon sheet-dismiss${options.showClose===false?' touch-only':''}" data-action="close" data-focus="sheet-dismiss" aria-label="Закрыть панель">${icon('close')}<span>Закрыть</span></button></div>${content}</section>`;
  document.body.append(el);app.inert=true;
  el.addEventListener('click',e=>{if(e.target===el)closeSheet()});
  animateUI(el.querySelector('.panel-scrim'),[{opacity:0},{opacity:motion.scrimOpacity}],motion.menuEnter);
  const panel=el.querySelector('.side-sheet');
  // Телефон: bottom sheet; планшет/ТВ: правая панель. Кривые AppMotion общие.
  const entrance=isCompactUI()&&phoneLayout.matches?'translateY(100%)':'translateX(100%)';
  animateUI(panel,[{transform:entrance},{transform:'translate(0,0)'}],motion.menuEnter);
  for(const child of isCompactUI()?[]:panel.children){
    animateUI(child,[{opacity:0},{opacity:1}],motion.fast);
    animateUI(child,[{transform:'translateX(8px)'},{transform:'translateX(0)'}],motion.menuEnter);
  }
  (el.querySelector('button:not([data-action="close"])')||el.querySelector('button'))?.focus();
}
// Для будущих ИИ: это ТВ-панель по долгому нажатию на карточку.
// На ТВ НЕ показывать крестик (showClose:false): закрытие пультом Back/Escape/влево.
// При адаптации под телефон/сенсорный интерфейс добавить крестик справа вверху
// В HTML крестик .touch-only включается адаптивным CSS; во Flutter выбирать по
// возможностям платформы, не по одному разрешению телевизора. Это общий renderer sheet().
function favoriteSheet(id){
  const a=item(id);
  sheet(a.title,button('favorite',fav.has(id)?'Удалить из избранного':'Добавить в избранное',fav.has(id)?'heartMinus':'heartPlus','btn favorite-action',`data-id="${id}"`),{favorite:true,showClose:false});
}
// Для будущих ИИ: те же правила закрытия, что у favoriteSheet.
// ТВ: без крестика; «Остаться» или Back закрывает панель, «Выйти» подтверждает выход.
// Телефон/сенсорная версия: дополнительно нужен крестик в правом верхнем углу
// (showClose:true). Не удалять «Остаться» при добавлении крестика.
// TODO для будущих ИИ: подключить appExitSheet() к нативному запросу закрытия.
// Само подтверждение реализовано в прототипе, закрытие процесса пока имитируется.
// Перед закрытием показывать подтверждение, переиспользуя оформление sheet(),
// кнопки и AppMotion окна signoutSheet, а не создавая новый вариант дизайна.
// Текст: «Выйти из приложения?». Действия: «Выйти» и «Остаться».
// Начальный фокус — «Остаться»; отказ или Back закрывает только диалог и возвращает
// фокус на прежний элемент. Подтверждение закрывает приложение через API платформы.
// Не путать с выходом из аккаунта: сессию и избранное при закрытии сохранять.
// На ТВ крестика нет; в сенсорной версии — справа сверху, как в окне выхода из аккаунта.
// Подключать к запросу закрытия на корневом экране; обычный Back из вложенных экранов
// должен продолжать возвращать назад, не вызывая подтверждение закрытия приложения.
// Это задача для нативного приложения; не заменять её browser beforeunload/window.close.
// Только прототип: подтверждение показывает результат, НЕ закрывает окно браузера
// и НЕ выходит из аккаунта. Во Flutter после подтверждения вызвать API платформы.
// Временный запуск по логотипу удалить при переносе: см. brand(testExit).
function appExitSheet(){
  sheet('Выйти из приложения?',`${button('confirm-app-exit','Выйти','logout','btn danger')}${button('close','Остаться')}`,{showClose:false});
  focus('close',true);
}
function signoutSheet(){
  sheet('Выйти из аккаунта?',`${button('confirm-signout','Выйти','logout','btn danger')}${button('close','Остаться')}`,{showClose:false});
}

// UI Kit / PlayerChoices: оформление панелей общее с меню, Lucide и AppMotion.
// Открывать список на текущей серии с фокусом и прокруткой; текущую помечать отдельно
// от фокуса. Повторный выбор текущей серии только закрывает панель, без сброса видео.
// Смена серии ВНУТРИ плеера не вызывает go()/push в history: иначе Back проходит
// через все выбранные серии вместо возврата к экрану аниме. Позиция сбрасывается
// только при выборе другой серии. Качество брать из реальной PlaybackSession;
// у тестового видео доступен один формат — не добавлять выдуманные 720p/1080p.
function openPlayerEpisodes(){
  const a=item(route.id);
  const cards=episodeNumbersDescending(a).map(n=>episode(a,n).replace('data-action="play"','data-action="select-player-episode"')).join('');
  sheet('Выбрать серию',`<div class="od-grid episode-picker" data-grid>${cards}</div>`,{showClose:false});
  const current=document.querySelector(`.episode-picker [data-episode="${route.episode}"]`);
  if(current){current.setAttribute('aria-current','step');current.setAttribute('aria-label','Серия '+route.episode+', текущая');current.classList.add('is-current-episode');current.querySelector('.poster-wrap')?.insertAdjacentHTML('beforeend',`<span class="episode-current-mark" aria-hidden="true">${icon('check')}</span>`);current.focus();current.scrollIntoView({block:'center',behavior:'instant'});}
}
function selectPlayerEpisode(n){
  n=Number(n);const a=item(route.id);
  if(route.name!=='player'||!Number.isInteger(n)||n<1||n>a.episodes)return;
  if(n===Number(route.episode)){closeSheet();return;}
  testVideo.pause();route.episode=n;position=0;watched.add(a.id+':'+n);save();
  const previous=history[history.length-1];
  if(previous?.route.name==='detail'){previous.key='episode-'+n;previous.scroll=0;}
  render('toggle');
}
function play(id,n){
  watched.add(id+':'+n);save();go({name:'player',id,episode:Number(n)});
  // Даже запуск основной кнопкой возвращает к соответствующей карточке серии.
  const previous=history[history.length-1];
  if(previous?.route.name==='detail'){previous.key='episode-'+Number(n);previous.scroll=0;}
}
document.addEventListener('focusin',e=>{
  syncMenuFocus();
  if(e.target.closest('#main')&&e.target.dataset.focus)lastContent=e.target.dataset.focus;
  const card=e.target.closest('.home-grid-wrap .anime-card');
  if(!card){cancelInspectorUpdate();cancelInspectorAnimations();}
  if(card&&['home','favorites','browse'].includes(route.name)){
    updateInspector(card.dataset.id);
    if(route.name!=='home')return;
    const grid=card.closest('[data-grid]'),cells=[...grid.children];
    const cols=getComputedStyle(grid).gridTemplateColumns.split(' ').length;
    if(cells.indexOf(card)>=cells.length-cols*2)maybeLoadCatalog();
  }
});
document.addEventListener('focusout',()=>queueMicrotask(syncMenuFocus));
document.addEventListener('pointerover',e=>{const card=e.target.closest('.home-grid-wrap .anime-card');if(card)updateInspector(card.dataset.id)});
document.addEventListener('click',e=>{if(e.target.closest('.overlay[data-closing="true"]'))return;if(e.target.matches('.menu-scrim')){if(!focus(lastContent))document.querySelector('#main button')?.focus();syncMenuFocus();return}const b=e.target.closest('[data-action]');if(!b||b.disabled)return;const action=b.dataset.action,id=b.dataset.id;switch(action){case'rotate-player':void rotatePlayer();break;case'account':compactAccount();break;case'browse-sort':openBrowseSort();break;case'draft-sort-criterion':case'draft-sort-direction':changeBrowseSortDraft(action,b.dataset.value);break;case'apply-browse-sort':applyBrowseSort();break;case'session-login':go({name:'login'});break;case'app-exit':appExitSheet();break;case'confirm-app-exit':closeSheet();toast('Выход подтверждён');break;case'retry-genre':retryGenreCatalog();break;case'choose-genres':chooseAnotherGenre();break;case'retry-video':retryVideo();break;case'toggle-password':togglePasswordVisibility();break;case'nav':history=[];route={name:b.dataset.name};playing=false;render('nav-'+b.dataset.name);break;case'home':history=[];go({name:'home'},false);break;case'retry-catalog':void loadCatalog();break;case'detail':go({name:'detail',id});break;case'genre':go({name:'browse',genre:b.dataset.genre});break;case'filter':go({name:'browse',filterType:b.dataset.filterType,genre:b.dataset.filterValue});break;case'back':back();break;case'close':closeSheet();break;case'favorite-toggle':void toggleDetailFavorite(id);break;case'favorite-sheet':favoriteSheet(id);break;case'favorite':{const origin=returnFromSheet,scroll=$('#main')?.scrollTop||0;fav.has(id)?fav.delete(id):fav.add(id);save();render(origin,scroll);if(route.name==='favorites'&&!fav.size)focus('nav-favorites');toast(fav.has(id)?'Добавлено в избранное':'Удалено из избранного');break}case'play':play(id,b.dataset.episode||1);break;case'sort':sheet('Порядок аниме',`<p class="sheet-copy">Сортировка демонстрационной подборки</p>${[['default','По умолчанию'],['year','Сначала новые'],['name','По названию']].map(([v,t])=>button('set-sort',t,sort===v?'check':'','sheet-option',`data-value="${v}" aria-pressed="${sort===v}" data-focus="sort-${v}"`)).join('')}`);break;case'set-sort':sort=b.dataset.value;render('sort');break;case'signout':signoutSheet();break;case'confirm-signout':history=[];go({name:'login'},false);break;case'toggle':toggleMedia();break;case'rewind':case'forward':seekMedia(position+(action==='rewind'?-10:10));break;case'quality':sheet('Качество видео',`${[quality].map(q=>button('set-quality',q,'check','sheet-option',`data-value="${q}" aria-pressed="true" data-focus="quality-${q}"`)).join('')}`,{showClose:false});break;case'set-quality':quality=b.dataset.value;closeSheet();break;case'episodes':openPlayerEpisodes();break;case'select-player-episode':selectPlayerEpisode(b.dataset.episode);break;case'previous':case'next':{const a=item(route.id),nextEpisode=Number(route.episode)+(action==='previous'?-1:1);if(nextEpisode>=1&&nextEpisode<=a.episodes){route.episode=nextEpisode;position=0;testVideo.pause();watched.add(route.id+':'+route.episode);save();render('toggle')}break}}});
function focusables(root){return [...root.querySelectorAll('button:not(:disabled),input,a[href]')].filter(x=>x.getClientRects().length)}
function spatial(key){const overlay=$('.overlay'),active=document.activeElement,root=overlay||app;if(overlay&&key==='ArrowLeft'){closeSheet();return}if(active?.matches('input:not([type=range])')){if(key==='ArrowLeft'||key==='ArrowRight')return;}if(active?.matches('input[type=range]')&&(key==='ArrowLeft'||key==='ArrowRight')){seekMedia(position+(key==='ArrowLeft'?-10:10));return}if(active?.closest('.sidebar')){if(key==='ArrowRight'){if(!focus(lastContent))document.querySelector('#main button')?.focus();return}const list=focusables($('.sidebar')),index=list.indexOf(active);if(key==='ArrowUp')list[Math.max(0,index-1)]?.focus();if(key==='ArrowDown')list[Math.min(list.length-1,index+1)]?.focus();return;}const grid=active?.closest('[data-grid]');if(grid){const cells=[...grid.children],index=cells.indexOf(active),cols=getComputedStyle(grid).gridTemplateColumns.split(' ').length;if(key==='ArrowLeft'&&index%cols===0){focus('nav-'+(route.name==='browse'?'genres':['home','favorites','genres'].includes(route.name)?route.name:'home'));return}if(key==='ArrowRight'&&(index%cols===cols-1||index===cells.length-1))return;if(key==='ArrowLeft'){cells[index-1]?.focus();return}if(key==='ArrowRight'){cells[index+1]?.focus();return}if(key==='ArrowDown'){if(index+cols<cells.length){cells[index+cols].focus();cells[index+cols].scrollIntoView({block:'nearest'})}else if(route.name==='home'){if(homeFeed.error)focus('retry-catalog');else if(homeFeed.hasNext){pendingCatalogFocus={origin:currentKey(),cols};maybeLoadCatalog();}}return}if(key==='ArrowUp'&&index>=cols){cells[index-cols].focus();cells[index-cols].scrollIntoView({block:'nearest'});return}if(key==='ArrowUp'&&route.name==='home')return;if(key==='ArrowUp'&&route.name==='favorites')return;if(key==='ArrowUp'&&route.name==='detail'){focus('play');return}if(key==='ArrowUp'&&route.name==='browse'){focus('browse-sort',true);return;}}
const r=active.getBoundingClientRect(),x=r.x+r.width/2,y=r.y+r.height/2,horizontal=key==='ArrowLeft'||key==='ArrowRight',sign=key==='ArrowLeft'||key==='ArrowUp'?-1:1;const candidates=focusables(root).filter(el=>el!==active&&(!el.closest('.sidebar')||key==='ArrowLeft')).map(el=>{const b=el.getBoundingClientRect(),dx=b.x+b.width/2-x,dy=b.y+b.height/2-y,forward=(horizontal?dx:dy)*sign,cross=Math.abs(horizontal?dy:dx);return {el,forward,score:forward+cross*2}}).filter(v=>v.forward>8).sort((a,b)=>a.score-b.score);if(candidates[0]){candidates[0].el.focus({preventScroll:true});candidates[0].el.scrollIntoView({block:'nearest',inline:'nearest'})}}
document.addEventListener('keydown',e=>{if($('.overlay[data-closing="true"]')){e.preventDefault();return;}if(['Escape','BrowserBack'].includes(e.key)||e.key==='Backspace'&&!e.target.matches('input')){e.preventDefault();held=null;back();return}if(e.key.startsWith('Arrow')){if(e.target.matches('input:not([type=range])')&&['ArrowLeft','ArrowRight'].includes(e.key))return;e.preventDefault();spatial(e.key);return}if(e.key==='Tab'&&$('.overlay')){const list=focusables($('.overlay')),i=list.indexOf(document.activeElement);e.preventDefault();list[(i+(e.shiftKey?-1:1)+list.length)%list.length]?.focus();return}if(['Enter',' ','Select','Accept'].includes(e.key)&&!e.target.matches('input:not([type=range])')){e.preventDefault();const b=document.activeElement;if(!held)held={key:e.key,target:b,long:false};if(e.repeat&&held.target===b&&b.dataset.action==='detail'&&!held.long){held.long=true;favoriteSheet(b.dataset.id)}}});
document.addEventListener('keyup',e=>{if(!held||e.key!==held.key)return;e.preventDefault();const state=held;held=null;if(!state.long&&state.target===document.activeElement)state.target.click()});
window.addEventListener('blur',()=>held=null);
// Touch / MediaCard: long press открывает ТО ЖЕ favoriteSheet, что удержание OK.
// Перемещение пальца отменяет жест: прокрутка никогда не добавляет в избранное.
// Не использовать preventDefault на pointerdown и не захватывать pointer для списка.
// Для Flutter перенести в общий MediaCard.onLongPress, не копировать по каталогам.
let touchCardPress=null,suppressedCardClick=null;
function cancelTouchCardPress(){clearTimeout(touchCardPress?.timer);touchCardPress=null;}
document.addEventListener('pointerdown',e=>{
  if(e.pointerType!=='touch'||!isCompactUI()||$('.overlay'))return;
  const card=e.target.closest('.ui-media-card[data-action="detail"]');if(!card)return;
  cancelTouchCardPress();
  const press={card,pointerId:e.pointerId,x:e.clientX,y:e.clientY,timer:null};
  press.timer=setTimeout(()=>{
    if(touchCardPress!==press||!card.isConnected)return;
    suppressedCardClick={card,until:Date.now()+1200};touchCardPress=null;
    favoriteSheet(card.dataset.id);
  },600);
  touchCardPress=press;
},{passive:true});
document.addEventListener('pointermove',e=>{
  if(touchCardPress&&e.pointerId===touchCardPress.pointerId&&Math.hypot(e.clientX-touchCardPress.x,e.clientY-touchCardPress.y)>10)cancelTouchCardPress();
},{passive:true});
document.addEventListener('pointerup',cancelTouchCardPress,{passive:true});
document.addEventListener('pointercancel',cancelTouchCardPress,{passive:true});
document.addEventListener('scroll',cancelTouchCardPress,{passive:true,capture:true});
document.addEventListener('click',e=>{
  if(suppressedCardClick&&Date.now()<suppressedCardClick.until&&suppressedCardClick.card.contains(e.target)){
    e.preventDefault();e.stopImmediatePropagation();suppressedCardClick=null;
  }
},true);
document.addEventListener('contextmenu',e=>{const card=e.target.closest('.ui-media-card[data-action="detail"]');if(card){e.preventDefault();cancelTouchCardPress();if(!$('.overlay'))favoriteSheet(card.dataset.id)}});
document.addEventListener('input',e=>{if(e.target.id==='timeline'){seekMedia(Number(e.target.value))}});
function validate(input){const el=$('#'+input.id+'-error');if(!el)return true;const valid=input.id==='username'?!!input.value.trim():!!input.value;el.textContent=valid?'':input.id==='username'?'Введите логин.':'Введите пароль.';input.setAttribute('aria-invalid',!valid);return valid;}
document.addEventListener('focusout',e=>{if(e.target.matches('#username,#password'))validate(e.target)});
document.addEventListener('submit',e=>{
  if(e.target.id!=='login')return;
  e.preventDefault();const form=e.target;
  if(form.dataset.submitting==='true')return;
  const errors=[$('#username'),$('#password')].filter(x=>!validate(x));
  const summary=$('#error-summary');
  if(errors.length){
    summary.className='error-summary';
    summary.innerHTML='Проверьте данные:'+errors.map(x=>`<a href="#${x.id}">${x.id==='username'?'Логин':'Пароль'}</a>`).join('');
    errors[0].focus();return;
  }
  summary.className='';summary.textContent='';
  const authFeedback=$('#auth-error');authFeedback.textContent='';
  const submittedLogin=$('#username').value.trim().toLowerCase();
  form.dataset.submitting='true';form.setAttribute('aria-busy','true');
  const b=form.querySelector('[type=submit]');
  b.textContent='Входим…';b.setAttribute('aria-disabled','true');b.setAttribute('aria-busy','true');
  // Локальная задержка вместо запроса. Не показывать успешный вход при ответе сервера
  // с ошибкой: при интеграции восстановить кнопку и вывести понятное сообщение.
  setTimeout(()=>{
    if(!form.isConnected||route.name!=='login')return;
    // Flutter login_screen.dart: Failure.message под паролем, liveRegion=true.
    // anistar_errors.dart разделяет connection/timeout/server/request. Не путать
    // отказ авторизации с пустыми полями; при ошибке не очищать введённые данные.
    // Прототип: error / offline / server — локальные сценарии, на сервер не отправляются.
    const failures={error:'Неверный логин или пароль. Проверьте данные и попробуйте ещё раз.',offline:'Нет соединения. Проверьте подключение к интернету и повторите вход.',server:'Сервис временно недоступен. Попробуйте войти позже.'};
    const failure=failures[submittedLogin]||(!navigator.onLine?failures.offline:null);
    if(failure){
      form.dataset.submitting='false';form.removeAttribute('aria-busy');
      b.textContent='Войти';b.removeAttribute('aria-disabled');b.removeAttribute('aria-busy');
      authFeedback.innerHTML=icon('alert')+`<p>${esc(failure)}</p>`;
      focus('login-submit',true);return;
    }
    form.reset();history=[];go({name:'home'},false);
  },600);
});

homeFeed.items=[...catalogPages[0].items];
homeFeed.page=1;
homeFeed.hasNext=catalogPages[0].hasNext;
render();

})();
