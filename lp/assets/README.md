# assets

`ZenKakuGothicNew-Black-subset.ttf` is the face drawn into the Open Graph card
(`src/app/[locale]/opengraph-image.tsx`). It is the same display face the site
uses for its headings, cut down to the characters the card actually shows.

Any character missing from it silently falls back to a different face, so when
the card's copy changes, rebuild the subset:

```sh
curl -sL -o /tmp/ZenKakuGothicNew-Black.ttf \
  "https://github.com/google/fonts/raw/main/ofl/zenkakugothicnew/ZenKakuGothicNew-Black.ttf"

pyftsubset /tmp/ZenKakuGothicNew-Black.ttf \
  --text="Nonja 通知を、静かに溜めておく受信箱 A quiet inbox for your notifications MACOS MENU BAR" \
  --unicodes="U+0020-007E,U+00A0-00FF,U+2010-2027,U+3000-303F,U+30FB" \
  --output-file=assets/ZenKakuGothicNew-Black-subset.ttf \
  --no-hinting --desubroutinize --layout-features=''
```

## sample-earth.jpg

The picture shown inside the window on the landing page. Taken from the International Space
Station on Expedition 58 (NASA id iss058e005282) and resized to 1100×733. NASA imagery is not
copyrighted, which is why it is here: the screenshot needed a photograph whose licence asks
nothing of whoever reuses the screenshot.
