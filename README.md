# x86_64 自作ファームウェア実験プロジェクト

## プロジェクト概要

本プロジェクトは UEFI そのものではありません。しかし、UEFI が存在するファームウェア層と同等のレイヤにおいて、既存実装（EDK2 等）を一切使わず、ゼロから CPU 初期化と実行環境を構築することを目的としています。

教育・検証・低レイヤ理解を主目的とした**完全自作ファームウェア実験**です。

## 主な特徴

* **ROM 書き換え不可を前提とした RAM 上での GDT 構築**
* **手動による Protected Mode への遷移**
* **PAE + Identity Mapping による Long Mode 突入**
* **ファームウェアサービス非依存の VGA フレームバッファ描画**
* **QEMU (`qemu-system-x86_64`) 上での動作確認**

## 動作モード

このログは、それぞれ Real Mode / Protected Mode / Long Mode に正しく到達していることを示します。

## VGA 描画仕様

VGA 描画については、Mode 13h 相当（320×200 / 256色）を前提とし、パレットを I/O ポート（0x3C8 / 0x3C9）で設定した上で、VRAM（物理アドレス 0xA0000）へ直接 RAW データを書き込む方式を採用しています。

**BIOS の int 0x10 や UEFI GOP などは使用していません。**

## 実行例

以下は VGA フレームバッファに直接描画した実行例です。

*(実行例の画像や出力ログがここに表示されることを想定)*

## ビルドおよび実行手順

### 1. アセンブル

```bash
nasm -f bin src\boot\reset.asm -o build\reset.bin
```

### 2. ファームウェアイメージ生成

```powershell
fsutil file createnew build\firmware.bin 65536
$rom    = [System.IO.File]::ReadAllBytes("build\firmware.bin")
$reset  = [System.IO.File]::ReadAllBytes("build\reset.bin")
$offset = $rom.Length - $reset.Length
[Array]::Copy($reset, 0, $rom, $offset, $reset.Length)
[System.IO.File]::WriteAllBytes("build\firmware.bin", $rom)
```

### 3. QEMU で実行

```bash
qemu-system-x86_64 -bios build\firmware.bin -nographic ^
 -chardev file,id=dbg,path=debug.log ^
 -device isa-debugcon,iobase=0xe9,chardev=dbg
```

## 今後の拡張予定

* **VESA BIOS Extensions (VBE) による高解像度描画**
* **フォント描画（テキストレンダリング）**
* **C 言語エントリポイントへの移行**
* **UEFI GOP 実装との挙動比較**

---

本プロジェクトは、x86_64 アーキテクチャの低レイヤ動作を深く理解し、ファームウェアレベルでの実装