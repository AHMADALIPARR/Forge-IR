# Oberon-07 backend

Target: x86-64 Linux, ELF64, NASM syntax, System V AMD64 ABI.

Modules:

- `IR.Mod`: bounded canonical IR representation and structural validation.
- `Parser.Mod`: token reader for canonical IR v1.
- `X64.Mod`: stack-slot lowering, checked arithmetic, function prologue/epilogue,
  System V entry wrapper, and NASM emission.
- `Driver.Mod`: loads an IR text, parses it, validates it, and stores assembly.

The initial v1 backend accepts exactly one zero-argument function with ID 0.
Registers are 64-bit stack slots. `RAX` is the return register. The generated
`main` wrapper calls `forge_fn_0`, preserving the System V stack alignment.
Overflow returns status 70.

Build and invocation are toolchain-specific because Oberon-07 implementations
have different module loaders and Texts implementations. Compile the modules
in dependency order (`IR`, `Parser`, `X64`, `Driver`), then invoke
`Driver.Compile("multiply.fir", "multiply.asm")` in the Oberon environment.
Assemble with `nasm -f elf64 multiply.asm -o multiply.o`, then link with
`cc -no-pie multiply.o -o multiply-native`.

This source has not been compiled in an Oberon-07 implementation in this
workspace. Verify the exact `Texts` API against the selected Oberon runtime.
