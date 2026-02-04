; =========================================================
; reset.asm (32bit Draw Version)
; =========================================================

BITS 16
ORG 0x0000

CODE32_SEL equ 0x08
DATA_SEL   equ 0x10
CODE64_SEL equ 0x18

; ---------------------------------------------------------
; 16-bit Mode (物理 0xF0000)
; ---------------------------------------------------------
main_entry:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; A20 有効化
    in  al, 0x92
    or  al, 00000010b
    out 0x92, al

    ; -----------------------------------------------------
    ; VGA Mode 13h (320x200, 256色) レジスタ設定
    ; -----------------------------------------------------
    mov dx, 0x3C2
    mov al, 0x63
    out dx, al

    mov dx, 0x3C4
    mov si, vga_seq_data
    mov cx, 5
.seq_loop:
    mov al, [cs:si]
    inc si
    out dx, al
    inc dx
    mov al, [cs:si]
    inc si
    out dx, al
    dec dx
    loop .seq_loop

    mov dx, 0x3D4
    mov si, vga_crtc_data
    mov cx, 25
.crtc_loop:
    mov al, [cs:si]
    inc si
    out dx, al
    inc dx
    mov al, [cs:si]
    inc si
    out dx, al
    dec dx
    loop .crtc_loop

    mov dx, 0x3CE
    mov si, vga_gc_data
    mov cx, 9
.gc_loop:
    mov al, [cs:si]
    inc si
    out dx, al
    inc dx
    mov al, [cs:si]
    inc si
    out dx, al
    dec dx
    loop .gc_loop

    mov dx, 0x3DA
    in al, dx
    mov dx, 0x3C0
    mov si, vga_ac_data
    mov cx, 20
.ac_loop:
    mov al, [cs:si]
    inc si
    out dx, al
    mov al, [cs:si]
    inc si
    out dx, al
    loop .ac_loop

    mov dx, 0x3DA
    in al, dx
    mov dx, 0x3C0
    mov al, 0x20
    out dx, al

    ; -----------------------------------------------------
    ; パレット設定 (成功しているのでそのまま)
    ; -----------------------------------------------------
    mov dx, 0x3C8
    xor al, al
    out dx, al

    mov dx, 0x3C9
    mov si, palette_data
    mov cx, 768
.pal_loop:
    db 0x2E         ; CS override
    lodsb
    out dx, al
    loop .pal_loop

    ; -----------------------------------------------------
    ; GDT & Protect Mode
    ; -----------------------------------------------------
    xor eax, eax
    mov ax, cs
    shl eax, 4
    add eax, gdt_start
    mov word [0x0800], gdt_end - gdt_start - 1
    mov dword [0x0802], eax
    lgdt [0x0800]

    mov eax, cr0
    or  eax, 1
    mov cr0, eax

    db 0x66, 0xEA
    dd 0xF0000 + pm_entry
    dw CODE32_SEL

; ---------------------------------------------------------
; VGA Register Data
; ---------------------------------------------------------
vga_seq_data:  db 0x00,0x03, 0x01,0x01, 0x02,0x0F, 0x03,0x00, 0x04,0x0E
vga_crtc_data: db 0x00,0x5F, 0x01,0x4F, 0x02,0x50, 0x03,0x82, 0x04,0x54, 0x05,0x80, 0x06,0xBF, 0x07,0x1F, 0x08,0x00, 0x09,0x41, 0x0A,0x00, 0x0B,0x00, 0x0C,0x00, 0x0D,0x00, 0x0E,0x00, 0x0F,0x00, 0x10,0x9C, 0x11,0x0E, 0x12,0x8F, 0x13,0x28, 0x14,0x40, 0x15,0x96, 0x16,0xB9, 0x17,0xA3, 0x18,0xFF
vga_gc_data:   db 0x00,0x00, 0x01,0x00, 0x02,0x00, 0x03,0x00, 0x04,0x00, 0x05,0x40, 0x06,0x05, 0x07,0x0F, 0x08,0xFF
vga_ac_data:   db 0x00,0x00, 0x01,0x01, 0x02,0x02, 0x03,0x03, 0x04,0x04, 0x05,0x05, 0x06,0x06, 0x07,0x07, 0x08,0x08, 0x09,0x09, 0x0A,0x0A, 0x0B,0x0B, 0x0C,0x0C, 0x0D,0x0D, 0x0E,0x0E, 0x0F,0x0F, 0x10,0x41, 0x11,0x00, 0x12,0x0F, 0x13,0x00

; =========================================================
; 32-bit Protected Mode
; =========================================================
BITS 32
pm_entry:
    mov ax, DATA_SEL
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x7C00

    ; -----------------------------------------------------
    ; ★ 画像描画 (32bitモードで実行) ★
    ; -----------------------------------------------------
    ; 32bitモードなら物理アドレス計算が単純です。
    ; ソース: 0xF0000(ROM先頭) + image_data(オフセット)
    ; 宛先:   0xA0000(VRAM)
    
    mov esi, 0xF0000 + image_data
    mov edi, 0xA0000
    mov ecx, 57600 / 4  ; 320*180 / 4 (4バイトずつ転送)
    rep movsd

    ; 描画が終わったらここで停止 (画像を確認するため)
    ; 64bitへは後でも行けます
stop:
    hlt
    jmp stop

; =========================================================
; Data Section
; =========================================================
ALIGN 4
gdt_start:
    dq 0
    dw 0xFFFF, 0x0000, 0x9A00, 0x00CF
    dw 0xFFFF, 0x0000, 0x9200, 0x00CF
    dw 0xFFFF, 0x0000, 0, 0x9A, 0xAF, 0
gdt_end:

ALIGN 16
palette_data:
    incbin "girl.pal"

ALIGN 16
image_data:
    incbin "girl.raw"

; ---------------------------------------------------------
; Reset Vector (16-bit)
; ---------------------------------------------------------
BITS 16
times 0xFFF0 - ($ - $$) db 0x90
reset_vector:
    jmp 0xF000:0x0000
times 0x10000 - ($ - $$) db 0x90