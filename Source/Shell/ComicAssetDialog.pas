unit ComicAssetDialog;
interface
uses System.SysUtils, System.Classes, System.IOUtils, System.Generics.Collections,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  Vcl.Dialogs, Vcl.Graphics, Vcl.Imaging.pngimage, Vcl.Imaging.jpeg, ComicModel;
type
  TAssetDialog = class(TForm)
  private
    FList: TObjectList<TComicAsset>;
    FProject: TComicProject;
    FCharacters: Boolean;
    FTree: TTreeView;
    FName: TEdit;
    FNotes: TMemo;
    FImage: TImage;
    FHint: TLabel;
    FCurrent: TComicAsset;
    FLoading: Boolean;
    procedure BuildTree;
    procedure Change(Sender: TObject; Node: TTreeNode);
    procedure Store;
    procedure AddItem(Sender: TObject);
    procedure ChooseImage(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure CloseCheck(Sender: TObject; var CanClose: Boolean);
  public
    constructor CreateManager(AOwner: TComponent; List: TObjectList<TComicAsset>;
      Project: TComicProject; Characters: Boolean);
  end;
implementation
constructor TAssetDialog.CreateManager(AOwner: TComponent; List: TObjectList<TComicAsset>;
  Project: TComicProject; Characters: Boolean);
var Left,Right,Bar: TPanel; B: TButton; L: TLabel;
  procedure Button(const Caption: string; X,W,Tag: Integer; Handler: TNotifyEvent);
  begin B:=TButton.Create(Self); B.Parent:=Bar; B.SetBounds(X,10,W,32); B.Caption:=Caption; B.Tag:=Tag; B.OnClick:=Handler; end;
begin
  inherited CreateNew(AOwner); FList:=List; FProject:=Project; FCharacters:=Characters;
  Position:=poOwnerFormCenter; Width:=940; Height:=680; Constraints.MinWidth:=760; Constraints.MinHeight:=580;
  Font.Name:='Yu Gothic UI'; Font.Size:=10;
  if Characters then Caption:='キャラクター管理 — 共通ライブラリ' else Caption:='画像管理 — '+Project.Title;
  Bar:=TPanel.Create(Self); Bar.Parent:=Self; Bar.Align:=alBottom; Bar.Height:=54; Bar.BevelOuter:=bvNone;
  if Characters then begin Button('人物を追加',12,130,0,AddItem); Button('服装を追加',150,130,1,AddItem); end
  else begin Button('新規場面',12,130,0,AddItem); Button('派生画像を追加',150,160,1,AddItem); end;
  Button('画像を登録',324,130,0,ChooseImage); Button('保存して閉じる',654,220,0,SaveClick);
  Left:=TPanel.Create(Self); Left.Parent:=Self; Left.Align:=alLeft; Left.Width:=250; Left.BevelOuter:=bvNone;
  FTree:=TTreeView.Create(Self); FTree.Parent:=Left; FTree.Align:=alClient; FTree.ReadOnly:=True; FTree.HideSelection:=False; FTree.OnChange:=Change;
  Right:=TPanel.Create(Self); Right.Parent:=Self; Right.Align:=alClient; Right.BevelOuter:=bvNone; Right.Padding.SetBounds(18,16,18,16);
  L:=TLabel.Create(Self); L.Parent:=Right; L.AutoSize:=False; L.Align:=alTop; L.Height:=24; L.Caption:='名前／服装名・場面名';
  FName:=TEdit.Create(Self); FName.Parent:=Right; FName.Align:=alTop; FName.Height:=30;
  FHint:=TLabel.Create(Self); FHint.Parent:=Right; FHint.AutoSize:=False; FHint.Align:=alBottom; FHint.Height:=44; FHint.WordWrap:=True;
  FHint.Caption:='名前と参照画像を登録してください。画像は管理フォルダーにコピーして保持します。';
  FNotes:=TMemo.Create(Self); FNotes.Parent:=Right; FNotes.Align:=alBottom; FNotes.Height:=130; FNotes.ScrollBars:=ssVertical;
  FImage:=TImage.Create(Self); FImage.Parent:=Right; FImage.Align:=alClient; FImage.Proportional:=True; FImage.Center:=True;
  OnCloseQuery:=CloseCheck; BuildTree;
end;
procedure TAssetDialog.Store;
var N: TTreeNode;
begin
  if FLoading or (FCurrent=nil) then Exit;
  FCurrent.Name:=Trim(FName.Text); FCurrent.Notes:=FNotes.Text;
  for N in FTree.Items do if N.Data=Pointer(FCurrent) then begin
    N.Text:=FCurrent.Name;
    if FCurrent.FileName='' then N.Text:=N.Text+'  [No Image]';
  end;
end;
procedure TAssetDialog.BuildTree;
var A,B: TComicAsset; Root,N,Child,Selected: TTreeNode;
begin
  FLoading:=True;
  try
    FTree.Items.Clear; Selected:=nil; Root:=nil;
    if FCharacters then Root:=FTree.Items.Add(nil,'人物');
    for A in FList do if A.ParentID='' then begin
      N:=FTree.Items.AddChildObject(Root,A.Name, A);
      if A.FileName='' then N.Text:=N.Text+'  [No Image]';
      if A=FCurrent then Selected:=N;
      for B in FList do if B.ParentID=A.ID then begin
        Child:=FTree.Items.AddChildObject(N,B.Name,B);
        if B.FileName='' then Child.Text:=Child.Text+'  [No Image]';
        if B=FCurrent then Selected:=Child;
      end;
    end;
    if Root<>nil then Root.Expand(False);
    if Selected<>nil then begin Selected.MakeVisible; FTree.Selected:=Selected; end;
  finally FLoading:=False; end;
  FCurrent:=nil; Change(FTree,FTree.Selected);
end;
procedure TAssetDialog.Change(Sender: TObject; Node: TTreeNode);
var Path: string;
begin
  if FLoading then Exit; Store; FCurrent:=nil; FImage.Picture.Assign(nil);
  if (Node<>nil) and (Node.Data<>nil) then FCurrent:=TComicAsset(Node.Data);
  FName.Enabled:=FCurrent<>nil; FNotes.Enabled:=FCurrent<>nil;
  FName.Text:=''; FNotes.Clear;
  if FCurrent=nil then Exit;
  FName.Text:=FCurrent.Name; FNotes.Text:=FCurrent.Notes;
  if FCurrent.FileName='' then Exit;
  if FCharacters then Path:=SafeChild(TPath.Combine(DataRoot,'Characters'),FCurrent.FileName)
  else Path:=FProject.ImagePath(FCurrent.ID);
  if FileExists(Path) then FImage.Picture.LoadFromFile(Path);
end;
procedure TAssetDialog.AddItem(Sender: TObject);
var A: TComicAsset; Parent: string;
begin
  Store; Parent:='';
  if TButton(Sender).Tag=1 then begin
    if FCurrent=nil then begin ShowMessage('親となる項目を選択してください。'); Exit; end;
    Parent:=FCurrent.ID; if FCurrent.ParentID<>'' then Parent:=FCurrent.ParentID;
  end;
  A:=TComicAsset.Create; A.ParentID:=Parent;
  if FCharacters then begin if Parent='' then A.Name:='新しい人物' else A.Name:='別の服装'; end
  else begin if Parent='' then A.Name:='新しい場面' else A.Name:='派生画像'; end;
  FList.Add(A); FCurrent:=A; BuildTree; FName.SetFocus; FName.SelectAll;
end;
procedure TAssetDialog.ChooseImage(Sender: TObject);
var D: TOpenDialog; P: TPicture; Root,Relative,Path: string;
begin
  if FCurrent=nil then begin ShowMessage('先に人物または場面を追加してください。'); Exit; end;
  D:=TOpenDialog.Create(Self); P:=TPicture.Create;
  try
    D.Filter:='画像 (*.png;*.jpg;*.jpeg;*.bmp)|*.png;*.jpg;*.jpeg;*.bmp';
    D.Options:=[ofFileMustExist,ofEnableSizing]; if not D.Execute then Exit;
    P.LoadFromFile(D.FileName);
    if (P.Width=0) or (P.Height=0) then raise Exception.Create('画像のサイズが不正です。');
    if FCharacters then begin Root:=TPath.Combine(DataRoot,'Characters'); Relative:=FCurrent.ID+'-'+NewUID+ExtractFileExt(D.FileName); end
    else begin Root:=FProject.Folder; Relative:='Images\'+FCurrent.ID+'-'+NewUID+ExtractFileExt(D.FileName); end;
    ForceDirectories(Root); Path:=SafeChild(Root,Relative); TFile.Copy(D.FileName,Path,False);
    FCurrent.FileName:=Relative; FImage.Picture.Assign(P); Store;
  finally P.Free; D.Free; end;
end;
procedure TAssetDialog.SaveClick(Sender: TObject);
begin ModalResult:=mrOK; end;
procedure TAssetDialog.CloseCheck(Sender: TObject; var CanClose: Boolean);
begin
  Store;
  if FCharacters then WriteAssets(FList,TPath.Combine(DataRoot,'Characters\Library.json'));
end;
end.
