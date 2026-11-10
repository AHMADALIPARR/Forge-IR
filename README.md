# FORGE / Forge-IR

FORGE is a language and runtime workspace in Racket, Factor, Oberon-07, and ATS2, plus a raw x86-64 opcode image. A source module names types, functors, and a program. A functor has parameters, an executable body, and a proof clause for the same relation. The program binds constants, invokes a functor, and asserts a result. The closed profile stage 3 accepts is FORGE Core v1 in `spec/forge-core-v1.txt`: one unsigned 64-bit type, one binary multiplication functor, and one program with two constant bindings. `compiler/expand.rkt` emits textual IR. `backend/oberon/` prints x86-64 NASM. `runtime/forge/` is a Factor machine with registers, a data stack, and a heap. `proof/` describes a typed heap and does not prove that the Factor collector matches `tests/fixtures/`. `opcode-engine/` is a separate image of 25,377 instructions, a flat binary, a static ELF, and 278 checks.

Copyright SAINT ERRANT DIGITAL INSTITUTE OF TECHNOLOGY (SEIT NGO) and the SNAPKITTY COLLECTIVE, SPDX `AGPL-3.0-only OR LicenseRef-Commercial`. They point at `LICENSE-AGPL` and `LICENSE-COMMERCIAL. `
SHA-256 `f86a95661a4832af9c0332fb4498edb8ab5195dd3e53b06a614d937403bc0eee`, # Forge-IR` and `FACTOR × RACKET × OBERON`.

## Directory layout

Moves were `git mv`. Each is a rename at 100% similarity and a diff of zero lines. Blobs match `main`. `LICENSE`, `frontend/forge-ir-v1.rkt`, `runtime/forge/ir/reader.factor`, and `spec/kernel.ir` stayed put. Stage-archive and opcode-archive files were copied byte for byte. The stage archive README is `docs/stages-3-5.md`. `tests/scripts/run-conformance.sh` keeps the archive bytes; the archive mode is `100644`, and this tree uses `100755` so `make conformance` can execute it. The opcode archive stores `engine.elf` and `engine.bin` as `100755` and the hex and JSON as `100644`. `.gitattributes` marks the two images binary so Git does not apply text conversion.

The root holds only `README.md`, `LICENSE`, `Makefile`, and `.gitattributes`.

```
LICENSE
README.md
Makefile
.gitattributes
docs/stages-3-5.md
frontend/forge-ir-v1.rkt
frontend/lexer.rkt
grammar/grammar.ebnf
compiler/expand.rkt
compiler/expand-tests.rkt
backend/oberon/{Driver,IR,Parser,X64}.Mod
backend/oberon/README.md
runtime/forge/vm/vm.factor
runtime/forge/runtime/runtime.factor
runtime/forge/ir/reader.factor
spec/kernel.ir
spec/forge-core-v1.txt
proof/forge_gc_kernel.dats
proof/ForgeHeap.sats
proof/README.md
opcode-engine/engine.hex
opcode-engine/engine.bin
opcode-engine/engine.elf
opcode-engine/validation.json
tests/fixtures/multiply.forge
tests/fixtures/multiply.fir
tests/fixtures/multiply.expected.asm
tests/fixtures/heap-valid.events
tests/fixtures/heap-invalid-sweep.events
tests/scripts/run-conformance.sh
```

`source-test` runs `racket compiler/expand-tests.rkt`. `conformance` runs the shell script. `clean` deletes `module.fir`, `module.asm`, `module.o`, and `module-native`. The moved root names are `lexer.rkt`, `grammar.ebnf`, `vm.factor`, `runtime.factor`, and `forge_gc_kernel.dats`.

## Paths 

`frontend/lexer.rkt` still requires `../syntax/lexer.rkt`, `../compiler/lower.rkt`, `syntax/tokens.rkt`, `test-lexer.rkt`, and the siblings of those paths. None of those modules are in the tree. From `frontend/`, `../syntax/` resolves outside the repository. Seven `#lang racket/base` forms mean the file is not one module. `grammar/grammar.ebnf` contains the same kind of require strings; they moved with the file.

With a Factor root of `runtime/`, `forge.vm` and `forge.runtime` match the new paths. Nothing adds that root automatically. `IN: forge.ir.reader` does not match the path that was left alone: Factor looks up `<root>/forge/ir/reader/reader.factor`, and the file is `runtime/forge/ir/reader.factor`. `proof/forge_gc_kernel.dats` includes `share/atspre_define.hats` and `share/atspre_staload.hats`, ATS2 library paths. The move does not change them.

