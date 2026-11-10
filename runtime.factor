Copyright (C) 2026 ERRANT DIGITAL INSTITUTE OF TECHNOLOGY (SEIT NGO) % SNAPKITTY COLLECTIVE
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Commercial
// See LICENSE-AGPL and LICENSE-COMMERCIAL in this repository for license terms.

USING: kernel math math.order sequences vectors arrays
       hashtables assocs namespaces combinators accessors
       io io.encodings.utf8 io.files ;


IN: forge.runtime

! ============================================================
! FORGE VIRTUAL MACHINE
! ============================================================

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

CONSTANT: MAX-REGISTERS 256
CONSTANT: MAX-STACK 65536
CONSTANT: MAX-HEAP-OBJECTS 65536
CONSTANT: MAX-FUNCTIONS 4096

! ============================================================
! INSTRUCTION MODEL
! ============================================================

TUPLE: instruction
    opcode
    dst
    a
    b
    immediate
    source-line ;

: <instruction> ( opcode dst a b immediate line -- ins )
    instruction boa ;

! ============================================================
! FUNCTION MODEL
! ============================================================

TUPLE: forge-function
    name
    code
    argument-count
    register-count
    return-type ;

: <forge-function> ( name code args regs return -- fn )
    forge-function boa ;

! ============================================================
! EXECUTION FRAME
! ============================================================

TUPLE: call-frame
    function
    pc
    registers ;

: <call-frame> ( fn -- frame )
    call-frame new
        swap >>function
        0 >>pc
        H{ } clone >>registers ;

! ============================================================
! TYPED OBJECT MODEL
! ============================================================

TUPLE: type-descriptor
    type-id
    object-size
    alignment
    fields
    pointer-fields
    sealed ;

: <type-descriptor> ( id size alignment fields pointers -- td )
    type-descriptor new
        swap >>pointer-fields
        swap >>fields
        swap >>alignment
        swap >>object-size
        swap >>type-id
        t >>sealed ;

TUPLE: heap-object
    object-id
    type-id
    size
    payload
    generation
    marked
    pinned
    allocated ;

: <heap-object> ( id type size payload -- object )
    heap-object new
        swap >>payload
        swap >>size
        swap >>type-id
        swap >>object-id
        0 >>generation
        f >>marked
        f >>pinned
        t >>allocated ;

! ============================================================
! HEAP REGISTRY
! ============================================================

TUPLE: typed-heap
    descriptors
    objects
    roots
    next-object-id
    allocated-bytes
    collection-count ;

: <typed-heap> ( -- heap )
    typed-heap new
        H{ } clone >>descriptors
        H{ } clone >>objects
        V{ } clone >>roots
        1 >>next-object-id
        0 >>allocated-bytes
        0 >>collection-count ;

:: register-type ( descriptor heap -- )
    descriptor sealed>> [
        descriptor type-id>> heap descriptors>> at*
        [ "duplicate type identifier" throw ] [ drop ] if
        descriptor type-id>>
        heap descriptors>>
        set-at
    ] [
        "unsealed type descriptor" throw
    ] if ;

:: descriptor-valid? ( type-id heap -- ? )
    type-id heap descriptors>> at*
    [ drop f ]
    [ nip sealed>> ]
    if ;

:: register-object ( object heap -- )
    object object-id>> heap objects>> at*
    [ "duplicate object identifier" throw ]
    [ drop ] if

    object object-id>>
    heap objects>>
    set-at ;

:: heap-allocate ( type-id size payload heap -- object )
    type-id heap descriptor-valid?
    [ ] [ "invalid allocation type" throw ] if

    size 0 <=
    [ "invalid allocation size" throw ] when

    heap next-object-id>> :> id

    id type-id size payload <heap-object> :> object

    object heap register-object

    id 1 + heap >>next-object-id drop

    heap allocated-bytes>> size + heap >>allocated-bytes drop

    object ;

:: heap-object-at ( id heap -- object/f )
    id heap objects>> at ;

