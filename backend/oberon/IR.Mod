MODULE IR;

CONST
  MaxFunctions* = 64;
  MaxInstructions* = 4096;
  MaxRegisters* = 256;
  Const* = 1;
  Move* = 2;
  Add* = 3;
  Sub* = 4;
  Mul* = 5;
  Return* = 6;

TYPE
  Instruction* = RECORD
    op*: INTEGER;
    dst*, a*, b*: INTEGER;
    imm*: LONGINT;
  END;
  Function* = RECORD
    id*, argc*, regc*, count*: INTEGER;
    code*: ARRAY MaxInstructions OF Instruction;
  END;
  Module* = RECORD
    id*, count*: INTEGER;
    funcs*: ARRAY MaxFunctions OF Function;
  END;

VAR
  error*: BOOLEAN;
  message*: ARRAY 128 OF CHAR;

PROCEDURE Fail*(msg: ARRAY OF CHAR);
BEGIN
  error := TRUE;
  COPY(msg, message)
END Fail;

PROCEDURE Init*(VAR m: Module);
BEGIN
  error := FALSE;
  message := "";
  m.id := -1;
  m.count := 0
END Init;

PROCEDURE AddFunction*(VAR m: Module; id, argc, regc: INTEGER);
VAR f: Function;
BEGIN
  IF error THEN RETURN END;
  IF m.count >= MaxFunctions THEN Fail("function capacity exceeded"); RETURN END;
  IF id < 0 THEN Fail("negative function ID"); RETURN END;
  IF (argc < 0) OR (regc < argc) OR (regc < 1) OR (regc > MaxRegisters) THEN
    Fail("invalid function register declaration"); RETURN
  END;
  IF (m.count > 0) & (id <= m.funcs[m.count-1].id) THEN
    Fail("function IDs must be ascending"); RETURN
  END;
  f.id := id; f.argc := argc; f.regc := regc; f.count := 0;
  m.funcs[m.count] := f;
  INC(m.count)
END AddFunction;

PROCEDURE AddInstruction*(VAR f: Function; op, dst, a, b: INTEGER; imm: LONGINT);
VAR x: Instruction;
BEGIN
  IF error THEN RETURN END;
  IF f.count >= MaxInstructions THEN Fail("instruction capacity exceeded"); RETURN END;
  x.op := op; x.dst := dst; x.a := a; x.b := b; x.imm := imm;
  f.code[f.count] := x;
  INC(f.count)
END AddInstruction;

PROCEDURE ValidateFunction*(VAR f: Function);
VAR i: INTEGER; x: Instruction;
BEGIN
  IF error THEN RETURN END;
  IF f.count = 0 THEN Fail("empty function"); RETURN END;
  FOR i := 0 TO f.count-1 DO
    x := f.code[i];
    CASE x.op OF
      Const:
        IF (x.dst < 0) OR (x.dst >= f.regc) THEN Fail("CONST destination out of range") END
      | Move:
        IF (x.dst < 0) OR (x.dst >= f.regc) OR (x.a < 0) OR (x.a >= f.regc) THEN Fail("MOVE register out of range") END
      | Add, Sub, Mul:
        IF (x.dst < 0) OR (x.dst >= f.regc) OR (x.a < 0) OR (x.a >= f.regc) OR (x.b < 0) OR (x.b >= f.regc) THEN Fail("arithmetic register out of range") END
      | Return:
        IF (x.a < 0) OR (x.a >= f.regc) THEN Fail("RETURN register out of range") END;
        IF i # f.count-1 THEN Fail("RETURN must be final instruction") END
      ELSE
        Fail("unknown opcode")
    END
  END;
  IF f.code[f.count-1].op # Return THEN Fail("function missing RETURN") END
END ValidateFunction;

PROCEDURE Validate*(VAR m: Module);
VAR i: INTEGER;
BEGIN
  IF m.id < 0 THEN Fail("invalid module ID") END;
  IF m.count # 1 THEN Fail("IR v1 requires exactly one entry function") END;
  IF (m.funcs[0].id # 0) OR (m.funcs[0].argc # 0) THEN
    Fail("IR v1 requires zero-argument entry function ID 0")
  END;
  FOR i := 0 TO m.count-1 DO ValidateFunction(m.funcs[i]) END
END Validate;

END IR.