## Frontend, grammar, and canonical IR

`grammar/grammar.ebnf` is 52,961 bytes and 1,466 lines. It opens as EBNF for modules, `UNSIGNED` types, functors (`ACCEPT`, `EXECUTE`, `PROVE`), and `LET` / `INVOKE` / `ASSERT` programs, then an Arithmetic example that asserts 96. `#lang racket/base` occurs 26 times after that. Nothing loads the file as a grammar or as one module.

`frontend/lexer.rkt` is 7,864 bytes and 195 lines of lexer, parser, semantic, IR, and lowering fragments, plus a driver whose usage line is `racket forge.rkt FILE.forge [--dump tokens|ast|ir]`. Keywords in the tests are case-sensitive. `compiler/expand.rkt` does not import it. `racket frontend/lexer.rkt` exits 1: `default-load-handler: expected a module declaration, but found something else`.

`frontend/forge-ir-v1.rkt` is 5,035 bytes and 158 lines. A copyright header and a markdown fence precede `#lang racket/base`. It validates `CONST`, `MOVE`, `ADD`, `SUB`, `MUL`, and `RETURN`, requires `RETURN` only as the last instruction, requires unique sorted function ids, and emits UTF-8 `FORGE-IR 1` through `ENDMODULE`. Direct `racket` on the file exits 1 with the same load-handler error.

`spec/kernel.ir` is the eleven-line shape. `spec/forge-core-v1.txt` requires UTF-8, LF, one ASCII space, no blank lines or comments, a final LF, canonical decimals, signed 64-bit checked arithmetic, and one zero-argument function id 0. `forge-ir-v1.rkt` allows several functions. Oberon `IR.Validate` requires exactly one. Stage 3 emits the narrower shape. `multiply.fir` is 89 bytes: module 1, `FUNC 0 0 3`, constants 12 and 8, `MUL 2 0 1`, `RETURN 2`. SHA-256 `cadf3ca53b423d605042bf06fa70bc037a1541d4c4e11d2220e8d26725ebc0df`.

## Stage 3

`compiler/expand.rkt` (7,148 bytes) provides `compile-forge` and `forge-source->ir`. It accepts one `MODULE`, one `UNSIGNED 64` type, one `FUNCTOR` that multiplies its two parameters, and one `PROGRAM` with two `LET` bindings and an `ASSERT` equal to the product. Source integers stop at `2^63-1`. `multiply.forge` is Arithmetic / Multiply / `x = 12` / `y = 8` / assert 96. `expand-tests.rkt` would compare that to `multiply.fir` and reject an assertion of 95 or a `PLUS` body.

`module+ main` uses `#:args (source [target])`. Racket 8.10 accepts an optional formal only as `[id default-expr]` and rejects this while expanding the module, so the tests never run. The source was not patched. Timings are under Benchmarks.

## Stage 4

`IR.Mod` allows 64 functions, 4,096 instructions, and 256 registers. The immediate is `LONGINT`. `Validate` requires one function, id 0, and a final `RETURN`. `Parser.Mod` and `X64.Mod` import `Texts`. The emitter writes NASM: `main` calls `forge_fn_0`, slots are `[rbp-(r+1)*8]`, and overflow returns 70 in `eax`. `multiply.expected.asm` (449 bytes) is the checked-in NASM. Assembled and linked here, that binary exits 96. Oberon did not emit it.

OBNC 0.17.2 (`obnc -v` prints that version; tarball 233,220 bytes) rejects the modules: `obnc-compile IR.Mod` exits 1 with `undeclared type: LONGINT` at line 18, and `obnc Driver.Mod` exits 1 because `Texts` is missing. The Oakwood `Input` library also failed to build here for lack of `SDL/SDL.h`. The repository `.Mod` files were not modified.

## Stage 5 and the Factor sources

`run-conformance.sh` needs `racket`, `cmp`, `nasm`, `cc`, `FORGE_OBERON_COMPILE`, and `FORGE_FACTOR_RUN`. It expands the fixture, compares bytes, runs Oberon, assembles, links with `cc -no-pie`, requires exit status 96, and requires the Factor command to print `96`. With the variables unset the script exits 2 before expand. There is no measured conformance pass.