:: heap-free ( id heap -- )
    id heap heap-object-at :> object

    object [
        object allocated>> [
            object pinned>>
            [ "cannot free pinned object" throw ] when

            f object >>allocated drop
            object size>> heap allocated-bytes>>
            - heap >>allocated-bytes drop
        ] [
            "double reclamation" throw
        ] if
    ] [
        "unknown object handle" throw
    ] if ;

:: register-root ( id heap -- )
    id heap heap-object-at
    [ "invalid root handle" throw ] unless*
    id heap roots>> push ;

:: unregister-root ( id heap -- )
    id heap roots>>
    [ id = not ] filter
    heap >>roots drop ;

! ============================================================
! VIRTUAL MACHINE STATE
! ============================================================

TUPLE: forge-vm
    data
    return-stack
    frames
    functions
    heap
    halted
    error
    instruction-count
    maximum-instructions ;

: <forge-vm> ( -- vm )
    forge-vm new
        V{ } clone >>data
        V{ } clone >>return-stack
        V{ } clone >>frames
        H{ } clone >>functions
        <typed-heap> >>heap
        f >>halted
        f >>error
        0 >>instruction-count
        10000000 >>maximum-instructions ;

! ============================================================
! DATA STACK
! ============================================================

:: ds-push ( value vm -- )
    vm data>> length MAX-STACK >=
    [ "data stack overflow" throw ] when

    value vm data>> push ;

:: ds-pop ( vm -- value )
    vm data>> empty?
    [ "data stack underflow" throw ] when

    vm data>> pop ;

:: ds-peek ( vm -- value )
    vm data>> empty?
    [ "data stack underflow" throw ] when

    vm data>> last ;

:: ds-depth ( vm -- n )
    vm data>> length ;

:: ds-dup ( vm -- )
    vm ds-peek vm ds-push ;

:: ds-drop ( vm -- )
    vm ds-pop drop ;

:: ds-swap ( vm -- )
    vm ds-pop :> a
    vm ds-pop :> b
    a vm ds-push
    b vm ds-push ;

:: ds-over ( vm -- )
    vm ds-depth 2 <
    [ "over requires two values" throw ] when

    vm data>> second
    vm ds-push ;

! ============================================================
! REGISTER FILE
! ============================================================

:: register-get ( id frame -- value )
    id frame registers>> at*
    [ drop "undefined virtual register" throw ]
    [ nip ]
    if ;

:: register-set ( value id frame -- )
    value id frame registers>> set-at ;

:: register-valid? ( id fn -- ? )
    id integer?
    id 0 >= and
    id fn register-count>> < and ;

! ============================================================
! FRAME MANAGEMENT
! ============================================================

:: register-function ( fn vm -- )
    fn name>> vm functions>> at*
    [ "duplicate function name" throw ] [ drop ] if

    fn name>> vm functions>>
    set-at ;

:: function-get ( name vm -- fn )
    name vm functions>> at*
    [ drop "unknown function" throw ]
    [ nip ]
    if ;

:: frame-push ( fn vm -- )
    fn <call-frame> vm frames>> push ;

:: current-frame ( vm -- frame )
    vm frames>> empty?
    [ "no active execution frame" throw ] when

    vm frames>> last ;

:: frame-pop ( vm -- frame )
    vm frames>> empty?
    [ "call stack underflow" throw ] when

    vm frames>> pop ;

! ============================================================
! INSTRUCTION VALIDATION
! ============================================================

