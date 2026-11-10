Copyright (C) 2026 ERRANT DIGITAL INSTITUTE OF TECHNOLOGY (SEIT NGO) % SNAPKITTY COLLECTIVE
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Commercial
// See LICENSE-AGPL and LICENSE-COMMERCIAL in this repository for license terms.

USING: kernel math math.parser parser sequences splitting strings ;

IN: forge.ir.reader

TUPLE: forge-instruction opcode operands ;
TUPLE: forge-function id argument-count register-count instructions ;
TUPLE: forge-module id functions ;

: ir-fail ( message -- * )
    throw ;

:: canonical-int ( token -- n )
    token parse-number :> value
    value integer? [
        token value number>string =
        [ value ]
        [ "non-canonical integer field" ir-fail ]
        if
    ] [
        "integer field required" ir-fail
    ] if ;

:: require-arity ( operands expected opcode -- )
    operands length expected =
    [ ] [
        opcode " has incorrect operand count" append ir-fail
    ] if ;

:: require-register ( register register-count -- )
    register 0 >=
    register register-count < and
    [ ] [
        "register index outside declared range" ir-fail
    ] if ;

:: validate-register-operands ( operands register-count -- )
    operands [| register |
        register register-count require-register
    ] each ;

:: parse-ir-instruction ( line register-count -- instruction )
    line split-words :> fields

    fields empty? [
        "empty instruction record" ir-fail
    ] when

    fields first :> opcode
    fields rest [ canonical-int ] map :> operands

    line fields join-words =
    [ ] [
        "instruction is not canonically spaced" ir-fail
    ] if

    opcode {
        { "CONST" [
            operands 2 "CONST" require-arity
            operands first register-count require-register
            operands second integer?
            [ ] [ "CONST immediate must be an integer" ir-fail ] if
        ] }
        { "MOVE" [
            operands 2 "MOVE" require-arity
            operands register-count validate-register-operands
        ] }
        { "ADD" [
            operands 3 "ADD" require-arity
            operands register-count validate-register-operands
        ] }
        { "SUB" [
            operands 3 "SUB" require-arity
            operands register-count validate-register-operands
        ] }
        { "MUL" [
            operands 3 "MUL" require-arity
            operands register-count validate-register-operands
        ] }
        { "RETURN" [
            operands 1 "RETURN" require-arity
            operands register-count validate-register-operands
        ] }
        [ "unknown FORGE-IR opcode" ir-fail ]
    } case

    opcode operands forge-instruction boa ;
```