`vm.factor` (`IN: forge.vm`, 704 lines) starts with the word `Copyright`, not a `!` comment. Opcodes run from `OP-CONST` 0 through `OP-COLLECT` 30. `collect-heap` marks from roots and frees the rest. The file ends with `END`. `runtime.factor` (`IN: forge.runtime`, 1,190 lines) is a second machine with no `OP-COLLECT`. `forge-runtime-version` returns `FORGE FACTOR RUNTIME 0.1.0`, and line 697 is `MAIN: forge-runtime-version print`. From line 699 the file is prose and a fenced ATS sketch. `reader.factor` (91 lines) accepts `CONST`, `MOVE`, `ADD`, `SUB`, `MUL`, and `RETURN`, ends on a markdown fence, and is not called from `vm-start`.

Factor 0.100 with `-roots` set to `runtime/` finds `forge.vm` and `forge.runtime`, then stops on `Copyright`. `USE: forge.ir.reader` says the vocabulary does not exist. `-no-user-init` skips `load-vocab-roots`, so `-roots` is ignored. `/usr/bin/factor` is GNU coreutils 9.4; `factor 96` prints `96: 2 2 2 2 2 3`, which is factorization, not a FORGE result.

The heap event files are unread `HEAP-EVENTS 1` traces. The invalid one marks object 1 and sweeps it in the same epoch.

## ATS

`ForgeHeap.sats` is an abstract contract: linear `heap_vt`, a `step` dataprop (`AllocStep`, `StoreRefStep`, `RootAddStep`, `RootRemoveStep`, `ReleaseStep`, `CollectStep`), and six `heap_verify_*` functions with no bodies. `proof/README.md` says these are not completed proofs. `patscc -verbose -tcats` on ATS/Postiats 0.4.2 runs `patsopt --typecheck --static` and exits 0. That checks the signature only. `patsopt -tc -d` exits 1 because dynamic mode wants `=` bodies.

`forge_gc_kernel.dats` does not implement that signature. It has a linear `live_obj` and four `praxi` assumptions: `heap_consistency`, `sweep_sound`, `mark_complete`, and `barrier_correct`. A `praxi` is trusted, not proved. Trailing `THEOREM` lines use `⇒` (U+21D2). `patscc -tcats` exits 1 on those bytes and on the `Copyright` token at line 1. The collector in `forge.vm` is not formally verified by either file.

## Opcode engine

`opcode-engine/` is the owner's raw x86-64 image, byte for byte.

`engine.hex` is 25,377 lines and 260,351 bytes, one lowercase hex instruction per line. Instructions are 1 to 10 bytes and sum to 117,487, which is the size of `engine.bin`. `file` calls the flat image data. `engine.elf` is a stripped static ELF64 executable, 121,864 bytes, mode `100755`. `validation.json` says the entry is `0x401000`, that `.text` matches `engine.bin`, that the only syscalls are `write(1)` and `exit(60)`, that privileged or trap instructions are zero, and that all 25,377 instructions are reachable. The JSON file is 35,283 bytes and 1,716 lines. Digests for all four files are in the table below. The JSON lists 278 invariants, all `"observed": "pass"`. Seventeen are named algorithm checks (LCG, CRC-32, Adler-32, FNV-1a, a sieve, gcd, integer square root, iterative and recursive Fibonacci, an 8 by 8 matrix checksum, two sorts, popcount, two SSE2 reductions, CRC32C, and Collatz). The other 261 are `mix_block_0000` through `mix_block_0260`. The file says `./engine.elf` prints one `P` or `F` per invariant and exits with the failure count capped at 255.

The 25,377 lines are not 25,377 hand-written programs. Roughly 370 instructions are the real loop programs. The rest, about 25,000 instructions, are generated straight-line arithmetic blocks. This VM did not re-slice the disassembly into those two groups. The measured totals are the line count, the objdump counts, and the 278 passing checks. In the default objdump, `add` (4122), `movabs` (3366), `xor` (3215), `rol` (2804), and `mov` (2022) dominate. Control transfers are fewer: `call` 282, `jge` 192, four `ret`, two `syscall`.

## Build and run