:: instruction-valid? ( ins fn -- ? )
    ins opcode>> :> op

    ins dst>> :> dst
    ins a>> :> a
    ins b>> :> b

    {
        OP-CONST
        OP-ADD
        OP-SUB
        OP-MUL
        OP-DIV
        OP-MOD
        OP-MOVE
        OP-COMPARE
        OP-ALLOC
        OP-LOAD
        OP-STORE
    } member? :> known-op

    op OP-PUSH =
    op OP-POP =
    op OP-DUP =
    op OP-DROP =
    op OP-SWAP =
    op OP-OVER =
    op OP-JUMP =
    op OP-JUMP-ZERO =
    op OP-JUMP-NONZERO =
    op OP-CALL =
    op OP-RETURN =
    op OP-HALT =
    op OP-FREE =
    op OP-AND =
    op OP-OR =
    op OP-XOR =
    op OP-NOT =
    op OP-SHL =
    op OP-SHR =

    or or or or or or or or or or or or or or or or or or
    or or or or or or or or :> supported

    known-op supported or [
        t
    ] [
        f
    ] if ;

! ============================================================
! ARITHMETIC
! ============================================================

:: arithmetic-binary ( op vm -- value )
    vm ds-pop :> rhs
    vm ds-pop :> lhs

    op OP-ADD = [ lhs rhs + ]
    [ op OP-SUB = [ lhs rhs - ]
      [ op OP-MUL = [ lhs rhs * ]
        [ op OP-DIV = [
            rhs 0 = [ "division by zero" throw ] when
            lhs rhs /i
          ] [
            op OP-MOD = [
                rhs 0 = [ "modulo by zero" throw ] when
                lhs rhs mod
            ] [ 0 ] if
          ] if
        ] if
      ] if
    ] if ;

:: bitwise-binary ( op vm -- value )
    vm ds-pop :> rhs
    vm ds-pop :> lhs

    op OP-AND = [ lhs rhs bitand ]
    [ op OP-OR = [ lhs rhs bitor ]
      [ op OP-XOR = [ lhs rhs bitxor ]
        [ op OP-SHL = [ lhs rhs shift ]
          [ op OP-SHR = [ lhs rhs neg shift ] if ]
        if ]
      if ]
    if ;

! ============================================================
! CONTROL FLOW
! ============================================================

:: set-pc ( target frame -- )
    target frame >>pc drop ;

:: jump-target-valid? ( target fn -- ? )
    target integer?
    target 0 >= and
    target fn code>> length < and ;

:: execute-jump ( target frame -- )
    target frame function>> jump-target-valid?
    [ target frame set-pc ]
    [ "invalid jump target" throw ] if ;

! ============================================================
! CORE INSTRUCTION EXECUTION
! ============================================================

:: execute-instruction ( ins vm -- )
    vm current-frame :> frame
    frame function>> :> fn

    ins fn instruction-valid?
    [ ] [ "invalid instruction" throw ] if

    ins opcode>> :> op

    op OP-CONST = [
        ins immediate>> ins dst>> frame register-set
    ] [
    op OP-MOVE = [
        ins a>> frame register-get
        ins dst>> frame register-set
    ] [
    op OP-PUSH = [
        ins a>> frame register-get vm ds-push
    ] [
    op OP-POP = [
        vm ds-pop ins dst>> frame register-set
    ] [
    op OP-DUP = [ vm ds-dup ] [
    op OP-DROP = [ vm ds-drop ] [
    op OP-SWAP = [ vm ds-swap ] [
    op OP-OVER = [ vm ds-over ] [
    op OP-ADD = [
        op vm arithmetic-binary
        ins dst>> frame register-set
    ] [
    op OP-SUB = [
        op vm arithmetic-binary
        ins dst>> frame register-set
    ] [
    op OP-MUL = [
        op vm arithmetic-binary
        ins dst>> frame register-set
    ] [
    op OP-DIV = [
        op vm arithmetic-binary
        ins dst>> frame register-set
    ] [
    op OP-MOD = [
        op vm arithmetic-binary
        ins dst>> frame register-set
    ] [
    op OP-AND = [
        op vm bitwise-binary
        vm ds-push
    ] [
    op OP-OR = [
        op vm bitwise-binary
        vm ds-push
    ] [
    op OP-XOR = [
        op vm bitwise-binary
        vm ds-push
    ] [
    op OP-SHL = [
        op vm bitwise-binary
        vm ds-push
    ] [
    op OP-SHR = [
        op vm bitwise-binary
        vm ds-push
    ] [
    op OP-NOT = [
        vm ds-pop
        bitnot
        vm ds-push
    ] [
    op OP-COMPARE = [
        ins a>> frame register-get :> lhs
        ins b>> frame register-get :> rhs
        lhs rhs =
        ins dst>> frame register-set
    ] [
    op OP-JUMP = [
        ins immediate>> frame execute-jump
    ] [
    op OP-JUMP-ZERO = [
        vm ds-pop zero?
        [ ins immediate>> frame execute-jump ]
        [ ] if
    ] [
    op OP-JUMP-NONZERO = [
        vm ds-pop zero?
        [ ] [ ins immediate>> frame execute-jump ] if
    ] [
    op OP-HALT = [
        t vm >>halted drop
    ] [
        "unsupported instruction" throw
    ] if ] ] ] ] ] ] ] ] ] ] ] ] ] ] ] ] ] ] ] ] ] ] ] ] ] ] ;

