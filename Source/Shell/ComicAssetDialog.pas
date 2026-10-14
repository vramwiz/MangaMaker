unit ComicAssetDialog;
interface
uses Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, System.Generics.Collections,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  Vcl.Dialogs, Vcl.Graphics, Vcl.Menus, Vcl.Imaging.pngimage, Vcl.Imaging.jpeg, ComicModel, ComicAssetEditing, ComicCharacterRefs;
type
  TAssetDialog = class(TForm)
  private
    FList: TObjectList<TComicAsset>;
    FProject: TComicProject;
    FCharacters,FWritable: Boolean;
    FTree: TTreeView;
    FName: TEdit;
    FNotes: TMemo;
    FImage: TImage;
    FHint: TLabel;
    FCurrent: TComicAsset;
    FCharacterName: TEdit;
    FCharacterNotes: TMemo;
    FPopup: TPopupMenu;
    FPromote: TMenuItem;
    FDragAsset: TComicAsset;
    FDragRootExpanded: Boolean;
    FPreviewError,FBaseHint: string;
    FCharacterList: TObjectList<TComicAsset>;
    FReferences: TButton;
    FAlternate,FTitle: TMenuItem;
    FLoading: Boolean;
    FGenerate,FCancelGeneration: TButton;
    FGenerationStatus: TLabel;
    FGenerationBusy: Boolean;
    FGenerationSessionID: string;
    FGenerateHandler,FCancelHandler: TNotifyEvent;
    procedure GenerateClick(Sender: TObject);
    procedure CancelGenerateClick(Sender: TObject);
    procedure UpdateGenerateButton;
    procedure BuildTree;
    procedure Change(Sender: TObject; Node: TTreeNode);
    procedure Store;
    procedure AddItem(Sender: TObject);
    procedure ChooseImage(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure CloseCheck(Sender: TObject; var CanClose: Boolean);
    procedure Popup(Sender: TObject);
    procedure PromoteClick(Sender: TObject);
    procedure StartTreeDrag(Sender: TObject; var DragObject: TDragObject);
    procedure EndTreeDrag(Sender,Target: TObject; X,Y: Integer);
    procedure TreeDragOver(Sender,Source: TObject; X,Y: Integer; State: TDragState; var Accept: Boolean);
    procedure TreeDragDrop(Sender,Source: TObject; X,Y: Integer);
    procedure ChooseReferences(Sender: TObject);
    procedure SceneVariantClick(Sender: TObject);
  public
    constructor CreateManager(AOwner: TComponent; List: TObjectList<TComicAsset>;
      Project: TComicProject; Characters: Boolean; Writable: Boolean=True; PresetHandler: TNotifyEvent=nil;
      CharacterList: TObjectList<TComicAsset>=nil; GenerateHandler: TNotifyEvent=nil; CancelHandler: TNotifyEvent=nil);
    destructor Destroy; override;
    procedure SetGenerationBusy(Busy: Boolean; const Status: string);
    procedure RefreshFromGenerated(const AssetID: string; Preview: TGraphic); virtual;
    property GenerateButton: TButton read FGenerate;
    property GenerationStatus: TLabel read FGenerationStatus;
    property GenerationBusy: Boolean read FGenerationBusy;
    property GenerationSessionID: string read FGenerationSessionID;
    procedure FlushDraft;
    procedure RefreshFromExternal;
    procedure SelectAsset(const ID: string);
    procedure SetGenerationSummary(const Name,Instructions: string);
    procedure PromoteSelected;
    procedure MoveAsset(const MovingID,BeforeID: string);
    procedure AddSceneVariant(const Mode: string);
    procedure ApplyReferences(const IDs: TArray<string>);
    property CurrentAsset: TComicAsset read FCurrent;
    property IsCharacters: Boolean read FCharacters;
    property DraftName: TEdit read FName;
    property DraftNotes: TMemo read FNotes;
    property PreviewError: string read FPreviewError;
    property AssetTree: TTreeView read FTree;
    property CommonName: TEdit read FCharacterName;
    property CommonNotes: TMemo read FCharacterNotes;
  end;
implementation
procedure TAssetDialog.FlushDraft;
begin Store; end;
procedure TAssetDialog.RefreshFromExternal;
begin BuildTree; end;
procedure TAssetDialog.SelectAsset(const ID: string);
var Node: TTreeNode;
begin for Node in FTree.Items do if (Node.Data<>nil) and (TComicAsset(Node.Data).ID=ID) then begin FTree.Selected:=Node; Exit; end; end;
constructor TAssetDialog.CreateManager(AOwner: TComponent; List: TObjectList<TComicAsset>;
  Project: TComicProject; Characters: Boolean; Writable: Boolean; PresetHandler: TNotifyEvent; CharacterList: TObjectList<TComicAsset>; GenerateHandler,CancelHandler: TNotifyEvent);
var Left,Right,Bar,Details: TPanel; B: TButton; L: TLabel;
  procedure Button(const Caption: string; X,W,Tag: Integer; Handler: TNotifyEvent);
  begin B:=TButton.Create(Self); B.Parent:=Bar; B.SetBounds(X,10,W,32); B.Caption:=Caption; B.Tag:=Tag; B.OnClick:=Handler; B.Enabled:=Writable or (Caption='保存して閉じる'); end;
begin
  inherited CreateNew(AOwner); FList:=List; FProject:=Project; FCharacters:=Characters; FWritable:=Writable; FCharacterList:=CharacterList;
  FGenerateHandler:=GenerateHandler; FCancelHandler:=CancelHandler; FGenerationSessionID:=NewUID;
  if Characters then NormalizeCharacters(List);
  Position:=poOwnerFormCenter; Width:=940; Height:=680; Constraints.MinWidth:=760; Constraints.MinHeight:=580;
  Font.Name:='Yu Gothic UI'; Font.Size:=10;
  if Characters then Caption:='キャラクター管理 — 共通ライブラリ' else Caption:='画像管理 — '+Project.Title;
  Bar:=TPanel.Create(Self); Bar.Parent:=Self; Bar.Align:=alBottom; Bar.Height:=54; Bar.BevelOuter:=bvNone;
  if Characters then begin Button('人物を追加',12,130,0,AddItem); Button('服装を追加',150,130,1,AddItem); end
  else begin Button('新規場面',12,130,0,AddItem); Button('派生画像を追加',150,160,1,AddItem); end;
  Button('画像を登録',324,130,0,ChooseImage); Button('保存して閉じる',654,220,0,SaveClick);
  if not Characters and Assigned(PresetHandler) then Button('生成プリセット',466,170,0,PresetHandler);
  if Assigned(GenerateHandler) then begin
    Bar.Height:=102;
    FGenerate:=TButton.Create(Self); FGenerate.Parent:=Bar; FGenerate.SetBounds(12,56,200,34);
    FGenerate.Caption:='Codexで画像生成'; FGenerate.OnClick:=GenerateClick;
    FCancelGeneration:=TButton.Create(Self); FCancelGeneration.Parent:=Bar; FCancelGeneration.SetBounds(220,56,100,34);
    FCancelGeneration.Caption:='生成を中止'; FCancelGeneration.OnClick:=CancelGenerateClick; FCancelGeneration.Enabled:=False;
    FGenerationStatus:=TLabel.Create(Self); FGenerationStatus.Parent:=Bar; FGenerationStatus.SetBounds(330,56,580,38);
    FGenerationStatus.AutoSize:=False; FGenerationStatus.WordWrap:=True; FGenerationStatus.Anchors:=[akLeft,akTop,akRight];
    FGenerationStatus.Caption:='対象の名前・説明を入力して、生成ボタンを押してください。';
  end;
  Left:=TPanel.Create(Self); Left.Parent:=Self; Left.Align:=alLeft; Left.Width:=250; Left.BevelOuter:=bvNone;
  FTree:=TTreeView.Create(Self); FTree.Parent:=Left; FTree.Align:=alClient; FTree.ReadOnly:=True; FTree.HideSelection:=False; FTree.OnChange:=Change;
  if Characters then begin
    FTree.DragMode:=dmAutomatic; FTree.OnStartDrag:=StartTreeDrag; FTree.OnEndDrag:=EndTreeDrag;
    FTree.OnDragOver:=TreeDragOver; FTree.OnDragDrop:=TreeDragDrop; FTree.RightClickSelect:=True;
    FPopup:=TPopupMenu.Create(Self); FPopup.OnPopup:=Popup; FTree.PopupMenu:=FPopup;
    FPromote:=TMenuItem.Create(Self); FPromote.Caption:='これを親にする'; FPromote.OnClick:=PromoteClick; FPopup.Items.Add(FPromote);
  end else begin
    FPopup:=TPopupMenu.Create(Self); FPopup.OnPopup:=Popup; FTree.PopupMenu:=FPopup; FTree.RightClickSelect:=True;
    FAlternate:=TMenuItem.Create(Self); FAlternate.Caption:='別位置の背景を追加'; FAlternate.Tag:=0; FAlternate.OnClick:=SceneVariantClick; FPopup.Items.Add(FAlternate);
    FTitle:=TMenuItem.Create(Self); FTitle.Caption:='タイトルを追加'; FTitle.Tag:=1; FTitle.OnClick:=SceneVariantClick; FPopup.Items.Add(FTitle);
  end;
  Right:=TPanel.Create(Self); Right.Parent:=Self; Right.Align:=alClient; Right.BevelOuter:=bvNone; Right.Padding.SetBounds(18,16,18,16);
  if Characters then begin
    L:=TLabel.Create(Self); L.Parent:=Right; L.AutoSize:=False; L.Align:=alTop; L.Height:=24; L.Caption:='人物名（全服装の共通情報）'; L.Top:=0;
    FCharacterName:=TEdit.Create(Self); FCharacterName.Parent:=Right; FCharacterName.Align:=alTop; FCharacterName.Height:=30; FCharacterName.Top:=24;
  end;
  L:=TLabel.Create(Self); L.Parent:=Right; L.AutoSize:=False; L.Align:=alTop; L.Height:=24; L.Caption:='名前／服装名・場面名';
  if Characters then begin L.Caption:='服装／見た目の状態名'; L.Top:=54; end;
  FName:=TEdit.Create(Self); FName.Parent:=Right; FName.Align:=alTop; FName.Height:=30;
  if Characters then FName.Top:=78;
  if not Characters then begin
    FReferences:=TButton.Create(Self); FReferences.Parent:=Right; FReferences.Align:=alTop; FReferences.Height:=34;
    FReferences.Top:=54; FReferences.Caption:='参照する人物・服装: 0件'; FReferences.OnClick:=ChooseReferences;
  end;
  FHint:=TLabel.Create(Self); FHint.Parent:=Right; FHint.AutoSize:=False; FHint.Align:=alBottom; FHint.Height:=44; FHint.WordWrap:=True;
  FHint.Caption:='名前と参照画像を登録してください。画像は管理フォルダーにコピーして保持します。';
  if not FWritable then begin
    Caption:=Caption+'（読み取りのみ）'; B.Caption:='閉じる';
    FHint.Caption:='ライブラリの読込に失敗したため保存を停止しています。元ファイルを確認・修復してから管理画面を開き直してください。';
  end;
  FNotes:=TMemo.Create(Self); FNotes.Parent:=Right; FNotes.Align:=alBottom; FNotes.Height:=130; FNotes.ScrollBars:=ssVertical;
  if Characters then begin
    Details:=TPanel.Create(Self); Details.Parent:=Right; Details.Align:=alBottom; Details.Height:=228; Details.BevelOuter:=bvNone;
    FNotes.Parent:=Details; FNotes.Align:=alNone; FNotes.SetBounds(0,138,Details.ClientWidth,90); FNotes.Anchors:=[akLeft,akTop,akRight];
    FCharacterNotes:=TMemo.Create(Self); FCharacterNotes.Parent:=Details; FCharacterNotes.SetBounds(0,24,Details.ClientWidth,80);
    FCharacterNotes.Anchors:=[akLeft,akTop,akRight]; FCharacterNotes.ScrollBars:=ssVertical;
    L:=TLabel.Create(Self); L.Parent:=Details; L.SetBounds(0,0,Details.ClientWidth,24); L.Caption:='人物共通の外見補足';
    L:=TLabel.Create(Self); L.Parent:=Details; L.SetBounds(0,114,Details.ClientWidth,24); L.Caption:='この服装・状態の補足';
  end;
  FImage:=TImage.Create(Self); FImage.Parent:=Right; FImage.Align:=alClient; FImage.Proportional:=True; FImage.Center:=True;
  FBaseHint:=FHint.Caption; OnCloseQuery:=CloseCheck; BuildTree;
  if not Characters then SetGenerationSummary(Project.GenerationPresetName,Project.GenerationInstructions);
end;
destructor TAssetDialog.Destroy;
begin if Assigned(FCancelHandler) then FCancelHandler(Self); inherited; end;
procedure TAssetDialog.UpdateGenerateButton;
begin if FGenerate<>nil then FGenerate.Enabled:=FWritable and (FCurrent<>nil) and not FGenerationBusy; end;
procedure TAssetDialog.SetGenerationBusy(Busy: Boolean; const Status: string);
begin
  FGenerationBusy:=Busy; UpdateGenerateButton;
  if FCancelGeneration<>nil then FCancelGeneration.Enabled:=Busy;
  if FGenerationStatus<>nil then FGenerationStatus.Caption:=Status;
end;
procedure TAssetDialog.GenerateClick(Sender: TObject);
begin if FWritable and not FGenerationBusy and (FCurrent<>nil) and Assigned(FGenerateHandler) then begin Store; FGenerateHandler(Self); end; end;
procedure TAssetDialog.CancelGenerateClick(Sender: TObject);
begin if Assigned(FCancelHandler) then FCancelHandler(Self); end;
procedure TAssetDialog.RefreshFromGenerated(const AssetID: string; Preview: TGraphic);
var N: TTreeNode; A: TComicAsset;
begin
  for N in FTree.Items do if N.Data<>nil then begin A:=TComicAsset(N.Data); N.Text:=A.Name; if A.FileName='' then N.Text:=N.Text+'  [No Image]'; end;
  if (FCurrent<>nil) and (FCurrent.ID=AssetID) and (Preview<>nil) then begin
    FImage.Picture.Assign(Preview); FPreviewError:=''; FHint.Caption:=FBaseHint;
  end;
end;
procedure TAssetDialog.SetGenerationSummary(const Name,Instructions: string);
begin
  if FCharacters then Exit;
  FHint.Height:=64;
  if Name='' then FBaseHint:='生成指示: 未選択。生成プリセットで共通指示を選び、作品に適用できます。'
  else FBaseHint:='生成指示: '+Name+sLineBreak+Copy(StringReplace(Instructions,sLineBreak,' ',[rfReplaceAll]),1,160);
  FHint.Caption:=FBaseHint; if FPreviewError<>'' then FHint.Caption:=FHint.Caption+sLineBreak+'参照画像の表示: '+FPreviewError;
end;
procedure TAssetDialog.Store;
var N: TTreeNode;
begin
  if not FWritable or FLoading or (FCurrent=nil) then Exit;
  FCurrent.Name:=Trim(FName.Text); FCurrent.Notes:=FNotes.Text;
  if FCharacters then begin
    FCurrent.StateName:=Trim(FName.Text); SetCharacterInfo(FList,FCurrent,FCharacterName.Text,FCharacterNotes.Text);
    if FCurrent.ParentID='' then FCurrent.Name:=FCurrent.CharacterName;
  end;
  for N in FTree.Items do if N.Data=Pointer(FCurrent) then begin
    N.Text:=FCurrent.Name;
    if FCurrent.FileName='' then N.Text:=N.Text+'  [No Image]';
  end;
end;
procedure TAssetDialog.BuildTree;
var A,B: TComicAsset; Root,N,Child,Selected: TTreeNode; Expanded: TList<string>;
begin
  Expanded:=TList<string>.Create;
  for N in FTree.Items do if (N.Data<>nil) and N.Expanded then Expanded.Add(TComicAsset(N.Data).ID);
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
      if Expanded.Contains(A.ID) then N.Expand(False);
    end;
    if Root<>nil then Root.Expand(False);
    if Selected<>nil then begin Selected.MakeVisible; FTree.Selected:=Selected; end;
  finally FLoading:=False; Expanded.Free; end;
  FCurrent:=nil; Change(FTree,FTree.Selected);
end;
procedure TAssetDialog.Change(Sender: TObject; Node: TTreeNode);
var Path: string;
begin
  if FLoading then Exit; Store; FCurrent:=nil; FImage.Picture.Assign(nil); FPreviewError:=''; FHint.Caption:=FBaseHint;
  if FCharacters then FHint.Height:=MulDiv(44,CurrentPPI,96) else FHint.Height:=MulDiv(64,CurrentPPI,96);
  if (Node<>nil) and (Node.Data<>nil) then FCurrent:=TComicAsset(Node.Data);
  FName.Enabled:=FWritable and (FCurrent<>nil); FNotes.Enabled:=FWritable and (FCurrent<>nil);
  FName.Text:=''; FNotes.Clear;
  if FCharacters then begin FCharacterName.Clear; FCharacterNotes.Clear; FCharacterName.Enabled:=FWritable and (FCurrent<>nil); FCharacterNotes.Enabled:=FCharacterName.Enabled; end;
  if FReferences<>nil then begin FReferences.Enabled:=FWritable and (FCurrent<>nil) and (FCurrent.ParentID<>'') and (FCharacterList<>nil); FReferences.Caption:='参照する人物・服装: 0件'; end;
  UpdateGenerateButton;
  if FCurrent=nil then Exit;
  FName.Text:=FCurrent.Name; FNotes.Text:=FCurrent.Notes;
  if FCharacters then begin FName.Text:=FCurrent.StateName; FCharacterName.Text:=FCurrent.CharacterName; FCharacterNotes.Text:=FCurrent.CharacterNotes; end;
  if FReferences<>nil then FReferences.Caption:='参照する人物・服装: '+IntToStr(Length(FCurrent.CharacterRefs))+'件';
  if FCurrent.FileName='' then Exit;
  if FCharacters then Path:=SafeChild(TPath.Combine(DataRoot,'Characters'),FCurrent.FileName)
  else Path:=FProject.ImagePath(FCurrent.ID);
  try
    if not FileExists(Path) then raise Exception.Create('ファイルが見つかりません。');
    FImage.Picture.LoadFromFile(Path);
  except on E: Exception do begin
    FImage.Picture.Assign(nil); FPreviewError:=E.Message;
    FHint.Height:=MulDiv(88,CurrentPPI,96);
    FHint.Caption:=FBaseHint+sLineBreak+'参照画像を表示できません。元の登録は保持しています。'+E.Message;
  end; end;
end;
procedure TAssetDialog.AddItem(Sender: TObject);
var A: TComicAsset; Parent,Mode: string;
begin
  if not FWritable then Exit;
  Store; Parent:='';
  if TButton(Sender).Tag=1 then begin
    if FCurrent=nil then begin ShowMessage('親となる項目を選択してください。'); Exit; end;
    Parent:=FCurrent.ID; if FCurrent.ParentID<>'' then Parent:=FCurrent.ParentID;
  end;
  if FCharacters then begin A:=TComicAsset.Create; A.ParentID:=Parent; if Parent='' then A.Name:='新しい人物' else A.Name:='別の服装'; end
  else begin
    if Parent='' then Mode:='scene' else Mode:='child';
    A:=NewSceneAsset(FList,FCurrent,Mode,'新しい場面','',FProject.Title,FProject.Episode);
    if Parent<>'' then A.Name:='派生画像';
  end;
  FList.Add(A); if FCharacters then NormalizeCharacters(FList);
  FCurrent:=A; BuildTree;
  if FCharacters and (Parent='') then begin FCharacterName.SetFocus; FCharacterName.SelectAll; end else begin FName.SetFocus; FName.SelectAll; end;
end;
procedure TAssetDialog.ChooseImage(Sender: TObject);
var D: TOpenDialog; P: TPicture; Root,Relative,Path: string;
begin
  if not FWritable then Exit;
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
procedure TAssetDialog.Popup(Sender: TObject);
begin
  if FCharacters then FPromote.Enabled:=FWritable and (FCurrent<>nil) and (FCurrent.ParentID<>'')
  else begin FAlternate.Enabled:=FWritable and (FCurrent<>nil); FTitle.Enabled:=FWritable and (FCurrent<>nil) and (FCurrent.ParentID<>''); end;
end;
procedure TAssetDialog.ChooseReferences(Sender: TObject);
var Dialog: TComicCharacterRefDialog;
begin
  if (FCurrent=nil) or not FWritable or FCharacters or (FCurrent.ParentID='') or (FCharacterList=nil) then Exit;
  Dialog:=TComicCharacterRefDialog.CreateSelector(Self,FCharacterList,FCurrent.CharacterRefs);
  try if Dialog.ShowModal=mrOK then ApplyReferences(Dialog.SelectedIDs); finally Dialog.Free; end;
end;
procedure TAssetDialog.ApplyReferences(const IDs: TArray<string>);
begin
  if not FWritable or FCharacters or (FCurrent=nil) or (FCurrent.ParentID='') then Exit;
  FCurrent.CharacterRefs:=Copy(IDs); FReferences.Caption:='参照する人物・服装: '+IntToStr(Length(IDs))+'件';
end;
procedure TAssetDialog.SceneVariantClick(Sender: TObject);
begin if TMenuItem(Sender).Tag=0 then AddSceneVariant('alternate_scene') else AddSceneVariant('title'); end;
procedure TAssetDialog.AddSceneVariant(const Mode: string);
var Asset: TComicAsset; Name: string;
begin
  if FCharacters or not FWritable or (FCurrent=nil) then Exit; Store;
  if Mode='alternate_scene' then Name:='別位置の背景' else if Mode='title' then Name:='タイトル用画像' else raise Exception.Create('追加方式が不正です。');
  Asset:=NewSceneAsset(FList,FCurrent,Mode,Name,'',FProject.Title,FProject.Episode); FList.Add(Asset); FCurrent:=Asset; BuildTree;
end;
procedure TAssetDialog.PromoteClick(Sender: TObject);
begin PromoteSelected; end;
procedure TAssetDialog.PromoteSelected;
var Before: TArray<TComicAssetState>;
begin
  if not FCharacters or not FWritable or (FCurrent=nil) or (FCurrent.ParentID='') then Exit;
  Store; Before:=CaptureAssets(FList);
  try
    if not PromoteCharacter(FList,FCurrent) then Exit;
    WriteAssets(FList,TPath.Combine(DataRoot,'Characters\Library.json'));
  except RestoreAssets(FList,Before); BuildTree; raise; end;
  BuildTree;
end;
procedure TAssetDialog.MoveAsset(const MovingID,BeforeID: string);
var Before: TArray<TComicAssetState>;
begin
  if not FCharacters or not FWritable then Exit; Store; Before:=CaptureAssets(FList);
  try
    if not ReorderCharacter(FList,AssetByID(FList,MovingID),AssetByID(FList,BeforeID)) then Exit;
    WriteAssets(FList,TPath.Combine(DataRoot,'Characters\Library.json'));
  except RestoreAssets(FList,Before); BuildTree; raise; end;
  BuildTree;
end;
procedure TAssetDialog.StartTreeDrag(Sender: TObject; var DragObject: TDragObject);
begin
  FDragAsset:=nil; if not FWritable or (FTree.Selected=nil) or (FTree.Selected.Data=nil) then Exit;
  FDragAsset:=TComicAsset(FTree.Selected.Data); FDragRootExpanded:=FTree.Selected.Expanded;
  if FDragAsset.ParentID='' then FTree.Selected.Collapse(False);
end;
procedure TAssetDialog.EndTreeDrag(Sender,Target: TObject; X,Y: Integer);
var Node: TTreeNode;
begin
  if (FDragAsset<>nil) and FDragRootExpanded then for Node in FTree.Items do if Node.Data=Pointer(FDragAsset) then begin Node.Expand(False); Break; end;
  FDragAsset:=nil;
end;
procedure TAssetDialog.TreeDragOver(Sender,Source: TObject; X,Y: Integer; State: TDragState; var Accept: Boolean);
var Node: TTreeNode; Target: TComicAsset;
begin
  Node:=FTree.GetNodeAt(X,Y); Accept:=False;
  if not FWritable or (Source<>FTree) or (FDragAsset=nil) or (Node=nil) or (Node.Data=nil) then Exit;
  Target:=TComicAsset(Node.Data);
  if FDragAsset.ParentID='' then Accept:=CharacterRoot(FList,Target)<>FDragAsset
  else Accept:=(Target<>FDragAsset) and ((Target.ParentID=FDragAsset.ParentID) or (Target.ID=FDragAsset.ParentID));
end;
procedure TAssetDialog.TreeDragDrop(Sender,Source: TObject; X,Y: Integer);
var Node: TTreeNode; Accept: Boolean;
begin
  TreeDragOver(Sender,Source,X,Y,dsDragMove,Accept); if not Accept then Exit;
  Node:=FTree.GetNodeAt(X,Y); MoveAsset(FDragAsset.ID,TComicAsset(Node.Data).ID);
end;
procedure TAssetDialog.CloseCheck(Sender: TObject; var CanClose: Boolean);
begin
  if Assigned(FCancelHandler) then FCancelHandler(Self);
  if not FWritable then Exit;
  Store;
  if FCharacters then WriteAssets(FList,TPath.Combine(DataRoot,'Characters\Library.json'));
end;
end.
