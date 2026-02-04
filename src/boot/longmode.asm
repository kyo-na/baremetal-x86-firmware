BITS 32
pm_entry:
    mov ax, 0x10
    mov ds, ax
    mov ss, ax
    mov esp, 0x90000

    ; PAE
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; Long mode enable
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    jmp 0x08:long_mode_entry

BITS 64
long_mode_entry:
    mov rsp, 0x80000
    extern kernel_main
    call kernel_main

hang:
    hlt
    jmp hang
