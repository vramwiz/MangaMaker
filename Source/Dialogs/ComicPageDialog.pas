unit ComicPageDialog;

// 責務：作品のページ基準と共通プリセットの操作を区別し、取消時の未反映状態を保つ。

interface

uses ComicDpi, System.Classes, System.SysUtils, System.Types, System.Generics.Collections,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls, ComicModel, ComicPagePresets;

type
  TComicPageDialog = class(TForm)
  private
    FPresets: TObjectList<TComicPagePreset>;
    FWritable: Boolean;
    FFileName: string;
    FList: TComboBox;
    FFields: array[0..5] of TEdit;
    FName: TEdit;
    FStatus: TLabel;
    FResult: TComicPageBasis;
    procedure RefreshPresets;
    procedure PresetChanged(Sender: TObject);
    procedure RegisterClick(Sender: TObject);
    procedure RenameClick(Sender: TObject);
    procedure RemoveClick(Sender: TObject);
    procedure Accept(Sender: TObject);
    procedure Cancel(Sender: TObject);
    function ReadFields: TComicPageBasis;
    procedure ValidateName(const Name: string; Exclude: Integer=-1);
  public
    constructor CreateSettings(AOwner: TComponent; const Basis: TComicPageBasis;
      Presets: TObjectList<TComicPagePreset>; const FileName: string; Writable: Boolean);
    procedure SetDraftBasis(const Basis: TComicPageBasis);
    procedure SelectPreset(Index: Integer);
    function RegisterPreset(const Name: string): TComicPagePreset;
    procedure RenamePreset(Index: Integer; const Name: string);
    procedure RemovePreset(Index: Integer);
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    property ResultBasis: TComicPageBasis read FResult;
  end;

implementation

uses Winapi.Windows, Vcl.Dialogs, System.UITypes;

constructor TComicPageDialog.CreateSettings(AOwner: TComponent; const Basis: TComicPageBasis;
  Presets: TObjectList<TComicPagePreset>; const FileName: string; Writable: Boolean);
var I,Column,Row: Integer; LabelControl: TLabel; Button: TButton; Bar: TPanel;
  function D(Value: Integer): Integer; begin Result:=MulDiv(Value,CurrentPPI,96); end;
  procedure AddButton(const Caption: string; X,Y,W: Integer; Handler: TNotifyEvent; Enabled: Boolean=True);
  begin
    Button:=TButton.Create(Self); Button.Parent:=Self; Button.SetBounds(D(X),D(Y),D(W),D(34));
    Button.Caption:=Caption; Button.OnClick:=Handler; Button.Enabled:=Enabled;
  end;