Stage 3 is `racket compiler/expand-tests.rkt` and `racket compiler/expand.rkt tests/fixtures/multiply.forge /tmp/multiply.fir`, then `cmp` against `tests/fixtures/multiply.fir`. Stage 4 needs Oberon-07 `Texts` and `LONGINT`; OBNC 0.17.2 does not accept these modules. The checked-in assembly is `nasm -f elf64` and `cc -no-pie`. Stage 5 exits 2 until `FORGE_OBERON_COMPILE` and `FORGE_FACTOR_RUN` are set. Factor loads with `factor -roots="$PWD/runtime"`. ATS checks are `patscc -tcats` on the two proof files. The opcode image is `./opcode-engine/engine.elf`. On Racket 8.10 the expand commands fail while expanding `compiler/expand.rkt`.

## Benchmarks

Measured on 10 November 2026 (UTC) in this VM. Failing commands are reported with the observed exit status. No source file was edited to force a pass.

`uname -a`: `Linux cursor 6.12.113+ #1 SMP PREEMPT_DYNAMIC Mon Nov  9 16:04:37 UTC 2026 x86_64 GNU/Linux`. Four cores, `Intel(R) Xeon(R) Processor` family 6 model 207, KVM. `free -h` showed 15Gi total. Ubuntu 24.04.5 LTS, Bash 5.2.21(1)-release. Racket v8.10 [cs] (`8.10+dfsg1-2ubuntu1`), NASM 2.16.01, hyperfine 1.18.0, `cc` Ubuntu clang 18.1.3, gcc 13.3.0, GNU ld 2.42, Make 4.3, ATS/Postiats 0.4.2, OBNC 0.17.2 (`./build --prefix=/tmp/obnc-prefix` exited 0), Factor `0.100 x86.64 (2281, tags/0.100-80a4633f05, Oct 14 2024 15:53:19)` from a 52,023,705-byte tarball, coreutils `factor` 9.4, `GNU objdump (GNU Binutils for Ubuntu) 2.42`.

`racket compiler/expand-tests.rkt` exits 1, empty stdout. Stderr begins `compiler/expand.rkt:170:10: command-line: bad formals for #:args` and shows the form `(source (target))`, with context in `/usr/share/racket/collects/racket/cmdline.rkt:165:38`. `racket compiler/expand.rkt tests/fixtures/multiply.forge /tmp/multiply.fir` exits 1 with the same message and creates no file. `cmp /tmp/multiply.fir tests/fixtures/multiply.fir` exits 2: `cmp: /tmp/multiply.fir: No such file or directory`. `make source-test` exits 2, stdout `racket compiler/expand-tests.rkt`, stderr ending `make: *** [Makefile:4: source-test] Error 1`.

There is no successful expand timing. hyperfine `--warmup 3 --runs 20 --ignore-failure` on the expand command printed `143.2 ms ± 7.4 ms` (user 103.9 ms, system 39.0 ms), range 135.5 ms to 169.9 ms, 20 runs, `Warning: Ignoring non-zero exit code.` JSON mean 0.14318066619, min 0.13551934764, max 0.16990562264, twenty exits of 1. On `racket compiler/expand-tests.rkt`, `--warmup 2 --runs 10 --ignore-failure`, it printed `313.8 ms ± 33.8 ms` (user 240.9 ms, system 72.4 ms), range 272.3 ms to 400.0 ms, 10 runs, plus an outliers warning. JSON mean 0.31376585356, min 0.27231540526000003, max 0.40002829726, ten exits of 1. These times are the syntax error, not `forge-source->ir` throughput.

Bash `TIMEFORMAT`, ten runs of that expand command, each exit 1, real seconds from 0.140 to 0.192 (the ten samples were 0.192, 0.147, 0.141, 0.169, 0.148, 0.140, 0.147, 0.180, 0.162, 0.148). `/usr/bin/time` is not installed.

`nasm -f elf64` on `multiply.expected.asm` exits 0. `cc -no-pie` exits 0. ld warns that the object lacks `.note.GNU-stack` and implies an executable stack. The binary prints nothing and exits 96. Object SHA-256, not a repository file: `66bb64b804edaad142b42c12d838dc5725f8014124bc59afad175fcefe2c40a3`.

`./tests/scripts/run-conformance.sh` exits 2: `FORGE_OBERON_COMPILE: set FORGE_OBERON_COMPILE to an Oberon runner command that invokes Driver.Compile(input, output)`. Empty variables do the same. `make conformance` exits 2 with `make: *** [Makefile:9: conformance] Error 2`.

