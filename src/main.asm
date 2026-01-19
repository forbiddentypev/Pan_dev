org 0x7C00
BITS 16

%define ENDL 0x0D, 0x0A

start:
    jmp main

; printing string to screan
puts:
    push si
    push ax

.loop:
    lodsb           ; loads next character in al
    or al, al       ; verify if next character is null?
    jz .done

    mov ah, 0x0e
    mov bh, 0 ;
    int 0x10

    jmp .loop ;

.done:
    pop ax
    pop si
    ret

main:

    ; setup data segments
    mov ax, 0       ; can't write to ds/es directry
    mov ds, ax
    mov es, ax

    ; setup stack
    mov ss, ax
    mov sp, 0x7C00   ; stack grows downwaards from where we are loaded in memory

    mov si, msg_hello
    call puts

    hlt

.halt:
    jmp .halt

msg_hello: db 'Pan OS!', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h