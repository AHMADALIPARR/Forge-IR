# FORGE Stages 3–5

This repository slice implements the initial FORGE Core v1 source profile and
its canonical IR v1 path.

## Stage 3: Racket syntax engine

`compiler/expand.rkt` contains a hand-written lexer, recursive declaration
parser, semantic validation, functor/proof-clause consistency checks, checked
constant evaluation, and canonical IR byte emission. It accepts the closed
source profile in `spec/forge-core-v1.txt` and rejects all other syntax.

Run:

```sh
racket compiler/expand.rkt tests/fixtures/multiply.forge /tmp/multiply.fir
cmp /tmp/multiply.fir tests/fixtures/multiply.fir
racket compiler/expand-tests.rkt
```

## Stage 4: Oberon-07 native backend

`backend/oberon/` contains the IR record model, parser, x86-64 NASM emitter,
and driver. The emitted native entry uses the System V AMD64 ABI, stack slots
for virtual registers, `RAX` for return values, and checked arithmetic.

Compile `IR.Mod`, `Parser.Mod`, `X64.Mod`, and `Driver.Mod` with the selected
Oberon-07 toolchain. Invoke `Driver.Compile` with the canonical IR input and
assembly output names. Then assemble and link with NASM and the system C linker.

## Stage 5: conformance

`tests/scripts/run-conformance.sh` compares Racket-emitted bytes with the
canonical fixture, runs the Oberon backend, assembles and executes the native
binary, and compares its exit result with the Factor VM result.

Set `FORGE_OBERON_COMPILE` to a shell command that invokes the compiled Oberon
driver with input and output file arguments. Set `FORGE_FACTOR_RUN` to a shell
command that loads the Factor VM and executes the supplied IR file, printing
only its integer result.

## Proof boundary

`proof/ForgeHeap.sats` defines the ATS2 abstract state and transition witness
interface. `proof/ForgeHeap.sats` is an abstract proof contract only. There is no `.dats`
proof implementation in this package. The heap event fixtures are test vectors
for the next proof implementation. Do not report the collector as formally
verified until a concrete ATS heap model and transition proofs exist.

## Scope and correctness status

The v1 source profile intentionally supports one unsigned-64 declaration,
one binary multiplication functor, and one program invocation with two
constant LET bindings and a result assertion. To remain compatible with the
existing signed-64 canonical IR v1 and checked native arithmetic, v1 source
integer literals are restricted to `0..2^63-1`. Full unsigned-64 arithmetic,
multiple function calls, branches, and heap opcodes require a separately
versioned IR extension.

No Python component is used in the compiler/runtime/backend pipeline.

The Racket, Oberon, Factor, and ATS sources have not been compiled together in
this environment. The available `factor` executable here is the Unix
factorization utility, not the Factor language runtime. Treat this as a
source-level implementation package pending toolchain compilation and
conformance execution, not as a certified passing build.