`obnc-compile IR.Mod` exits 1: `IR.Mod:18: error: undeclared type: LONGINT`. `obnc -V Driver.Mod` exits 1: `module imported by Driver.Mod not found: Texts`.

Factor 0.100 `USE: forge.vm` and `-run=forge.runtime` exit 1 on the `Copyright` line. `USE: forge.ir.reader` exits 1 with `Vocabulary does not exist`. `patscc -tcats` on the kernel exits 1 (`FatalErrorExn(1025)`). `patscc -verbose -tcats` on `ForgeHeap.sats` prints `exec(patsopt --typecheck --static ForgeHeap.sats) = 0`. `patsopt -tc -d` on that file exits 1. `patscc -tc` forwarded `-tc` to gcc, which rejected it; that run is not a typecheck.

`wc -l opcode-engine/engine.hex` prints `25377 opcode-engine/engine.hex`.

`./opcode-engine/engine.elf; echo $?` writes 278 `P` characters and a newline (279 bytes), writes nothing on stderr, and exits 0. There is no `F`. Exit 0 means all 278 internal checks passed, matching `validation.json`.

`objdump -D -b binary -m i386:x86-64 opcode-engine/engine.bin | grep -c '^ '` prints `28939`. Wrapped continuation lines are included. That dump has 25,377 mnemonic lines. `objdump -D -b binary -m i386:x86-64 --insn-width=16 opcode-engine/engine.bin | grep -c '^ '` prints `25377`. `validation.json` records the `--insn-width=16` shape under objdump 2.44; this machine's objdump is 2.42, and the line count here is 25,377.

hyperfine on `./opcode-engine/engine.elf`, `--warmup 3 --runs 20`, printed `975.4 µs ± 151.6 µs` (user 931.0 µs, system 56.9 µs), range 752.2 µs to 1265.9 µs, 20 runs, and warned that a command under 5 ms may be inaccurate. JSON mean 0.0009754091400000003, min 0.0007521758400000002, max 0.0012658678400000003, twenty exits of 0. `--warmup 5 --runs 50 --shell=none` printed `951.7 µs ± 138.3 µs` (user 863.0 µs, system 14.8 µs), range 761.6 µs to 1363.3 µs, 50 runs, all exit 0. JSON mean 0.0009517208200000002, min 0.000761644, max 0.0013632560000000002. Bash `time`, five runs, each exit 0 and 279 stdout bytes, reported real 0.001, 0.002, 0.001, 0.001, 0.001. The shell keyword resolves only milliseconds.

`wc -l` and `wc -c` produced the table. Digests are `sha256sum`. This README's digest is not stored in the file, because writing it would change it. `wc -l` on `engine.bin` and `engine.elf` counts newline bytes in binary images (266 each) and is not an instruction count. The instruction count is the 25,377 hex lines. The eighteen stage-archive files match the archive, including `docs/stages-3-5.md` against the archive README. The five moved files match the `main` blobs. `LICENSE`, `frontend/forge-ir-v1.rkt`, `runtime/forge/ir/reader.factor`, and `spec/kernel.ir` match their `main` blobs.