! ============================================================
! INSTRUCTION POINTER
! ============================================================

:: current-instruction ( frame -- ins )
    frame pc>> :> pc
    frame function>> code>> :> code

    pc 0 <
    pc code length >= or
    [ "program counter outside function" throw ] when

    code pc nth ;

:: advance-pc ( frame -- )
    frame pc>> 1 + frame >>pc drop ;

:: vm-step ( vm -- )
    vm halted>> [ "machine already halted" throw ] when

    vm instruction-count>> vm maximum-instructions>> >=
    [ "instruction budget exceeded" throw ] when

    vm current-frame :> frame
    frame current-instruction :> ins

    ins vm execute-instruction

    ins opcode>> OP-JUMP =
    [ ]
    [ frame advance-pc ] if

    1 vm instruction-count>> + vm >>instruction-count drop ;

! ============================================================
! PROGRAM EXECUTION
! ============================================================

:: vm-run ( vm -- vm )
    [ vm halted>> not ]
    [ vm vm-step ] while

    vm ;

:: vm-start ( name vm -- vm )
    name vm function-get :> fn

    vm frames>> empty?
    [ fn vm frame-push ]
    [ "machine already has an active frame" throw ] if

    vm vm-run ;

! ============================================================
! QUOTATION EXECUTION
! ============================================================

TUPLE: quotation
    instructions
    input-depth
    output-depth ;

: <quotation> ( instructions in out -- quotation )
    quotation boa ;

:: quotation-execute ( q vm -- )
    q input-depth>> vm ds-depth <
    [ "quotation input underflow" throw ] when

    q instructions>> [
        vm swap execute-instruction
    ] each

    q output-depth>> vm ds-depth = not
    [ "quotation stack effect violation" throw ] when ;

! ============================================================
! FACTOR-STYLE COMBINATORS
! ============================================================

:: combinator-apply ( q vm -- )
    q vm quotation-execute ;

:: combinator-times ( n q vm -- )
    n 0 < [ "negative repetition count" throw ] when

    n [
        q vm combinator-apply
    ] times ;

:: combinator-when ( condition q vm -- )
    condition [
        q vm combinator-apply
    ] when ;

:: combinator-unless ( condition q vm -- )
    condition [
        f
    ] unless
    q vm combinator-apply ;

! ============================================================
! FUNCTION RETURN
! ============================================================

:: vm-return ( vm -- )
    vm frame-pop drop

    vm frames>> empty?
    [ t vm >>halted drop ] when ;

! ============================================================
! DIAGNOSTICS
! ============================================================

:: vm-fail ( message vm -- )
    message vm >>error drop
    t vm >>halted drop ;

:: vm-valid? ( vm -- ? )
    vm data>> length MAX-STACK <=
    vm frames>> length MAX-FUNCTIONS <= and
    vm functions>> length MAX-FUNCTIONS <= and ;

! ============================================================
! RUNTIME ENTRY POINT
! ============================================================

: forge-runtime-version ( -- string )
    "FORGE FACTOR RUNTIME 0.1.0" ;

