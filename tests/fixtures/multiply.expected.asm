default rel
section .text
global main
main:
    push rbp
    mov rbp, rsp
    call forge_fn_0
    leave
    ret

global forge_fn_0
forge_fn_0:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    mov rax, 12
    mov [rbp-8], rax
    mov rax, 8
    mov [rbp-16], rax
    mov rax, [rbp-8]
    imul rax, [rbp-16]
    jo .Lforge_overflow_0
    mov [rbp-24], rax
    mov rax, [rbp-24]
    leave
    ret
.Lforge_overflow_0:
    mov eax, 70
    leave
    ret
