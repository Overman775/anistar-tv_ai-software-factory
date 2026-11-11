(() => {
'use strict';
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
const relatedTitles=[{id:'frieren2',sourceId:'10686',title:'Провожающая в последний путь Фрирен 2 сезон',year:2026,episodes:10,genre:['Приключения','Сёнен','Фэнтези','Драма'],w:400,h:572,desc:'Продолжение путешествия Фрирен и её спутников.',rating:8.9,director:'Китагава Томоя',voiceover:'Русская озвучка',seriesInfo:'(10 эп.), 25 мин.'},...(window.ANISTAR_CATALOG_SNAPSHOT.relatedTitles||[])];
// Дополнительные реальные тайтлы: локальный снимок каталога, подключённый до app.js.
const siteCatalogItems=window.ANISTAR_CATALOG_SNAPSHOT.pages.flatMap(page=>page.items);
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
// SVG lucide-static 1.60.0 (ISC) встроены в lucideIcons; лицензия: assets/lucide/LICENSE.
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
  search:{"name": "search", "flutter": "search", "svg": "<path d=\"m21 21-4.34-4.34\" />\n  <circle cx=\"11\" cy=\"11\" r=\"8\" />"},
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
Object.assign(lucideIcons,{"arrow-down":{"name":"arrow-down","flutter":"arrowDown","svg":"<path d=\"M12 5v14\" />\n  <path d=\"m19 12-7 7-7-7\" />"},"arrow-left":{"name":"arrow-left","flutter":"arrowLeft","svg":"<path d=\"m12 19-7-7 7-7\" />\n  <path d=\"M19 12H5\" />"},"arrow-up":{"name":"arrow-up","flutter":"arrowUp","svg":"<path d=\"m5 12 7-7 7 7\" />\n  <path d=\"M12 19V5\" />"},"check":{"name":"check","flutter":"check","svg":"<path d=\"M20 6 9 17l-5-5\" />"},"chevron-right":{"name":"chevron-right","flutter":"chevronRight","svg":"<path d=\"m9 18 6-6-6-6\" />"},"circle-alert":{"name":"circle-alert","flutter":"circleAlert","svg":"<circle cx=\"12\" cy=\"12\" r=\"10\" />\n  <line x1=\"12\" x2=\"12\" y1=\"8\" y2=\"12\" />\n  <line x1=\"12\" x2=\"12.01\" y1=\"16\" y2=\"16\" />"},"eye-off":{"name":"eye-off","flutter":"eyeOff","svg":"<path d=\"M10.733 5.076a10.744 10.744 0 0 1 11.205 6.575 1 1 0 0 1 0 .696 10.747 10.747 0 0 1-1.444 2.49\" />\n  <path d=\"M14.084 14.158a3 3 0 0 1-4.242-4.242\" />\n  <path d=\"M17.479 17.499a10.75 10.75 0 0 1-15.417-5.151 1 1 0 0 1 0-.696 10.75 10.75 0 0 1 4.446-5.143\" />\n  <path d=\"m2 2 20 20\" />"},"eye":{"name":"eye","flutter":"eye","svg":"<path d=\"M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0\" />\n  <circle cx=\"12\" cy=\"12\" r=\"3\" />"},"fast-forward":{"name":"fast-forward","flutter":"fastForward","svg":"<path d=\"M12 6a2 2 0 0 1 3.414-1.414l6 6a2 2 0 0 1 0 2.828l-6 6A2 2 0 0 1 12 18z\" />\n  <path d=\"M2 6a2 2 0 0 1 3.414-1.414l6 6a2 2 0 0 1 0 2.828l-6 6A2 2 0 0 1 2 18z\" />"},"funnel":{"name":"funnel","flutter":"funnel","svg":"<path d=\"M10 20a1 1 0 0 0 .553.895l2 1A1 1 0 0 0 14 21v-7a2 2 0 0 1 .517-1.341L21.74 4.67A1 1 0 0 0 21 3H3a1 1 0 0 0-.742 1.67l7.225 7.989A2 2 0 0 1 10 14z\" />"},"heart-minus":{"name":"heart-minus","flutter":"heartMinus","svg":"<path d=\"m14.876 18.99-1.368 1.323a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5a5.5 5.5 0 0 1 9.591-3.676.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5a5.2 5.2 0 0 1-.244 1.572\" />\n  <path d=\"M15 15h6\" />"},"heart-off":{"name":"heart-off","flutter":"heartOff","svg":"<path d=\"M10.5 4.893a5.5 5.5 0 0 1 1.091.931.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5c0 1.872-1.002 3.356-2.187 4.655\" />\n  <path d=\"m16.967 16.967-3.459 3.346a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5a5.5 5.5 0 0 1 2.747-4.761\" />\n  <path d=\"m2 2 20 20\" />"},"heart-plus":{"name":"heart-plus","flutter":"heartPlus","svg":"<path d=\"m14.479 19.374-.971.939a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5a5.5 5.5 0 0 1 9.591-3.676.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5a5.2 5.2 0 0 1-.219 1.49\" />\n  <path d=\"M15 15h6\" />\n  <path d=\"M18 12v6\" />"},"heart":{"name":"heart","flutter":"heart","svg":"<path d=\"M2 9.5a5.5 5.5 0 0 1 9.591-3.676.56.56 0 0 0 .818 0A5.49 5.49 0 0 1 22 9.5c0 2.29-1.5 4-3 5.5l-5.492 5.313a2 2 0 0 1-3 .019L5 15c-1.5-1.5-3-3.2-3-5.5\" />"},"house":{"name":"house","flutter":"house","svg":"<path d=\"M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8\" />\n  <path d=\"M3 10a2 2 0 0 1 .709-1.528l7-6a2 2 0 0 1 2.582 0l7 6A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z\" />"},"info":{"name":"info","flutter":"info","svg":"<circle cx=\"12\" cy=\"12\" r=\"10\" />\n  <path d=\"M12 16v-4\" />\n  <path d=\"M12 8h.01\" />"},"layout-grid":{"name":"layout-grid","flutter":"layoutGrid","svg":"<rect width=\"7\" height=\"7\" x=\"3\" y=\"3\" rx=\"1\" />\n  <rect width=\"7\" height=\"7\" x=\"14\" y=\"3\" rx=\"1\" />\n  <rect width=\"7\" height=\"7\" x=\"14\" y=\"14\" rx=\"1\" />\n  <rect width=\"7\" height=\"7\" x=\"3\" y=\"14\" rx=\"1\" />"},"list-filter":{"name":"list-filter","flutter":"listFilter","svg":"<path d=\"M2 5h20\" />\n  <path d=\"M6 12h12\" />\n  <path d=\"M9 19h6\" />"},"list-video":{"name":"list-video","flutter":"listVideo","svg":"<path d=\"M21 5H3\" />\n  <path d=\"M10 12H3\" />\n  <path d=\"M10 19H3\" />\n  <path d=\"M15 12.003a1 1 0 0 1 1.517-.859l4.997 2.997a1 1 0 0 1 0 1.718l-4.997 2.997a1 1 0 0 1-1.517-.86z\" />"},"list":{"name":"list","flutter":"list","svg":"<path d=\"M3 5h.01\" />\n  <path d=\"M3 12h.01\" />\n  <path d=\"M3 19h.01\" />\n  <path d=\"M8 5h13\" />\n  <path d=\"M8 12h13\" />\n  <path d=\"M8 19h13\" />"},"loader-circle":{"name":"loader-circle","flutter":"loaderCircle","svg":"<path d=\"M21 12a9 9 0 1 1-6.219-8.56\" />"},"log-in":{"name":"log-in","flutter":"logIn","svg":"<path d=\"m10 17 5-5-5-5\" />\n  <path d=\"M15 12H3\" />\n  <path d=\"M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4\" />"},"log-out":{"name":"log-out","flutter":"logOut","svg":"<path d=\"m16 17 5-5-5-5\" />\n  <path d=\"M21 12H9\" />\n  <path d=\"M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4\" />"},"pause":{"name":"pause","flutter":"pause","svg":"<rect x=\"14\" y=\"3\" width=\"5\" height=\"18\" rx=\"1\" />\n  <rect x=\"5\" y=\"3\" width=\"5\" height=\"18\" rx=\"1\" />"},"play":{"name":"play","flutter":"play","svg":"<path d=\"M5 5a2 2 0 0 1 3.008-1.728l11.997 6.998a2 2 0 0 1 .003 3.458l-12 7A2 2 0 0 1 5 19z\" />"},"refresh-cw":{"name":"refresh-cw","flutter":"refreshCw","svg":"<path d=\"M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8\" />\n  <path d=\"M21 3v5h-5\" />\n  <path d=\"M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16\" />\n  <path d=\"M8 16H3v5\" />"},"rewind":{"name":"rewind","flutter":"rewind","svg":"<path d=\"M12 6a2 2 0 0 0-3.414-1.414l-6 6a2 2 0 0 0 0 2.828l6 6A2 2 0 0 0 12 18z\" />\n  <path d=\"M22 6a2 2 0 0 0-3.414-1.414l-6 6a2 2 0 0 0 0 2.828l6 6A2 2 0 0 0 22 18z\" />"},"rotate-ccw":{"name":"rotate-ccw","flutter":"rotateCcw","svg":"<path d=\"M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8\" />\n  <path d=\"M3 3v5h5\" />"},"rotate-cw-square":{"name":"rotate-cw-square","flutter":"rotateCwSquare","svg":"<path d=\"M12 5H6a2 2 0 0 0-2 2v3\" />\n  <path d=\"m9 8 3-3-3-3\" />\n  <path d=\"M4 14v4a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2\" />"},"rotate-cw":{"name":"rotate-cw","flutter":"rotateCw","svg":"<path d=\"M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8\" />\n  <path d=\"M21 3v5h-5\" />"},"search":{"name":"search","flutter":"search","svg":"<path d=\"m21 21-4.34-4.34\" />\n  <circle cx=\"11\" cy=\"11\" r=\"8\" />"},"share-2":{"name":"share-2","flutter":"share2","svg":"<circle cx=\"18\" cy=\"5\" r=\"3\" />\n  <circle cx=\"6\" cy=\"12\" r=\"3\" />\n  <circle cx=\"18\" cy=\"19\" r=\"3\" />\n  <line x1=\"8.59\" x2=\"15.42\" y1=\"13.51\" y2=\"17.49\" />\n  <line x1=\"15.41\" x2=\"8.59\" y1=\"6.51\" y2=\"10.49\" />"},"skip-back":{"name":"skip-back","flutter":"skipBack","svg":"<path d=\"M17.971 4.285A2 2 0 0 1 21 6v12a2 2 0 0 1-3.029 1.715l-9.997-5.998a2 2 0 0 1-.003-3.432z\" />\n  <path d=\"M3 20V4\" />"},"skip-forward":{"name":"skip-forward","flutter":"skipForward","svg":"<path d=\"M21 4v16\" />\n  <path d=\"M6.029 4.285A2 2 0 0 0 3 6v12a2 2 0 0 0 3.029 1.715l9.997-5.998a2 2 0 0 0 .003-3.432z\" />"},"smartphone":{"name":"smartphone","flutter":"smartphone","svg":"<rect width=\"14\" height=\"20\" x=\"5\" y=\"2\" rx=\"2\" ry=\"2\" />\n  <path d=\"M12 18h.01\" />"},"star":{"name":"star","flutter":"star","svg":"<path d=\"M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z\" />"},"user":{"name":"user","flutter":"user","svg":"<path d=\"M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2\" />\n  <circle cx=\"12\" cy=\"7\" r=\"4\" />"},"x":{"name":"x","flutter":"x","svg":"<path d=\"M18 6 6 18\" />\n  <path d=\"m6 6 12 12\" />"},"login":{"name":"log-in","flutter":"logIn","svg":"<path d=\"m10 17 5-5-5-5\" />\n  <path d=\"M15 12H3\" />\n  <path d=\"M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4\" />"},"file":{"name":"list","flutter":"list","svg":"<path d=\"M3 5h.01\" />\n  <path d=\"M3 12h.01\" />\n  <path d=\"M3 19h.01\" />\n  <path d=\"M8 5h13\" />\n  <path d=\"M8 12h13\" />\n  <path d=\"M8 19h13\" />"},"share":{"name":"share-2","flutter":"share2","svg":"<circle cx=\"18\" cy=\"5\" r=\"3\" />\n  <circle cx=\"6\" cy=\"12\" r=\"3\" />\n  <circle cx=\"18\" cy=\"19\" r=\"3\" />\n  <line x1=\"8.59\" x2=\"15.42\" y1=\"13.51\" y2=\"17.49\" />\n  <line x1=\"15.41\" x2=\"8.59\" y1=\"6.51\" y2=\"10.49\" />"},"up":{"name":"arrow-up","flutter":"arrowUp","svg":"<path d=\"m5 12 7-7 7 7\" />\n  <path d=\"M12 19V5\" />"},"down":{"name":"arrow-down","flutter":"arrowDown","svg":"<path d=\"M12 5v14\" />\n  <path d=\"m19 12-7 7-7-7\" />"},"seekBack":{"name":"rotate-ccw","flutter":"rotateCcw","svg":"<path d=\"M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8\" />\n  <path d=\"M3 3v5h5\" />"},"seekForward":{"name":"rotate-cw","flutter":"rotateCw","svg":"<path d=\"M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8\" />\n  <path d=\"M21 3v5h-5\" />"}});
const icon=n=>{
  const entry=lucideIcons[n]||lucideIcons.info;
  return `<svg class="od-icon lucide-icon" data-lucide="${entry.name}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">${entry.svg}</svg>`;
};
const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const read=(k,d)=>{try{return JSON.parse(localStorage.getItem(k))??d}catch{return d}};
let fav=new Set(read('anistar-tv-favorites',['frieren','spy'])),watched=new Set(read('anistar-tv-watched',[]));
function save(){try{if(nativeAccount())localStorage.setItem('anistar-native-favorites:'+nativeState.user,JSON.stringify([...fav]));localStorage.setItem('anistar-tv-favorites',JSON.stringify([...fav]));localStorage.setItem('anistar-tv-watched',JSON.stringify([...watched]))}catch{}}
let route={name:'home'},history=[],sort='default',playing=false,position=0,quality='SD',timer,toastTimer,lastContent='card-frieren',returnFromSheet=null,held=null;
const app=$('#app');
// Native parity layer — reference: /Users/overman/Desktop/anistar_tv/anistar_tv/lib/.
// All server operations below are fixtures; no credentials, cookies or private logs
// are imported. AppMotion, UI Kit and feature presentation remain the source of truth.
// Показываем developer-build вариант: AppConfig.isDebugToolsEnabled = !kReleaseMode.
// Поэтому «Логи» доступны в прототипе. Для release-сценария выставить debugTools=false.
const nativeState={detailCache:new Set(),detailStatus:'ready',debugTools:true,access:read('anistar-native-access',null)==='account'?'account':null,user:read('anistar-native-user',''),destination:'home',expandedDescription:null,loginReturn:null,loginDestination:null,startupStage:'site',quality:'SD',events:[],logOpen:false,refreshing:false,seek:null};
function nativeAccount(){return nativeState.access==='account';}
function nativeHistoryKey(){return 'anistar-search-history-v2:'+(nativeAccount()?'account:'+nativeState.user:'guest');}
function nativeLoadHistory(){
  const entries=read(nativeHistoryKey(),[]),same=s=>s.trim().toLocaleLowerCase('ru').replace(/ё/g,'е'),seen=new Set();
  recentSearches=Array.isArray(entries)?entries.filter(x=>{if(typeof x!=='string'||!x.trim()||[...x].length>120||seen.has(same(x)))return false;seen.add(same(x));return true;}).map(x=>x.trim()).slice(0,8):[];
}
function nativeLog(message){nativeState.events.push(new Date().toLocaleTimeString('ru-RU')+'  INFO  '+message);nativeState.events=nativeState.events.slice(-200);}
function nativeIntro(){return `<main class="native-intro" tabindex="-1"><section class="native-intro-brand">${brand()}</section><section class="native-intro-actions"><h1>Смотрите аниме на AniStar TV</h1><p>Войдите в аккаунт или продолжите без входа.</p><div class="od-stack">${button('sign-in','Войти','','btn primary','data-focus="intro-sign-in"')}${button('enter-guest','Продолжить без входа','','btn','data-focus="intro-guest"')}</div></section></main>`;}
function nativeStartup(){
  if(nativeState.startupError)return `<main class="native-startup"><img src="assets/anistar-logo.png" width="1254" height="1254" alt=""><div class="catalog-feedback">${icon('alert')}<h1>${nativeState.startupStage==='site'?'Не удалось подключиться к AniStar':'Не удалось проверить сессию'}</h1><p>${esc(nativeState.startupError)}</p>${button('startup-retry','Попробовать снова','refresh','btn primary')}</div></main>`;
  return `<main class="native-startup" tabindex="-1" data-focus="startup-surface"><img src="assets/anistar-logo.png" width="1254" height="1254" alt=""><h1>AniStar TV</h1><span class="native-spinner" aria-hidden="true">${icon('loading')}</span><p role="status">${nativeState.startupStage==='site'?'Проверяем доступность AniStar…':'Проверяем сохранённую сессию…'}</p></main>`;
}
function nativeBeginStartup(){
  // StartupScreen checks are fixtures, not real mirror/network/session verification.
  if(nativeState.startupBusy)return;
  nativeState.startupBusy=true;nativeState.startupError=null;
  route={name:'startup'};nativeState.startupStage='site';render();
  setTimeout(()=>{
    if(route.name!=='startup'){nativeState.startupBusy=false;return;}
    if(nativeState.failStartup){nativeState.startupBusy=false;nativeState.startupError='Проверьте подключение и попробуйте снова.';render('startup-retry');return;}
    nativeState.startupStage='session';render();
    setTimeout(()=>{nativeState.startupBusy=false;if(route.name!=='startup')return;route={name:nativeState.access?'home':'intro'};nativeLoadHistory();if(nativeAccount()){fav=new Set(read('anistar-native-favorites:'+nativeState.user,['frieren','spy']));watched=new Set(read('anistar-native-viewing:'+nativeState.user,[]));}render();nativeLog('Приложение готово');},450);
  },450);
}
function requestNativeLogin(destination=null){
  nativeState.loginDestination=destination;
  nativeState.loginReturn={route:{...route},key:$('.overlay')?returnFromSheet:currentKey(),scroll:$('#main')?.scrollTop||0};
  closeSheet(false);go({name:'login'},false);
}
function cancelNativeLogin(){
  const previous=nativeState.loginReturn;nativeState.loginReturn=null;nativeState.loginDestination=null;
  route=previous?.route||{name:'intro'};render(previous?.key,previous?.scroll||0);
}
function completeNativeAccess(access,user=''){
  nativeState.access=access;nativeState.user=user;nativeState.expandedDescription=null;nativeState.rootScroll={};
  // AuthController: guest lives only in this process. Never persist it as a saved session.
  // Demo account stores only a name/access marker; never credentials or server cookies.
  try{if(access==='account'){localStorage.setItem('anistar-native-access',JSON.stringify(access));localStorage.setItem('anistar-native-user',JSON.stringify(user));}else{localStorage.removeItem('anistar-native-access');localStorage.removeItem('anistar-native-user');}}catch{}
  nativeLoadHistory();nativeResetSearchContext();
  fav=new Set(access==='account'?read('anistar-native-favorites:'+user,['frieren','spy']):[]);
  watched=new Set(access==='account'?read('anistar-native-viewing:'+user,[]):[]);
  nativeState.loginReturn=null;nativeState.loginDestination=null;nativeState.destination='home';history=[];route={name:'home'};render();
  nativeLog(access==='account'?'Вход в аккаунт выполнен':'Включён гостевой доступ');
}
function nativeSignOut(){
  closeSheet(false);nativeState.access=null;nativeState.user='';nativeState.loginReturn=null;
  try{localStorage.removeItem('anistar-native-access');localStorage.removeItem('anistar-native-user');}catch{}
  nativeLoadHistory();nativeResetSearchContext();history=[];route={name:'intro'};render();nativeLog('Выход из аккаунта');
}
function nativeQualitySheet(){
  // Two UI fixtures, one remote test clip; this is not a real SD/HD HLS source swap.
  sheet('Качество видео',['SD','HD'].map(q=>button('set-native-quality',q,quality===q?'check':'','sheet-option',`data-value="${q}" data-focus="quality-${q}" aria-pressed="${quality===q}"`)).join(''),{showClose:false});
  returnFromSheet='player-surface';focus('quality-'+quality,true);
}
async function nativeMoreSearch(retry=false){
  if(route.name!=='search'||!searchState.hasNext||searchState.loadingMore||searchState.moreError&&!retry)return;
  const id=searchState.requestId,origin=currentKey();searchState.loadingMore=true;searchState.moreError=false;
  const tail=$('.native-search-tail');if(tail)tail.innerHTML=tvCatalogRoute()?tvSearchTail():'<p role="status">Загружаем…</p>';
  await new Promise(resolve=>setTimeout(resolve,450));if(route.name!=='search'||id!==searchState.requestId)return;
  searchState.loadingMore=false;
  if(normalizeSearch(searchState.query)==='сбой страницы'&&!retry)searchState.moreError=true;
  else{searchState.items=[...searchState.allItems];searchState.hasNext=false;}
  syncSearchBody();if(origin)focus(origin,true);
}
function nativeLogs(){
  const content=nativeState.events.join('\n');
  return `<section class="native-logs"><header class="native-log-header">${button('back','Назад','back','btn icon','data-focus="logs-back" aria-label="Назад"')}<h1>Логи</h1><div class="od-row">${button('refresh-logs','Обновить','refresh','btn icon','aria-label="Обновить логи"')}${nativeState.logOpen?button('share-logs','Поделиться логом','share','btn icon','aria-label="Поделиться логом"'):''}</div></header><div class="od-field native-log-select"><label for="log-file">Файл лога</label><select id="log-file" data-focus="log-file"><option value="">Выберите файл</option><option value="session" ${nativeState.logOpen?'selected':''}>prototype-session.log</option></select></div>${nativeState.logOpen?`<pre class="native-log-content" tabindex="0" data-focus="log-content">${esc(content||'Нет записей')}</pre><div class="native-log-scroll od-row">${button('log-top','В начало','up','btn')}${button('log-bottom','В конец','down','btn')}</div>`:`<div class="catalog-feedback">${icon('file')}<h2>${nativeState.events.length?'Выберите файл':'Создайте несколько логов'}</h2>${nativeState.events.length?'<p>Содержимое выбранного лога появится здесь.</p>':''}</div>`}</section>`;
}
async function nativeRefreshCurrent(){
  if(nativeState.refreshing)return;nativeState.refreshing=true;
  const origin=route,key=currentKey(),scroll=$('#main')?.scrollTop||0;
  const node=document.createElement('div');node.className='native-refresh';node.setAttribute('role','status');node.innerHTML=icon('loading')+'<span>Обновляем…</span>';$('#main')?.prepend(node);
  await new Promise(resolve=>setTimeout(resolve,500));nativeState.refreshing=false;
  if(route!==origin)return;node.remove();render(key,scroll);nativeLog('Содержимое обновлено');
}
function nativeCancelSeek(){nativeState.seek=null;playerScrubbing=false;$('.native-seek-preview')?.remove();}
function nativeSeekKey(e){
  if(route.name!=='player'||isCompactUI()||$('.overlay')||mediaState!=='ready'||!mediaDuration)return;
  if(!['ArrowLeft','ArrowRight'].includes(e.key)||!(document.activeElement?.id==='timeline'||document.activeElement?.matches('.tv-player')))return;
  e.preventDefault();e.stopImmediatePropagation();showPlayerControls(false);clearTimeout(playerControlsTimer);playerScrubbing=true;
  const now=Date.now();if(!nativeState.seek||nativeState.seek.key!==e.key)nativeState.seek={key:e.key,start:now,value:position};
  const seek=nativeState.seek,elapsed=now-seek.start,step=elapsed>=3000?60:elapsed>=1500?30:10;
  seek.value=Math.max(0,Math.min(mediaDuration,seek.value+(e.key==='ArrowLeft'?-step:step)));
  const range=$('#timeline');if(range){range.value=seek.value;range.setAttribute('aria-valuetext','Перемотка: '+fmt(seek.value));}
  let preview=$('.native-seek-preview');if(!preview){preview=document.createElement('div');preview.className='native-seek-preview';preview.setAttribute('role','status');$('.player-chrome')?.append(preview);}preview.textContent=fmt(seek.value)+' / '+fmt(mediaDuration);
}
// Capture precedes generic remote spatial navigation. One seek on key release,
// not dozens of native seek calls per repeated key event (PlayerView held seek).
document.addEventListener('keydown',nativeSeekKey,true);
document.addEventListener('keyup',e=>{if(!nativeState.seek||e.key!==nativeState.seek.key)return;e.preventDefault();e.stopImmediatePropagation();const value=nativeState.seek.value;nativeCancelSeek();seekMedia(value);armPlayerControls();},true);
window.addEventListener('blur',nativeCancelSeek);
document.addEventListener('keydown',e=>{
  if(nativeState.seek&&['Escape','BrowserBack'].includes(e.key))nativeCancelSeek();
  const sort=$('.overlay .browse-sort-draft');
  if(sort&&['ArrowLeft','ArrowRight'].includes(e.key)){e.preventDefault();e.stopImmediatePropagation();}
  if(route.name==='browse'&&!$('.overlay')&&['ArrowDown','ArrowUp'].includes(e.key)){
    const key=currentKey();if(e.key==='ArrowDown'&&key==='browse-sort'&&genreCatalogError()){e.preventDefault();e.stopImmediatePropagation();focus('retry-genre');}
    else if(e.key==='ArrowUp'&&key==='retry-genre'){e.preventDefault();e.stopImmediatePropagation();focus('browse-sort');}
  }
},true);
document.addEventListener('change',e=>{if(e.target.id==='log-file'){nativeState.logOpen=!!e.target.value;render(nativeState.logOpen?'log-content':'log-file');}});
document.addEventListener('scroll',e=>{if(route.name==='search'&&e.target.id==='search-body'){searchState.scroll=e.target.scrollTop;if(e.target.scrollHeight-e.target.scrollTop-e.target.clientHeight<320)void nativeMoreSearch();}},{capture:true,passive:true});
let nativePull=null;
document.addEventListener('pointerdown',e=>{if(e.pointerType==='touch'&&isCompactUI()&&['home','favorites','browse','detail'].includes(route.name)&&$('#main')?.scrollTop===0&&!$('.overlay'))nativePull={x:e.clientX,y:e.clientY};},{passive:true});
document.addEventListener('pointerup',e=>{if(nativePull&&e.clientY-nativePull.y>80&&Math.abs(e.clientX-nativePull.x)<50)void nativeRefreshCurrent();nativePull=null;},{passive:true});
document.addEventListener('pointercancel',()=>nativePull=null);
document.addEventListener('click',async e=>{
  const b=e.target.closest('[data-action]');if(!b||b.disabled)return;
  const action=b.dataset.action;
  const handled=['sign-in','enter-guest','cancel-login','confirm-signout','logs','description-toggle','quality','set-native-quality','refresh-episodes','search-more','refresh-logs','share-logs','log-top','log-bottom','favorite','previous','next'];
  if(!handled.includes(action))return;e.preventDefault();e.stopImmediatePropagation();
  if(action==='sign-in'){requestNativeLogin();return;}
  if(action==='enter-guest'){completeNativeAccess('guest');return;}
  if(action==='cancel-login'){cancelNativeLogin();return;}
  if(action==='confirm-signout'){nativeSignOut();return;}
  if(action==='logs'){const key=returnFromSheet||currentKey();closeSheet(false);focus(key,true);go({name:'logs'});return;}
  if(action==='description-toggle'){nativeState.expandedDescription=nativeState.expandedDescription===b.dataset.id?null:b.dataset.id;const section=b.closest('.detail-description');section.classList.toggle('is-expanded',nativeState.expandedDescription===b.dataset.id);b.setAttribute('aria-expanded',String(nativeState.expandedDescription===b.dataset.id));b.textContent=nativeState.expandedDescription?'Свернуть описание':'Подробнее';return;}
  if(action==='previous'||action==='next'){const n=nativeAdjacentEpisode(item(route.id),Number(route.episode),action);if(n!==null)selectPlayerEpisode(n);return;}
  if(action==='quality'){nativeQualitySheet();return;}
  if(action==='set-native-quality'){quality=b.dataset.value;nativeState.quality=quality;closeSheet(true,()=>{const button=$('[data-action="quality"]');if(button){button.querySelector('span').textContent=quality;button.setAttribute('aria-label','Качество: '+quality);}});nativeLog('Выбрано качество '+quality);return;}
  if(action==='refresh-episodes'){void nativeRefreshCurrent();return;}
  if(action==='search-more'){void nativeMoreSearch(true);return;}
  if(action==='refresh-logs'){nativeLog('Журнал обновлён');render('log-file');return;}
  if(action==='log-top'||action==='log-bottom'){const content=$('.native-log-content');if(content)content.scrollTop=action==='log-top'?0:content.scrollHeight;return;}
  if(action==='share-logs'){try{if(navigator.share)await navigator.share({title:'AniStar TV — логи',text:nativeState.events.join('\n')});else if(navigator.clipboard)await navigator.clipboard.writeText(nativeState.events.join('\n'));toast(navigator.share?'':'Лог скопирован');}catch{toast('Не удалось поделиться логом.');}return;}
  if(action==='favorite'){
    if(!nativeAccount()){requestNativeLogin();return;}
    const id=b.dataset.id,key=returnFromSheet,scroll=$('#main')?.scrollTop||0,origin=route,accountFavorites=fav;
    b.disabled=true;b.setAttribute('aria-busy','true');b.innerHTML=icon('loading')+'<span>Сохраняем…</span>';
    await new Promise(resolve=>setTimeout(resolve,600));
    if(!nativeAccount()||fav!==accountFavorites)return;
    fav.has(id)?fav.delete(id):fav.add(id);save();
    if(route===origin){closeSheet(false);render(key,scroll);}nativeLog('Избранное обновлено');
  }
},true);

// SearchScreen/SearchBloc/SearchRules now exist in Flutter. Native parity 2026-11-11.
// HTML uses local fixtures for the same states; real HTTP/auth remain in Flutter.
const searchState={draft:'',query:'',status:'idle',items:[],selectedId:null,requestId:0};
let recentSearches=(()=>{const stored=read('anistar-search-history',[]);return Array.isArray(stored)?[...new Set(stored.filter(x=>typeof x==='string'&&x.trim()).map(x=>x.trim().slice(0,120)))].slice(0,8):[]})();
const normalizeSearch=text=>String(text).toLocaleLowerCase('ru').replace(/ё/g,'е').replace(/[^\p{L}\p{N}]+/gu,' ').trim();
function persistSearchHistory(){try{localStorage.setItem(nativeHistoryKey(),JSON.stringify(recentSearches));}catch{}}
function rememberSearch(query){const same=s=>s.trim().toLocaleLowerCase('ru').replace(/ё/g,'е');recentSearches=[query,...recentSearches.filter(x=>same(x)!==same(query))].slice(0,8);persistSearchHistory();}
async function searchCatalog(query,retry=false){
  // SearchRepository в HTML заменён локальной fixture. Сеть/POST парсер не вызываются.
  await new Promise(resolve=>setTimeout(resolve,500));
  const q=normalizeSearch(query);
  if((q==='ошибка'||q==='offline')&&!retry)throw new Error('Не удалось загрузить результаты. Попробуйте ещё раз.');
  const all=[...data,...siteCatalogItems,...relatedTitles].map(catalogRecord);
  if(q==='демо'||q==='demo'||q==='сбой страницы'||retry&&(q==='ошибка'||q==='offline'))return all;
  const aliases={frieren:'frieren',jujutsu:'jujutsu',demon:'demon',chainsaw:'chainsaw',attack:'attack',spy:'spy'};
  // Локальный поиск по русскому и оригинальному названию, независимо от ё/е,
  // регистра, знаков и порядка слов. Поддерживает короткие запросы от 2 символов.
  const terms=q.split(/\s+/).filter(Boolean);
  if(!terms.length)return [];
  return all.filter(a=>{
    const legacyAliases=Object.entries(aliases).filter(([id])=>a.id.startsWith(id)).map(([,alias])=>alias);
    const text=normalizeSearch([a.title,a.originalTitle,...legacyAliases].filter(Boolean).join(' '));
    return terms.every(term=>text.includes(term));
  });
}
function searchMessage(title,copy,action,label,ic='search'){
  return `<div class="search-feedback catalog-feedback od-stack">${icon(ic)}<h2>${esc(title)}</h2>${copy?`<p>${esc(copy)}</p>`:''}${action?`<div class="catalog-feedback-actions od-cluster">${button(action,label,action==='search-retry'?'refresh':'search','btn')}</div>`:''}</div>`;
}
function searchBody(){
  if(searchState.status==='loading')return `<p class="search-status" role="status">Ищем аниме…</p>${catalogSkeleton()}`;
  if(searchState.status==='error')return searchMessage('Поиск недоступен',searchState.error||'Не удалось загрузить результаты. Попробуйте ещё раз.','search-retry','Повторить','alert');
  if(searchState.status==='ready'){
    if(!searchState.items.length)return searchMessage('Ничего не найдено','Попробуйте другое название или проверьте написание.');
    if(tvCatalogRoute())return tvCatalogScreen('Результаты: '+searchState.query+' · '+searchState.items.length,'search-results');
    return `<p class="search-status" role="status">Результаты для «${esc(searchState.query)}» · Найдено: ${searchState.items.length}</p><section class="search-results home-catalog"><section id="catalog-inspector" class="catalog-inspector od-row-top" aria-label="О выбранном аниме">${inspectorContent()}</section><div class="home-grid-wrap">${grid(searchState.items)}</div></section><div class="native-search-tail">${searchState.moreError?`<p role="alert">Не удалось загрузить следующую страницу.</p>${button('search-more','Повторить загрузку','refresh','btn')}`:searchState.loadingMore?'<p role="status">Загружаем…</p>':''}</div>${searchState.hasNext?'<div id="search-sentinel" aria-hidden="true"></div>':''}`;
  }
  if(!recentSearches.length)return searchMessage('Что будем смотреть?','');
  return `<div class="search-history"><div class="search-history-heading od-row"><h2 class="od-fill">Последние запросы</h2><button type="button" class="btn" data-action="search-clear-history" data-focus="search-clear-history">Очистить</button></div><div class="od-stack">${recentSearches.map((q,i)=>`<div class="search-history-row od-row"><button type="button" class="search-recent od-fill" data-action="search-recent" data-index="${i}" data-focus="search-recent-${i}"><span class="od-clamp-2">${esc(q)}</span></button><button type="button" class="btn search-icon-button od-fixed" data-action="search-remove-history" data-index="${i}" data-focus="search-remove-${i}" aria-label="Удалить запрос ${esc(q)}">${icon('close')}</button></div>`).join('')}</div></div>`;
}
// SearchField / UI Kit: видимая подсказка внутри поля — placeholder.
// По просьбе пользователя она скрывается при фокусе, возвращается при blur,
// если поле пустое. Связанный label остаётся для доступного имени, визуально скрыт.
// Flutter: hintText + FocusNode.hasFocus; не удалять semanticsLabel при фокусе.
// Крестик внутри поля справа (Flutter suffixIcon) очищает ввод; Back — отдельная навигация.
// TV SearchFocus / для будущих ИИ: два разных режима, НЕ геометрический поиск
// ближайшей кнопки. Navigation: поле → очистка → «Найти» (и обратно).
// Если поле пустое, disabled-очистку пропускать. Вниз из формы — к результатам
// или истории; вверх из первого ряда карточек — в поле; влево из поля — в меню.
// Editing включается OK/Enter или кликом: стрелки принадлежат курсору/системной
// IME и НЕ вызывают spatial(). Back завершает ввод, сохраняя запрос; следующий
// Back переводит фокус в левое меню. Ещё Back возвращает к предыдущему экрану.
// Во Flutter: FocusNode/FocusTraversalPolicy + Shortcuts/Actions; OK вызывает
// requestKeyboard, Back сначала отдаётся IME. Не перехватывать D-pad самой IME.
// HTML readonly здесь моделирует navigation, это НЕ замена нативной ТВ-клавиатуры.
// На телефоне поле всегда редактируемо: эти перехваты только для TV-layout.
let searchEditing=false,searchInputNode=null;
function syncSearchInputMode(){
  const input=$('#search-query');
  // Resize/появление экранной клавиатуры не завершают уже начатый ввод.
  // Новый узел означает новый экран; compact всегда использует обычное поле.
  if(input!==searchInputNode||isCompactUI())searchEditing=false;
  // Keep the HTML field editable for paste/autofill as well as typing.
  // TV editing/navigation is a logical key mode, not a browser readonly lock.
  searchInputNode=input;if(input)input.readOnly=false;
}
function beginSearchEditing(){
  const input=$('#search-query');if(!input||isCompactUI())return;
  searchEditing=true;input.readOnly=false;input.focus({preventScroll:true});
}
function endSearchEditing(){
  searchEditing=false;
  const input=$('#search-query');if(input)input.readOnly=false;
}
function focusSearchBody(){
  const target=$('#search-body .anime-card, #search-body [data-action="search-recent"], #search-body [data-action="search-retry"], #search-body [data-action="search-edit"]');
  if(target)focus(target.dataset.focus);
}
document.addEventListener('click',e=>{if(e.target.id==='search-query'&&!isCompactUI())beginSearchEditing();});
document.addEventListener('focusout',e=>{if(e.target.id==='search-query')endSearchEditing();});
document.addEventListener('keydown',e=>{
  if(route.name!=='search'||isCompactUI()||$('.overlay'))return;
  const active=document.activeElement,key=e.key,query=active?.id==='search-query';
  const consume=()=>{e.preventDefault();e.stopImmediatePropagation();held=null;};
  // Не подтверждать промежуточный составной символ как запрос (IME/composition).
  if(query&&(e.isComposing||e.keyCode===229)){e.stopImmediatePropagation();return;}
  if(query&&searchEditing){
    if(['Escape','BrowserBack'].includes(key)){consume();endSearchEditing();return;}
    if(['Enter','Select','Accept'].includes(key)){consume();endSearchEditing();void runSearch();return;}
    // Нативное редактирование и IME получают стрелки без preventDefault.
    if(key.startsWith('Arrow'))e.stopImmediatePropagation();
    return;
  }
  if(['Escape','BrowserBack'].includes(key)||(key==='Backspace'&&!query)){
    consume();back();return; // Тот же корневой контракт, что у остальных разделов.
  }
  if(query&&['Enter','Select','Accept'].includes(key)){consume();beginSearchEditing();return;}
  // Физическая клавиатура также может начать ввод без лишнего Enter.
  if(query&&!e.ctrlKey&&!e.metaKey&&!e.altKey&&(key.length===1||key==='Backspace')){beginSearchEditing();return;}
  if(!key.startsWith('Arrow'))return;
  const clear=$('[data-action="search-clear"]');
  if(active?.closest('#search-form')){
    consume();const current=active.dataset.focus;
    if(key==='ArrowDown'){focusSearchBody();return;}
    if(key==='ArrowUp'){if(!query)focus('search-query');return;}
    if(key==='ArrowLeft')focus(current==='search-query'?'nav-search':current==='search-clear'?'search-query':clear&&!clear.disabled?'search-clear':'search-query');
    if(key==='ArrowRight'&&current!=='search-submit')focus(query&&clear&&!clear.disabled?'search-clear':'search-submit');
    return;
  }
  const row=active?.closest('.search-history-row');
  if(row){
    consume();const rows=[...document.querySelectorAll('.search-history-row')],index=rows.indexOf(row);
    const remove=active.dataset.action==='search-remove-history';
    if(key==='ArrowLeft')focus(remove?'search-recent-'+index:'nav-search');
    if(key==='ArrowRight'&&!remove)focus('search-remove-'+index);
    if(key==='ArrowUp'){if(!index)focus('search-query');else focus((remove?'search-remove-':'search-recent-')+(index-1));}
    if(key==='ArrowDown'&&index+1<rows.length)focus((remove?'search-remove-':'search-recent-')+(index+1));
    return;
  }
  if(active?.closest('#search-body')&&!active.closest('[data-grid]')){
    consume();if(key==='ArrowUp')focus('search-query');else if(key==='ArrowLeft')focus('nav-search');else if(key==='ArrowDown')focusSearchBody();
  }
},true);

function search(){
  return `<section class="search-page" aria-labelledby="search-title"><h1 class="section-title search-title" id="search-title">Поиск</h1><form id="search-form" class="search-form" role="search"><div class="search-field od-field od-fill"><label class="sr-only" for="search-query">Название аниме</label><div class="search-input-row od-row"><input class="od-fill" id="search-query" name="query" type="search" placeholder="Название аниме" autocomplete="off" enterkeyhint="search" data-focus="search-query" aria-describedby="search-input-error" value="${esc(searchState.draft)}"><button type="button" class="btn search-icon-button od-fixed" data-action="search-clear" data-focus="search-clear" aria-label="Очистить запрос" ${searchState.draft?'':'disabled'}>${icon('close')}</button></div><span id="search-input-error" class="search-input-error" role="alert"></span></div><button type="button" class="btn primary search-submit" data-action="search-submit" data-focus="search-submit">${icon('search')}<span>Найти</span></button></form><div id="search-body" aria-busy="${searchState.status==='loading'}">${searchBody()}</div></section>`;
}
function syncSearchBody(){
  if(route.name!=='search'||!$('#search-body'))return;
  cancelInspectorUpdate();cancelInspectorAnimations();
  cancelHomeRailMove();
  const body=$('#search-body');body.innerHTML=searchBody();body.setAttribute('aria-busy',String(searchState.status==='loading'));
  if(tvCatalogRoute()&&$('.home-poster-rail'))$('.home-poster-rail').scrollLeft=tvRailOffset();
  setupCatalogObserver();
}
function resetSearch(){
  searchState.requestId++;Object.assign(searchState,{draft:'',query:'',status:'idle',items:[],selectedId:null,hasNext:false,loadingMore:false,moreError:false});
  const input=$('#search-query');if(input){input.value='';input.removeAttribute('aria-invalid');}
  if($('#search-input-error'))$('#search-input-error').textContent='';
  if($('[data-action="search-clear"]'))$('[data-action="search-clear"]').disabled=true;
  syncSearchBody();focus('search-query');
}
async function runSearch(value=$('#search-query')?.value??searchState.draft,retry=false){
  const query=String(value).trim(),length=[...query].length,input=$('#search-query');
  const requestId=++searchState.requestId;
  tvCatalogOffsets.delete('search:'+query);
  endSearchEditing();
  if(input)input.value=query;
  const message=length>0&&length<2?'Введите не менее 2 символов.':length>120?'Введите не более 120 символов.':'';
  $('#search-input-error').textContent=message;input?.setAttribute('aria-invalid',String(!!message));
  Object.assign(searchState,{scroll:0,draft:query,query,status:message?'idle':query?'loading':'ready',items:[],selectedId:null,hasNext:false,loadingMore:false,moreError:false,error:''});
  if($('[data-action="search-clear"]'))$('[data-action="search-clear"]').disabled=!query;
  focus('search-query',true);if($('#main'))$('#main').scrollTop=0;if($('#search-body'))$('#search-body').scrollTop=0;syncSearchBody();
  if(!query||message)return;
  rememberSearch(query);
  try{
    const items=await searchCatalog(query,retry);if(requestId!==searchState.requestId)return;
    searchState.allItems=items;searchState.items=items.slice(0,4);searchState.hasNext=items.length>4;searchState.status='ready';searchState.selectedId=items[0]?.id;
  }catch(error){if(requestId!==searchState.requestId)return;searchState.status='error';searchState.error=error.message;}
  if(route.name!=='search')return;
  const keepFocus=currentKey()==='search-query'&&searchState.draft===query&&!searchEditing;
  syncSearchBody();
  // Не красть фокус при завершении запроса. Успех тоже остаётся в форме как SearchScreen;
  // Down открывает результат; при ошибке доступен явный повтор, без потери запроса.
  if(keepFocus)focus('search-query',true);
}
// История локальная, максимум 8 запросов, без фиктивных подсказок. Хранить только
// запросы, не личные данные. Удаление одного пункта и всей истории доступны касанием
// и пультом. Возврат из detail не меняет историю и не очищает поисковое поле.
document.addEventListener('submit',e=>{if(e.target.id==='search-form'){e.preventDefault();void runSearch($('#search-query')?.value??searchState.draft);}});
document.addEventListener('input',e=>{
  if(e.target.id!=='search-query')return;
  searchState.draft=e.target.value;
  $('[data-action="search-clear"]').disabled=!e.target.value;
  e.target.removeAttribute('aria-invalid');$('#search-input-error').textContent='';
});
document.addEventListener('click',e=>{
  const b=e.target.closest('[data-action]');if(!b||b.disabled||b.closest('.overlay'))return;
  switch(b.dataset.action){
    // Прямое действие кнопки: клик/касание/OK не зависят от default submit
    // HTML-формы в контейнере превью. type=button исключает второй запуск.
    // IME Search/Enter отдельно обрабатывает submit этой же формы.
    // Всегда читать фактическое поле: внешняя клавиатура/автозаполнение могут
    // изменить value без input. Во Flutter все способы ведут в один onSearch.
    case 'search-submit':void runSearch($('#search-query')?.value??searchState.draft);break;
    case 'search-clear':resetSearch();break;
    case 'search-edit':focus('search-query');break;
    case 'search-retry':void runSearch(searchState.query,true);break;
    case 'search-recent':if(recentSearches[Number(b.dataset.index)])void runSearch(recentSearches[Number(b.dataset.index)]);break;
    case 'search-remove-history':{const index=Number(b.dataset.index);recentSearches.splice(index,1);persistSearchHistory();syncSearchBody();if(!focus('search-recent-'+Math.min(index,recentSearches.length-1)))focus('search-query');break;}
    case 'search-clear-history':recentSearches=[];persistSearchHistory();syncSearchBody();focus('search-query');break;
  }
});

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
// Постер скрыт внутри TV-подробностей: общего Hero между каталогом и сериалом нет.
// Остаётся обычное появление страницы; возврат восстанавливает фокус/прокрутку.
function animateRoute(previous){
  const current=route.name+':'+(route.id||(route.filterType?route.filterType+':'+route.genre:route.genre)||'');
  if(!previous||previous===current)return;
  const el=$('#main')||$('.player')||$('.login');
  const isDetail=route.name==='detail';
  animateUI(el,isDetail?[{opacity:0,transform:'translateY(16px)'},{opacity:1,transform:'translateY(0)'}]:[{opacity:0},{opacity:1}],isDetail?motion.page:motion.fast);
}
reducedMotion.addEventListener('change',e=>{
  if(e.matches)(document.getAnimations?.()||[]).forEach(a=>{try{a.finish()}catch{a.cancel()}});
});

const item=id=>[...data,...siteCatalogItems,...relatedTitles].find(a=>a.id===id)||data[0];
const poster=a=>`<img class="od-media" src="assets/${a.id}.jpg" width="${a.w||225}" height="${a.h}" alt="Постер аниме «${esc(a.title)}»">`;
// UI Kit / ActionButton: один уникальный focus key на узел. Явный ключ
// важнее action: у ссылок сезонов и пунктов панелей ключи различаются.
// Не дублировать data-focus в HTML — браузер сохраняет первый атрибут.
// Flutter: один стабильный FocusNode/ValueKey для конкретного действия.
function button(action,label,ic='',cls='btn',attrs=''){
  const key=attrs.match(/\bdata-focus="([^"]*)"/)?.[1]??action;
  const rest=attrs.replace(/\s*\bdata-focus="[^"]*"/g,'');
  return `<button type="button" class="${cls}" data-action="${action}" data-focus="${esc(key)}" ${rest}>${ic?icon(ic):''}<span>${label}</span></button>`;
}
// Brand is a static native UI Kit component; app exit is Android root Back.
function brand(){
  // lib/packages/ui_kit: AnistarLogo/LoginBrand. Логотип не запускает выход.
  return '<div class="brand"><img src="assets/anistar-logo.png" width="1254" height="1254" alt=""><span>AniStar <em>TV</em></span></div>';
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
function menu(){
  const routes=[['home','Главная','home'],['search','Поиск','search'],...(nativeAccount()?[['favorites','Избранное','heart']]:[]),['genres','Жанры','grid']];
  return `<aside class="sidebar ${menuExpanded?'is-expanded':''}" aria-label="Основная навигация"><div class="menu-inner">${brand()}<nav class="menu">${routes.map(([n,t,ic])=>`<button type="button" data-action="nav" data-name="${n}" data-focus="nav-${n}" aria-label="${t}" ${route.name===n||(route.name==='browse'&&n==='genres')||(route.name==='detail'&&n===nativeState.destination)?'aria-current="page"':''}>${icon(ic)}<span>${t}</span></button>`).join('')}<button type="button" data-action="${nativeAccount()?'signout':'sign-in'}" data-focus="nav-account" aria-label="${nativeAccount()?'Выйти из аккаунта':'Войти'}">${icon(nativeAccount()?'logout':'login')}<span>${nativeAccount()?'Выйти из аккаунта':'Войти'}</span></button>${nativeState.debugTools?`<button type="button" data-action="logs" data-focus="nav-logs" aria-label="Открыть логи">${icon('file')}<span>Открыть логи</span></button>`:''}</nav>${nativeAccount()?`<div class="account">${accountSummary({displayName:nativeState.user,initials:nativeState.user.slice(0,2).toUpperCase(),avatarUrl:null})}</div>`:''}</div></aside>`;
}
// AdaptiveNavigation: одна route и одна история для ТВ и телефона, без копии приложения.
// Скрытая навигация inert; одинаковые focus keys допустимы только у взаимоисключающих
// вариантов. focus() ниже выбирает видимый элемент. Логотип телефона НЕ запускает exit.
function compactHeader(){
  const nested=['detail','browse','logs'].includes(route.name);
  const label=route.name==='browse'?route.genre:route.name==='detail'?item(route.id).title:({home:'Главная',search:'Поиск',favorites:'Избранное',genres:'Жанры',logs:'Логи'})[route.name]||'AniStar';
  // Content owns long titles; the mobile bar must not repeat them.
  const contentTitle=['detail','genres','browse'].includes(route.name);
  return `<header class="compact-header" aria-label="${contentTitle?'Навигация':esc(label)}">${nested?button('back','Назад','back','btn compact-back','aria-label="Назад"'):brand()}${contentTitle?'':`<h1 class="compact-heading ${nested?'compact-context-heading':''}"><span class="compact-heading-text">${esc(label)}</span></h1>`}<button type="button" class="btn compact-account" data-action="${nativeAccount()?'account':'sign-in'}" data-focus="compact-account" aria-label="${nativeAccount()?'Аккаунт: '+esc(nativeState.user):'Войти'}">${icon(nativeAccount()?'user':'login')}</button></header>`;
}
function compactNavigation(){
  const current=['home','favorites','genres','search'].includes(route.name)?route.name:nativeState.destination;
  return `<nav class="compact-nav" aria-label="Основная навигация">${[['home','Главная','home'],['search','Поиск','search'],...(nativeAccount()?[['favorites','Избранное','heart']]:[]),['genres','Жанры','grid']].map(([name,label,ic])=>`<button type="button" data-action="nav" data-name="${name}" data-focus="nav-${name}" ${current===name?'aria-current="page"':''}>${icon(ic)}<span>${label}</span></button>`).join('')}</nav>`;
}
function compactAccount(){
  if(!nativeAccount()){requestNativeLogin();return;}
  sheet('Аккаунт',`<div class="compact-profile">${accountSummary({displayName:nativeState.user,initials:nativeState.user.slice(0,2).toUpperCase(),avatarUrl:null})}</div>${button('signout','Выйти из аккаунта','logout','btn')}${nativeState.debugTools?button('logs','Открыть логи','file','btn'):''}`,{showClose:false});
}
function syncAdaptiveLayout(){
  const compact=isCompactUI();
  syncSearchInputMode();
  syncDetailDisclosureLayout();
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
compactLayout.addEventListener('change',()=>{
  // Swap only the home content. Account forms, player, overlays and shared data survive resize.
  const main=$('#main');
  if(route.name==='home'&&main){
    const key=currentKey();
    if(main.classList.contains('home-stage'))homeRailScroll=$('.home-poster-rail')?.scrollLeft||0;
    else homeMobileScroll=main.scrollTop;
    cancelHomeRailMove();cancelInspectorUpdate();cancelInspectorAnimations();
    main.innerHTML=home();
    main.classList.toggle('home-stage',!isCompactUI());
    main.scrollTop=isCompactUI()?homeMobileScroll:0;
    if($('.home-poster-rail'))$('.home-poster-rail').scrollLeft=homeRailScroll;
    if(!$('.overlay')&&!focus(key,true))main.focus({preventScroll:true});
    syncAdaptiveLayout();setupCatalogObserver();
    return;
  }
  if(['browse','favorites','search'].includes(route.name)&&main){const key=currentKey();cancelHomeRailMove();render(key);return;}
  syncAdaptiveLayout();
});
phoneLayout.addEventListener('change',()=>{cancelInspectorUpdate();cancelInspectorAnimations();});
// Источник информации на телефоне — полная карточка; hover/TV-inspector не нужен.
// Ничего не удаляем из данных и не запускаем параллельный мобильный парсер.
function top(title,back=false){return `<header class="topbar">${back?button('back','Назад','back','back-btn'):`<strong>${title}</strong>`}<div class="right"><span>AniStar TV</span></div></header>`;}
// Expanded projection proposed for the site's catalog HTML. These are demo records,
// not a live snapshot. Optional ratings, release/update labels and voiceovers stay null
// unless supplied by a source; planned episode totals are never treated as availability.
const catalogRatings={frieren:9.2,jujutsu:9.5,demon:9.7,attack:9.7,spy:9.5};
// Additional fields transcribed from AniStar pages; unknown fields remain absent.
const catalogDetails={
  frieren:{author:'Канэхито Ямада',manga:'Провожающая в последний путь Фрирен',metadataSource:'https://anistar.org/9576-provozhayuschaya-v-posledniy-put-friren-sousou-no-frieren.html',watchOrder:[{"label": "Провожающая в последний путь Фрирен [TB-1]", "url": "https://v31.astar.bz/9576-.html"}, {"label": "Провожающая в последний путь Фрирен [TB-2]", "url": "https://v31.astar.bz/10686-.html"}],categories:['Аниме','Сёнен','Драма','Приключения','Фэнтези'],genres:['Приключения','Сёнен','Фэнтези','Драма'],voiceover:'Русская озвучка',director:'Кэйитиро Сайто',seriesInfo:'ТВ (28 эп.), 25 мин.',updateText:'Добавлена 28 (заключительная) серия с русской озвучкой',publishedAt:'22-03-2024, 19:05',publishedISO:'2024-03-22T19:05:00'},
  jujutsu:{categories:['Аниме','Демоны','Экшен','Сверхъестественное','Школа','Сёнен','Ужасы'],voiceover:'Русская озвучка',director:'Пак Сон Ху',seriesInfo:'ТВ (24 эп.), 25 мин.'},
  spy:{author:'Тацуя Эндо',manga:'Семья шпиона',metadataSource:'https://anistar.org/8643-semya-shpiona-spy-x-family.html',categories:['Аниме','Экшен','Сёнен','Комедия'],voiceover:'Русская озвучка',director:'Кадзухиро Фурухаси',seriesInfo:'ТВ (25 эп.), 25 мин.',updateText:'Добавлена 25 (заключительная) серия с русской озвучкой',publishedAt:'24.12.2022, 20:22',publishedISO:'2022-12-24T20:22:00'},
  attack:{categories:['Аниме','Приключения','Фантастика'],voiceover:'Русская озвучка',seriesInfo:'ТВ (25 эп.), 25 мин.'}
};
// Старые демонстрационные тайтлы остаются доступны через избранное и поиск.
const legacyCatalogRecords=data.map(a=>({...a,posterUri:'assets/'+a.id+'.jpg',rating:catalogRatings[a.id]??null,genres:[...a.genre],description:a.desc,seriesInfo:'ТВ · '+a.episodes+' эпизодов',...(catalogDetails[a.id]||{})}));
// Размеры реальных порций: первая 9 (реклама исключена), вторая 10.
// Это локальный снимок, не живой API. Новые серии не выводятся из счётчика эпизодов.
const catalogPages=window.ANISTAR_CATALOG_SNAPSHOT.pages;
const CATALOG_PAGE_SIZE=window.ANISTAR_CATALOG_SNAPSHOT.pageSize;
const homeFeed={items:[],page:0,hasNext:true,loading:false,error:null};
let homeRailScroll=0,homeMobileScroll=0,homeRailMotion=null;
let selectedCatalogId=catalogPages[0].items[0]?.id,selectedFavoritesId=null,catalogObserver=null,pendingCatalogFocus=null,inspectorResizeObserver=null;
function catalogRecord(a){return homeFeed.items.find(x=>x.id===a.id)||catalogPages.flatMap(p=>p.items).find(x=>x.id===a.id)||legacyCatalogRecords.find(x=>x.id===a.id)||(a.id==='frieren2'?{...a,watchOrder:catalogDetails.frieren.watchOrder}:a);}
/** UI Kit / MediaCard — единый компонент карточек главной, избранного и жанров.
 * Не копировать разметку и анимацию в новые экраны: вызывать mediaCard(options).
 * variant: poster | landscape | episode — готовые варианты; ratio: [w,h] переопределяет их.
 * frameHeight: положительное число px, если нужна фиксированная высота; по умолчанию
 * высота следует пропорциям и ширине сетки. fit: cover | contain, без растягивания.
 * imageWidth/imageHeight — реальные размеры файла; title — доступное имя и подпись.
 * action/id/genre/focusKey задают поведение; saved включает отметку избранного.
 * episodeNumber/status — номер и состояние серии; вариант episode использует previewUri и общую подложку подписи.
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
function mediaCard({title,image='',imageWidth=225,imageHeight=350,variant='poster',id=null,action='detail',focusKey='',saved=false,genre=null,episodeNumber=null,status='',caption='',selected=false,rating=null,cardClass=''}){
  const attrs=`type="button" data-action="${esc(action)}" data-focus="${esc(focusKey||action)}" ${id!==null?`data-id="${esc(id)}"`:''} ${genre!==null?`data-genre="${esc(genre)}"`:''} ${episodeNumber!==null?`data-episode="${episodeNumber}"`:''}`;
  if(variant==='episode')return `<button class="ui-media-card anime-card native-episode ${selected?'is-current-episode':''}" ${attrs} aria-label="${esc(title+(caption?', '+caption:'')+(status?', '+status:'')+(selected?', текущая':''))}" ${selected?'aria-current="step"':''}><span class="poster-wrap">${image?`<img class="od-media" src="${esc(image)}" width="${imageWidth}" height="${imageHeight}" alt="">`:`<span class="native-preview-fallback" aria-hidden="true">${icon('alert')}</span>`}<span class="poster-title od-field"><span class="media-card-label">${esc(title)}</span>${caption?`<span class="media-card-status">${esc(caption)}</span>`:''}</span>${status?`<span class="native-watched" aria-label="Просмотрено">${icon('check')}</span>`:''}${selected?`<span class="native-current" aria-hidden="true">${icon('check')}</span>`:''}</span></button>`;
  // Shared TV/mobile poster overlays. Data and favorite state have one producer;
  // parents control dimensions via CSS variables, never a second card template.
  const score=typeof rating==='number'&&Number.isFinite(rating)?`<span class="media-card-rating" aria-label="Рейтинг ${rating.toFixed(1)} из 10">${icon('star')}<span>${rating.toFixed(1).replace('.',',')}</span></span>`:'';
  const content=`<span class="poster-wrap"><img class="od-media" src="${esc(image)}" width="${imageWidth}" height="${imageHeight}" alt="">${score}${saved?favoriteRibbon():''}<span class="poster-title"><span class="od-clamp-2">${esc(title)}</span></span></span>`;
  // Card tap opens the title. No per-card menu button; saved status is passive.
  // Favorite actions remain in title details / the existing long-press sheet.
  return `<div class="native-media-item"> <button class="ui-media-card anime-card od-tile poster-card${variant==='landscape'?' ui-media-card--landscape':''}${cardClass?' '+esc(cardClass):''}${selected?' is-selected':''}" ${attrs} aria-label="${esc(title)}">${content}</button></div>`;
}
// Shared poster component: stable title ID, rating and current-account favorite status.
function card(a,{tvHome=false}={}){
  // Favorites already conveys this status; suppress the ribbon in both layouts.
  const saved=route.name!=='favorites'&&nativeAccount()&&fav.has(a.id);
  return mediaCard({title:a.title,image:'assets/'+a.id+'.jpg',imageWidth:a.w||225,imageHeight:a.h,id:a.id,focusKey:'card-'+a.id,saved,rating:tvHome||route.name==='home'?catalogRecord(a).rating:null,cardClass:tvHome?'home-poster-card':'',selected:tvHome&&a.id===selectedInspectorId()});
}
function grid(items){return `<div class="od-grid poster-grid" data-grid>${items.map(a=>card(a)).join('')}</div>`;}
// Loading повторяет геометрию постера: подписи у MediaCard внутри картинки.
// Не возвращать внешние полоски-подписи, иначе выдача скачет при загрузке.
function catalogSkeleton(){return `<div class="od-grid poster-grid home-grid" aria-hidden="true">${Array.from({length:4},()=>'<div class="catalog-skeleton"><div class="skeleton-poster"></div></div>').join('')}</div>`;}
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
  const records=[...data,...siteCatalogItems].map(catalogRecord);
  if(route.filterType==='year')return records.filter(a=>String(a.year)===route.genre);
  if(route.filterType==='director')return records.filter(a=>a.director===route.genre);
  if(['author','manga'].includes(route.filterType))return records.filter(a=>a[route.filterType]===route.genre);
  const filter=siteGenres.find(g=>g.name===route.genre)?.filter||route.genre;
  // Источники смешивают регистр и латинскую e в «Фэнтeзи»; подписи не меняем.
  const genreKey=value=>normalizeSearch(value).replace(/e/g,'е');
  return records.filter(a=>(a.genres||[]).some(genre=>genreKey(genre)===genreKey(filter)));
}
function sortValue(record,criterion){
  if(criterion==='title')return record.title;
  if(criterion==='date')return record.publishedISO||null;
  const value=record[{popularity:'rating',visits:'visits',comments:'commentCount'}[criterion]];
  return typeof value==='number'&&Number.isFinite(value)?value:null;
}
function canSortBy(criterion){return ['date','popularity','visits','comments','title'].includes(criterion);}
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
  // Every existing catalog-filter entry uses the same compact label/control row.
  return `<div class="catalog-filter-row" role="group" aria-label="Фильтр каталога"><span class="catalog-filter-label">Фильтр</span>${button('browse-sort',browseSortLabel(),'filter','btn browse-sort-button',`aria-label="Фильтр, сортировка: ${esc(browseSortLabel())}" aria-haspopup="dialog" ${genreSessionExpired()?'disabled':''}`)}</div>`;
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
  if(route.name!=='browse'||genreSessionExpired())return;
  browseSortDraft={...currentBrowseSort()};browseSortOrigin=route;
  sheet('Сортировка','<div id="browse-sort-draft" class="browse-sort-draft">'+browseSortPanel()+'</div>',{showClose:false});
  focus('criterion-'+browseSortDraft.criterion,true);
}
function changeBrowseSortDraft(action,value){
  if(!browseSortDraft||route!==browseSortOrigin)return;
  if(action==='draft-sort-criterion'){if(!canSortBy(value))return;browseSortDraft.criterion=value;}
  else browseSortDraft.ascending=value==='true';
  const panel=$('#browse-sort-draft');if(!panel)return;
  panel.innerHTML=browseSortPanel();
  focus((action==='draft-sort-criterion'?'criterion-':'direction-')+value,true);
}
function applyBrowseSort(){
  if(!browseSortDraft||route!==browseSortOrigin)return;
  const origin=route,previous=currentBrowseSort();
  if(previous.criterion===browseSortDraft.criterion&&previous.ascending===browseSortDraft.ascending){closeSheet();return;}
  browseSorts.set(browseFilterKey(),{...browseSortDraft});
  // Как Flutter _chooseSort(): сохранять фильтр, сбросить выдачу к началу,
  // оставить фокус на сортировке. Отмена/Back не меняют применённые настройки.
  selectedGenreIds.delete(browseFilterKey());tvCatalogOffsets.delete('browse:'+browseFilterKey());
  closeSheet(true,()=>{if(route===origin)render('browse-sort',0);});
}
const tvCatalogOffsets=new Map();
let restoringTvCatalogFocus=false;
function tvCatalogRoute(){return !isCompactUI()&&['home','browse','favorites','search'].includes(route.name);}
function tvCatalogKey(){return route.name+':'+(route.name==='browse'?browseFilterKey():route.name==='search'?searchState.query:'');}
function tvRailOffset(){return route.name==='home'?homeRailScroll:tvCatalogOffsets.get(tvCatalogKey())||0;}
function rememberTvRailOffset(value){if(route.name==='home')homeRailScroll=value;else tvCatalogOffsets.set(tvCatalogKey(),value);}
function activeCatalogItems(){
  if(route.name==='search')return searchState.items;
  if(route.name==='favorites')return [...data,...siteCatalogItems,...relatedTitles].filter(a=>fav.has(a.id)).map(catalogRecord);
  if(route.name==='browse')return sortedBrowseRecords(filteredCatalogRecords());
  return homeFeed.items;
}
function selectedInspectorId(){if(route.name==='search')return searchState.selectedId;return route.name==='favorites'?selectedFavoritesId:route.name==='browse'?selectedGenreIds.get((route.filterType||'genre')+':'+route.genre):selectedCatalogId;}
function selectInspectorId(id){if(route.name==='search'){searchState.selectedId=id;return;}if(route.name==='favorites')selectedFavoritesId=id;else if(route.name==='browse')selectedGenreIds.set((route.filterType||'genre')+':'+route.genre,id);else selectedCatalogId=id;}
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
// Home-only composition. Reuses localized posters and catalog records; other catalogs retain their layout.
function homeSelection(){const items=activeCatalogItems();return items.find(a=>a.id===selectedInspectorId())||items[0];}
// Same renderer as mobile; TV adds only sizing/selection through a modifier.
function homeCard(a){return card({...item(a.id),...a},{tvHome:true});}
function homeMetadataFilters(c,a){
  // На главной только жанры: без подписи слева и без внутренних скроллеров.
  // Остальные метаданные и фильтры остаются на полной странице сериала.
  return `<div class="home-feature-tags od-cluster" role="group" aria-label="Жанры">${(c.genres||a.genre||[]).map((genre,i)=>metadataFilter('genre',genre,esc(genre),'home-filter-genre-'+i)).join('')}</div>`;
}
// Только TV-главная: длинная fixture второго тайтла для проверки TextOverflow.ellipsis.
// Реальные description/desc в catalog-data.js и полный сюжет сериала не изменяются.
const homeDescriptionOriginals=new WeakMap();
function homeDescriptionText(c){
  const original=c.description||'';
  if(route.name!=='home'||c.id!==catalogPages[0].items[1]?.id||!original)return original;
  return 'Демонстрация длинного описания. '+Array.from({length:12},()=>original).join(' ');
}
function syncHomeDescriptionLines(){
  if(!tvCatalogRoute())return;
  const description=$('.home-feature-description');if(!description)return;
  const text=description.querySelector('.home-description-text');if(!text)return;
  if(!homeDescriptionOriginals.has(text))homeDescriptionOriginals.set(text,text.textContent);
  const full=homeDescriptionOriginals.get(text);
  text.textContent=full;description.removeAttribute('aria-label');
  description.dataset.truncated='false';
  const lineHeight=parseFloat(getComputedStyle(description).lineHeight);
  const available=description.clientHeight;
  if(!lineHeight||available<lineHeight)return;
  // Размер берём из реальной свободной области, а не из количества символов.
  // Округляем вниз до целых строк; при resize всегда восстанавливаем исходник.
  const limit=Math.floor(available/lineHeight)*lineHeight;
  if(text.scrollHeight<=limit+1)return;
  // Двоичный подбор гарантирует видимое многоточие и в браузерах, где
  // -webkit-line-clamp обрезает текст без ellipsis при растянутой grid-строке.
  const words=full.trim().split(/\s+/),units=words.length>1?words:Array.from(full);
  const join=words.length>1?' ':'';
  let low=0,high=units.length;
  while(low<high){
    const mid=Math.ceil((low+high)/2);
    text.textContent=units.slice(0,mid).join(join).trimEnd()+'…';
    if(text.scrollHeight<=limit+1)low=mid;else high=mid-1;
  }
  text.textContent=units.slice(0,low).join(join).trimEnd()+'…';
  description.dataset.truncated='true';description.setAttribute('aria-label',full);
}
// После загрузки локального шрифта ширина букв может измениться.
document.fonts?.ready.then(()=>syncHomeDescriptionLines());

function selectHomeCard(id){
  document.querySelectorAll('.home-poster-card').forEach(card=>card.classList.toggle('is-selected',card.dataset.id===id));
}
// Same confirmed-viewing rule as the title screen, including sparse episode lists.
function homeWatchEpisode(a){
  const ascending=[...episodeNumbersDescending(a)].sort((x,y)=>x-y);
  const prefix=a.id+':';
  const confirmed=[...watched].filter(key=>key.startsWith(prefix)).map(key=>Number(key.slice(prefix.length))).filter(Number.isFinite);
  for(const record of a.episodeRecords||[])if(record.isWatched)confirmed.push(record.number);
  const last=confirmed.length?Math.max(...confirmed):null;
  return ascending.find(number=>last===null||number>last)??ascending[0];
}
function homeFavoriteButton(id){
  if(!nativeAccount())return '';
  const saved=nativeAccount()&&fav.has(id),busy=pendingFavorites.has(id);
  return button('favorite-toggle',busy?'Сохраняем…':saved?'Убрать из избранного':'В избранное',saved?'heartMinus':'heartPlus','btn home-favorite-action',`data-id="${esc(id)}" data-focus="home-feature-favorite" aria-pressed="${saved}" aria-busy="${busy}" aria-disabled="${busy}"`);
}
// TV 16:9: нижняя лента закреплена grid-строкой экрана; верхний блок занимает остаток.
// Порядок: название / сведения с датой / жанры / описание (в том числе пустое) / обновление / действия.
// В home.css заданы grid-row: кнопки и обновление закреплены снизу постоянными строками.
// Смена фокуса анимирует только opacity; высоту hero и координату ленты не анимировать.
function homeInspectorContent(){
  const c=homeSelection();
  if(!c)return `<div class="home-preview-empty od-stack"><span class="eyebrow">Главная</span><h2>Выбирайте, что смотреть</h2><p>Подборка появится после загрузки каталога.</p></div>`;
  const a=item(c.id),rating=typeof c.rating==='number'&&Number.isFinite(c.rating)?c.rating:null;
  const n=homeWatchEpisode(a),descriptionText=homeDescriptionText(c);
  // Отсутствие списка серий в каталожном снимке не означает «серий нет».
  // Кнопка остаётся акцентной и доступной: открывает сериал для выбора серии,
  // а при известном номере запускает уже существующий сценарий воспроизведения.
  const watch=button(n===undefined?'detail':'play','Смотреть','play','btn primary home-watch-action',`data-id="${esc(c.id)}" ${n===undefined?'':`data-episode="${n}"`} data-focus="home-feature-play" aria-label="${n===undefined?'Открыть серии: '+esc(c.title):'Смотреть: '+esc(c.title)+', серия '+n}"`);
  // Background fits the screen height at the poster ratio; rail keeps its own crop.
  return `<div class="home-feature-backdrop" style="--home-backdrop-ratio:${a.w||225} / ${a.h||350}" aria-hidden="true"><img class="home-backdrop-halo" src="assets/${esc(c.id)}.jpg" width="${a.w||225}" height="${a.h||350}" alt=""><img class="home-backdrop-image" src="assets/${esc(c.id)}.jpg" width="${a.w||225}" height="${a.h||350}" alt=""></div><div class="home-feature-copy od-stack"><h2 class="anime-title">${esc(c.title)}</h2><div class="home-feature-facts od-cluster">${rating!==null?`<span class="home-feature-rating od-row" aria-label="Рейтинг ${rating.toFixed(1)} из 10">${icon('star')}<strong>${rating.toFixed(1).replace('.',',')}</strong><span class="home-rating-scale">/ 10</span></span>`:''}${c.seriesInfo?`<span>${esc(c.seriesInfo)}</span>`:''}${c.voiceover||c.publishedAt?`<span class="home-voice-publication od-cluster">${c.voiceover?`<span>${esc(c.voiceover)}</span>`:''}${c.publishedAt?`<span class="home-publication-date od-nowrap" aria-label="Дата обновления">${esc(c.publishedAt)}</span>`:''}</span>`:''}</div>${homeMetadataFilters(c,a)}<p class="home-feature-description"${descriptionText?'':' aria-hidden="true"'}><span class="home-description-text">${esc(descriptionText)}</span></p>${c.updateText?`<div class="home-feature-update od-field"><p class="home-update-text">${esc(c.updateText)}</p></div>`:''}<div class="home-feature-actions od-cluster">${watch}${homeFavoriteButton(c.id)}</div></div>`;
}
function updateHomeInspector(id){
  selectHomeCard(id);
  if(!activeCatalogItems().some(a=>a.id===id)||pendingInspectorId===id)return;
  cancelInspectorUpdate();cancelInspectorAnimations();
  if(selectedInspectorId()===id)return;
  const el=$('#catalog-inspector'),origin=route;
  if(!el)return;
  pendingInspectorId=id;
  const commit=()=>{
    if(route!==origin||!el.isConnected||pendingInspectorId!==id)return;
    selectInspectorId(id);pendingInspectorId=null;
    el.innerHTML=homeInspectorContent();
    syncHomeDescriptionLines();
    if(!reducedMotion.matches){const incoming=animateUI(el,[{opacity:0},{opacity:1}],220,motion.enter);if(incoming)inspectorMotions.push(incoming);}
  };
  if(reducedMotion.matches){commit();return;}
  inspectorUpdateTimer=setTimeout(()=>{
    inspectorUpdateTimer=null;
    const outgoing=animateUI(el,[{opacity:1},{opacity:0}],110,motion.exit);
    if(outgoing){inspectorMotions.push(outgoing);outgoing.finished.then(commit,()=>{});}else commit();
  },motion.inspectorDelay);
}
function homeLoadingCards(){
  const nextPage=catalogPages[homeFeed.page];
  const count=nextPage?.items.length??CATALOG_PAGE_SIZE;
  // Одна заглушка на каждую запись следующего ответа; единая геометрия TV-кадра 2:3.
  return `<div class="home-loading-cards od-row" aria-hidden="true">${Array.from({length:count},()=>'<div class="home-loading-card od-stack"><div class="skeleton-poster"></div></div>').join('')}</div>${homeFeed.loading?`<span class="sr-only" role="status">Загружаем следующую страницу: ${count} аниме…</span>`:''}`;
}
// TV infinite scroll: только реальная видимость первого незагруженного слота,
// без rootMargin-предзагрузки. Фокус/первый шаг вправо сами по себе не являются запросом.
function observeHomeLoadingEdge(){
  catalogObserver?.disconnect();catalogObserver=null;
  const rail=$('.home-poster-rail'),placeholder=rail?.querySelector('.home-loading-card');
  if(!rail||!placeholder||typeof IntersectionObserver==='undefined')return;
  catalogObserver=new IntersectionObserver(entries=>{
    if(entries.some(entry=>entry.isIntersecting))maybeLoadCatalog();
  },{root:rail,rootMargin:'0px',threshold:0});
  catalogObserver.observe(placeholder);
}
function onHomeRailScroll(event){
  rememberTvRailOffset(event.currentTarget.scrollLeft);
  if(route.name==='search')maybeLoadTvSearch();else maybeLoadCatalog();
}

function tvSearchTail(){
  if(searchState.moreError)return `<div class="home-rail-error od-stack"><p>Не удалось загрузить следующую страницу.</p>${button('search-more','Повторить','refresh','btn')}</div>`;
  if(!searchState.hasNext)return '';
  const remaining=searchState.allItems.length-searchState.items.length;
  return `<div class="home-loading-cards od-row" aria-hidden="true">${Array.from({length:remaining},()=>'<div class="home-loading-card"><div class="skeleton-poster"></div></div>').join('')}</div>${searchState.loadingMore?'<span class="sr-only" role="status">Загружаем результаты…</span>':''}`;
}
function maybeLoadTvSearch(){
  if(route.name!=='search'||!tvCatalogRoute()||!searchState.hasNext||searchState.loadingMore||searchState.moreError)return;
  const rail=$('.home-poster-rail'),slot=rail?.querySelector('.home-loading-card');if(!slot)return;
  const r=rail.getBoundingClientRect(),s=slot.getBoundingClientRect();
  if(Math.min(r.right,s.right)>Math.max(r.left,s.left)&&Math.min(r.bottom,s.bottom)>Math.max(r.top,s.top))void nativeMoreSearch();
}
function homeRailMarkup(){
  const tail=route.name==='home'?`<div id="catalog-pagination" class="catalog-pagination">${paginationContent()}</div><span id="catalog-sentinel" aria-hidden="true"></span>`:route.name==='search'?`<div class="native-search-tail">${tvSearchTail()}</div>`:'';
  return `<div class="home-poster-rail od-rail" data-grid aria-label="Аниме"><span class="sr-only">Влево и вправо — выбор аниме, OK — открыть сериал</span>${activeCatalogItems().map(homeCard).join('')}${tail}</div>`;
}
function tvCatalogScreen(label,extraClass=''){
  const items=activeCatalogItems(),chosen=homeSelection();
  if(chosen&&!items.some(a=>a.id===selectedInspectorId()))selectInspectorId(chosen.id);
  const toolbar=route.name==='browse'?`<div class="tv-catalog-tools">${browseSortControl()}</div>`:'';
  return `<section class="catalog home-catalog home-redesign tv-catalog-stage ${extraClass}" aria-label="${esc(label)}"><section id="catalog-inspector" class="catalog-inspector home-feature ${toolbar?'has-toolbar':''}" aria-label="О выбранном аниме">${homeInspectorContent()}</section>${toolbar}<section class="home-shelf"><header class="home-shelf-header od-row"><h1>${esc(label)}</h1></header><div class="home-grid-wrap" aria-busy="${route.name==='home'?homeFeed.loading:route.name==='search'?searchState.loadingMore:false}">${homeRailMarkup()}</div></section></section>`;
}
// TV PageView: no debounce on focus or rail movement. Only inspector data waits.
// One continuous animation retargets from the current position on every keypress;
// repeated focus notifications never cancel/restart the scroll or build a queue.
function cancelHomeRailMove(){
  if(homeRailMotion)cancelAnimationFrame(homeRailMotion.frame);
  homeRailMotion=null;
}
function revealHomeCard(card){
  const rail=card.closest('.home-poster-rail'),slot=card.closest('.native-media-item');
  if(!rail||!slot||isCompactUI())return;
  const inset=parseFloat(getComputedStyle(rail).paddingLeft)||0;
  const requested=slot.getBoundingClientRect().left-rail.getBoundingClientRect().left+rail.scrollLeft-inset;
  const target=Math.max(0,Math.min(requested,Math.max(0,rail.scrollWidth-rail.clientWidth)));
  if(reducedMotion.matches){cancelHomeRailMove();rail.scrollLeft=target;rememberTvRailOffset(rail.scrollLeft);return;}
  if(homeRailMotion?.rail===rail){homeRailMotion.target=target;return;}
  cancelHomeRailMove();
  if(Math.abs(target-rail.scrollLeft)<0.5)return;
  const response=parseFloat(getComputedStyle(rail).getPropertyValue('--home-rail-response'))||64;
  const state={rail,target,origin:route,lastTime:performance.now(),frame:0};
  homeRailMotion=state;
  const tick=now=>{
    if(homeRailMotion!==state)return;
    if(route!==state.origin||!rail.isConnected||isCompactUI()){cancelHomeRailMove();return;}
    const remaining=state.target-rail.scrollLeft;
    if(reducedMotion.matches||Math.abs(remaining)<0.5){
      rail.scrollLeft=state.target;rememberTvRailOffset(rail.scrollLeft);homeRailMotion=null;return;
    }
    const dt=Math.max(0,now-state.lastTime);state.lastTime=now;
    // Frame-rate independent ease-out. Retargeting does not reset its clock.
    rail.scrollLeft+=remaining*(1-Math.exp(-dt/response));
    rememberTvRailOffset(rail.scrollLeft);
    state.frame=requestAnimationFrame(tick);
  };
  state.frame=requestAnimationFrame(tick);
}

function inspectorContent(){
  if(route.name==='home')return homeInspectorContent();
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
  if(tvCatalogRoute()){updateHomeInspector(id);return;}
  if(isCompactUI())return; // На телефоне нет hover-панели и скрытых CrossFade-анимаций.
  if(!['home','favorites','browse','search'].includes(route.name)||!activeCatalogItems().some(a=>a.id===id))return;
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
  if(route.name==='home'&&!isCompactUI()){
    if(homeFeed.error)return `<div class="home-rail-error od-stack" role="alert"><p>Не удалось загрузить аниме.</p>${button('retry-catalog','Повторить','refresh','btn','data-focus="retry-catalog"')}</div>`;
    if(homeFeed.loading||homeFeed.hasNext)return homeLoadingCards();
    return '';
  }
  if(homeFeed.loading)return '<p role="status" class="catalog-status">Загружаем следующую страницу…</p>';
  if(homeFeed.error)return `<div class="catalog-error compact" role="alert"><p>Не удалось загрузить следующую страницу. Открытые аниме остаются доступны.</p>${button('retry-catalog','Повторить','refresh')}</div>`;
  if(!homeFeed.hasNext)return '';
  return '';
}
function home(){
  if(isCompactUI()){
    let content=homeFeed.items.length?grid(homeFeed.items):catalogSkeleton();
    if(!homeFeed.items.length&&homeFeed.error)content=`<div class="catalog-error" role="alert"><h2>Не удалось загрузить каталог</h2><p>Попробуй ещё раз или вернись позже.</p>${button('retry-catalog','Повторить','refresh','btn primary')}</div>`;
    return `<section class="catalog home-catalog mobile-home-catalog" aria-labelledby="catalog-title"><h1 id="catalog-title" class="sr-only">Главная — каталог аниме</h1><div class="home-grid-wrap" aria-busy="${homeFeed.loading}">${content}</div><div id="catalog-pagination" class="catalog-pagination">${paginationContent()}</div><div id="catalog-sentinel" aria-hidden="true"></div></section>`;
  }
  return tvCatalogScreen('Каталог аниме');
}
function syncCatalogStatus(){
  const el=$('#catalog-pagination');if(el)el.innerHTML=paginationContent();
  $('.home-grid-wrap')?.setAttribute('aria-busy',String(homeFeed.loading));
  if(route.name==='home'&&!isCompactUI())observeHomeLoadingEdge();
}
function setupCatalogObserver(){
  catalogObserver?.disconnect();catalogObserver=null;inspectorResizeObserver?.disconnect();inspectorResizeObserver=null;
  if(!['home','favorites','browse','search'].includes(route.name))return;
  const main=$('#main'),sentinel=$('#catalog-sentinel')||$('#search-sentinel'),inspector=$('#catalog-inspector');
  if(main&&inspector){
    const reserve=()=>{main.style.setProperty('--catalog-sticky-offset',isCompactUI()?'16px':(inspector.offsetHeight+24)+'px');syncHomeDescriptionLines();};
    reserve();
    if(typeof ResizeObserver!=='undefined'){inspectorResizeObserver=new ResizeObserver(reserve);inspectorResizeObserver.observe(inspector);}
  }
  if(route.name==='search'&&main&&sentinel&&isCompactUI()&&typeof IntersectionObserver!=='undefined'){catalogObserver=new IntersectionObserver(entries=>{if(entries.some(e=>e.isIntersecting))void nativeMoreSearch();},{root:main,rootMargin:'0px 0px 240px 0px'});catalogObserver.observe(sentinel);}
  if(tvCatalogRoute()){
    const rail=$('.home-poster-rail');
    if(rail){rail.addEventListener('scroll',onHomeRailScroll,{passive:true});}
    if(route.name==='search'){
      const slot=rail?.querySelector('.home-loading-card');
      if(slot&&typeof IntersectionObserver!=='undefined'){catalogObserver=new IntersectionObserver(entries=>{if(entries.some(e=>e.isIntersecting))maybeLoadTvSearch();},{root:rail,threshold:0});catalogObserver.observe(slot);}
    }else if(route.name==='home')observeHomeLoadingEdge();
    return;
  }
  if(route.name!=='home')return;
  if(isCompactUI()){
    if(main)main.addEventListener('scroll',()=>{
      if(main.scrollHeight-main.scrollTop-main.clientHeight<400)maybeLoadCatalog();
    },{passive:true});
    if(main&&sentinel&&typeof IntersectionObserver!=='undefined'){
      catalogObserver=new IntersectionObserver(entries=>{if(entries.some(e=>e.isIntersecting))maybeLoadCatalog();},{root:main,rootMargin:'0px 0px 400px 0px'});
      catalogObserver.observe(sentinel);
    }
    return;
  }
  const rail=$('.home-poster-rail');
  if(rail){
    rail.removeEventListener('scroll',onHomeRailScroll);
    rail.addEventListener('scroll',onHomeRailScroll,{passive:true});
  }
  observeHomeLoadingEdge();
}
function maybeLoadCatalog(){
  if(route.name!=='home'||!homeFeed.hasNext||homeFeed.loading||homeFeed.error)return;
  if(!isCompactUI()&&homeFeed.items.length){
    const rail=$('.home-poster-rail'),placeholder=rail?.querySelector('.home-loading-card');
    if(!rail||!placeholder)return;
    const viewport=rail.getBoundingClientRect(),slot=placeholder.getBoundingClientRect();
    // Даже часть пустой карточки должна уже войти в настоящий viewport ленты.
    const visibleWidth=Math.min(slot.right,viewport.right)-Math.max(slot.left,viewport.left);
    const visibleHeight=Math.min(slot.bottom,viewport.bottom)-Math.max(slot.top,viewport.top);
    if(visibleWidth<1||visibleHeight<1)return;
    // Реальная порция достаточно длинная: отдельная проверка номера выбранной
    // карточки не нужна. Запрос определяется видимостью первого скелетона,
    // без упреждающего rootMargin и без прежних ограничений короткой демоподборки.
  }
  void loadCatalog();
}

async function loadCatalog(){
  if(homeFeed.loading||(!homeFeed.hasNext&&!homeFeed.error))return;
  homeFeed.loading=true;homeFeed.error=null;syncCatalogStatus();
  try{
    // Replace this local asynchronous adapter with getPage(page) in the Flutter app.
    const loadDelay=route.name==='home'&&!isCompactUI()?1100:450;
    const next=await new Promise((resolve,reject)=>setTimeout(()=>{
      const page=catalogPages[homeFeed.page];
      if(!page||!Array.isArray(page.items))reject(new Error('Catalog page is unavailable'));
      else resolve(page);
    },loadDelay));
    const seen=new Set(homeFeed.items.map(a=>a.id));
    const added=next.items.filter(a=>!seen.has(a.id));
    homeFeed.items.push(...added);homeFeed.page=next.page;homeFeed.hasNext=next.hasNext;homeFeed.loading=false;
    if(route.name==='home'){
      const grid=$('.home-grid-wrap [data-grid]');
      if(grid){
        if(isCompactUI())grid.insertAdjacentHTML('beforeend',added.map(card).join(''));
        else $('#catalog-pagination').insertAdjacentHTML('beforebegin',added.map(homeCard).join(''));
      }
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
function gridMarkupForLoaded(){return route.name==='home'&&!isCompactUI()?homeRailMarkup():grid(homeFeed.items);}
function empty(){return `<div class="empty"><span class="empty-symbol">${icon('heartOff')}</span><h1>Избранное пусто</h1><p>Добавьте сериал с главной страницы или из его карточки.</p><div class="actions">${button('home','Перейти на главную','grid','btn primary')}</div></div>`;}
// Для будущих ИИ: дизайн заполненного «Избранного» идентичен главной.
// Визуальные отличия: заголовок «Избранное» над информацией об аниме и отсутствие сердечек.
// Не возвращайте сердечки на постеры в этом разделе: принадлежность к избранному уже очевидна.
// Сохраняйте общими grid/card, inspectorContent, стили home-shell/home-main,
// обновление информации при выборе постера, фокус и анимации; не создавайте отдельный дизайн.
// Отличается только источник списка: здесь сохранённые аниме, на главной — лента каталога.
function favorites(){
  const items=activeCatalogItems();
  if(tvCatalogRoute()&&items.length)return tvCatalogScreen('Избранное','favorites-catalog');
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
  return `<div class="catalog-feedback" ${failed?'role="alert"':'role="status"'} aria-busy="${loading}">${icon(loading?'loading':failed?'alert':'grid')}<h2>${loading?'Загружаем каталог…':failed?'Каталог недоступен':'Каталог пуст'}</h2><p>${loading?'Подождите немного.':failed?'Не удалось получить список аниме. Проверьте подключение и попробуйте ещё раз.':'На сайте AniStar не найдено аниме.'}</p>${failed?`<div class="catalog-feedback-actions od-cluster">${button('retry-genre',loading?'Загружаем…':'Попробовать снова',loading?'':'refresh','btn primary',`aria-disabled="${loading}" aria-busy="${loading}"`)}</div>`:''}</div>`;
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
// В HTML вход имитируется; в Flutter использовать AuthController и его маршрутизацию.
function genreSessionExpired(){return nativeAccount()&&route.name==='browse'&&(!route.filterType||route.filterType==='genre')&&route.genre==='Драма';}
function sessionExpiredFeedback(){
  return `<div class="catalog-feedback" role="alert">${icon('user')}<h2>Сессия истекла</h2><p>Войдите в аккаунт снова, чтобы продолжить.</p><div class="catalog-feedback-actions od-cluster">${button('session-login','Войти снова','user','btn primary')}${button('choose-genres','К жанрам','','btn')}</div></div>`;
}
function browse(){
  const items=activeCatalogItems(),failed=genreCatalogError(),expired=genreSessionExpired();
  if(tvCatalogRoute()&&!failed&&!expired&&items.length)return tvCatalogScreen(route.genre,'browse-catalog');
  return `<section class="catalog home-catalog browse-catalog ${expired||failed||!items.length?'catalog-state-page':''}" aria-labelledby="browse-title">${!expired&&!failed&&items.length?`<section id="catalog-inspector" class="catalog-inspector od-row-top" aria-label="О выбранном аниме">${inspectorContent()}</section><div class="home-grid-wrap">${grid(items)}</div>`:`<header class="section-header">${catalogSectionHeading()}</header>${expired?sessionExpiredFeedback():catalogFeedback(failed)}`}</section>`;
}
// Flutter EpisodeCard / MediaCardMetrics: реальное превью, номер, отдельное
// название при наличии и подтверждённая viewing-отметка. В локальных fixtures
// превью отсутствует: используем такой же fallback, как AppNetworkImage.
// ТВ — три колонки, компактный экран — одна. Не подменять кадры иллюстрациями жанров.
// UI Kit / EpisodeOrder — единый порядок отображения в карточке и выборе плеера.
// Для будущих ИИ: сначала ПОСЛЕДНЯЯ доступная серия, затем по убыванию до первой.
// Сортировать реальные доступные
// эпизоды по числовому номеру DESC на копии списка, не по тексту/индексу карточки.
// Сохранять исходные episode ID/номер/URL и ключи фокуса: порядок не меняет их.
// «Следующая/предыдущая», история и выбор продолжения работают по номеру серии,
// а не позиции в этой выдаче. detail() повторяет актуальный selectAnimeWatchAction.
function episodeNumbersDescending(a){
  // Server episode numbers may have gaps. Never infer availability from a count.
  const supplied=Array.isArray(a.episodeRecords)?a.episodeRecords.map(e=>e.number):a.episodeNumbers;
  const numbers=Array.isArray(supplied)?supplied:Array.from({length:Math.max(0,Number(a.episodes)||0)},(_,i)=>i+1);
  return [...new Set(numbers.filter(n=>Number.isInteger(n)&&n>0))].sort((a,b)=>b-a);
}
function episode(a,n){
  // EpisodeCard/EpisodeCaption: number + optional distinct title + confirmed viewing.
  // Local fixtures omit previewUri: show the native network-image fallback,
  // not unrelated genre art. Add real preview dimensions with an acquired image.
  const record=a.episodeRecords?.find(e=>e.number===n);
  const title=record?.title?.trim(),caption=title&&title.toLocaleLowerCase('ru')!==('Серия '+n).toLocaleLowerCase('ru')?title:'';
  return mediaCard({title:'Серия '+n,caption,image:record?.preview||'',imageWidth:record?.previewWidth||219,imageHeight:record?.previewHeight||92,variant:'episode',action:'play',id:a.id,episodeNumber:n,focusKey:'episode-'+n,status:record?.isWatched||watched.has(a.id+':'+n)?'Просмотрено':''});
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
// TV-главная поддерживает эти фильтры для записей с подтверждёнными полями author/manga.
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
  return button('favorite-toggle',busy?'Сохраняем…':saved?'Убрать из избранного':'В избранное',saved?'heartMinus':'heartPlus','btn',`data-id="${esc(id)}" aria-pressed="${saved}" aria-busy="${busy}" aria-disabled="${busy}"`);
}
function syncDetailFavorite(id){
  const b=document.querySelector('[data-action="favorite-toggle"]');
  if(!b||b.dataset.id!==id)return;
  const busy=pendingFavorites.has(id),saved=fav.has(id);
  b.innerHTML=icon(saved?'heartMinus':'heartPlus')+`<span>${busy?'Сохраняем…':saved?'Убрать из избранного':'В избранное'}</span>`;
  b.setAttribute('aria-pressed',String(saved));
  b.setAttribute('aria-busy',String(busy));
  b.setAttribute('aria-disabled',String(busy));
}
async function toggleDetailFavorite(id){
  if(pendingFavorites.has(id))return;
  if(!nativeAccount()){requestNativeLogin();return;}
  const accountFavorites=fav,nextSaved=!fav.has(id);
  pendingFavorites.add(id);
  syncDetailFavorite(id); // Не заменять кнопку: фокус пульта остаётся на том же элементе.
  try{
    // При интеграции заменить задержку запросом добавления/удаления и проверить ответ.
    await new Promise(resolve=>setTimeout(resolve,650));
    // A delayed mock response must not update a different guest/account context.
    if(!nativeAccount()||fav!==accountFavorites)return;
    nextSaved?fav.add(id):fav.delete(id);
    save();
    toast(nextSaved?'Добавлено в избранное':'Удалено из избранного');
  }catch{
    toast('Не удалось изменить избранное. Попробуйте ещё раз.');
  }finally{
    pendingFavorites.delete(id);
    syncDetailFavorite(id);
    if(['home','favorites','browse','search'].includes(route.name)&&!$('.overlay')){
      render(currentKey(),$('#main')?.scrollTop||0);
    }
  }
}
function detailFilters(a,c){
  const extra=(type,label,value)=>value?`<div class="detail-filter-row"><span class="detail-filter-label" id="detail-${type}-label">${label}</span><div class="od-cluster" role="group" aria-labelledby="detail-${type}-label">${metadataFilter(type,value,esc(value),'detail-'+type)}</div></div>`:'';
  return `<div class="detail-filters od-stack"><div class="detail-filter-row"><span class="detail-filter-label" id="detail-genres-label">Жанры</span><div class="od-cluster" role="group" aria-labelledby="detail-genres-label">${(c.genres||a.genre||[]).map((g,i)=>metadataFilter('genre',g,esc(g),'detail-genre-'+i)).join('')}</div></div>${extra('director','Режиссёр',c.director)}${extra('author','Автор',c.author)}${extra('manga','Манга',c.manga)}</div>`;
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
// Постер находится внутри раскрываемых сведений; переход Hero отключён.
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
  // Связанные сезоны: компактные chip-кнопки по содержимому, source order и Wrap.
  // Known source IDs resolve across catalog and related details; unknown parts stay text,
  // matching native canOpen=false, until their native repository data is connected.
  const links=(c.watchOrder||[]).filter(entry=>entry.label&&/^https?:\/\//i.test(entry.url));
  if(!links.length)return '';
  const sourceId=c.sourceId||(route.id==='frieren'?'9576':'');
  return `<section class="detail-watch-order" aria-labelledby="watch-order-title"><h2 id="watch-order-title">Смотреть также</h2><ol class="watch-order-list od-cluster">${links.map((entry,i)=>{
    let pageId;
    try{pageId=new URL(entry.url).pathname.match(/^\/(\d+)(?:-|\.html|\/|$)/)?.[1]}catch{return ''}
    const current=!!sourceId&&!!pageId&&pageId===String(sourceId);
    const id=pageId==='9576'?'frieren':[...siteCatalogItems,...relatedTitles].find(a=>String(a.sourceId)===pageId)?.id;
    const label=entry.label+(current?', Открыто':'');
    return `<li>${id?button(current?'current-part':'detail',label,'','btn watch-order-link'+(current?' is-current':''),`data-id="${esc(id)}" data-focus="watch-order-${i}" ${current?'aria-current="page"':''}`):`<p class="native-watch-order-unavailable">${esc(label)}</p>`}</li>`;
  }).join('')}</ol></section>`;
}
// На странице сериала нет «следующей серии»: запуск только из карточек выпусков.
// TV disclosure хранится в route, поэтому возврат из фильтра сохраняет раскрытие.
// Mobile and TV retain independent disclosure state when viewport mode changes.
const detailDisclosureOpen=()=>!!route[isCompactUI()?'mobileDetailsOpen':'detailsOpen'];
let detailDisclosureMotion=null;
function cancelDetailDisclosureMotion(){
  detailDisclosureMotion?.cancel();detailDisclosureMotion=null;
  $('#detail-information')?.classList.remove('is-animating');
}
function syncDetailDisclosureLayout(){
  const panel=$('#detail-information'),toggle=$('[data-action="detail-disclosure-toggle"]');
  if(!panel||!toggle)return;
  cancelDetailDisclosureMotion();
  const visible=detailDisclosureOpen();
  toggle.hidden=false;
  if(!visible&&panel.contains(document.activeElement))toggle.focus({preventScroll:true});
  panel.hidden=!visible;panel.inert=!visible;panel.toggleAttribute('inert',!visible);
  toggle.setAttribute('aria-expanded',String(visible));
  toggle.querySelector('span').textContent=visible?'Скрыть подробности':'Подробнее';
}
function toggleDetailDisclosure(open=!detailDisclosureOpen()){
  if(route.name!=='detail')return;
  const panel=$('#detail-information'),toggle=$('[data-action="detail-disclosure-toggle"]');
  if(!panel||!toggle)return;
  // Capture the current animated size before cancellation: rapid toggles reverse
  // from the visible height, rather than snapping to the fully open/closed state.
  const startHeight=panel.hidden?0:panel.getBoundingClientRect().height;
  const startOpacity=panel.hidden?0:Number(getComputedStyle(panel).opacity);
  cancelDetailDisclosureMotion();route[isCompactUI()?'mobileDetailsOpen':'detailsOpen']=!!open;
  toggle.setAttribute('aria-expanded',String(!!open));
  toggle.querySelector('span').textContent=open?'Скрыть подробности':'Подробнее';
  // Закрываемая область сразу покидает фокус; анимация не оставляет невидимых кнопок.
  if(!open&&panel.contains(document.activeElement))focus('detail-more',true);
  panel.hidden=false;panel.inert=!open;panel.toggleAttribute('inert',!open);
  // The content is already in the local snapshot. Reveal it without a fake request
  // or skeleton flash. Animate measured height so the episode grid moves smoothly.
  const endHeight=open?panel.scrollHeight:0;
  panel.classList.add('is-animating');
  const animation=animateUI(panel,[
    {height:startHeight+'px',opacity:startOpacity},
    {height:endHeight+'px',opacity:open?1:0}
  ],open?motion.page:motion.reverse,motion.enter);
  if(!animation){panel.hidden=!open;panel.classList.remove('is-animating');return;}
  detailDisclosureMotion=animation;
  animation.finished.then(()=>{
    if(detailDisclosureMotion!==animation||!panel.isConnected)return;
    detailDisclosureMotion=null;panel.hidden=!detailDisclosureOpen();
    panel.classList.remove('is-animating');
    // No fixed height remains: wrapping, font scaling and mobile stay natural.
  }).catch(()=>{});
}
// Initial TV focus is the latest actually available episode, not the planned count.
// Descending numbers also handle gaps; explicit history keys take precedence in render().
function detailInitialFocus(){
  if(nativeState.detailStatus==='error')return 'retry-detail';
  const latest=episodeNumbersDescending(item(route.id))[0];
  return latest===undefined?'detail-more':'episode-'+latest;
}
function detail(){
  const a=item(route.id);
  // Detail data already lives in the snapshot: do not render a large poster skeleton
  // and then replace it with the collapsed page. No deferred whole-page rerender.
  if(nativeState.detailStatus==='loading'&&!nativeState.failDetail){
    nativeState.detailStatus='ready';nativeState.detailCache.add(a.id);
  }
  if(nativeState.detailStatus==='loading')return nativeDetailLoading(a);
  if(nativeState.detailStatus==='error')return nativeDetailError(a);
  const c=catalogRecord(a),numbers=episodeNumbersDescending(a);
  const rating=typeof c.rating==='number'?c.rating:null;
  const description=c.description||a.desc||'Описание отсутствует в локальном снимке каталога.';
  const visible=detailDisclosureOpen();
  return `<div class="detail-page">
    <h1 id="anime-title" class="anime-title detail-title">${esc(a.title)}</h1>
        <div class="actions detail-actions">
          ${button('detail-disclosure-toggle',visible?'Скрыть подробности':'Подробнее','chevron-right','btn detail-more',`data-focus="detail-more" aria-controls="detail-information" aria-expanded="${visible}"`)}
          ${nativeAccount()?detailFavoriteButton(a.id):''}
        </div>
        <section id="detail-information" class="detail-information od-stack" role="region" aria-label="Подробная информация о сериале" ${visible?'':'hidden inert'}>
    <section class="detail-intro" aria-labelledby="anime-title">
      <div class="detail-poster">${poster(a)}</div>
      <div class="detail-overview od-stack">
        ${rating!==null?`<div class="detail-filter-row detail-rating-row"><span class="detail-filter-label">Рейтинг</span><div class="od-cluster"><span class="detail-rating native-rating" aria-label="Рейтинг ${rating.toFixed(1)} из 10">${icon('star')}<strong>${rating.toFixed(1).replace('.',',')}</strong><span class="detail-rating-scale">/ 10</span></span></div></div>`:''}
        <div class="detail-filter-row"><span class="detail-filter-label" id="detail-year-label">Год</span><div class="od-cluster" role="group" aria-labelledby="detail-year-label">${metadataFilter('year',String(a.year),String(a.year),'detail-year')}</div></div>
        ${detailFilters(a,c)}
      </div>
    </section>
          <section class="detail-description ${nativeState.expandedDescription===a.id?'is-expanded':''}" aria-labelledby="description-title">
            <h2 id="description-title">Сюжет</h2><p>${esc(description)}</p>
            <button type="button" class="native-description-toggle touch-only" data-action="description-toggle" data-id="${a.id}" data-focus="description-toggle" aria-expanded="${nativeState.expandedDescription===a.id}">${nativeState.expandedDescription===a.id?'Свернуть описание':'Подробнее'}</button>
          </section>
          ${detailPublication(c)}
          ${c.seriesInfo||c.voiceover?`<section class="detail-credits" aria-label="Сведения об аниме">${c.seriesInfo?`<p>${esc(c.seriesInfo)}</p>`:''}${c.voiceover?`<p>${esc(c.voiceover)}</p>`:''}</section>`:''}
    ${detailWatchOrder(c)}
    </section>
    <section class="detail-episodes" aria-labelledby="episodes-title">
      <div class="section-head"><h2 id="episodes-title">Серии</h2></div>
      ${numbers.length?`<div class="od-grid episode-card-grid" data-grid>${numbers.map(n=>episode(a,n)).join('')}</div>`:`<div class="catalog-feedback"><h2>${a.sourceId?'Список серий не загружен':'Серии не найдены'}</h2><p>${a.sourceId?'В локальном снимке есть сведения об аниме, но нет списка выпусков. Это не означает, что серии ещё не вышли.':'Для этого аниме пока нет доступных выпусков.'}</p>${a.sourceId?button('back','Вернуться к каталогу','back','btn'):button('refresh-episodes','Обновить серии','refresh','btn',`data-id="${a.id}"`)}</div>`}
    </section>
  </div>`;
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
  return `<main class="login tv-login"><section class="login-copy" aria-label="AniStar TV">${brand()}</section><form class="login-form" id="login" novalidate aria-labelledby="login-title"><h1 id="login-title">Вход в аккаунт</h1><div id="error-summary" role="alert"></div><div class="field"><label for="username">Логин</label><input id="username" data-focus="username" autocomplete="username" autocapitalize="none" spellcheck="false" required aria-describedby="username-error"><span id="username-error" class="error" aria-live="polite"></span></div><div class="field"><label for="password">Пароль</label><div class="password-field"><input id="password" data-focus="password" type="password" autocomplete="current-password" required aria-describedby="password-error"><button class="btn password-visibility" type="button" data-action="toggle-password" data-focus="toggle-password" aria-label="Показать пароль" aria-pressed="false">${icon('eye')}</button></div><span id="password-error" class="error" aria-live="polite"></span></div><div id="auth-error" class="auth-feedback" role="alert" aria-live="assertive"></div><div class="login-actions od-stack"><button class="btn primary" type="button" data-action="login-submit" data-focus="login-submit">Войти</button>${button('cancel-login','Отмена','','btn login-guest','data-focus="login-guest"')}</div></form></main>`;
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
// PlayerOverlay: актуальная Flutter-компоновка содержит Back-иконку и на ТВ.
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
// SD/HD в HTML имитируют PlayerChoicesDialog; тестовый поток общий, фактическая смена HLS только во Flutter.
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
// Длительность и геометрию брать из metadata. SD/HD — локальная UI-имитация;
// реальную смену источника выполняет Flutter PlaybackSession.
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
testVideo.addEventListener('loadedmetadata',()=>{mediaDuration=testVideo.duration;quality=nativeState.quality;const b=document.querySelector('[data-action="quality"]');if(b){b.querySelector('span').textContent=quality;b.setAttribute('aria-label','Качество: '+quality);}syncPlayerPosition();});
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
  return `<main class="player tv-player" tabindex="-1" data-focus="player-surface" aria-label="Видеоплеер"><div class="player-chrome"><header class="player-top">${button('back','К сериям','back','btn player-back','aria-label="К сериям"')}<div class="od-field"><h1 class="player-title">${esc(a.title)}</h1><span class="player-episode">Серия ${route.episode}</span></div><div class="mobile-player-tools touch-only" aria-label="Серия и качество"></div>${button('rotate-player','Повернуть экран','rotateScreen','btn touch-only player-rotate','aria-label="Повернуть экран"')}</header><div class="mobile-player-center touch-only" role="group" aria-label="Воспроизведение и перемотка"></div><div id="playback-feedback" class="player-stage" aria-live="polite"></div><section class="playback" aria-label="Управление воспроизведением"><label for="timeline" class="sr-only">Позиция воспроизведения</label><input class="timeline" data-focus="timeline" id="timeline" type="range" min="0" max="${mediaDuration||1}" step="0.1" value="${position}" aria-valuetext="${fmt(position)}"><div class="controls"><div class="transport player-transport">${playerControl('toggle',playing?'Пауза':'Воспроизвести',playing?'pause':'play',`aria-pressed="${playing}"`)}${playerControl('rewind','Назад на 10 секунд','seekBack')}${playerControl('forward','Вперёд на 10 секунд','seekForward')}${nativeAdjacentEpisode(a,Number(route.episode),'previous')!==null?playerControl('previous','Предыдущая серия','previous'):''}${nativeAdjacentEpisode(a,Number(route.episode),'next')!==null?playerControl('next','Следующая серия','next'):''}<div class="player-time od-nowrap" aria-label="Время воспроизведения"><span id="position">${fmt(position)}</span><span class="player-time-total" id="duration"> / ${mediaDuration?fmt(mediaDuration):'—:—'}</span></div></div><div class="transport player-settings">${playerControl('episodes','Выбрать серию','episodeList')}${button('quality',quality,'','btn player-quality',`aria-label="Качество: ${quality}"`)}</div></div></section></div></main>`;
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
function focus(key,prevent=false){const el=[...document.querySelectorAll('[data-focus]')].find(b=>b.dataset.focus===key&&!b.disabled&&!b.closest('[inert],[hidden]')&&b.getClientRects().length&&getComputedStyle(b).visibility!=='hidden');if(el){const restoring=restoringTvCatalogFocus;restoringTvCatalogFocus=prevent&&!!el.closest('.home-poster-rail');el.focus({preventScroll:true});restoringTvCatalogFocus=restoring;if(!prevent){if(el.closest('.home-poster-rail'))revealHomeCard(el);else el.scrollIntoView({block:'nearest',inline:'nearest',behavior:'instant'});}return true}return false;}
function currentKey(){return document.activeElement?.dataset.focus||''}
function render(key='',scroll=0){
  cancelDetailDisclosureMotion();
  cancelHomeRailMove();
  clearTimeout(playerControlsTimer);playerScrubbing=false;playerControlsVisible=true;cancelInspectorUpdate();cancelInspectorAnimations();
  const previousRoute=renderedRoute;clearInterval(timer);closeSheet(false);
  const view=({home,favorites,genres,browse,detail,login,player,search,intro:nativeIntro,startup:nativeStartup,logs:nativeLogs}[route.name]||nativeRouteError)();
  const standalone=['intro','startup','login','player'].includes(route.name);
  app.innerHTML=standalone?view:route.name==='logs'?`<main class="native-logs-route home-shell" id="main" tabindex="-1">${view}</main>`:`<div class="shell home-shell ${menuExpanded?'menu-is-open':''}">${menu()}${compactHeader()}<div class="menu-scrim" aria-hidden="true"></div><main class="main home-main ${tvCatalogRoute()?'home-stage ':''}${route.name==='favorites'?'favorites-main':route.name==='genres'?'genres-main':route.name==='detail'?'detail-main':''}" id="main" tabindex="-1">${view}</main>${compactNavigation()}</div>`;
  if(tvCatalogRoute()&&$('.home-poster-rail'))$('.home-poster-rail').scrollLeft=tvRailOffset();
  const initial=route.name==='intro'?'intro-sign-in':route.name==='startup'?'startup-surface':route.name==='search'?'search-query':route.name==='detail'?detailInitialFocus():route.name==='player'?'toggle':route.name==='login'?'username':route.name==='genres'?'genre-0':route.name==='logs'?'log-file':'card-'+(['favorites','browse'].includes(route.name)?activeCatalogItems()[0]?.id||'':homeFeed.items[0]?.id||'');
  syncAdaptiveLayout();if($('#main'))$('#main').scrollTop=route.name==='search'?0:scroll;if(route.name==='search'&&$('#search-body'))$('#search-body').scrollTop=scroll||searchState.scroll||0;
  if(route.name==='detail'&&nativeState.detailStatus==='loading'&&!key){$('#main')?.focus({preventScroll:true});}
  else if(isCompactUI()&&!key){($('#main')||$('.tv-player')||$('main'))?.focus({preventScroll:true});}
  else if(!focus(key||initial,!!scroll||!!key&&tvCatalogRoute())){const target=focusables(app).find(n=>!n.closest('.sidebar'));target?.focus({preventScroll:true});}
  if(route.name==='browse'&&!key&&(genreCatalogError()||!activeCatalogItems().length))focus(genreCatalogError()?'retry-genre':'nav-genres',true);
  if(genreSessionExpired())focus('session-login',true);
  mountTestVideo();armPlayerControls();setupCatalogObserver();syncMenuFocus();animateRoute(previousRoute);renderedRoute=route.name+':'+(route.id||(route.filterType?route.filterType+':'+route.genre:route.genre)||'');
  nativeState.lastRoute=route.name;
}
// TV / SectionNavigation — общий контракт для будущих ИИ и Flutter UI Kit.
// Up/Down в раскрытом меню ТОЛЬКО выбирают пункт фокусом, не меняют экран.
// Только OK/Select/клик подтверждает раздел: открыть его с начала и передать фокус
// первому аниме/жанру. Новый вход в поиск запрашивает IME, повторный — только фокус.
// Меню сворачивается
// существующим syncMenuFocus(), когда фокус уходит из sidebar, без таймера/дубликата.
// Пустое избранное: действие «Перейти на главную». Если содержимого/действий нет,
// фокус остаётся на выбранном пункте меню; скелетоны не получают фокус.
// На handheld не переносить ТВ-фокус на карточку: render() оставляет обычный
// touch-сценарий, без прыжка прокрутки и вызова клавиатуры.
// Flutter: после появления содержимого requestFocus первого доступного FocusNode;
// selected destination и focused item — независимы, не выбирать route на onFocus.
// Это ТОЛЬКО подтверждение корневого раздела. Возврат из detail по-прежнему
// восстанавливает конкретный focus key и scroll из history, не вызывает эту функцию.
function activateSection(name){
  if(!['home','favorites','genres','search'].includes(name))return;
  if(name==='favorites'&&!nativeAccount()){requestNativeLogin(name);return;}
  // MobileHomeShell retains each tab's scroll controller. TV confirmation still
  // activates its first focus target. A detail return restores history separately.
  nativeState.rootScroll??={};
  if(['home','favorites','genres','search'].includes(route.name))nativeState.rootScroll[route.name]=(route.name==='search'?$('#search-body')?.scrollTop:$('#main')?.scrollTop)||0;
  const restoreScroll=isCompactUI()?nativeState.rootScroll[name]||0:0;
  const newSearch=name==='search'&&route.name!=='search';
  history=[];playing=false;nativeState.destination=name;route={name};
  let target='nav-'+name;
  if(name==='search')target='search-query';
  else if(name==='genres')target='genre-0';
  else if(name==='home')target=homeFeed.items.length?'card-'+homeFeed.items[0].id:homeFeed.error?'retry-catalog':target;
  else if(name==='favorites')target=activeCatalogItems().length?'card-'+activeCatalogItems()[0].id:'home';
  render(isCompactUI()?'':target,restoreScroll);
  // SearchScreen.openKeyboardOnEntry: новый вход открывает IME, повтор активного
  // раздела/возврат из detail — нет. Web может лишь сфокусировать input; ОС решает IME.
  if(newSearch)requestAnimationFrame(()=>{if(route.name==='search'){const input=$('#search-query');if(input){searchEditing=!isCompactUI();input.readOnly=false;input.focus({preventScroll:true});}}});
}
function go(next,push=true){
  const sourceKey=currentKey(),sourceScroll=(route.name==='search'?$('#search-body')?.scrollTop:$('#main')?.scrollTop)||0;
  const mutate=()=>{
    if(push)history.push({route:{...route},key:sourceKey,scroll:sourceScroll});playing=false;position=0;route=next;nativeState.expandedDescription=null;
    if(next.name==='detail')nativeState.detailStatus=nativeState.detailCache.has(next.id)?'ready':'loading';
    render();if(next.name==='detail'&&nativeState.detailStatus==='loading')nativeLoadDetail(next.id);
  };
  mutate();
}
function back(){
  if($('.overlay')){closeSheet();return;}
  if(route.name==='startup')return;
  if(route.name==='intro')return;
  if(route.name==='login'){cancelNativeLogin();return;}
  if(route.name==='detail'&&!isCompactUI()&&route.detailsOpen){toggleDetailDisclosure(false);focus('detail-more',true);return;}
  if(!isCompactUI()&&['home','favorites','genres','search'].includes(route.name)){
    if(!document.activeElement?.closest('.sidebar')){focus('nav-'+route.name);return;}
    if(route.name!=='home')activateSection('home');else appExitSheet();return;
  }
  if(document.activeElement?.closest('.sidebar')){focus(lastContent);return;}
  if(route.name==='home'){focus('nav-home');return;}
  const old=history.pop();
  const restore=()=>{
    playing=false;route=old?.route||{name:'home'};
    // Detail status belongs to the restored title, not the child route just left.
    if(route.name==='detail')nativeState.detailStatus=nativeState.detailCache.has(route.id)?'ready':'loading';
    render(old?.key,old?.scroll||0);
    if(route.name==='detail'&&nativeState.detailStatus==='loading')nativeLoadDetail(route.id);
  };
  restore();
}
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
  if(!restore||reducedMotion.matches){(el.getAnimations?.({subtree:true})||[]).forEach(a=>a.cancel());finish();return;}
  el.dataset.closing='true';
  const panel=el.querySelector('.side-sheet'),scrim=el.querySelector('.panel-scrim'),state=getComputedStyle(panel),opacity=getComputedStyle(scrim).opacity;
  const transform=state.transform==='none'?'translate(0,0)':state.transform;
  const destination=isCompactUI()&&phoneLayout.matches?'translateY(100%)':'translateX(100%)';
  (el.getAnimations?.({subtree:true})||[]).forEach(a=>a.cancel());
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
  // TvSideSheet/AppActionSheet: header stays outside the scrollable body.
  // Episode/quality current-item scrolling must not scroll the title offscreen.
  el.innerHTML=`<div class="panel-scrim" aria-hidden="true"></div><section class="side-sheet ${options.favorite?'favorite-panel':''}" role="dialog" aria-modal="true" aria-labelledby="sheet-title"><div class="sheet-head"><h2 id="sheet-title">${esc(title)}</h2><button type="button" class="btn icon sheet-dismiss${options.showClose===false?' touch-only':''}" data-action="close" data-focus="sheet-dismiss" aria-label="Закрыть панель">${icon('close')}<span>Закрыть</span></button></div><div class="native-sheet-body">${content}</div></section>`;
  document.body.append(el);app.inert=true;
  el.addEventListener('click',e=>{if(e.target===el)closeSheet();});
  animateUI(el.querySelector('.panel-scrim'),[{opacity:0},{opacity:motion.scrimOpacity}],motion.menuEnter);
  const panel=el.querySelector('.side-sheet'),entrance=isCompactUI()&&phoneLayout.matches?'translateY(100%)':'translateX(100%)';
  animateUI(panel,[{transform:entrance},{transform:'translate(0,0)'}],motion.menuEnter);
  (el.querySelector('button:not(:disabled):not([data-action="close"])')||el.querySelector('button:not(:disabled)'))?.focus();
}
// Для будущих ИИ: это ТВ-панель по долгому нажатию на карточку.
// На ТВ НЕ показывать крестик (showClose:false): закрытие пультом Back/Escape/влево.
// При адаптации под телефон/сенсорный интерфейс добавить крестик справа вверху
// В HTML крестик .touch-only включается адаптивным CSS; во Flutter выбирать по
// возможностям платформы, не по одному разрешению телевизора. Это общий renderer sheet().
function favoriteSheet(id){
  if(!nativeAccount()){
    sheet(item(id).title,`<p class="sheet-copy">Войдите в аккаунт, чтобы добавлять аниме в избранное.</p>${button('sign-in','Войти','login','btn primary')}`,{showClose:false});return;
  }
  const a=item(id);sheet(a.title,button('favorite',fav.has(id)?'Удалить из избранного':'Добавить в избранное',fav.has(id)?'heartMinus':'heartPlus','btn favorite-action',`data-id="${id}"`),{favorite:true,showClose:false});
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
  // Как в подтверждении закрытия: безопасное действие получает первый фокус.
  // Во Flutter переиспользовать ConfirmDialog UI Kit с initialFocus на «Остаться».
  focus('close',true);
}

// UI Kit / PlayerChoices: оформление панелей общее с меню, Lucide и AppMotion.
// Открывать список на текущей серии с фокусом и прокруткой; текущую помечать отдельно
// от фокуса. Повторный выбор текущей серии только закрывает панель, без сброса видео.
// Смена серии ВНУТРИ плеера не вызывает go()/push в history: иначе Back проходит
// через все выбранные серии вместо возврата к экрану аниме. Позиция сбрасывается
// только при выборе другой серии. Качество брать из реальной PlaybackSession;
// у тестового видео доступен один формат — не добавлять выдуманные 720p/1080p.
function openPlayerEpisodes(){
  const a=item(route.id),cards=episodeNumbersDescending(a).map(n=>episode(a,n).replace('data-action="play"','data-action="select-player-episode"'));
  sheet('Выбрать серию',`<div class="od-grid episode-picker" data-grid>${cards.join('')}</div>`,{showClose:false});
  returnFromSheet='player-surface';
  const current=document.querySelector(`.episode-picker [data-episode="${route.episode}"]`);
  if(current){current.setAttribute('aria-current','step');current.setAttribute('aria-label','Серия '+route.episode+', текущая');current.classList.add('is-current-episode');current.focus();current.scrollIntoView({block:'center',behavior:'instant'});}
}
function selectPlayerEpisode(n){
  n=Number(n);const a=item(route.id);
  if(route.name!=='player'||!episodeNumbersDescending(a).includes(n))return;
  if(n===Number(route.episode)){closeSheet();return;}
  testVideo.pause();route.episode=n;position=0;
  const previous=history[history.length-1];if(previous?.route.name==='detail'){previous.key='episode-'+n;previous.scroll=0;}
  render('player-surface');
}
function play(id,n){
  const episode=Number(n);if(!episodeNumbersDescending(item(id)).includes(episode))return;
  go({name:'player',id,episode});
  const previous=history[history.length-1];if(previous?.route.name==='detail'){previous.key='episode-'+episode;previous.scroll=0;}
}
document.addEventListener('focusin',e=>{
  syncMenuFocus();
  if(e.target.closest('#main')&&e.target.dataset.focus)lastContent=e.target.dataset.focus;
  const card=e.target.closest('.home-grid-wrap .anime-card');
  if(!card){cancelInspectorUpdate();cancelInspectorAnimations();}
  if(card&&['home','favorites','browse','search'].includes(route.name)){
    updateInspector(card.dataset.id);
    if(route.name!=='home'&&!tvCatalogRoute())return;
    const grid=card.closest('[data-grid]'),cells=[...grid.querySelectorAll('.anime-card')];
    if(!isCompactUI()&&!restoringTvCatalogFocus)revealHomeCard(card);
    if(isCompactUI()){
      const threshold=getComputedStyle(grid).gridTemplateColumns.split(' ').length*2;
      if(cells.indexOf(card)>=cells.length-threshold)maybeLoadCatalog();
    }
  }
});
document.addEventListener('focusout',()=>queueMicrotask(syncMenuFocus));
document.addEventListener('pointerover',e=>{const card=e.target.closest('.home-grid-wrap .anime-card');if(card)updateInspector(card.dataset.id)});
document.addEventListener('click',e=>{if(e.target.closest('.overlay[data-closing="true"]'))return;if(e.target.matches('.menu-scrim')){if(!focus(lastContent))document.querySelector('#main button')?.focus();syncMenuFocus();return}const b=e.target.closest('[data-action]');if(!b||b.disabled)return;const action=b.dataset.action,id=b.dataset.id;switch(action){case'detail-disclosure-toggle':toggleDetailDisclosure();break;case'rotate-player':void rotatePlayer();break;case'account':compactAccount();break;case'browse-sort':openBrowseSort();break;case'draft-sort-criterion':case'draft-sort-direction':changeBrowseSortDraft(action,b.dataset.value);break;case'apply-browse-sort':applyBrowseSort();break;case'session-login':requestNativeLogin();break;case'app-exit':appExitSheet();break;case'confirm-app-exit':closeSheet();toast('Выход подтверждён');break;case'retry-genre':retryGenreCatalog();break;case'choose-genres':chooseAnotherGenre();break;case'retry-video':retryVideo();break;case'toggle-password':togglePasswordVisibility();break;case'nav':activateSection(b.dataset.name);break;case'home':history=[];go({name:'home'},false);break;case'retry-catalog':void loadCatalog();break;case'detail':go({name:'detail',id});break;case'genre':go({name:'browse',genre:b.dataset.genre});break;case'filter':go({name:'browse',filterType:b.dataset.filterType,genre:b.dataset.filterValue});break;case'back':back();break;case'close':closeSheet();break;case'favorite-toggle':void toggleDetailFavorite(id);break;case'favorite':{const origin=returnFromSheet,scroll=$('#main')?.scrollTop||0;fav.has(id)?fav.delete(id):fav.add(id);save();render(origin,scroll);if(route.name==='favorites'&&!fav.size)focus('nav-favorites');toast(fav.has(id)?'Добавлено в избранное':'Удалено из избранного');break}case'play':play(id,b.dataset.episode||1);break;case'sort':sheet('Порядок аниме',`<p class="sheet-copy">Сортировка демонстрационной подборки</p>${[['default','По умолчанию'],['year','Сначала новые'],['name','По названию']].map(([v,t])=>button('set-sort',t,sort===v?'check':'','sheet-option',`data-value="${v}" aria-pressed="${sort===v}" data-focus="sort-${v}"`)).join('')}`);break;case'set-sort':sort=b.dataset.value;render('sort');break;case'signout':signoutSheet();break;case'confirm-signout':history=[];go({name:'login'},false);break;case'toggle':toggleMedia();break;case'rewind':case'forward':seekMedia(position+(action==='rewind'?-10:10));break;case'quality':sheet('Качество видео',`${[quality].map(q=>button('set-quality',q,'check','sheet-option',`data-value="${q}" aria-pressed="true" data-focus="quality-${q}"`)).join('')}`,{showClose:false});break;case'set-quality':quality=b.dataset.value;closeSheet();break;case'episodes':openPlayerEpisodes();break;case'select-player-episode':selectPlayerEpisode(b.dataset.episode);break;case'previous':case'next':{const a=item(route.id),nextEpisode=Number(route.episode)+(action==='previous'?-1:1);if(nextEpisode>=1&&nextEpisode<=a.episodes){route.episode=nextEpisode;position=0;testVideo.pause();render('toggle')}break}}});
function focusables(root){return [...root.querySelectorAll('button:not(:disabled),input,select,textarea,a[href],[tabindex="0"]')].filter(x=>!x.closest('[inert],[hidden]')&&x.getClientRects().length)}
function spatial(key){const overlay=$('.overlay'),active=document.activeElement,root=overlay||app;if(overlay&&key==='ArrowLeft'){closeSheet();return}if(active?.matches('input:not([type=range])')){if(key==='ArrowLeft'||key==='ArrowRight')return;}if(active?.matches('input[type=range]')&&(key==='ArrowLeft'||key==='ArrowRight')){seekMedia(position+(key==='ArrowLeft'?-10:10));return}if(active?.closest('.sidebar')){if(key==='ArrowRight'){if(route.name==='search'){focus('search-query');return;}if(!focus(lastContent))document.querySelector('#main button')?.focus();return}const list=focusables($('.sidebar')),index=list.indexOf(active);if(key==='ArrowUp')list[Math.max(0,index-1)]?.focus();if(key==='ArrowDown')list[Math.min(list.length-1,index+1)]?.focus();return;}if(!overlay&&route.name==='search'&&key==='ArrowDown'&&active?.closest('#search-form')){const first=$('.search-results [data-grid] button,[data-action=search-recent],[data-action=search-retry],[data-action=search-edit]');if(first){first.focus();first.scrollIntoView({block:'nearest'});}return;}if(!overlay&&tvCatalogRoute()){
  const rail=$('.home-poster-rail'),cells=rail?[...rail.querySelectorAll('.anime-card')]:[],index=cells.indexOf(active);
  const reachCatalogFilter=()=>{
    if(route.name!=='browse')return false;
    const target=$('[data-focus="browse-sort"]');if(!target||target.disabled)return false;
    route.filterReturnFocus=currentKey();return focus('browse-sort');
  };
  if(index>=0){
    if(key==='ArrowLeft'){if(index===0)focus('nav-'+(route.name==='browse'?'genres':route.name));else focus(cells[index-1].dataset.focus);return;}
    if(key==='ArrowRight'){if(index+1<cells.length)focus(cells[index+1].dataset.focus);else if(route.name==='search'){if(searchState.moreError)focus('search-more');else maybeLoadTvSearch();}else if(route.name==='home'&&homeFeed.error)focus('retry-catalog');else if(route.name==='home'&&homeFeed.hasNext){pendingCatalogFocus={origin:currentKey(),cols:1};maybeLoadCatalog();}return;}
    if(key==='ArrowUp'){
      // С карточки вверх — Смотреть; вправо — Избранное; вверх с действий — нижний фильтр.
      // Перед выходом из ленты синхронизируем выбранный тайтл, даже во время fade.
      cancelInspectorUpdate();cancelInspectorAnimations();
      selectInspectorId(active.dataset.id);
      const inspector=$('#catalog-inspector');if(inspector){inspector.innerHTML=homeInspectorContent();syncHomeDescriptionLines();}
      focus('home-feature-play')||focus('home-feature-favorite');return;
    }
    if(key==='ArrowDown')return;
  }
  if(active?.matches('.home-feature [data-action="filter"]')){
    const filters=[...document.querySelectorAll('.home-feature [data-action="filter"]')],i=filters.indexOf(active);
    if(key==='ArrowLeft'){if(i>0)focus(filters[i-1].dataset.focus);else focus('nav-'+(route.name==='browse'?'genres':route.name));return;}
    if(key==='ArrowRight'){if(i+1<filters.length)focus(filters[i+1].dataset.focus);else reachCatalogFilter();return;}
    if(key==='ArrowUp'&&i===0){if(!reachCatalogFilter()&&route.name==='search')focus('search-query');return;}
    const box=active.getBoundingClientRect(),center=box.x+box.width/2,sign=key==='ArrowUp'?-1:1;
    const next=filters.filter(el=>el!==active).map(el=>{const r=el.getBoundingClientRect();return {el,dy:(r.y-box.y)*sign,dx:Math.abs(r.x+r.width/2-center)};}).filter(v=>v.dy>8).sort((a,b)=>a.dy-b.dy||a.dx-b.dx)[0];
    if(next)focus(next.el.dataset.focus);else if(key==='ArrowDown')focus('home-feature-play')||focus('home-feature-favorite');
    return;
  }
  if(active?.closest('.home-feature-actions')){
    if(key==='ArrowDown'){focus('card-'+homeSelection()?.id);return;}
    if(key==='ArrowUp'){const last=[...document.querySelectorAll('.home-feature [data-action="filter"]')].at(-1);if(!focus(last?.dataset.focus)&&!reachCatalogFilter()&&route.name==='search')focus('search-query');return;}
    if(key==='ArrowLeft'){if(currentKey()==='home-feature-favorite'&&focus('home-feature-play'))return;focus('nav-'+(route.name==='browse'?'genres':route.name));return;}
    if(key==='ArrowRight'){if(currentKey()==='home-feature-play'){if(!focus('home-feature-favorite'))reachCatalogFilter();}else reachCatalogFilter();return;}
  }
  if(currentKey()==='browse-sort'){
    if(key==='ArrowLeft'){
      const lastGenre=[...document.querySelectorAll('.home-feature [data-action="filter"]')].at(-1);
      if(!focus(route.filterReturnFocus)&&!focus(lastGenre?.dataset.focus))focus('home-feature-play');
    }else if(key==='ArrowDown')focus('card-'+homeSelection()?.id);
    return;
  }
  if(currentKey()==='search-more'&&(key==='ArrowLeft'||key==='ArrowUp')){focus(cells.at(-1)?.dataset.focus);return;}
  if(currentKey()==='retry-catalog'&&(key==='ArrowLeft'||key==='ArrowUp')){focus(cells.at(-1)?.dataset.focus);return;}
}
const grid=active?.closest('[data-grid]');if(grid){const cells=[...grid.children].map(n=>n.matches('.anime-card')?n:n.querySelector('.anime-card')).filter(Boolean),index=cells.indexOf(active),cols=getComputedStyle(grid).gridTemplateColumns.split(' ').length;if(key==='ArrowLeft'&&index%cols===0){focus('nav-'+(route.name==='browse'?'genres':['home','search','favorites','genres'].includes(route.name)?route.name:'home'));return}if(key==='ArrowRight'&&(index%cols===cols-1||index===cells.length-1))return;if(key==='ArrowLeft'){cells[index-1]?.focus();return}if(key==='ArrowRight'){cells[index+1]?.focus();return}if(key==='ArrowDown'){if(index+cols<cells.length){cells[index+cols].focus();cells[index+cols].scrollIntoView({block:'nearest'})}else if(route.name==='home'){if(homeFeed.error)focus('retry-catalog');else if(homeFeed.hasNext){pendingCatalogFocus={origin:currentKey(),cols};maybeLoadCatalog();}}return}if(key==='ArrowUp'&&index>=cols){cells[index-cols].focus();cells[index-cols].scrollIntoView({block:'nearest'});return}if(key==='ArrowUp'&&route.name==='search'){focus('search-query');return;}if(key==='ArrowUp'&&route.name==='home')return;if(key==='ArrowUp'&&route.name==='favorites')return;if(key==='ArrowUp'&&route.name==='detail'){focus('detail-more');return}if(key==='ArrowUp'&&route.name==='browse'){focus('browse-sort',true);return;}}
const r=active.getBoundingClientRect(),x=r.x+r.width/2,y=r.y+r.height/2,horizontal=key==='ArrowLeft'||key==='ArrowRight',sign=key==='ArrowLeft'||key==='ArrowUp'?-1:1;const candidates=focusables(root).filter(el=>el!==active&&(!el.closest('.sidebar')||key==='ArrowLeft')).map(el=>{const b=el.getBoundingClientRect(),dx=b.x+b.width/2-x,dy=b.y+b.height/2-y,forward=(horizontal?dx:dy)*sign,cross=Math.abs(horizontal?dy:dx);return {el,forward,score:forward+cross*2}}).filter(v=>v.forward>8).sort((a,b)=>a.score-b.score);if(candidates[0]){candidates[0].el.focus({preventScroll:true});candidates[0].el.scrollIntoView({block:'nearest',inline:'nearest'})}}
document.addEventListener('keydown',e=>{if($('.overlay[data-closing="true"]')){e.preventDefault();return;}if(['Escape','BrowserBack'].includes(e.key)||e.key==='Backspace'&&!e.target.matches('input')){e.preventDefault();held=null;back();return}if(e.target.matches('select,textarea'))return;if(e.key.startsWith('Arrow')){if(e.target.matches('input:not([type=range])')&&['ArrowLeft','ArrowRight'].includes(e.key))return;e.preventDefault();spatial(e.key);return}if(e.key==='Tab'&&$('.overlay')){const list=focusables($('.overlay')),i=list.indexOf(document.activeElement);e.preventDefault();list[(i+(e.shiftKey?-1:1)+list.length)%list.length]?.focus();return}if(['Enter',' ','Select','Accept'].includes(e.key)&&!e.target.matches('input:not([type=range])')){e.preventDefault();const b=document.activeElement;if(!held)held={key:e.key,target:b,long:false};if(e.repeat&&held.target===b&&b.dataset.action==='detail'&&!held.long){held.long=true;favoriteSheet(b.dataset.id)}}});
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
function submitNativeLogin(form=$('#login')){
  if(!form||route.name!=='login'||!form.isConnected)return;
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
  const b=form.querySelector('[data-action="login-submit"]');
  b.textContent='Входим…';b.setAttribute('aria-disabled','true');b.setAttribute('aria-busy','true');
  // Локальная задержка вместо запроса. Не показывать успешный вход при ответе сервера
  // с ошибкой: при интеграции восстановить кнопку и вывести понятное сообщение.
  setTimeout(()=>{
    if(!form.isConnected||route.name!=='login')return;
    // Flutter login_screen.dart: Failure.message под паролем, liveRegion=true.
    // anistar_errors.dart разделяет connection/timeout/server/request. Не путать
    // отказ авторизации с пустыми полями. Неверные credentials очищают только пароль;
    // сетевые/серверные ошибки сохраняют оба поля, как LoginScreen во Flutter.
    // Прототип: error / offline / server — локальные сценарии, на сервер не отправляются.
    const failures={error:'Неверный логин или пароль. Проверьте данные и попробуйте ещё раз.',offline:'Нет соединения. Проверьте подключение к интернету и повторите вход.',server:'Сервис временно недоступен. Попробуйте войти позже.'};
    const failure=failures[submittedLogin]||null;
    if(failure){
      form.dataset.submitting='false';form.removeAttribute('aria-busy');
      b.textContent='Войти';b.removeAttribute('aria-disabled');b.removeAttribute('aria-busy');
      authFeedback.innerHTML=icon('alert')+`<p>${esc(failure)}</p>`;
      if(submittedLogin==='error')$('#password').value='';
      focus('password',true);return;
    }
    const account=$('#username').value.trim();form.reset();completeNativeAccess('account',account);
  },600);
}
// The demo must not depend on a preview host allowing native form submission.
// Click, remote OK, input Enter and IME submit share one guarded local action.
document.addEventListener('click',e=>{
  const target=e.target.closest('[data-action="login-submit"]');
  if(!target||route.name!=='login')return;
  e.preventDefault();e.stopImmediatePropagation();submitNativeLogin(target.closest('form'));
},true);
document.addEventListener('submit',e=>{
  if(e.target.id!=='login')return;
  e.preventDefault();submitNativeLogin(e.target);
});
document.addEventListener('keydown',e=>{
  if(route.name!=='login'||$('.overlay')||e.key!=='Enter'||e.isComposing||e.keyCode===229||!e.target.matches('#username,#password'))return;
  e.preventDefault();e.stopImmediatePropagation();submitNativeLogin();
},true);

function nativeDetailLoading(a){
  // Mobile retains its existing loading layout. TV never skeletonizes hidden details.
  if(!isCompactUI())return `<div class="detail-page" aria-busy="true"><h1 class="anime-title detail-title">${esc(a.title)}</h1><p role="status">Загружаем серии…</p></div>`;
  return `<div class="detail-page native-detail-loading" aria-busy="true"><h1 class="anime-title detail-title">${esc(a.title)}</h1><div class="detail-intro"><div class="detail-poster">${poster(a)}</div><div class="detail-overview od-stack"><div class="native-skeleton-line wide"></div><div class="native-skeleton-line"></div><div class="native-skeleton-line short"></div><p class="sr-only" role="status">Загружаем аниме…</p></div></div><div class="native-skeleton-copy od-stack"><div class="native-skeleton-line wide"></div><div class="native-skeleton-line wide"></div><div class="native-skeleton-line"></div></div></div>`;
}
function nativeDetailError(a){return `<div class="catalog-feedback" role="alert">${icon('alert')}<h2>Не удалось загрузить аниме</h2><p>Проверьте подключение и попробуйте ещё раз.</p>${button('retry-detail','Повторить','refresh','btn primary',`data-id="${a.id}"`)}</div>`;}
function nativeLoadDetail(id){
  const origin=route;nativeState.detailStatus='loading';
  setTimeout(()=>{
    if(route!==origin||route.name!=='detail')return;
    nativeState.detailStatus=nativeState.failDetail?'error':'ready';
    if(nativeState.detailStatus==='ready')nativeState.detailCache.add(id);
    const key=currentKey(),scroll=$('#main')?.scrollTop||0;
    // Do not scroll the phone down to the watch action when the future completes.
    const target=nativeState.detailStatus==='error'?'retry-detail':isCompactUI()?key:key||detailInitialFocus();
    render(target,scroll);
  },450);
}
function nativeGridColumns(grid){
  const value=getComputedStyle(grid).gridTemplateColumns;
  return /^\d/.test(value)?value.split(' ').filter(Boolean).length:parseInt(getComputedStyle(grid).getPropertyValue('--od-cols'))||1;
}

// Viewing state mirrors the server flag, not local playback progress.
testVideo.addEventListener('playing',()=>{if(route.name!=='player'||!nativeAccount()||simulatedVideoFailure)return;const id=route.id,n=route.episode;setTimeout(()=>{if(route.name==='player'&&route.id===id&&route.episode===n){watched.add(id+':'+n);save();try{localStorage.setItem('anistar-native-viewing:'+nativeState.user,JSON.stringify([...watched]));}catch{}}},300);});
document.addEventListener('click',e=>{const b=e.target.closest('[data-action]');if(!b)return;if(b.dataset.action==='startup-retry'){e.preventDefault();e.stopImmediatePropagation();nativeState.failStartup=false;nativeBeginStartup();}else if(b.dataset.action==='retry-detail'){e.preventDefault();e.stopImmediatePropagation();nativeState.failDetail=false;nativeState.detailCache.delete(route.id);nativeState.detailStatus='loading';render();nativeLoadDetail(route.id);}},true);
document.addEventListener('keydown',e=>{
 if($('.overlay'))return;
 if(route.name==='detail'&&!isCompactUI()){
   const active=document.activeElement,key=currentKey();
   const filters=[...document.querySelectorAll('.detail-information [data-action="filter"]')].filter(n=>!n.closest('[hidden],[inert]'));
   const parts=[...document.querySelectorAll('.watch-order-list button')].filter(n=>!n.closest('[hidden],[inert]'));
   const cards=[...document.querySelectorAll('.episode-card-grid .anime-card')];
   const more=$('[data-focus="detail-more"]'),favorite=$('.detail-actions [data-action="favorite-toggle"]');
   const emptyAction=$('.detail-episodes .catalog-feedback button');
   const index=cards.indexOf(active),filter=filters.indexOf(active),part=parts.indexOf(active);
   const columns=cards.length?nativeGridColumns(cards[0].closest('[data-grid]')):3;
   const lower=parts[0]||cards[0]||emptyAction||more;
   const upper=filters.at(-1)||more;
   const consume=target=>{e.preventDefault();e.stopImmediatePropagation();if(target)focus(typeof target==='string'?target:target.dataset.focus);};
   // Wrap navigation uses visual rows, not an assumed count of chips per row.
   const vertical=(nodes,direction)=>{
     const r=active.getBoundingClientRect(),sign=direction==='ArrowUp'?-1:1;
     return nodes.filter(n=>n!==active).map(node=>{const q=node.getBoundingClientRect();return {node,dy:(q.top-r.top)*sign,dx:Math.abs(q.left+q.width/2-r.left-r.width/2)};}).filter(n=>n.dy>8).sort((a,b)=>a.dy-b.dy||a.dx-b.dx)[0]?.node;
   };
   if(e.key==='ArrowLeft'&&(active===more||filter===0||index>=0&&index%columns===0))consume('nav-'+nativeState.destination);
   else if(active===more&&e.key==='ArrowRight')consume(favorite||more);
   else if(active===favorite&&e.key==='ArrowLeft')consume(more);
   else if((active===more||active===favorite)&&e.key==='ArrowUp')consume(active);
   else if((active===more||active===favorite)&&e.key==='ArrowDown')consume(filters[0]||lower);
   else if(filter>=0&&['ArrowLeft','ArrowRight'].includes(e.key))consume(filters[Math.max(0,Math.min(filters.length-1,filter+(e.key==='ArrowRight'?1:-1)))]);
   else if(filter>=0&&e.key==='ArrowUp')consume(vertical(filters,e.key)||more);
   else if(filter>=0&&e.key==='ArrowDown')consume(vertical(filters,e.key)||lower);
   else if(part>=0&&['ArrowLeft','ArrowRight','ArrowUp','ArrowDown'].includes(e.key)){
     if(e.key==='ArrowLeft')consume(parts[part-1]||'nav-'+nativeState.destination);
     else if(e.key==='ArrowRight')consume(parts[part+1]||active);
     else consume(vertical(parts,e.key)||(e.key==='ArrowUp'?upper:(cards[0]||emptyAction||active)));
   }
   else if(index>=0&&index<columns&&e.key==='ArrowUp')consume(parts.at(-1)||upper);
   else if(active===emptyAction&&e.key==='ArrowUp')consume(parts.at(-1)||upper);
 }
 if(route.name==='search'&&!isCompactUI()&&e.key==='ArrowDown'){
  const active=document.activeElement,grid=active?.closest('.search-results [data-grid]');
  if(grid&&!grid.matches('.home-poster-rail')){const cells=[...grid.querySelectorAll('.anime-card')],i=cells.indexOf(active);if(i+nativeGridColumns(grid)>=cells.length&&searchState.hasNext){e.preventDefault();e.stopImmediatePropagation();if(searchState.moreError)focus('search-more');else void nativeMoreSearch();}}
 }
 if(route.name==='search'&&currentKey()==='search-more'&&e.key==='ArrowUp'){e.preventDefault();e.stopImmediatePropagation();const cards=[...document.querySelectorAll('#search-body .anime-card')];focus(cards.at(-1)?.dataset.focus);}
 if(route.name==='logs'&&currentKey()==='log-content'&&['ArrowUp','ArrowDown'].includes(e.key)){e.preventDefault();e.stopImmediatePropagation();document.activeElement.scrollTop+=e.key==='ArrowDown'?80:-80;}
},true);

function nativeRouteError(){return `<div class="catalog-feedback" role="alert">${icon('alert')}<h2>Не удалось открыть страницу</h2><p>Вернитесь на главную и выберите аниме заново.</p>${button('home','На главную','home','btn primary')}</div>`;}
function nativeResetSearchContext(){
  // SearchBloc/history repositories are rebuilt when guest/account context changes.
  const generation=searchState.requestId+1;
  Object.assign(searchState,{draft:'',query:'',items:[],allItems:[],selectedId:null,status:'idle',hasNext:false,loadingMore:false,moreError:false,error:'',requestId:generation});
}
function nativeAdjacentEpisode(a,current,direction){
  const ordered=episodeNumbersDescending(a).sort((x,y)=>x-y);
  return direction==='next'?ordered.find(n=>n>current)??null:ordered.filter(n=>n<current).at(-1)??null;
}
homeFeed.items=[...catalogPages[0].items];
homeFeed.page=1;
homeFeed.hasNext=catalogPages[0].hasNext;
nativeBeginStartup();

})();
