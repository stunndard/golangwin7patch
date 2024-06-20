program GoWin7Fixer;

{$R *.dres}

uses
  Vcl.Forms,
  Main in 'Main.pas' {frmMain},
  Patcher in 'Patcher.pas',
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Windows10 SlateGray');
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
