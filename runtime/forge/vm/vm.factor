Copyright (C) 2026 ERRANT DIGITAL INSTITUTE OF TECHNOLOGY (SEIT NGO) % SNAPKITTY COLLECTIVE
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Commercial
// See LICENSE-AGPL and LICENSE-COMMERCIAL in this repository for license terms.


USING: accessors assocs combinators kernel locals math
       sequences vectors hashtables ;

IN: forge.vm

! ------------------------------------------------------------
! CANONICAL OPCODES
! ------------------------------------------------------------

CONSTANT: OP-CONST 0
CONSTANT: OP-ADD 1
CONSTANT: OP-SUB 2
CONSTANT: OP-MUL 3
CONSTANT: OP-DIV 4
CONSTANT: OP-MOD 5
CONSTANT: OP-MOVE 6
CONSTANT: OP-PUSH 7
CONSTANT: OP-POP 8
CONSTANT: OP-DUP 9
CONSTANT: OP-DROP 10
CONSTANT: OP-SWAP 11
CONSTANT: OP-OVER 12
CONSTANT: OP-COMPARE 13
CONSTANT: OP-JUMP 14
CONSTANT: OP-JUMP-ZERO 15
CONSTANT: OP-JUMP-NONZERO 16
CONSTANT: OP-ALLOC 17
CONSTANT: OP-FREE 18
CONSTANT: OP-LOAD 19
CONSTANT: OP-STORE 20
CONSTANT: OP-CALL 21
CONSTANT: OP-RETURN 22
CONSTANT: OP-HALT 23
CONSTANT: OP-AND 24
CONSTANT: OP-OR 25
CONSTANT: OP-XOR 26
CONSTANT: OP-NOT 27
CONSTANT: OP-SHL 28
CONSTANT: OP-SHR 29
CONSTANT: OP-COLLECT 30

CONSTANT: MAX-STACK 65536
CONSTANT: MAX-REGISTERS 256
CONSTANT: MAX-FRAMES 4096
CONSTANT: MAX-INSTRUCTIONS 10000000

! ------------------------------------------------------------
! CANONICAL IR INSTRUCTION
! ------------------------------------------------------------

TUPLE: forge-insn
    opcode dst a b immediate source-line ;

: <forge-insn>
    ( opcode dst a b immediate line -- insn )
    forge-insn boa ;

TUPLE: forge-function
    id name code argument-count register-count ;

: <forge-function>
    ( id name code argc registers -- fn )
    forge-function boa ;

! ------------------------------------------------------------
! EXECUTION FRAME
! ------------------------------------------------------------

TUPLE: forge-frame
    function pc registers ;

: <forge-frame> ( fn -- frame )
    forge-frame new
        swap >>function
        0 >>pc
        0 >>registers
        drop ;

:: initialize-frame ( fn -- frame )
    forge-frame new
        fn >>function
        0 >>pc
        fn register-count>> [ 0 ] replicate >vector >>registers ;

! ------------------------------------------------------------
! TYPE DESCRIPTORS AND HEAP OBJECTS
! ------------------------------------------------------------

TUPLE: forge-type
    type-id size alignment field-count pointer-fields sealed ;

: <forge-type>
    ( id size alignment fields pointers -- type )
    forge-type new
        swap >>pointer-fields
        swap >>field-count
        swap >>alignment
        swap >>size
        swap >>type-id
        t >>sealed ;

TUPLE: forge-object
    object-id type-id payload marked pinned allocated ;

TUPLE: forge-heap
    types objects next-id allocated-bytes collection-count ;

: <forge-heap> ( -- heap )
    forge-heap new
        H{ } clone >>types
        H{ } clone >>objects
        1 >>next-id
        0 >>allocated-bytes
        0 >>collection-count ;

:: register-type ( type heap -- )
    type sealed>> [
        type type-id>> heap types>> at*
        [ "duplicate type identifier" throw ] [ drop ] if

        type type-id>> heap types>> set-at
    ] [
        "unsealed type descriptor" throw
    ] if ;

:: get-type ( id heap -- type )
    id heap types>> at*
    [ drop "unknown type descriptor" throw ]
    [ nip ] if ;

:: heap-allocate ( type-id heap -- object-id )
    type-id heap get-type :> type

    type field-count>> [ f ] replicate >vector :> payload

    heap next-id>> :> id

    forge-object new
        id >>object-id
        type-id >>type-id
        payload >>payload
        f >>marked
        f >>pinned
        t >>allocated
    :> object

    object id heap objects>> set-at

    id 1 + heap >>next-id drop

    type size>> heap allocated-bytes>> +
    heap >>allocated-bytes drop

    id ;

