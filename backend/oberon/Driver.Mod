MODULE Driver;

IMPORT IR, Parser, X64, Texts;

VAR source, assembly: Texts.Text;

PROCEDURE Compile*(sourceName, assemblyName: ARRAY OF CHAR);
VAR m: IR.Module;
BEGIN
  Texts.Load(sourceName, source);
  Parser.Parse(source, m);
  IF ~IR.error THEN
    X64.Emit(m, assembly);
    Texts.Store(assemblyName, assembly)
  END
END Compile;

END Driver.
