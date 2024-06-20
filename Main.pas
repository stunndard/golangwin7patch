unit Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Imaging.jpeg,
  ShellApi, Vcl.ExtCtrls;

type
  TfrmMain = class(TForm)
    txtLog: TMemo;
    cmdOpen: TButton;
    imgPic: TImage;
    dlgOpen: TOpenDialog;
    procedure imgPicClick(Sender: TObject);
    procedure cmdOpenClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure WMDropFiles(var Msg: TWMDropFiles); message WM_DROPFILES;
    procedure TryPatch(fileName: string);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

uses
  Patcher;

var
  filesDropped: boolean = False;

function ChangeWindowMessageFilterEx(HWND: integer; Msg: Cardinal;
  Action: Dword; pChangeFilterStruct: pointer): BOOL; stdcall; external 'user32.dll';

procedure TfrmMain.cmdOpenClick(Sender: TObject);
begin
  if not dlgOpen.Execute then
    Exit;
  txtLog.Clear;
  TryPatch(dlgOpen.fileName);
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  DragAcceptFiles(frmMain.Handle, True);
  // enable drag and drop files for an elevated process
  ChangeWindowMessageFilterEx(frmMain.Handle, WM_DROPFILES, 1, nil);
  ChangeWindowMessageFilterEx(frmMain.Handle, WM_COPYDATA, 1, nil);
  ChangeWindowMessageFilterEx(frmMain.Handle, WM_COPYGLOBALDATA, 1, nil);
end;

procedure TfrmMain.imgPicClick(Sender: TObject);
begin
  ShellExecute(Self.Handle, 'open', 'https://github.com/rolandshoemaker', nil,
    nil, SW_SHOWNORMAL);
end;

procedure TfrmMain.TryPatch(fileName: string);
var
  res: boolean;
begin
  res := Patch(fileName);
  txtLog.Lines.AddStrings(Patcher.Log);
  txtLog.Lines.Add('');
  if (not filesDropped) and res then
  begin
    DropDLLs;
    filesDropped := True;
    txtLog.Lines.AddStrings(Patcher.Log);
    txtLog.Lines.Add('');
  end;
end;

procedure TfrmMain.WMDropFiles(var Msg: TWMDropFiles);
var
  DropH: HDROP; // drop handle
  DroppedFileCount: integer; // number of files dropped
  FileNameLength: integer; // length of a dropped file name
  fileName: string; // a dropped file name
  i: integer; // loops thru all dropped files
begin
  txtLog.Clear;
  inherited;
  // Store drop handle from the message
  DropH := Msg.Drop;
  try
    // Get count of files dropped
    DroppedFileCount := DragQueryFile(DropH, $FFFFFFFF, nil, 0);
    // Get name of each file dropped and process it
    for i := 0 to Pred(DroppedFileCount) do
    begin
      // get length of file name
      FileNameLength := DragQueryFile(DropH, I, nil, 0);
      // create string large enough to store file
      SetLength(fileName, FileNameLength);
      // get the file name
      DragQueryFile(DropH, I, PChar(fileName), FileNameLength + 1);
      // process file
      if LowerCase(ExtractFileExt(fileName)) <> '.exe' then
      begin
        txtLog.Lines.Add(ExtractFileName(fileName) + ' is not an .EXE file');
      end
      else
        TryPatch(fileName);
    end;
  finally
    DragFinish(DropH);
  end;
  // Note we handled the message
  Msg.Result := 0;
end;

end.
