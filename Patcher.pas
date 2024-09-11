unit Patcher;

interface

uses
  WinApi.Windows, System.SysUtils, System.Classes, System.Hash;

function Patch(fileName: string): boolean;
function DropDLLs: boolean;
function CheckOSVersion: boolean;

var
  Log: TStringList;

implementation

function FileSize(const aFilename: String): Int64;
var
  info: TWin32FileAttributeData;
begin
  result := -1;
  if not GetFileAttributesEx(PChar(aFilename), GetFileExInfoStandard, @info) then
    exit;
  Result := Int64(info.nFileSizeLow) or Int64(info.nFileSizeHigh shl 32);
end;

function PatchMem(pattern, buf: PAnsiChar; patternlen, buflen: integer): boolean;
var
  i: integer;
begin
  Result := False;
  for i := 0 to buflen - patternlen - 1 do
  begin
    if CompareMem(pattern, @buf[i], patternlen) then
    begin
      Log.Add('patching at: 0x' + i.ToHexString(8));
      buf[i] := 'a';
      Result := True;
    end;
  end;
end;

function WriteFromResource(resName, fileName: string): boolean;
var
  rs: TResourceStream;
  fs: TFileStream;
begin
  Result := False;
  rs := TResourceStream.Create(HInstance, resName, RT_RCDATA);
  try
    if FileExists(fileName) then
    begin
      if THashMD5.GetHashString(rs) = THashMD5.GetHashStringFromFile(fileName) then
      begin
        Log.Add(fileName + ' is correct version, no change required.');
        Result := True;
        exit;
      end;
      // update the file
      if not DeleteFile(fileName) then
      begin
        Log.Add('file ' + fileName + ' cannot be deleted, probably in use, trying to rename...');
        if not RenameFile(fileName, fileName.Substring(0, fileName.Length - 1) + '_') then
        begin
          Log.Add('cannot rename it to ' + fileName.Substring(0, fileName.Length - 1) + '. check if it''s opened my another program.');
          exit;
        end;
      end;
    end;

    rs.Seek(0, soFromBeginning);
    try
      {$WARNINGS OFF}
      fs := TFileStream.Create(fileName, fmCreate or fmShareDenyRead);
      {$WARNINGS ON}
    except
      Log.Add('cannot create file for writing: ' + fileName);
      exit;
    end;
    fs.CopyFrom(rs);
    fs.Free;
    Log.Add('file written ok: ' + fileName);

    Result := True;
  finally
    rs.Free;
  end;
end;

function CheckOSVersion: boolean;
var
  OSVersionInfoEx: TOSVersionInfoEx;
begin
  Result := False;
  Log.Clear;
  OSVersionInfoEx.dwOSVersionInfoSize := sizeof(TOSVersionInfo);
  if not GetVersionEx(OSVersionInfoEx) then
  begin
    Log.Add('cannot get OS version.');
    exit;
  end;

  if (OSVersionInfoEx.dwMajorVersion <> 6) and
    (OSVersionInfoEx.dwMinorVersion <> 1)  then
  begin
    Log.Add('current OS is not Windows 7 or Server 2008.');
    Log.Add('run this patcher on the actual Windows system you want to patch.');
    exit;
  end;

  Result := True;
end;

function DropDLLs: boolean;
var
  wd: string;
  size1, size2: int64;
  os64: boolean;
begin
  Result := False;
  Log.Clear;
  Log.Add('checking additional files...');

  SetLength(wd, MAX_PATH);
  GetWindowsDirectory(PChar(wd), MAX_PATH);
  wd := string(pchar(wd));

  size1 := FileSize(wd + '\System32\kernel32.dll');
  size2 := FileSize(wd + '\Sysnative\kernel32.dll');
  if size1 = -1 then
  begin
    Log.Add('cannot get system DLL size.');
    exit;
  end;

  os64 := size2 > size1;
  if not WriteFromResource('dll32', wd + '\System32\acryptprimitives.dll') then
    exit;
  if os64 then
    if not WriteFromResource('dll64', wd + '\Sysnative\acryptprimitives.dll') then
      exit;

  Log.Add('additional files are ok.');
  Result := True;
end;

function Patch(fileName: string): boolean;
var
  fs, bs: TFileStream;
  ms: TMemoryStream;
  buf: PAnsiChar;
  c1, c2: PAnsiChar;
begin
  Result := False;
  Log.Clear;
  Log.Add('checking file: ' + ExtractFileName(fileName) + '...');
  try
    {$WARNINGS OFF}
    fs := TFileStream.Create(fileName, fmOpenReadWrite or fmShareDenyRead);
    {$WARNINGS ON}
    GetMem(buf, fs.Size);
    fs.Read(buf^, fs.Size);
  except
    Log.Add('couldn''t read the file, check if it''s opened by another program.');
    exit;
  end;

  ms := TMemoryStream.Create;
  ms.CopyFrom(fs);
  ms.Seek(0, soFromBeginning);

  try
    c1 := 'bcryptprimitives.dll';
    c2 := @string(c1)[1];
    if not(PatchMem(c1, buf, Length(c1), fs.Size) and PatchMem(c2, buf,
      Length(c1) * 2, fs.Size)) then
    begin
      Log.Add('couldn''t find the required data to patch. file not changed.');
      exit;
    end;

    // write the changes
    fs.Seek(0, soFromBeginning);
    fs.Write(buf^, fs.Size);
    Log.Add('saved ok.');

    // save file backup
    try
      {$WARNINGS OFF}
      bs := TFileStream.Create(fileName + '.bak', fmCreate or fmShareDenyRead);
      {$WARNINGS ON}
    except
      Log.Add('couldn''t save backup file ' + fileName + '.bak');
      exit;
    end;
    bs.CopyFrom(ms);
    bs.Free;
    Log.Add('backup saved ok.');
  finally
    fs.Free;
    ms.Free;
  end;
  Result := True;
  Log.Add('file successfully patched.');
end;

initialization

Log := TStringList.Create;

finalization

Log.Free;

end.