: forge-runtime-ready? ( -- ? )
    t ;

MAIN: forge-runtime-version print

Good. Here are the four pieces, as real code. I'll flag where ATS incantations may need a round of tuning under your actual ATS2 version, but the structure and type boundaries are what matter.

---

forge_gc.sats — interface

```ats
#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"

datatype field_kind =
  | FKInt | FKFloat | FKPtr
  | FKStruct of int
  | FKArray of (int, field_kind)

datatype field_layout (n:int) =
  | {off,sz:int | off >= 0; sz > 0; off + sz <= n}
    FL (kind: field_kind, off: int off, sz: int sz)

typedef align_t = [a:int | a > 0] int a

datatype ty_descriptor (n:int) =
  | TyDescr (tid: int,
             sz: int n,
             al: align_t,
             flds: list0 (field_layout n),
             pmap: uint64)

datavtype live_obj (a:t@ype, n:int) =
  | {l:addr} LiveObj of (ptr l, a @ l)

abstype mark_state = ptr
abstype sweep_state = ptr

(* --- Descriptor builder --- *)
fun build_descriptor
  {n:int | n > 0}
  (tid: int, al: align_t, flds: list0 (field_layout n))
  :<> ty_descriptor n

(* --- Allocation --- *)
fun gc_alloc
  {a:t@ype}{n:int | n > 0}
  (d: ty_descriptor n, v: a):<> live_obj (a, n)

fun gc_free
  {a:t@ype}{n:int}
  (o: live_obj (a, n)):<> void

(* --- Mark --- *)
fun mark_init ():<> mark_state
fun mark_root {a:t@ype}{n:int}
                  (ms: mark_state, o: live_obj (a, n)):<> void
fun mark_traverse {n:int | n > 0}
                  (ms: mark_state, base: ptr, d: ty_descriptor n):<> void
fun mark_drain (ms: mark_state):<> void
fun mark_finish (ms: mark_state):<> void

(* --- Sweep --- *)
fun sweep_init (ms: mark_state):<> sweep_state
fun sweep_step (ss: sweep_state):<> bool
fun sweep_finish (ss: sweep_state):<> int
```

---

forge_gc.dats — builder, allocation, traversal