const Captions: array[0..5] of string = ('出力の幅 (px)','出力の高さ (px)','左余白 (px)','上余白 (px)','右余白 (px)','下余白 (px)');
begin
  inherited CreateScaledNew(AOwner,OwnerControlPPI(AOwner)); FPresets:=Presets; FFileName:=FileName; FWritable:=Writable; FResult:=Basis;
  Caption:='ページ基準 — 全ページ共通'; Position:=poOwnerFormCenter; BorderStyle:=bsDialog; KeyPreview:=True;
  Font.Name:='Yu Gothic UI'; Font.Size:=10; ClientWidth:=D(650); ClientHeight:=D(510);
  LabelControl:=TLabel.Create(Self); LabelControl.Parent:=Self; LabelControl.SetBounds(D(20),D(16),D(600),D(22)); LabelControl.Caption:='共通プリセット';
  FList:=TComboBox.Create(Self); FList.Parent:=Self; FList.SetBounds(D(20),D(42),D(610),D(30)); FList.Style:=csDropDownList; FList.OnChange:=PresetChanged;
  for I:=0 to 5 do begin
    Column:=I mod 2; Row:=I div 2;
    LabelControl:=TLabel.Create(Self); LabelControl.Parent:=Self; LabelControl.SetBounds(D(20+Column*310),D(94+Row*70),D(280),D(22)); LabelControl.Caption:=Captions[I];
    FFields[I]:=TEdit.Create(Self); FFields[I].Parent:=Self; FFields[I].SetBounds(D(20+Column*310),D(120+Row*70),D(280),D(30)); FFields[I].MaxLength:=5;
  end;
  LabelControl:=TLabel.Create(Self); LabelControl.Parent:=Self; LabelControl.SetBounds(D(20),D(310),D(600),D(22)); LabelControl.Caption:='プリセット名（登録は共通ライブラリへ保存します）';
  FName:=TEdit.Create(Self); FName.Parent:=Self; FName.SetBounds(D(20),D(336),D(280),D(30)); FName.MaxLength:=200;
  AddButton('登録',314,334,96,RegisterClick,FWritable); AddButton('名前変更',422,334,96,RenameClick,FWritable); AddButton('削除',530,334,96,RemoveClick,FWritable);
  FStatus:=TLabel.Create(Self); FStatus.Parent:=Self; FStatus.AutoSize:=False; FStatus.WordWrap:=True;
  FStatus.SetBounds(D(20),D(386),D(610),D(64));
  FStatus.Caption:='解像度変更時は全ページの配置をページ中心から縦横同率で拡縮します。文字は近い整数サイズへ調整し、余白だけの変更では配置を維持します。Undoで戻せます。';
  if not FWritable then FStatus.Caption:='共通ライブラリの読込に失敗しています。プリセットの保存は停止中です。作品のページ基準は変更できます。';
  Bar:=TPanel.Create(Self); Bar.Parent:=Self; Bar.Align:=alBottom; Bar.Height:=D(54); Bar.BevelOuter:=bvNone;
  Button:=TButton.Create(Self); Button.Parent:=Bar; Button.SetBounds(D(360),D(10),D(128),D(34)); Button.Caption:='作品に適用'; Button.OnClick:=Accept; Button.Default:=True;
  Button:=TButton.Create(Self); Button.Parent:=Bar; Button.SetBounds(D(502),D(10),D(128),D(34)); Button.Caption:='取消'; Button.OnClick:=Cancel; Button.Cancel:=True;
  RefreshPresets; SetDraftBasis(Basis);
end;
procedure TComicPageDialog.RefreshPresets;
var Preset: TComicPagePreset;
begin
  FList.Clear; for Preset in FPresets do FList.Items.AddObject(Preset.Name,Preset);
end;
procedure TComicPageDialog.SetDraftBasis(const Basis: TComicPageBasis);
var I: Integer;
begin
  FFields[0].Text:=IntToStr(Basis.Width); FFields[1].Text:=IntToStr(Basis.Height);
  FFields[2].Text:=IntToStr(Basis.Left); FFields[3].Text:=IntToStr(Basis.Top);
  FFields[4].Text:=IntToStr(Basis.Right); FFields[5].Text:=IntToStr(Basis.Bottom);
  // 既存作品の値を維持したまま、同じ寸法・余白のプリセットを初期表示する。
  FList.ItemIndex:=-1;
  for I:=0 to FPresets.Count-1 do if FPresets[I].Basis.Same(Basis) then begin FList.ItemIndex:=I; Break; end;
end;
function TComicPageDialog.ReadFields: TComicPageBasis;
var Values: array[0..5] of Integer; I: Integer;
begin
  for I:=0 to 5 do if not TryStrToInt(Trim(FFields[I].Text),Values[I]) then
    raise Exception.Create('寸法と余白は整数で入力してください。');
  Result.Width:=Values[0]; Result.Height:=Values[1]; Result.Left:=Values[2]; Result.Top:=Values[3]; Result.Right:=Values[4]; Result.Bottom:=Values[5];
  if not Result.Valid then raise Exception.Create('出力は100～8000px、余白は0以上で外枠内に領域が残る値を指定してください。');
end;
procedure TComicPageDialog.SelectPreset(Index: Integer);
begin
  if (Index<0) or (Index>=FPresets.Count) then Exit;
  SetDraftBasis(FPresets[Index].Basis); FList.ItemIndex:=Index; FName.Text:=FPresets[Index].Name;
