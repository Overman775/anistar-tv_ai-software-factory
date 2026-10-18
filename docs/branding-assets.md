# Ресурсы бренда

`lib/packages/ui_kit/assets/images/anistar_logo.png` — прозрачный знак для AnistarLogo: стартовый экран, вход и меню. PNG RGBA, 1254×1254; фон и промежутки между лучами имеют alpha=0. Тёмная рамка вокруг кнопки play принадлежит самому знаку.

`anistar_launcher.png` и `anistar_tv_banner.png` — отдельные ресурсы с фоном для Android launcher, Android TV banner и заставки до Android 12. FlutterGen генерирует доступ к изображениям из UI Kit.

Android 12+ native splash использует прозрачный `anistar_logo.png` и drawable `android12splash_safe.xml` с отступом 26% с каждой стороны. Отступы учитывают круглую маску системного splash и форму знака; фон совпадает с `#080B14`. Launcher icon и Flutter-логотип имеют собственные размеры.

Ресурсы пересоздаются командой `fvm dart run melos run generate:branding`: после стандартных Flutter generators скрипт сохраняет ссылку на safe drawable в light/night LaunchTheme и экспортирует TV icons/banner. Конфигурация splash не принуждает landscape: телефон запускается в своей ориентации, TV-профиль задаётся нативно и runner. [Требования Android к splash](https://developer.android.com/develop/ui/views/launch/splash-screen).

Прозрачный знак создан встроенным imagegen из существующего `anistar_launcher.png`. Промпт:

> Use case: background-extraction. Edit target: attached AniStar logo PNG. Create a production UI logo cutout by removing ONLY the dark background. Preserve the exact existing asymmetric violet shooting-star silhouette, three trailing streaks, rounded cyan right-facing play triangle and its dark inset border, original proportions, framing, violet/cyan gradients and polished shading. The space outside the star and BETWEEN trailing streaks must be genuinely alpha-transparent, with clean antialiased edges and no dark rectangular matte. Keep the dark inset triangle within the logo. Keep the original centered square canvas and logo scale. No added words, objects or redesign. Output a transparent RGBA PNG.

Проверка альфа-канала выполняется в `test/packages/ui_kit/brand_assets_test.dart`. Снимки входа, StartupScreen и меню фиксируют отображение на настоящих поверхностях приложения.