```ats
#include "forge_gc.sats"

(* ============================================================
   Runtime FFI
   ============================================================ *)

extern fun gc_is_null (p: ptr):<> bool = "forge_gc_is_null"

extern fun gc_read_ptr_at (base: ptr, off: size_t):<> ptr
  = "forge_gc_read_ptr_at"

extern fun gc_wl_push (ms: mark_state, p: ptr):<> void
  = "forge_gc_wl_push"

extern fun gc_desc_new
  (tid: int, sz: int, al: int, nfields: int, pmap: uint64):<> ptr
  = "forge_gc_desc_new"

extern fun gc_desc_add_field
  (h: ptr, kind: int, elem_kind: int, count: int,
   off: int, sz: int):<> void
  = "forge_gc_desc_add_field"

extern fun gc_register_object (obj: ptr, desc: ptr):<> void
  = "forge_gc_register_object"

extern fun gc_unregister_object (obj: ptr):<> void
  = "forge_gc_unregister_object"

extern fun gc_lshift64 (x: uint64, n: uint):<> uint64
  = "forge_gc_lshift64"

(* ============================================================
   Descriptor builder
   ============================================================ *)

fn fk_code (k: field_kind):<> int =
  case+ k of
  | FKInt => 0
  | FKFloat => 1
  | FKPtr => 2
  | FKStruct _ => 3
  | FKArray _ => 4

fn fk_elem_code (k: field_kind):<> int =
  case+ k of
  | FKArray (_, ek) => fk_code ek
  | _ => 0

fn fk_count (k: field_kind):<> int =
  case+ k of
  | FKArray (c, _) => c
  | _ => 0

fn fk_carries_ptrs (k: field_kind):<> bool =
  case+ k of
  | FKPtr => true
  | FKArray (_, ek) => fk_carries_ptrs ek
  | _ => false

fn compute_pmap_aux {n:int}
  (flds: list0 (field_layout n), idx: uint, acc: uint64):<> uint64 =
  case+ flds of
  | list0_nil () => acc
  | list0_cons (f, rest) =>
      let
        val bit =
          case+ f of FL (k, _, _) => if fk_carries_ptrs k then 1u64 else 0u64
        val acc' = if idx < 64u then acc lor (gc_lshift64 (bit, idx)) else acc
      in
        compute_pmap_aux (rest, idx + 1u, acc')
      end

fn compute_pmap {n:int} (flds: list0 (field_layout n)):<> uint64 =
  compute_pmap_aux (flds, 0u, 0u64)

fn register_descriptor_fields {n:int}
  (h: ptr, flds: list0 (field_layout n)):<> void =
  case+ flds of
  | list0_nil () => ()
  | list0_cons (f, rest) =>
      let
        val () = case+ f of
          | FL (k, off, sz) =>
              gc_desc_add_field
                (h, fk_code k, fk_elem_code k, fk_count k, off, sz)
      in
        register_descriptor_fields (h, rest)
      end

implement build_descriptor {n} (tid, al, flds) = let
  val pmap = compute_pmap (flds)
  val d = TyDescr (tid, n, al, flds, pmap)
  val h = gc_desc_new (tid, n, al, list0_length (flds), pmap)
  val () = register_descriptor_fields (h, flds)
in
  d
end

(* ============================================================
   Allocation
   ============================================================ *)

extern fun gc_desc_handle_of {n:int | n > 0}
  (d: ty_descriptor n):<> ptr = "forge_gc_lookup_desc_by_tid"

implement gc_alloc {a}{n} (d, v) = let
  val (p, pf) = ptr_alloc<a> ()
  val () = !pf := v
  val h = gc_desc_handle_of (d)
  val () = gc_register_object (p, h)
in
  LiveObj (p, pf)
end

implement gc_free (o) =
  case+ o of LiveObj (p, pf) => let
    val () = gc_unregister_object (p)
    val () = ptr_free (p, pf)
  in () end

(* ============================================================
   Mark: single-object traversal
   ============================================================ *)

fn traverse_field {n:int | n > 0}
  (ms: mark_state, base: ptr, f: field_layout n):<> void =
  case+ f of
  | FL (k, off, _) =>
      let val off = g0ofint (off): size_t in
        case+ k of
        | FKPtr => let
            val t = gc_read_ptr_at (base, off)
          in if not (gc_is_null t) then gc_wl_push (ms, t) end
        | FKArray (cnt, ek) =>
            (case+ ek of
             | FKPtr => let
                 fun loop (i: uint):<> void =
                   if i >= g0ofint cnt then ()
                   else let
                     val o = off + (g0ofsize i) * 8
                     val t = gc_read_ptr_at (base, o)
                   in
                     (if not (gc_is_null t) then gc_wl_push (ms, t));
                     loop (i + 1u)
                   end
               in loop (0u) end
             | _ => ())
        | _ => ()
      end

fn traverse_list {n:int | n > 0}
  (ms: mark_state, base: ptr, flds: list0 (field_layout n)):<> void =
  case+ flds of
  | list0_nil () => ()
  | list0_cons (f, rest) =>
      (traverse_field (ms, base, f);
       traverse_list (ms, base, rest))

implement mark_traverse {n} (ms, base, d) = let
  val TyDescr (_, _, _, flds, _) = d
in
  traverse_list (ms, base, flds)
end

(* Note: mark_drain lives in C — see runtime. It pops a pointer,
   reconstructs the ty_descriptor by castfn, and calls back into
   mark_traverse_one() exported from this module. That callback
   is where the ATS proof that "every field read is in bounds"
   attaches to the runtime. *)

(* ============================================================
   Sweep wrappers
   ============================================================ *)

extern fun gc_sweep_init (ms: mark_state):<> sweep_state
  = "forge_gc_sweep_init"

extern fun gc_sweep_step (ss: sweep_state):<> int
  = "forge_gc_sweep_step"

extern fun gc_sweep_finish (ss: sweep_state):<> int
  = "forge_gc_sweep_finish"

implement sweep_init (ms) = gc_sweep_init (ms)
implement sweep_step (ss) = gc_sweep_step (ss) <> 0
implement sweep_finish (ss) = gc_sweep_finish (ss)
```