end;
procedure TComicPageDialog.PresetChanged(Sender: TObject);
begin SelectPreset(FList.ItemIndex); end;
procedure TComicPageDialog.ValidateName(const Name: string; Exclude: Integer);
var I: Integer;
begin
  if not FWritable then raise Exception.Create('共通ライブラリへの保存は停止中です。');
  if (Trim(Name)='') or (Length(Trim(Name))>200) then raise Exception.Create('プリセット名を入力してください。');
  for I:=0 to FPresets.Count-1 do if (I<>Exclude) and SameText(FPresets[I].Name,Trim(Name)) then
    raise Exception.Create('同じ名前のプリセットがあります。別の名前を指定してください。');
end;
function TComicPageDialog.RegisterPreset(const Name: string): TComicPagePreset;
var Basis: TComicPageBasis;
begin
  ValidateName(Name); Basis:=ReadFields; Result:=TComicPagePreset.Create; Result.Name:=Trim(Name); Result.Basis:=Basis; FPresets.Add(Result);
  try SavePagePresets(FPresets,FFileName); except FPresets.Remove(Result); raise; end;
  RefreshPresets; SelectPreset(FPresets.Count-1);
end;
procedure TComicPageDialog.RenamePreset(Index: Integer; const Name: string);
var Previous: string;
begin
  if (Index<0) or (Index>=FPresets.Count) or FPresets[Index].BuiltIn then raise Exception.Create('登録したプリセットを選択してください。');
  ValidateName(Name,Index); Previous:=FPresets[Index].Name; FPresets[Index].Name:=Trim(Name);
  try SavePagePresets(FPresets,FFileName); except FPresets[Index].Name:=Previous; raise; end;
  RefreshPresets; SelectPreset(Index);
end;
procedure TComicPageDialog.RemovePreset(Index: Integer);
var Preset: TComicPagePreset;
begin
  if not FWritable then raise Exception.Create('共通ライブラリへの保存は停止中です。');
  if (Index<0) or (Index>=FPresets.Count) or FPresets[Index].BuiltIn then raise Exception.Create('登録したプリセットを選択してください。');
  Preset:=FPresets.Extract(FPresets[Index]);
  try SavePagePresets(FPresets,FFileName); except FPresets.Insert(Index,Preset); raise; end;
  Preset.Free; RefreshPresets; FName.Clear;
end;
procedure TComicPageDialog.RegisterClick(Sender: TObject);
begin try RegisterPreset(FName.Text); FStatus.Caption:='共通プリセットを登録しました。'; except on E: Exception do FStatus.Caption:=E.Message; end; end;
procedure TComicPageDialog.RenameClick(Sender: TObject);
begin try RenamePreset(FList.ItemIndex,FName.Text); FStatus.Caption:='プリセット名を変更しました。'; except on E: Exception do FStatus.Caption:=E.Message; end; end;
procedure TComicPageDialog.RemoveClick(Sender: TObject);
begin
  if MessageDlg('選択した共通プリセットを削除しますか？作品に適用したページ基準は保持されます。',mtConfirmation,[mbYes,mbNo],0)<>mrYes then Exit;
  try RemovePreset(FList.ItemIndex); FStatus.Caption:='共通プリセットを削除しました。'; except on E: Exception do FStatus.Caption:=E.Message; end;
end;
procedure TComicPageDialog.Accept(Sender: TObject);
begin try FResult:=ReadFields; ModalResult:=mrOK; except on E: Exception do FStatus.Caption:=E.Message; end; end;
procedure TComicPageDialog.Cancel(Sender: TObject);
begin ModalResult:=mrCancel; end;
procedure TComicPageDialog.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if Key=VK_ESCAPE then begin Cancel(Self); Key:=0; end
  else if Key=VK_RETURN then begin Accept(Self); Key:=0; end else inherited;
end;

end.
