# src/boot/convert.py
from PIL import Image
import os

# 入力ファイル名 (アップロードされた画像)
INPUT_FILE = "girl.jpg"

def main():
    if not os.path.exists(INPUT_FILE):
        print(f"エラー: {INPUT_FILE} が見つかりません。src\\boot に画像を置いてください。")
        return

    # 画像を開いてリサイズ (320x180)
    img = Image.open(INPUT_FILE)
    img = img.resize((320, 180), Image.LANCZOS)

    # 256色に減色 (パレット生成)
    img = img.convert("P", palette=Image.ADAPTIVE, colors=256)

    # パレットデータの抽出 (VGA用に 0-255 を 0-63 に変換)
    palette = img.getpalette()
    palette_data = bytearray()
    # 256色分 (R,G,B * 256 = 768 bytes)
    for i in range(256):
        r = palette[i*3] // 4
        g = palette[i*3+1] // 4
        b = palette[i*3+2] // 4
        palette_data.extend([r, g, b])

    # ピクセルデータの抽出
    pixel_data = list(img.getdata())

    # 保存
    with open("girl.pal", "wb") as f:
        f.write(palette_data)
    with open("girl.raw", "wb") as f:
        f.write(bytearray(pixel_data))

    print(f"変換完了: girl.raw ({len(pixel_data)} bytes), girl.pal ({len(palette_data)} bytes)")

if __name__ == "__main__":
    main()