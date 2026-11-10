MODULE Parser;

IMPORT IR, Texts;

VAR R: Texts.Reader;
    token: ARRAY 256 OF CHAR;
    number: LONGINT;
    failed: BOOLEAN;

PROCEDURE Next;
BEGIN
  Texts.ReadString(R, token)
END Next;

PROCEDURE Expect(s: ARRAY OF CHAR);
BEGIN
  IF token # s THEN IR.Fail("unexpected IR token"); failed := TRUE ELSE Next END
END Expect;

PROCEDURE Number(VAR n: LONGINT);
BEGIN
  Texts.ReadInt(R, n);
  Next
END Number;

PROCEDURE SmallNumber(VAR n: INTEGER);
VAR x: LONGINT;
BEGIN
  Number(x);
  IF (x < MIN(INTEGER)) OR (x > MAX(INTEGER)) THEN
    IR.Fail("integer outside Oberon index range"); failed := TRUE
  ELSE n := SHORT(x) END
END SmallNumber;

PROCEDURE Parse*(VAR text: Texts.Text; VAR m: IR.Module);
VAR id, argc, regc, op, dst, a, b: INTEGER;
    imm: LONGINT;
    f: IR.Function;
BEGIN
  IR.Init(m); failed := FALSE;
  Texts.OpenReader(R, text, 0);
  Next;
  Expect("FORGE-IR");
  IF token # "1" THEN IR.Fail("unsupported FORGE IR version"); failed := TRUE ELSE Next END;
  Expect("MODULE"); SmallNumber(m.id);
  WHILE (token = "FUNC") & ~failed DO
    Next; SmallNumber(id); SmallNumber(argc); SmallNumber(regc);
    IR.AddFunction(m, id, argc, regc);
    IF IR.error THEN failed := TRUE ELSE f := m.funcs[m.count-1] END;
    WHILE (token # "ENDFUNC") & (token # "") & ~failed DO
      IF token = "CONST" THEN
        op := IR.Const; Next; SmallNumber(dst); Number(imm);
        IR.AddInstruction(f, op, dst, 0, 0, imm)
      ELSIF token = "MOVE" THEN
        op := IR.Move; Next; SmallNumber(dst); SmallNumber(a);
        IR.AddInstruction(f, op, dst, a, 0, 0)
      ELSIF token = "ADD" THEN
        op := IR.Add; Next; SmallNumber(dst); SmallNumber(a); SmallNumber(b);
        IR.AddInstruction(f, op, dst, a, b, 0)
      ELSIF token = "SUB" THEN
        op := IR.Sub; Next; SmallNumber(dst); SmallNumber(a); SmallNumber(b);
        IR.AddInstruction(f, op, dst, a, b, 0)
      ELSIF token = "MUL" THEN
        op := IR.Mul; Next; SmallNumber(dst); SmallNumber(a); SmallNumber(b);
        IR.AddInstruction(f, op, dst, a, b, 0)
      ELSIF token = "RETURN" THEN
        op := IR.Return; Next; SmallNumber(a);
        IR.AddInstruction(f, op, 0, a, 0, 0)
      ELSE
        IR.Fail("unknown IR instruction"); failed := TRUE
      END
    END;
    IF ~failed THEN
      Expect("ENDFUNC");
      m.funcs[m.count-1] := f;
      IR.ValidateFunction(m.funcs[m.count-1])
    END
  END;
  Expect("ENDMODULE");
  IF token # "" THEN IR.Fail("trailing IR data") END;
  IR.Validate(m)
END Parse;

END Parser.