---

forge_gc_rt.h — runtime header

```c
#ifndef FORGE_GC_RT_H
#define FORGE_GC_RT_H

#include <stdint.h>
#include <stddef.h>

typedef struct forge_gc_field {
    int32_t kind;
    int32_t elem_kind;
    int32_t count;
    int32_t _pad;
    uint64_t off;
    uint64_t sz;
} forge_gc_field;

typedef struct forge_gc_desc {
    uint64_t tid;
    uint64_t sz;
    uint64_t al;
    uint32_t nfields;
    uint32_t _pad;
    uint64_t pmap;
    forge_gc_field fields[];
} forge_gc_desc;

typedef struct forge_gc_entry {
    void *obj;
    forge_gc_desc *desc;
    uint8_t mark;
    uint8_t gen;
    struct forge_gc_entry *next;
} forge_gc_entry;

typedef struct forge_gc_wl {
    void **buf;
    size_t cap, len;
} forge_gc_wl;

/* ATS FFI */
int forge_gc_is_null (void *p);
void *forge_gc_read_ptr_at (void *base, size_t off);
void forge_gc_wl_push (forge_gc_wl *wl, void *p);
void *forge_gc_desc_new (int64_t tid, int64_t sz, int64_t al,
                                  int64_t nfields, uint64_t pmap);
void forge_gc_desc_add_field (void *h, int32_t kind, int32_t ek,
                                  int32_t cnt, int64_t off, int64_t sz);
void *forge_gc_lookup_desc_by_tid (int64_t tid);
void forge_gc_register_object (void *obj, void *desc_handle);
void forge_gc_unregister_object(void *obj);
uint64_t forge_gc_lshift64 (uint64_t x, unsigned n);

/* Runtime */
forge_gc_wl *forge_gc_wl_new (void);
void forge_gc_wl_free (forge_gc_wl *wl);

void *forge_gc_sweep_init (forge_gc_wl *wl);
int forge_gc_sweep_step (void *sweep_state);
int forge_gc_sweep_finish (void *sweep_state);

/* Callback into ATS mark_traverse after pop */
extern void forge_ats_mark_traverse_one (forge_gc_wl *wl,
                                         void *obj, void *desc);

#endif
```

---

forge_gc_rt.c — runtime

