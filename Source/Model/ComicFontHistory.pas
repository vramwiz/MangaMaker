unit ComicFontHistory;

// 責務：フォント履歴と明示指定した文字サイズを保存し、作品の選択では既定値を変えない。

interface

uses System.Classes, System.Generics.Collections;

type
  TComicFontHistory = class
  private
    FNames: TList<string>;
    FLastSize: Integer;
    FSizeFile: string;
    FSizeWritable: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Load(const FileName: string);
    procedure Remember(const Name,FileName: string);
    procedure LoadSize(const FileName: string);
    procedure RememberSize(Value: Integer);
    property LastSize: Integer read FLastSize;
    function Choices(Installed: TStrings): TArray<string>;
    function Names: TArray<string>;
  end;

implementation

uses System.SysUtils, System.JSON, System.IOUtils, ComicModel;

constructor TComicFontHistory.Create;
begin inherited; FNames:=TList<string>.Create; FLastSize:=24; FSizeWritable:=True; end;
destructor TComicFontHistory.Destroy;
begin FNames.Free; inherited; end;
function TComicFontHistory.Names: TArray<string>;
begin Result:=FNames.ToArray; end;
procedure TComicFontHistory.LoadSize(const FileName: string);
var J: TJSONValue; Value: Integer;
begin
  FSizeFile:=FileName; J:=nil;
  try
    if not FileExists(FileName) then Exit;
    J:=TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName,TEncoding.UTF8));
    if not (J is TJSONNumber) or not TryStrToInt(J.Value,Value) or (Value<1) or (Value>1000) then
      raise Exception.Create('文字サイズの設定が不正です。');
    FLastSize:=Value;
  except
    // 壊れた設定は上書きせず、今回の起動中だけ既定値から使い続ける。
    FSizeWritable:=False;
  end;
  J.Free;
end;
procedure TComicFontHistory.RememberSize(Value: Integer);
begin
  if (Value<1) or (Value>1000) then Exit;
  FLastSize:=Value;
  if not FSizeWritable or (FSizeFile='') then Exit;
  try AtomicWrite(FSizeFile,IntToStr(Value));
  except FSizeWritable:=False; raise; end;
end;
procedure TComicFontHistory.Load(const FileName: string);
var J,V: TJSONValue; Prepared: TList<string>; Name: string;
begin
  if not FileExists(FileName) then Exit; Prepared:=TList<string>.Create; J:=nil;
  try
    J:=TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName,TEncoding.UTF8));
    if not (J is TJSONArray) or (TJSONArray(J).Count>10) then raise Exception.Create('フォント履歴が不正です。');
    for V in TJSONArray(J) do begin
      if not (V is TJSONString) then raise Exception.Create('フォント履歴の項目が不正です。');
      Name:=Trim(V.Value); if (Name='') or (Length(Name)>200) or Prepared.Contains(Name) then raise Exception.Create('フォント履歴の項目が不正です。');
      Prepared.Add(Name);
    end;
    FNames.Clear; FNames.AddRange(Prepared);
  finally J.Free; Prepared.Free; end;
end;
procedure TComicFontHistory.Remember(const Name,FileName: string);
var Before: TArray<string>; Value,Item: string; I: Integer; J: TJSONArray;
begin
  Value:=Trim(Name); if (Value='') or (Length(Value)>200) then Exit; Before:=FNames.ToArray;
  for I:=FNames.Count-1 downto 0 do if SameText(FNames[I],Value) then FNames.Delete(I);
  FNames.Insert(0,Value); while FNames.Count>10 do FNames.Delete(FNames.Count-1);
  J:=TJSONArray.Create;
  try
    for Item in FNames do J.Add(Item);
    try AtomicWrite(FileName,J.ToJSON); except FNames.Clear; FNames.AddRange(Before); raise; end;
  finally J.Free; end;
end;
function TComicFontHistory.Choices(Installed: TStrings): TArray<string>;
var ResultNames: TList<string>; Name: string;
begin
  ResultNames:=TList<string>.Create;
  try
    for Name in FNames do ResultNames.Add(Name);
    for Name in Installed do if not ResultNames.Contains(Name) and not Name.StartsWith('@') then ResultNames.Add(Name);
    Result:=ResultNames.ToArray;
  finally ResultNames.Free; end;
end;

end.
