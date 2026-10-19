unit ComicNewProjectDialog;

// 責務：保存先・作品名・用紙と任意の貼付台本を、新規作品の確定前にまとめて入力する。
interface
uses System.Classes, System.Generics.Collections, Vcl.Forms, Vcl.Controls, Vcl.StdCtrls,
  ComicModel, ComicPagePresets;
type
  TComicNewProjectDialog = class(TForm)
  private
    FFolder,FTitle,FEpisode: TEdit;
    FFields: array[0..5] of TEdit;
    FScript: TMemo;
    FPresets: TObjectList<TComicPagePreset>;
    FList: TComboBox;
    FAccept: TButton;
    FStatus: TLabel;
    procedure Browse(Sender: TObject);
    procedure InputChanged(Sender: TObject);
    procedure PresetChanged(Sender: TObject);
    procedure Accept(Sender: TObject);
  public
    constructor CreateSettings(AOwner: TComponent; Presets: TObjectList<TComicPagePreset>; const ScriptText: string='');
    function Basis: TComicPageBasis;
    procedure SetBasis(const Value: TComicPageBasis);
    function CreateProject(Characters: TObjectList<TComicAsset>): TComicProject;
  end;
function PasteComicScript(AOwner: TComponent; var Text: string): Boolean;
implementation
uses Winapi.Windows, System.SysUtils, System.UITypes, Vcl.Dialogs, Vcl.ExtCtrls,
  ComicDpi, ComicProjectCreation;
constructor TComicNewProjectDialog.CreateSettings(AOwner: TComponent; Presets: TObjectList<TComicPagePreset>; const ScriptText: string);
var L: TLabel; B: TButton; I: Integer; Default: TComicProject;
  function D(V: Integer): Integer; begin Result:=MulDiv(V,CurrentPPI,96); end;
  procedure LabelAt(const Caption: string; X,Y,W: Integer);
  begin L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(D(X),D(Y),D(W),D(24)); L.Caption:=Caption; end;
  function EditAt(X,Y,W: Integer): TEdit;
  begin Result:=TEdit.Create(Self); Result.Parent:=Self; Result.SetBounds(D(X),D(Y),D(W),D(28)); end;
const Names: array[0..5] of string=('幅 (px)','高さ (px)','左余白 (px)','上余白 (px)','右余白 (px)','下余白 (px)');
begin
  inherited CreateScaledNew(AOwner,OwnerControlPPI(AOwner)); FPresets:=Presets;
  Caption:='新規作品'; Position:=poOwnerFormCenter; BorderStyle:=bsDialog;
  Font.Name:='Yu Gothic UI'; Font.Size:=10; ClientWidth:=D(820); ClientHeight:=D(620);
  LabelAt('保存先フォルダ（必須・指定先へ直接保存）',20,16,740);
  FFolder:=EditAt(20,42,660); FFolder.OnChange:=InputChanged;
  B:=TButton.Create(Self); B.Parent:=Self; B.SetBounds(D(692),D(40),D(108),D(32)); B.Caption:='フォルダ選択'; B.OnClick:=Browse;
  LabelAt('作品名',20,86,560); FTitle:=EditAt(20,112,560); FTitle.MaxLength:=200; FTitle.OnChange:=InputChanged;
  LabelAt('話数（任意）',600,86,200); FEpisode:=EditAt(600,112,200); FEpisode.MaxLength:=200;
  LabelAt('全ページ共通の用紙プリセット',20,162,350);
  FList:=TComboBox.Create(Self); FList.Parent:=Self; FList.SetBounds(D(20),D(188),D(350),D(30));
  FList.Style:=csDropDownList; FList.OnChange:=PresetChanged;
  for var Preset in FPresets do FList.Items.Add(Preset.Name);
  for I:=0 to 5 do begin
    LabelAt(Names[I],20+(I mod 2)*180,240+(I div 2)*78,170);
    FFields[I]:=EditAt(20+(I mod 2)*180,266+(I div 2)*78,170); FFields[I].MaxLength:=5;
  end;
  LabelAt('台本（任意・ここへ貼り付け）',400,162,400);
  FScript:=TMemo.Create(Self); FScript.Parent:=Self; FScript.SetBounds(D(400),D(188),D(400),D(310));
  FScript.ScrollBars:=ssBoth; FScript.WordWrap:=False; FScript.MaxLength:=1024*1024; FScript.Text:=ScriptText;
  LabelAt('プリセット選択後も数値を変更できます。',20,478,370);
  FStatus:=TLabel.Create(Self); FStatus.Parent:=Self; FStatus.AutoSize:=False; FStatus.WordWrap:=True;
  FStatus.SetBounds(D(20),D(518),D(780),D(42)); FStatus.Caption:='保存先フォルダを指定してください。既存ファイルへの上書きは指定先を確認して行ってください。';
  FAccept:=TButton.Create(Self); FAccept.Parent:=Self; FAccept.SetBounds(D(560),D(572),D(112),D(32));
  FAccept.Caption:='作成'; FAccept.OnClick:=Accept;
  B:=TButton.Create(Self); B.Parent:=Self; B.SetBounds(D(688),D(572),D(112),D(32)); B.Caption:='取消'; B.Cancel:=True; B.ModalResult:=mrCancel;
  Default:=TComicProject.Create; try SetBasis(Default.PageBasis); finally Default.Free; end;
  InputChanged(nil);
