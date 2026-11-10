.PHONY: source-test conformance clean

source-test:
	racket compiler/expand-tests.rkt

# Requires a configured Oberon-07 toolchain, Factor language runtime, NASM,
# and a FORGE_FACTOR_RUN adapter that executes a supplied canonical IR file.
conformance:
	./tests/scripts/run-conformance.sh

clean:
	rm -f module.fir module.asm module.o module-native
