unit ComicEffectDialog;

// 責務：共通効果素材の管理画面を提供し、変更を編集側へ通知する。

interface

uses System.Classes, System.SysUtils, System.UITypes, System.Generics.Collections, Vcl.Forms, Vcl.Controls,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics, ComicEffects;

type
  TComicEffectDialog = class(TForm)
  private
    FMaterials: TObjectList<TComicEffectMaterial>;
    FWritable: Boolean;
    FLibraryPath: string;
    FList: TListBox;
    FImage: TImage;
    FHint: TLabel;
    FImport,FRename,FDelete: TButton;
    FOnChanged: TNotifyEvent;
    procedure Selection(Sender: TObject);
    procedure ImportClick(Sender: TObject);
    procedure RenameClick(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
    function Current: TComicEffectMaterial;
    procedure RefreshList(const ID: string='');
  public
    constructor CreateManager(AOwner: TComponent; Materials: TObjectList<TComicEffectMaterial>; Writable: Boolean; const LibraryPath: string; Changed: TNotifyEvent=nil);
    procedure SelectMaterial(const ID: string);
    function ImportMaterial(const Name,Source: string): string;
    procedure RenameSelected(const Name: string);
    procedure DeleteSelected;
  end;

implementation

uses Vcl.Dialogs, Vcl.Imaging.pngimage, System.IOUtils, System.Math;

constructor TComicEffectDialog.CreateManager(AOwner: TComponent; Materials: TObjectList<TComicEffectMaterial>; Writable: Boolean; const LibraryPath: string; Changed: TNotifyEvent);
var Bar,Right: TPanel; Button: TButton;
  function Action(const Caption: string; Width: Integer; Handler: TNotifyEvent): TButton;
  begin
    Result:=TButton.Create(Self); Result.Parent:=Bar; Result.AlignWithMargins:=True; Result.Margins.SetBounds(0,0,10,0);
    Result.Width:=Width; Result.Align:=alLeft; Result.Caption:=Caption; Result.OnClick:=Handler;
  end;
begin
  inherited CreateNew(AOwner); FMaterials:=Materials; FWritable:=Writable; FLibraryPath:=LibraryPath; FOnChanged:=Changed;
  Caption:='漫画効果素材 — 共通ライブラリ'; Width:=880; Height:=640; Constraints.MinWidth:=750; Constraints.MinHeight:=450;
  Position:=poOwnerFormCenter; Font.Name:='Yu Gothic UI'; Font.Size:=10;
  Bar:=TPanel.Create(Self); Bar.Parent:=Self; Bar.Align:=alBottom; Bar.Height:=54; Bar.Padding.SetBounds(12,10,12,10); Bar.BevelOuter:=bvNone;
  FImport:=Action('PNGを登録',140,ImportClick); FRename:=Action('名前変更',120,RenameClick); FDelete:=Action('削除',100,DeleteClick);
  Button:=TButton.Create(Self); Button.Parent:=Bar; Button.Align:=alRight; Button.Width:=140; Button.Caption:='閉じる'; Button.ModalResult:=mrCancel; Button.Cancel:=True;
  FList:=TListBox.Create(Self); FList.Parent:=Self; FList.Align:=alLeft; FList.Width:=230; FList.OnClick:=Selection;
  Right:=TPanel.Create(Self); Right.Parent:=Self; Right.Align:=alClient; Right.Padding.SetBounds(12,12,12,12); Right.BevelOuter:=bvNone;
  FHint:=TLabel.Create(Self); FHint.Parent:=Right; FHint.AutoSize:=False; FHint.Align:=alBottom; FHint.Height:=64; FHint.WordWrap:=True;
  FImage:=TImage.Create(Self); FImage.Parent:=Right; FImage.Align:=alClient; FImage.Proportional:=True; FImage.Center:=True;
  RefreshList;
end;
function TComicEffectDialog.Current: TComicEffectMaterial;
begin Result:=nil; if FList.ItemIndex>=0 then Result:=TComicEffectMaterial(FList.Items.Objects[FList.ItemIndex]); end;
procedure TComicEffectDialog.RefreshList(const ID: string);
var Material: TComicEffectMaterial; At: Integer;
begin
  At:=FList.ItemIndex; FList.Items.BeginUpdate;
  try FList.Clear; for Material in FMaterials do FList.Items.AddObject(Material.Name,Material);
    if ID<>'' then begin SelectMaterial(ID); Exit; end; FList.ItemIndex:=Min(At,FList.Count-1);
  finally FList.Items.EndUpdate; end;
  Selection(nil);
end;
procedure TComicEffectDialog.SelectMaterial(const ID: string);
var I: Integer;
begin for I:=0 to FList.Count-1 do if TComicEffectMaterial(FList.Items.Objects[I]).ID=ID then begin FList.ItemIndex:=I; Selection(nil); Exit; end; end;
procedure TComicEffectDialog.Selection(Sender: TObject);
var Material: TComicEffectMaterial;
begin
  Material:=Current; FImport.Enabled:=FWritable; FRename.Enabled:=FWritable and (Material<>nil) and not Material.BuiltIn; FDelete.Enabled:=FRename.Enabled;
  FImage.Picture.Assign(nil); FHint.Caption:='透明PNGなどの素材を登録します。削除しても配置済み作品の素材は保持します。';
  if not FWritable then FHint.Caption:='ライブラリの読込失敗により保存を停止しています。元ファイルを確認して開き直してください。';
  if Material<>nil then
    try FImage.Picture.LoadFromFile(EffectMaterialPath(Material));
    except on E: Exception do begin FImage.Picture.Assign(nil); FHint.Caption:='参照画像を表示できません。登録は保持します。'+E.Message; end; end;
end;
function TComicEffectDialog.ImportMaterial(const Name,Source: string): string;
var Material: TComicEffectMaterial;
begin
  if not FWritable then raise Exception.Create('効果素材ライブラリは読み取りのみです。');
  Material:=ImportEffectMaterial(FMaterials,Name,Source,FLibraryPath); Result:=Material.ID;
  if Assigned(FOnChanged) then FOnChanged(Self); RefreshList(Result);
end;
procedure TComicEffectDialog.RenameSelected(const Name: string);
var ID: string;
begin if not FWritable or (Current=nil) then Exit; ID:=Current.ID; RenameEffectMaterial(FMaterials,Current,Name,FLibraryPath);
  if Assigned(FOnChanged) then FOnChanged(Self); RefreshList(ID); end;
procedure TComicEffectDialog.DeleteSelected;
begin if not FWritable or (Current=nil) then Exit; DeleteEffectMaterial(FMaterials,Current,FLibraryPath);
  if Assigned(FOnChanged) then FOnChanged(Self); RefreshList; end;
procedure TComicEffectDialog.ImportClick(Sender: TObject);
var Dialog: TOpenDialog; Name: string;
begin
  Dialog:=TOpenDialog.Create(Self);
  try Dialog.Filter:='PNG素材 (*.png)|*.png'; Dialog.Options:=[ofFileMustExist,ofEnableSizing]; if not Dialog.Execute then Exit;
    Name:=TPath.GetFileNameWithoutExtension(Dialog.FileName); if not InputQuery('素材を登録','素材名',Name) then Exit; ImportMaterial(Name,Dialog.FileName);
  finally Dialog.Free; end;
end;
procedure TComicEffectDialog.RenameClick(Sender: TObject);
var Name: string;
begin if Current=nil then Exit; Name:=Current.Name; if InputQuery('効果素材の名前変更','素材名',Name) then RenameSelected(Name); end;
procedure TComicEffectDialog.DeleteClick(Sender: TObject);
begin if Current=nil then Exit; if MessageDlg('共通素材「'+Current.Name+'」を削除しますか？配置済み作品は保持します。',mtConfirmation,[mbYes,mbNo],0)=mrYes then DeleteSelected; end;

end.
