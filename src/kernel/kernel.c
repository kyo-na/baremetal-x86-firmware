void kernel_main(void) {
    // ここに到達したら「完全勝利」
    while (1) {
        __asm__("hlt");
    }
}
