; =========================================================
; reset.asm (16bit -> 32bit -> 64bit Long Mode)
; =========================================================

BITS 16
ORG 0x0000

; セレクタ定義
CODE32_SEL equ 0x08
DATA_SEL   equ 0x10
CODE64_SEL equ 0x18  ; 64bit用コードセグメント (新規追加)

; ---------------------------------------------------------
; 16-bit Mode (物理 0xF0000)
; ---------------------------------------------------------
main_entry:
    cli

    ; セグメント初期化
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; A20 有効化
    in  al, 0x92
    or  al, 00000010b
    out 0x92, al

    ; [OK1]
    mov dx, 0xE9
    mov al, 'O'
    out dx, al
    mov al, 'K'
    out dx, al
    mov al, '1'
    out dx, al

    ; -----------------------------------------------------
    ; GDT 準備 (RAM 0x0800 に GDTR を作成)
    ; -----------------------------------------------------
    xor eax, eax
    mov ax, cs
    shl eax, 4
    add eax, gdt_start   ; GDTの物理アドレス

    mov word [0x0800], gdt_end - gdt_start - 1
    mov dword [0x0802], eax
    lgdt [0x0800]

    ; CR0.PE = 1 (プロテクトモード)
    mov eax, cr0
    or  eax, 1
    mov cr0, eax

    ; 32bitへジャンプ
    db 0x66
    db 0xEA
    dd 0xF0000 + pm_entry
    dw CODE32_SEL

; =========================================================
; 32-bit Protected Mode
; =========================================================
BITS 32
pm_entry:
    mov ax, DATA_SEL
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x7C00

    ; [OK32]
    mov dx, 0xE9
    mov al, 'O'
    out dx, al
    mov al, 'K'
    out dx, al
    mov al, '3'
    out dx, al
    mov al, '2'
    out dx, al

    ; -----------------------------------------------------
    ; 64bit への準備: ページテーブル作成 (Identity Map)
    ; -----------------------------------------------------
    ; 構造: PML4 -> PDPT -> PD -> 物理メモリ(2MB Page)
    ; 0x1000: PML4
    ; 0x2000: PDPT
    ; 0x3000: PD

    ; 1. 領域をゼロクリア (0x1000 - 0x4000)
    cld
    xor eax, eax
    mov edi, 0x1000
    mov ecx, 0x1000 ; 4096 bytes * 3 くらい消せば十分
    rep stosd

    ; 2. PML4 (0x1000) -> PDPT (0x2000)
    ; 0x2003 = Address 0x2000 + Present(1) + RW(1)
    mov dword [0x1000], 0x2003

    ; 3. PDPT (0x2000) -> PD (0x3000)
    ; 0x3003 = Address 0x3000 + Present(1) + RW(1)
    mov dword [0x2000], 0x3003

    ; 4. PD (0x3000) -> 物理 0x00000000 (2MB Huge Page)
    ; 0x00000083 = Addr 0 + HugePage(0x80) + Present(1) + RW(1)
    mov dword [0x3000], 0x00000083

    ; -----------------------------------------------------
    ; 64bit 有効化シーケンス
    ; -----------------------------------------------------
    
    ; 1. CR4.PAE = 1 (Bit 5)
    mov eax, cr4
    or  eax, 1 << 5
    mov cr4, eax

    ; 2. CR3 に PML4 のアドレス (0x1000) をセット
    mov eax, 0x1000
    mov cr3, eax

    ; 3. EFER MSR (0xC0000080) の LME (Bit 8) をセット
    mov ecx, 0xC0000080 ; EFER MSR number
    rdmsr               ; EAX:EDX に読み込み
    or  eax, 1 << 8     ; LME bit
    wrmsr               ; 書き戻し

    ; 4. CR0.PG = 1 (ページング有効化 = Long Mode突入)
    mov eax, cr0
    or  eax, 1 << 31
    mov cr0, eax

    ; 5. 64bitコードセグメントへジャンプ (Far Jump)
    ; jmp CODE64_SEL:(0xF0000 + lm_entry)
    jmp CODE64_SEL:(0xF0000 + lm_entry)


; =========================================================
; 64-bit Long Mode
; =========================================================
BITS 64
lm_entry:
    ; セグメントレジスタは 64bit ではほぼ無視されるが、
    ; データ用に 0 (Null) または Data Segment を入れておくのが作法
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, 0x7C00

    ; -----------------------------------------------------
    ; [OK64]
    ; -----------------------------------------------------
    mov dx, 0xE9
    
    mov al, 'O'
    out dx, al
    mov al, 'K'
    out dx, al
    mov al, '6'
    out dx, al
    mov al, '4'
    out dx, al

hang:
    hlt
    jmp hang

; ---------------------------------------------------------
; GDT Definitions (ROM)
; ---------------------------------------------------------
BITS 16
gdt_start:
    dq 0x0000000000000000     ; Null

    ; [0x08] 32-bit Code
    dw 0xFFFF, 0x0000, 0x9A00, 0x00CF

    ; [0x10] Data
    dw 0xFFFF, 0x0000, 0x9200, 0x00CF

    ; [0x18] 64-bit Code (ここを追加！)
    ; Base=0, Limit=0 (無視される), Access=9A, Flags=AF (L-bit=1, D-bit=0)
    ; 10011010b = 0x9A (Present, Ring0, Code, Exec/Read)
    ; 10101111b = 0xAF (Granularity, LongMode=1, 32bit=0)
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10011010b ; Access
    db 10101111b ; Flags (L=1, D=0)
    db 0x00

gdt_end:

; ---------------------------------------------------------
; Reset Vector & Alignment
; ---------------------------------------------------------
times 0xFFF0 - ($ - $$) db 0x90

reset_vector:
    jmp 0xF000:0x0000

times 0x10000 - ($ - $$) db 0x90