:: get-object ( id heap -- object )
    id heap objects>> at*
    [ drop "invalid object handle" throw ]
    [ nip ] if ;

:: heap-free ( id heap -- )
    id heap get-object :> object

    object allocated>> [
        object pinned>> [
            "cannot free pinned object" throw
        ] when

        f object >>allocated drop

        object type-id>> heap get-type size>>
        heap allocated-bytes>> -
        heap >>allocated-bytes drop

        id heap objects>> delete-at
    ] [
        "object already reclaimed" throw
    ] if ;

:: heap-load ( object-id field heap -- value )
    object-id heap get-object :> object
    object payload>> :> payload

    field 0 < field payload length >= or [
        "field index outside object" throw
    ] when

    field payload nth ;

:: heap-store ( value object-id field heap -- )
    object-id heap get-object :> object
    object payload>> :> payload

    field 0 < field payload length >= or [
        "field index outside object" throw
    ] when

    value field payload set-nth ;

! ------------------------------------------------------------
! VM STATE
! ------------------------------------------------------------

TUPLE: forge-vm
    data return-stack frames functions heap roots
    halted steps limit result ;

: <forge-vm> ( -- vm )
    forge-vm new
        V{ } clone >>data
        V{ } clone >>return-stack
        V{ } clone >>frames
        H{ } clone >>functions
        <forge-heap> >>heap
        V{ } clone >>roots
        f >>halted
        0 >>steps
        MAX-INSTRUCTIONS >>limit
        f >>result ;

! ------------------------------------------------------------
! DATA STACK
! ------------------------------------------------------------

:: push-data ( value vm -- )
    vm data>> length MAX-STACK >= [
        "data stack overflow" throw
    ] when

    value vm data>> push ;

:: pop-data ( vm -- value )
    vm data>> empty? [
        "data stack underflow" throw
    ] when

    vm data>> pop ;

:: peek-data ( vm -- value )
    vm data>> empty? [
        "data stack underflow" throw
    ] when

    vm data>> last ;

:: dup-data ( vm -- )
    vm peek-data vm push-data ;

:: drop-data ( vm -- )
    vm pop-data drop ;

:: swap-data ( vm -- )
    vm pop-data :> a
    vm pop-data :> b
    a vm push-data
    b vm push-data ;

:: over-data ( vm -- )
    vm data>> length 2 < [
        "OVER requires two values" throw
    ] when

    vm data>> second vm push-data ;

! ------------------------------------------------------------
! REGISTERS
! ------------------------------------------------------------

:: register-get ( index frame -- value )
    index 0 < index frame registers>> length >= or [
        "invalid register read" throw
    ] when

    index frame registers>> nth ;

:: register-set ( value index frame -- )
    index 0 < index frame registers>> length >= or [
        "invalid register write" throw
    ] when

    value index frame registers>> set-nth ;

! ------------------------------------------------------------
! FUNCTION REGISTRY
! ------------------------------------------------------------

:: register-function ( fn vm -- )
    fn id>> vm functions>> at*
    [ "duplicate function ID" throw ] [ drop ] if

    fn id>> vm functions>> set-at ;

:: get-function ( id vm -- fn )
    id vm functions>> at*
    [ drop "unknown function ID" throw ]
    [ nip ] if ;

:: current-frame ( vm -- frame )
    vm frames>> empty? [
        "no active execution frame" throw
    ] when

    vm frames>> last ;

:: push-frame ( frame vm -- )
    vm frames>> length MAX-FRAMES >= [
        "call frame limit exceeded" throw
    ] when

    frame vm frames>> push ;

:: pop-frame ( vm -- frame )
    vm frames>> empty? [
        "return without active frame" throw
    ] when

    vm frames>> pop ;

! ------------------------------------------------------------
! CALL AND RETURN
! ------------------------------------------------------------

:: call-function ( function-id vm -- )
    function-id vm get-function :> fn

    fn initialize-frame :> frame

    fn argument-count>> [
        vm pop-data
    ] replicate reverse :> arguments

    arguments length fn register-count>> > [
        "function arguments exceed register file" throw
    ] when

    arguments [
        :> argument
        arguments index :> unused
        unused drop
    ] each

    arguments [
        :> argument
        arguments index drop
    ] each

    arguments length 0 > [
        arguments length [
            :> i
            arguments i nth
            i frame register-set
        ] each-integer
    ] when

    frame vm push-frame ;

