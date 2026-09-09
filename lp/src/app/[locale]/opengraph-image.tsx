import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { ImageResponse } from "next/og";
import { routing } from "@/i18n/routing";

export const alt = "Macview";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

/* ビルド時に焼く。動的なままだと public/ が関数側に含まれず、
   本番で icon.png を読めずに 500 になる */
export function generateStaticParams(): { locale: string }[] {
  return routing.locales.map((locale) => ({ locale }));
}

/* アイコンと名前を横に並べる形は Nonja と揃える。
   色はアイコンから。地はアプリが画像を載せている炭 */
const FIELD = "#212121";
const PAPER = "#f3f2ef";
const MUTED = "rgba(243, 242, 239, 0.6)";

export default async function OgImage({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<ImageResponse> {
  const { locale } = await params;
  const isJa = locale === "ja";
  const [icon, font] = await Promise.all([
    readFile(join(process.cwd(), "public/icon.png")),
    readFile(join(process.cwd(), "assets/ZenKakuGothicNew-Black-subset.ttf")),
  ]);
  const iconSrc = `data:image/png;base64,${icon.toString("base64")}`;

  return new ImageResponse(
    <div
      style={{
        alignItems: "center",
        background: FIELD,
        display: "flex",
        gap: 56,
        height: "100%",
        justifyContent: "center",
        width: "100%",
      }}
    >
      {/* biome-ignore lint/performance/noImgElement: next/image is not available in ImageResponse */}
      <img alt="" height={230} src={iconSrc} style={{ borderRadius: 52 }} width={230} />
      <div style={{ display: "flex", flexDirection: "column" }}>
        <div style={{ color: PAPER, display: "flex", fontSize: 112, letterSpacing: -2 }}>
          Macview
        </div>
        <div style={{ color: MUTED, display: "flex", fontSize: 32, marginTop: 14 }}>
          {isJa ? "開くと、画像だけが出ます" : "The picture, and nothing else"}
        </div>
      </div>
    </div>,
    {
      ...size,
      fonts: [{ data: font, name: "Zen Kaku Gothic New", style: "normal", weight: 900 }],
    },
  );
}
