unit ComicGenerationDialog;

interface

uses System.SysUtils, System.Classes, System.Generics.Collections, Vcl.Forms, Vcl.Controls,
  Vcl.StdCtrls, Vcl.ExtCtrls, ComicGenerationPresets;

type
  TComicGenerationDialog = class(TForm)
  private
    FPresets: TObjectList<TComicGenerationPreset>;
    FFileName: string;
    FWritable,FHasProject: Boolean;
    FList: TListBox;
    FName: TEdit;
    FInstructions: TMemo;
    FStatus: TLabel;
    FSelectedID,FSelectedName,FSelectedInstructions: string;
    procedure RefreshList(Index: Integer);
    procedure Select(Sender: TObject);
    procedure Add(Sender: TObject);
    procedure Save(Sender: TObject);
    procedure Remove(Sender: TObject);
    procedure Apply(Sender: TObject);
    procedure Cancel(Sender: TObject);
  public
    constructor CreateManager(AOwner: TComponent; List: TObjectList<TComicGenerationPreset>;
      const FileName: string; Writable,HasProject: Boolean);
    procedure SelectPreset(Index: Integer);
    procedure SetDraft(const Name,Instructions: string);
    procedure AcceptSelection;
    property SelectedID: string read FSelectedID;
    property SelectedName: string read FSelectedName;
    property SelectedInstructions: string read FSelectedInstructions;
  end;

implementation

uses Winapi.Windows, Vcl.Dialogs, System.UITypes, System.Math;

constructor TComicGenerationDialog.CreateManager(AOwner: TComponent; List: TObjectList<TComicGenerationPreset>;
  const FileName: string; Writable,HasProject: Boolean);
var Left,Right,Bar: TPanel; LabelControl: TLabel; Button: TButton;
  function D(Value: Integer): Integer; begin Result:=MulDiv(Value,CurrentPPI,96); end;
  procedure AddButton(const Caption: string; X,W: Integer; Handler: TNotifyEvent; Enabled: Boolean);
  begin Button:=TButton.Create(Self); Button.Parent:=Bar; Button.SetBounds(D(X),D(10),D(W),D(34)); Button.Caption:=Caption; Button.OnClick:=Handler; Button.Enabled:=Enabled; end;
begin
  inherited CreateNew(AOwner); FPresets:=List; FFileName:=FileName; FWritable:=Writable; FHasProject:=HasProject;
  Caption:='画像生成の共通指示プリセット'; Position:=poOwnerFormCenter; BorderStyle:=bsDialog; Font.Name:='Yu Gothic UI'; Font.Size:=10;
  ClientWidth:=D(880); ClientHeight:=D(580);
  Bar:=TPanel.Create(Self); Bar.Parent:=Self; Bar.Align:=alBottom; Bar.Height:=D(54); Bar.BevelOuter:=bvNone;
  AddButton('追加',12,96,Add,FWritable); AddButton('保存',120,96,Save,FWritable); AddButton('削除',228,96,Remove,FWritable);
  AddButton('作品へ適用',566,142,Apply,HasProject); AddButton('閉じる',722,142,Cancel,True); Button.Cancel:=True;
  Left:=TPanel.Create(Self); Left.Parent:=Self; Left.Align:=alLeft; Left.Width:=D(248); Left.BevelOuter:=bvNone;
  FList:=TListBox.Create(Self); FList.Parent:=Left; FList.Align:=alClient; FList.OnClick:=Select;
  Right:=TPanel.Create(Self); Right.Parent:=Self; Right.Align:=alClient; Right.BevelOuter:=bvNone; Right.Padding.SetBounds(D(18),D(16),D(18),D(12));
  LabelControl:=TLabel.Create(Self); LabelControl.Parent:=Right; LabelControl.Align:=alTop; LabelControl.AutoSize:=False; LabelControl.Height:=D(24); LabelControl.Caption:='プリセット名';
  FName:=TEdit.Create(Self); FName.Parent:=Right; FName.Align:=alTop; FName.MaxLength:=200; FName.ReadOnly:=not FWritable;
  FStatus:=TLabel.Create(Self); FStatus.Parent:=Right; FStatus.Align:=alBottom; FStatus.AutoSize:=False; FStatus.Height:=D(76); FStatus.WordWrap:=True;
  FStatus.Caption:='保存は共通プリセットを更新します。作品へ適用すると、表示中の名前と本文を作品へコピーします。以後の共通編集から作品の指示を保護します。';
  if not FWritable then FStatus.Caption:='ライブラリの読込に失敗しています。元ファイルを保持し、追加/変更/削除を停止しています。';
  FInstructions:=TMemo.Create(Self); FInstructions.Parent:=Right; FInstructions.Align:=alClient; FInstructions.ScrollBars:=ssVertical;
  FInstructions.MaxLength:=65536; FInstructions.ReadOnly:=not FWritable; RefreshList(0);
