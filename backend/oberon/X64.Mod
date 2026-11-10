MODULE X64;

IMPORT IR, Texts;

VAR W: Texts.Writer;

PROCEDURE Put(s: ARRAY OF CHAR);
BEGIN
  Texts.WriteString(W, s)
END Put;

PROCEDURE Int(n: INTEGER);
BEGIN
  Texts.WriteInt(W, n, 0)
END Int;

PROCEDURE Long(n: LONGINT);
VAR x: LONGINT; digits: ARRAY 32 OF CHAR; count, d: INTEGER;
BEGIN
  x := n; count := 0;
  IF x >= 0 THEN x := -x ELSE Put("-") END;
  REPEAT
    d := SHORT(-(x MOD 10));
    digits[count] := CHR(ORD("0") + d);
    INC(count);
    x := x DIV 10
  UNTIL x = 0;
  WHILE count > 0 DO
    DEC(count); Texts.Write(W, digits[count])
  END
END Long;

PROCEDURE Slot(r: INTEGER);
BEGIN
  Put("[rbp-"); Int((r+1)*8); Put("]")
END Slot;

PROCEDURE EmitInstruction(x: IR.Instruction; functionId: INTEGER);
BEGIN
  CASE x.op OF
    IR.Const:
      Put("    mov rax, "); Long(x.imm); Put("\n");
      Put("    mov "); Slot(x.dst); Put(", rax\n")
    | IR.Move:
      Put("    mov rax, "); Slot(x.a); Put("\n");
      Put("    mov "); Slot(x.dst); Put(", rax\n")
    | IR.Add:
      Put("    mov rax, "); Slot(x.a); Put("\n");
      Put("    add rax, "); Slot(x.b); Put("\n");
      Put("    jo .Lforge_overflow_"); Int(functionId); Put("\n");
      Put("    mov "); Slot(x.dst); Put(", rax\n")
    | IR.Sub:
      Put("    mov rax, "); Slot(x.a); Put("\n");
      Put("    sub rax, "); Slot(x.b); Put("\n");
      Put("    jo .Lforge_overflow_"); Int(functionId); Put("\n");
      Put("    mov "); Slot(x.dst); Put(", rax\n")
    | IR.Mul:
      Put("    mov rax, "); Slot(x.a); Put("\n");
      Put("    imul rax, "); Slot(x.b); Put("\n");
      Put("    jo .Lforge_overflow_"); Int(functionId); Put("\n");
      Put("    mov "); Slot(x.dst); Put(", rax\n")
    | IR.Return:
      Put("    mov rax, "); Slot(x.a); Put("\n");
      Put("    leave\n    ret\n")
  ELSE
    IR.Fail("unsupported x86-64 opcode")
  END
END EmitInstruction;

PROCEDURE EmitFunction(f: IR.Function);
VAR i, frame: INTEGER;
BEGIN
  frame := ((f.regc*8 + 15) DIV 16)*16;
  Put("global forge_fn_"); Int(f.id); Put("\nforge_fn_"); Int(f.id); Put(":\n");
  Put("    push rbp\n    mov rbp, rsp\n");
  IF frame > 0 THEN Put("    sub rsp, "); Int(frame); Put("\n") END;
  FOR i := 0 TO f.count-1 DO EmitInstruction(f.code[i], f.id) END;
  Put(".Lforge_overflow_"); Int(f.id); Put(":\n");
  Put("    mov eax, 70\n    leave\n    ret\n")
END EmitFunction;

PROCEDURE Emit*(VAR m: IR.Module; VAR out: Texts.Text);
VAR i: INTEGER;
BEGIN
  Texts.OpenWriter(W);
  Put("default rel\nsection .text\n");
  Put("global main\nmain:\n");
  Put("    push rbp\n    mov rbp, rsp\n    call forge_fn_0\n    leave\n    ret\n\n");
  FOR i := 0 TO m.count-1 DO EmitFunction(m.funcs[i]); Put("\n") END;
  Texts.CloseWriter(W);
  Texts.Append(out, W.buf)
END Emit;

END X64.