end;
procedure TComicNewProjectDialog.Browse(Sender: TObject);
var Dialog: TFileOpenDialog;
begin
  Dialog:=TFileOpenDialog.Create(Self);
  try
    Dialog.Title:='作品の保存先フォルダ'; Dialog.Options:=[fdoPickFolders,fdoPathMustExist,fdoForceFileSystem];
    if FFolder.Text<>'' then Dialog.DefaultFolder:=FFolder.Text;
    if Dialog.Execute then FFolder.Text:=Dialog.FileName;
  finally Dialog.Free; end;
end;
procedure TComicNewProjectDialog.InputChanged(Sender: TObject);
begin if FAccept<>nil then FAccept.Enabled:=(Trim(FFolder.Text)<>'') and (Trim(FTitle.Text)<>''); end;
function TComicNewProjectDialog.Basis: TComicPageBasis;
var Values: array[0..5] of Integer;
begin
  for var I:=0 to 5 do if not TryStrToInt(Trim(FFields[I].Text),Values[I]) then raise Exception.Create('用紙サイズと余白は整数で入力してください。');
  Result.Width:=Values[0]; Result.Height:=Values[1]; Result.Left:=Values[2]; Result.Top:=Values[3]; Result.Right:=Values[4]; Result.Bottom:=Values[5];
  if not Result.Valid then raise Exception.Create('サイズは100～8000px、余白は0以上で用紙内に領域が残る値を指定してください。');
end;
procedure TComicNewProjectDialog.SetBasis(const Value: TComicPageBasis);
begin
  FFields[0].Text:=IntToStr(Value.Width); FFields[1].Text:=IntToStr(Value.Height);
  FFields[2].Text:=IntToStr(Value.Left); FFields[3].Text:=IntToStr(Value.Top);
  FFields[4].Text:=IntToStr(Value.Right); FFields[5].Text:=IntToStr(Value.Bottom);
  FList.ItemIndex:=-1;
  for var I:=0 to FPresets.Count-1 do if FPresets[I].Basis.Same(Value) then begin FList.ItemIndex:=I; Break; end;
end;
procedure TComicNewProjectDialog.PresetChanged(Sender: TObject);
begin if FList.ItemIndex>=0 then SetBasis(FPresets[FList.ItemIndex].Basis); end;
procedure TComicNewProjectDialog.Accept(Sender: TObject);
begin
  try
    Basis; if Trim(FFolder.Text)='' then raise Exception.Create('保存先を指定してください。');
    ModalResult:=mrOK;
  except on E: Exception do FStatus.Caption:=E.Message; end;
end;
function TComicNewProjectDialog.CreateProject(Characters: TObjectList<TComicAsset>): TComicProject;
begin Result:=CreateProjectAt(FFolder.Text,FTitle.Text,FEpisode.Text,FScript.Text,Basis,Characters); end;
function PasteComicScript(AOwner: TComponent; var Text: string): Boolean;
var Dialog: TForm; Memo: TMemo; Bar: TPanel; B: TButton;
begin
  Dialog:=TForm.CreateScaledNew(AOwner,OwnerControlPPI(AOwner));
  try
    Dialog.Caption:='台本を貼り付けて読み込む'; Dialog.Position:=poOwnerFormCenter;
    Dialog.Width:=MulDiv(700,Dialog.CurrentPPI,96); Dialog.Height:=MulDiv(560,Dialog.CurrentPPI,96);
    Bar:=TPanel.Create(Dialog); Bar.Parent:=Dialog; Bar.Align:=alBottom; Bar.Height:=MulDiv(48,Dialog.CurrentPPI,96);
    B:=TButton.Create(Dialog); B.Parent:=Bar; B.Align:=alRight; B.Caption:='取消'; B.Cancel:=True; B.ModalResult:=mrCancel;
    B:=TButton.Create(Dialog); B.Parent:=Bar; B.Align:=alRight; B.Caption:='読み込む'; B.ModalResult:=mrOK;
    Memo:=TMemo.Create(Dialog); Memo.Parent:=Dialog; Memo.Align:=alClient; Memo.ScrollBars:=ssBoth;
    Memo.WordWrap:=False; Memo.MaxLength:=1024*1024; Memo.Text:=Text;
    Dialog.ActiveControl:=Memo; Result:=Dialog.ShowModal=mrOK; if Result then Text:=Memo.Text;
  finally Dialog.Free; end;
end;
end.