:: return-function ( register vm -- )
    vm current-frame :> frame

    register -1 > [
        register frame register-get
        vm >>result drop
    ] when

    vm pop-frame drop

    vm frames>> empty? [
        t vm >>halted drop
    ] when ;

! ------------------------------------------------------------
! INSTRUCTION VALIDATION
! ------------------------------------------------------------

:: valid-register? ( index frame -- ? )
    index integer?
    index 0 >= and
    index frame registers>> length < and ;

:: valid-instruction? ( ins frame -- ? )
    ins opcode>> {
        OP-CONST OP-ADD OP-SUB OP-MUL OP-DIV OP-MOD
        OP-MOVE OP-PUSH OP-POP OP-DUP OP-DROP OP-SWAP
        OP-OVER OP-COMPARE OP-JUMP OP-JUMP-ZERO
        OP-JUMP-NONZERO OP-ALLOC OP-FREE OP-LOAD
        OP-STORE OP-CALL OP-RETURN OP-HALT OP-AND
        OP-OR OP-XOR OP-NOT OP-SHL OP-SHR OP-COLLECT
    } member? ;

! ------------------------------------------------------------
! BINARY REGISTER OPERATIONS
! ------------------------------------------------------------

:: binary-register-op ( ins frame operation -- )
    ins a>> frame register-get :> lhs
    ins b>> frame register-get :> rhs

    lhs rhs operation call
    ins dst>> frame register-set ;

:: add-op ( ins frame -- )
    [ + ] binary-register-op ;

:: sub-op ( ins frame -- )
    [ - ] binary-register-op ;

:: mul-op ( ins frame -- )
    [ * ] binary-register-op ;

:: div-op ( ins frame -- )
    ins b>> frame register-get zero? [
        "division by zero" throw
    ] when

    [ /i ] binary-register-op ;

:: mod-op ( ins frame -- )
    ins b>> frame register-get zero? [
        "modulo by zero" throw
    ] when

    [ mod ] binary-register-op ;

:: compare-op ( ins frame -- )
    ins a>> frame register-get
    ins b>> frame register-get
    = ins dst>> frame register-set ;

! ------------------------------------------------------------
! MEMORY OPERATIONS
! ------------------------------------------------------------

:: alloc-op ( ins frame vm -- )
    ins immediate>> vm heap>> heap-allocate
    ins dst>> frame register-set ;

:: free-op ( ins frame vm -- )
    ins a>> frame register-get
    vm heap>> heap-free ;

:: load-op ( ins frame vm -- )
    ins a>> frame register-get
    ins immediate>> vm heap>> heap-load
    ins dst>> frame register-set ;

:: store-op ( ins frame vm -- )
    ins b>> frame register-get
    ins a>> frame register-get
    ins immediate>> vm heap>> heap-store ;

! ------------------------------------------------------------
! CONTROL FLOW
! ------------------------------------------------------------

:: jump-to ( target frame -- )
    target 0 < target frame function>> code>> length >= or [
        "invalid branch target" throw
    ] when

    target frame >>pc drop ;

:: jump-op ( ins frame -- )
    ins immediate>> frame jump-to ;

:: jump-zero-op ( ins frame -- )
    ins a>> frame register-get zero? [
        ins immediate>> frame jump-to
    ] when ;

:: jump-nonzero-op ( ins frame -- )
    ins a>> frame register-get zero? not [
        ins immediate>> frame jump-to
    ] when ;

! ------------------------------------------------------------
! BITWISE OPERATIONS
! ------------------------------------------------------------

:: bitwise-op ( ins frame operation -- )
    ins a>> frame register-get :> lhs
    ins b>> frame register-get :> rhs

    lhs rhs operation call
    ins dst>> frame register-set ;

! ------------------------------------------------------------
! COMPLETE OPCODE DISPATCH
! ------------------------------------------------------------