| Bytes | Lines | SHA-256 | Path |
| ---: | ---: | --- | --- |
| 34523 | 661 | `8486a10c4393cee1c25392769ddd3b2d6c242d6ec7928e1414efff7dfb2f07ef` | `LICENSE` |
| 349 | 12 | `56ac66be6b1c30fd84b3908bcd677c20ab500abb2b8d8f71379d6bf5f09768b1` | `Makefile` |
| 2979 | 66 | `6e05d7c83906c5a7361fa7a7fbeeb37a35beb0fe30745ef3a3bb5462b4b52b59` | `docs/stages-3-5.md` |
| 5035 | 158 | `3409cac19234abbeca6ec3288f62f099b48b90b1687ba8adceb5a410b3048778` | `frontend/forge-ir-v1.rkt` |
| 7864 | 195 | `3130d00bef30d700b6bb476a9db313e4bddbf0b363132a2cc25d6dc2c498f2af` | `frontend/lexer.rkt` |
| 52961 | 1466 | `d2c9918a72bdf06281873d2acf3fb294c6dacacf175f78e158ca6b21c530e09d` | `grammar/grammar.ebnf` |
| 7148 | 173 | `be55da789687f6bf6a8571c7074e174d333df436644db0ef608d02ba0eab06b2` | `compiler/expand.rkt` |
| 677 | 19 | `d7c8e95212df4b650a339a3ddd3e81d56406e30748ed162572c6dba9f858a263` | `compiler/expand-tests.rkt` |
| 348 | 18 | `c4e9a66b276dfe44bb4ec9faccb9eb426f1e4d6a445cff053859248dbb61e1b4` | `backend/oberon/Driver.Mod` |
| 3102 | 109 | `debab26c15f44a5977297e1582e9f93e142cda36d919435218bb4d29d78a1090` | `backend/oberon/IR.Mod` |
| 2504 | 84 | `061ae5d6180b85ef11e8a74674d79cf6a34de5a5dd9eab351354e5d6c9011be1` | `backend/oberon/Parser.Mod` |
| 2733 | 94 | `dfed5159d0b65a9a2d7781062dc95975d625b642734d239b0aee6f514c9ec542` | `backend/oberon/X64.Mod` |
| 1253 | 26 | `f2e6acf2df90586600d797617871d3adcc372bf253f4c1f3f5ce8def08fd6b80` | `backend/oberon/README.md` |
| 16996 | 704 | `768fcc2113ecdffaef82a0cb9842300145ce4534015fdab180c365e114e4a899` | `runtime/forge/vm/vm.factor` |
| 29363 | 1190 | `735a0102e7b6efcfcedcb83e2e7763e6ecb35227fbaf5af0d815c14ed5cc0c18` | `runtime/forge/runtime/runtime.factor` |
| 2677 | 91 | `40835c630442f5f46e4d1ae15331883e074a32937aad74a522e9696e6dbcf970` | `runtime/forge/ir/reader.factor` |
| 398 | 11 | `714796035ded50bd39f22e2e34d1ebe65cb8b25a672580391874b1a72eb0e141` | `spec/kernel.ir` |
| 1709 | 50 | `914bb0e569ce38956d67763eaacb501511ed0b070035461cbfc2efb9cf59079a` | `spec/forge-core-v1.txt` |
| 9822 | 264 | `ca2895e90201e54ddc4611bb72b9073b18f405530d37322fad88353b0dff45be` | `proof/forge_gc_kernel.dats` |
| 1585 | 43 | `c6ad6523622ce2bd0311f570432a5102a6680adc9bef82a511bfdb5c7f736be2` | `proof/ForgeHeap.sats` |
| 825 | 15 | `7ed537a0fc6ecb7932cc3b16026c64d9f3c04d713e60c53d001069ab3900d04c` | `proof/README.md` |
| 260351 | 25377 | `dadafddddef0e74f4131eef80414e1727fc6de4aa2d0d7cdb7a4ed428c5aca6c` | `opcode-engine/engine.hex` |
| 117487 | 266 | `d51909a0305fb66f196905d8b78ee2b1eb9d201e3d020234a1a0caae298df7ea` | `opcode-engine/engine.bin` |
| 121864 | 266 | `1ff5d1779f06e588c6443cc8c8c18960d6ea02b41913ccededb5fb55f23b3633` | `opcode-engine/engine.elf` |
| 35283 | 1716 | `7fb57c4c40050f308ab67f10c0890e3d651db9ff718476f32752635c2068810a` | `opcode-engine/validation.json` |
| 312 | 19 | `9fd2b3f3baa55e44e1017d724cc0144b3a6952335f84da6fa6fbf942be498b5e` | `tests/fixtures/multiply.forge` |
| 89 | 9 | `cadf3ca53b423d605042bf06fa70bc037a1541d4c4e11d2220e8d26725ebc0df` | `tests/fixtures/multiply.fir` |
| 449 | 30 | `05b75abf6a0367db3d14ea5f4be689874279621af1c875342970fb8592ddb829` | `tests/fixtures/multiply.expected.asm` |
| 202 | 16 | `8a2b7ad52bcc61bcb9651beda5d2304fe0df8249a8749b8f4da61bf48d9a76ef` | `tests/fixtures/heap-valid.events` |
| 97 | 8 | `d96bb0cb68e15e8e6e0cae2e02e201bcef04c22d5ecb0e946274c4d05764585f` | `tests/fixtures/heap-invalid-sweep.events` |
| 1559 | 34 | `6d1573dfffdbb9e1f82cf4dfad52f07b8b15169f3be860874d8733d0ca57829f` | `tests/scripts/run-conformance.sh` |
