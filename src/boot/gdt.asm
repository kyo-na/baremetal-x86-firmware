BITS 16

gdt_start:
    dq 0x0000000000000000     ; null
    dq 0x00AF9A000000FFFF     ; code
    dq 0x00AF92000000FFFF     ; data
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

protected_entry:
    lgdt [gdt_descriptor]

    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp 0x08:pm_entry