:: execute-instruction ( ins vm -- )
    vm current-frame :> frame

    ins frame valid-instruction? [
        "invalid opcode" throw
    ] unless

    ins opcode>> {
        { OP-CONST [
            ins immediate>> ins dst>> frame register-set
        ] }

        { OP-ADD [ ins frame add-op ] }
        { OP-SUB [ ins frame sub-op ] }
        { OP-MUL [ ins frame mul-op ] }
        { OP-DIV [ ins frame div-op ] }
        { OP-MOD [ ins frame mod-op ] }

        { OP-MOVE [
            ins a>> frame register-get
            ins dst>> frame register-set
        ] }

        { OP-PUSH [
            ins a>> frame register-get vm push-data
        ] }

        { OP-POP [
            vm pop-data ins dst>> frame register-set
        ] }

        { OP-DUP [ vm dup-data ] }
        { OP-DROP [ vm drop-data ] }
        { OP-SWAP [ vm swap-data ] }
        { OP-OVER [ vm over-data ] }

        { OP-COMPARE [ ins frame compare-op ] }

        { OP-JUMP [ ins frame jump-op ] }
        { OP-JUMP-ZERO [ ins frame jump-zero-op ] }
        { OP-JUMP-NONZERO [ ins frame jump-nonzero-op ] }

        { OP-ALLOC [ ins frame vm alloc-op ] }
        { OP-FREE [ ins frame vm free-op ] }
        { OP-LOAD [ ins frame vm load-op ] }
        { OP-STORE [ ins frame vm store-op ] }

        { OP-CALL [
            ins immediate>> vm call-function
        ] }

        { OP-RETURN [
            ins a>> vm return-function
        ] }

        { OP-HALT [
            t vm >>halted drop
        ] }

        { OP-AND [
            [ bitand ] ins frame bitwise-op
        ] }

        { OP-OR [
            [ bitor ] ins frame bitwise-op
        ] }

        { OP-XOR [
            [ bitxor ] ins frame bitwise-op
        ] }

        { OP-NOT [
            ins a>> frame register-get
            bitnot ins dst>> frame register-set
        ] }

        { OP-SHL [
            ins a>> frame register-get
            ins b>> frame register-get shift
            ins dst>> frame register-set
        ] }

        { OP-SHR [
            ins a>> frame register-get
            ins b>> frame register-get neg shift
            ins dst>> frame register-set
        ] }

        { OP-COLLECT [
            vm collect-heap
        ] }
    } case ;

! ------------------------------------------------------------
! EXECUTION ENGINE
! ------------------------------------------------------------

:: current-instruction ( frame -- ins )
    frame pc>> frame function>> code>> nth ;

:: advance-pc ( frame -- )
    frame pc>> 1 + frame >>pc drop ;

:: vm-step ( vm -- )
    vm halted>> [
        "execution after HALT" throw
    ] when

    vm steps>> vm limit>> >= [
        "instruction budget exceeded" throw
    ] when

    vm current-frame :> frame
    frame current-instruction :> ins

    frame advance-pc

    ins vm execute-instruction

    vm steps>> 1 + vm >>steps drop ;

:: vm-run ( vm -- vm )
    [
        vm halted>> not
        vm frames>> empty? not
        and
    ] [
        vm vm-step
    ] while

    vm ;

:: vm-start ( function-id vm -- vm )
    function-id vm get-function
    initialize-frame vm push-frame

    vm vm-run ;

! ------------------------------------------------------------
! ROOT MANAGEMENT
! ------------------------------------------------------------

:: register-root ( object-id vm -- )
    object-id vm heap>> objects>> at*
    [ drop "invalid root object" throw ] unless*

    object-id vm roots>> push ;

:: unregister-root ( object-id vm -- )
    object-id vm roots>>
    [ object-id = not ] filter
    vm >>roots drop ;

! ------------------------------------------------------------
! PRECISE MARK AND SWEEP
! ------------------------------------------------------------

:: collect-heap ( vm -- )
    vm heap>> :> heap
    V{ } clone :> worklist
    H{ } clone :> marked

    vm roots>> [ worklist push ] each

    [
        worklist empty? not
    ] [
        worklist pop :> object-id

        marked object-id at* [
            drop
        ] [
            t object-id marked set-at

            object-id heap objects>> at* [
                nip :> object

                object allocated>> [
                    object type-id>> heap get-type
                    pointer-fields>> :> fields

                    fields [
                        :> field
                        object payload>> field nth
                        dup integer? [
                            worklist push
                        ] [
                            drop
                        ] if
                    ] each
                ] when
            ] [
                drop
            ] if
        ] if
    ] while

    heap objects>> keys [
        :> object-id
        object-id marked at* [
            drop
        ] [
            object-id heap heap-free
        ] if
    ] each

    heap collection-count>> 1 +
    heap >>collection-count drop ;

END