end;
procedure TComicGenerationDialog.RefreshList(Index: Integer);
var Preset: TComicGenerationPreset;
begin
  FList.Clear; for Preset in FPresets do FList.Items.AddObject(Preset.Name,Preset);
  if FPresets.Count>0 then FList.ItemIndex:=Min(Index,FPresets.Count-1); Select(nil);
end;
procedure TComicGenerationDialog.Select(Sender: TObject);
begin
  if FList.ItemIndex<0 then begin FName.Clear; FInstructions.Clear; Exit; end;
  FName.Text:=FPresets[FList.ItemIndex].Name; FInstructions.Text:=FPresets[FList.ItemIndex].Instructions;
end;
procedure TComicGenerationDialog.SelectPreset(Index: Integer);
begin if (Index<0) or (Index>=FPresets.Count) then Exit; FList.ItemIndex:=Index; Select(nil); end;
procedure TComicGenerationDialog.SetDraft(const Name,Instructions: string);
begin if not FWritable then raise Exception.Create('共通プリセットの編集は停止中です。'); FName.Text:=Name; FInstructions.Text:=Instructions; end;
procedure TComicGenerationDialog.AcceptSelection;
begin Apply(nil); end;
procedure TComicGenerationDialog.Add(Sender: TObject);
var Preset,Other: TComicGenerationPreset; Number: Integer; Duplicate: Boolean;
begin
  if not FWritable then Exit; Preset:=TComicGenerationPreset.Create; Number:=FPresets.Count+1;
  repeat
    Preset.Name:='新しいプリセット '+IntToStr(Number); Duplicate:=False;
    for Other in FPresets do if SameText(Other.Name,Preset.Name) then Duplicate:=True; Inc(Number);
  until not Duplicate;
  FPresets.Add(Preset);
  try SaveGenerationPresets(FPresets,FFileName); RefreshList(FPresets.Count-1); FName.SetFocus; FName.SelectAll;
  except on E: Exception do begin FPresets.Remove(Preset); FStatus.Caption:=E.Message; end; end;
end;
procedure TComicGenerationDialog.Save(Sender: TObject);
var Index: Integer;
begin
  if not FWritable then Exit; Index:=FList.ItemIndex; if Index<0 then Exit;
  try UpdateGenerationPreset(FPresets,FPresets[Index],FName.Text,FInstructions.Text,FFileName); RefreshList(Index); FStatus.Caption:='共通プリセットを保存しました。作品に適用済みの本文は保持します。';
  except on E: Exception do FStatus.Caption:=E.Message; end;
end;
procedure TComicGenerationDialog.Remove(Sender: TObject);
var Index: Integer;
begin
  if not FWritable then Exit; Index:=FList.ItemIndex; if Index<0 then Exit;
  if MessageDlg('共通プリセットを削除しますか？作品に適用した本文は保持します。',mtConfirmation,[mbYes,mbNo],0)<>mrYes then Exit;
  try RemoveGenerationPreset(FPresets,FPresets[Index],FFileName); RefreshList(Index); except on E: Exception do FStatus.Caption:=E.Message; end;
end;
procedure TComicGenerationDialog.Apply(Sender: TObject);
begin
  if not FHasProject then begin FStatus.Caption:='作品を作成または開いてから適用できます。'; Exit; end;
  if FList.ItemIndex<0 then begin FStatus.Caption:='プリセットを選択してください。'; Exit; end;
  if Trim(FName.Text)='' then begin FStatus.Caption:='プリセット名を入力してください。'; Exit; end;
  FSelectedID:=FPresets[FList.ItemIndex].ID; FSelectedName:=Trim(FName.Text); FSelectedInstructions:=FInstructions.Text; ModalResult:=mrOK;
end;
procedure TComicGenerationDialog.Cancel(Sender: TObject);
begin ModalResult:=mrCancel; end;

end.