```c
#include "forge_gc_rt.h"
#include <stdlib.h>
#include <string.h>

/* ---------- tiny FFI ---------- */

int forge_gc_is_null (void *p) { return p == NULL; }

void *forge_gc_read_ptr_at (void *base, size_t off) {
    return *(void **)((char *)base + off);
}

uint64_t forge_gc_lshift64 (uint64_t x, unsigned n) {
    return n >= 64 ? 0 : (x << n);
}

void forge_gc_wl_push (forge_gc_wl *wl, void *p) {
    if (wl->len == wl->cap) {
        size_t nc = wl->cap ? wl->cap * 2 : 64;
        wl->buf = realloc(wl->buf, nc * sizeof(void *));
        wl->cap = nc;
    }
    wl->buf[wl->len++] = p;
}

/* ---------- descriptor registry (dedup by tid) ---------- */

#define DESC_TAB_SIZE 4096
static forge_gc_desc *g_desc_tab[DESC_TAB_SIZE];

static size_t desc_slot (int64_t tid) { return (size_t)(tid & (DESC_TAB_SIZE - 1)); }

void *forge_gc_desc_new (int64_t tid, int64_t sz, int64_t al,
                         int64_t nfields, uint64_t pmap) {
    size_t s = desc_slot (tid);
    for (forge_gc_desc *d = g_desc_tab[s]; d; d = NULL /* no chaining yet */) {
        if (d->tid == (uint64_t)tid) return d;
    }
    forge_gc_desc *d = malloc (sizeof (forge_gc_desc)
                             + nfields * sizeof (forge_gc_field));
    d->tid = (uint64_t)tid;
    d->sz = (uint64_t)sz;
    d->al = (uint64_t)al;
    d->nfields = (uint32_t)nfields;
    d->_pad = 0;
    d->pmap = pmap;
    /* linear-probe insert */
    size_t i = s;
    while (g_desc_tab[i] && g_desc_tab[i]->tid != (uint64_t)tid)
        i = (i + 1) & (DESC_TAB_SIZE - 1);
    g_desc_tab[i] = d;
    return d;
}

void forge_gc_desc_add_field (void *h, int32_t kind, int32_t ek,
                              int32_t cnt, int64_t off, int64_t sz) {
    forge_gc_desc *d = h;
    for (uint32_t i = 0; i < d->nfields; i++) {
        if (d->fields[i].off == (uint64_t)off
         && d->fields[i].sz == (uint64_t)sz) {
            d->fields[i].kind = kind;
            d->fields[i].elem_kind = ek;
            d->fields[i].count = cnt;
            return;
        }
    }
}

void *forge_gc_lookup_desc_by_tid (int64_t tid) {
    size_t s = desc_slot (tid);
    for (size_t i = 0; i < DESC_TAB_SIZE; i++) {
        size_t j = (s + i) & (DESC_TAB_SIZE - 1);
        forge_gc_desc *d = g_desc_tab[j];
        if (!d) return NULL;
        if (d->tid == (uint64_t)tid) return d;
    }
    return NULL;
}

/* ---------- object registry ---------- */

static forge_gc_entry *g_objs = NULL;

void forge_gc_register_object (void *obj, void *desc_handle) {
    forge_gc_entry *e = malloc (sizeof *e);
    e->obj = obj;
    e->desc = desc_handle;
    e->mark = 0;
    e->gen = 0;
    e->next = g_objs;
    g_objs = e;
}

void forge_gc_unregister_object (void *obj) {
    forge_gc_entry **pp = &g_objs;
    while (*pp) {
        if ((*pp)->obj == obj) {
            forge_gc_entry *e = *pp;
            *pp = e->next;
            free (e);
            return;
        }
        pp = &(*pp)->next;
    }
}

/* ---------- mark: drain loop lives here, calls back into ATS ---------- */

void forge_gc_mark_drain (forge_gc_wl *wl) {
    while (wl->len > 0) {
        void *obj = wl->buf[--wl->len];
        /* find descriptor */
        forge_gc_entry *e = g_objs;
        while (e && e->obj != obj) e = e->next;
        if (!e) continue;
        e->mark = 1;
        forge_ats_mark_traverse_one (wl, obj, e->desc);
    }
}

/* ---------- sweep ---------- */

typedef struct {
    forge_gc_entry **pp;
    int reclaimed;
} forge_gc_sweep_st;

void *forge_gc_sweep_init (forge_gc_wl *wl) {
    forge_gc_sweep_st *s = calloc (1, sizeof *s);
    s->pp = &g_objs;
    s->reclaimed = 0;
    return s;
}

int forge_gc_sweep_step (void *state) {
    forge_gc_sweep_st *s = state;
    forge_gc_entry *e = *s->pp;
    if (!e) return 0;

    if (e->mark) {
        e->mark = 0;
        s->pp = &e->next;
    } else {
        *s->pp = e->next;
        free (e->obj); /* ATS ptr_alloc uses libc malloc */
        free (e);
        s->reclaimed++;
    }
    return 1;
}

int forge_gc_sweep_finish (void *state) {
    forge_gc_sweep_st *s = state;
    int n = s->reclaimed;
    free (s);
    return n;
}
```
