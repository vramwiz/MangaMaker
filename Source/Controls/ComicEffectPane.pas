unit ComicEffectPane;

// 責務：素材の分類・ドロップ登録・生成入力を同じ画面に置き、生成要求の寿命と登録先を固定する。
interface
uses System.Classes, System.SysUtils, System.Types, System.Generics.Collections,
  Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Menus, ListBoxEdit,
  ComicFileDropList, ComicEffects, ComicEffectGroups, ComicEffectGeneration;
type
  TComicEffectPane = class(TPanel)
  private
    FStore: TObjectList<TComicEffectMaterial>;
    FGroups: TComicEffectGroups;
    FGroupList: TListBoxEdit;
    FMaterials: TComicFileDropList;
    FNote: TMemo;
    FSend,FStop: TButton;
    FStatus: TLabel;
    FGroupMenu,FMaterialMenu: TPopupMenu;
    FAddGroup,FDeleteGroup,FMoveMenu,FRenameMaterial,FDeleteMaterial: TMenuItem;
    FTimer: TTimer;
    FWritable,FBusy,FRefreshing: Boolean;
    FSelectedGroup,FContextGroup,FContextMaterial,FRequestedGroup,FRequestedName: string;
    FLibraryPath: string;
    FGeneration: IComicEffectGeneration;
    FFactory: TComicEffectGenerationFactory;
    FOnChanged: TNotifyEvent;
    procedure GroupChanged(Sender: TObject);
    procedure GroupEdited(Sender: TObject; const Value: string; const Index: Integer);
    procedure CanEditGroup(Sender: TObject; Index: Integer; var CanEdit: Boolean);
    procedure GroupContext(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
    procedure MaterialContext(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
    procedure AddGroupClick(Sender: TObject);
    procedure DeleteGroupClick(Sender: TObject);
    procedure MoveClick(Sender: TObject);
    procedure RenameMaterialClick(Sender: TObject);
    procedure DeleteMaterialClick(Sender: TObject);
    procedure FilesDropped(Sender: TObject; const Files: TArray<string>);
    procedure SendClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
    procedure NoteChanged(Sender: TObject);
    procedure UpdateControls;
    procedure RequireWritable;
    function PutInGroup(Material: TComicEffectMaterial; const GroupID: string): string;
  public
    constructor CreatePane(AOwner: TComponent; AParent: TWinControl; Store: TObjectList<TComicEffectMaterial>; Writable: Boolean; Changed: TNotifyEvent);
    destructor Destroy; override;
    procedure Refresh;
    procedure SelectGroup(const ID: string);
    function AddGroup(const Name: string): string;
    procedure RenameGroup(const ID,Name: string);
    procedure RemoveGroup(const ID: string);
    procedure MoveMaterial(const MaterialID,GroupID: string);
    procedure RenameMaterial(const MaterialID,Name: string);
    procedure RemoveMaterial(const MaterialID: string);
    procedure ImportFiles(const Files: TArray<string>);
    procedure StartGeneration(const Instruction: string);
    procedure PollGeneration(Sender: TObject);
    property MaterialList: TComicFileDropList read FMaterials;
    property GroupList: TListBoxEdit read FGroupList;
    property SelectedGroup: string read FSelectedGroup;
    property Busy: Boolean read FBusy;
    property SendButton: TButton read FSend;
    property CancelButton: TButton read FStop;
    property Instruction: TMemo read FNote;
    property Status: TLabel read FStatus;
    property GenerationFactory: TComicEffectGenerationFactory read FFactory write FFactory;
  end;
implementation
uses System.IOUtils, System.UITypes, Vcl.Forms, Vcl.Dialogs, Winapi.Windows,
  ComicModel, ComicEffectRegistration;
constructor TComicEffectPane.CreatePane(AOwner: TComponent; AParent: TWinControl; Store: TObjectList<TComicEffectMaterial>; Writable: Boolean; Changed: TNotifyEvent);
var Footer,Buttons: TPanel; Title: TLabel;
  function D(Value: Integer): Integer; begin Result:=MulDiv(Value,CurrentPPI,96); end;
begin
  inherited Create(AOwner);
  // リスト更新でHWNDが必要になるため、子コントロールの作成より先に親を確定する。
  Parent:=AParent; BevelOuter:=bvLowered; BevelWidth:=1; FStore:=Store; FWritable:=Writable; FOnChanged:=Changed;
  FLibraryPath:=TPath.Combine(DataRoot,'Effects\Library.json'); FSelectedGroup:=UngroupedEffectID; FFactory:=NewComicEffectGeneration;
  FGroups:=TComicEffectGroups.Create(TPath.Combine(DataRoot,'Effects\Groups.json'));
  Title:=TLabel.Create(Self); Title.Parent:=Self; Title.Align:=alTop; Title.Height:=D(20); Title.Caption:='グループ';
  FGroupList:=TListBoxEdit.Create(Self); FGroupList.Parent:=Self; FGroupList.Top:=D(20); FGroupList.Align:=alTop; FGroupList.Height:=D(72);
  FGroupList.OnClick:=GroupChanged; FGroupList.OnItemEdited:=GroupEdited; FGroupList.OnCanEdit:=CanEditGroup;
  FGroupList.Hint:='ダブルクリックで名前変更。右クリックで追加・削除。'; FGroupList.ShowHint:=True;
  Footer:=TPanel.Create(Self); Footer.Parent:=Self; Footer.Align:=alBottom; Footer.Height:=D(150); Footer.BevelOuter:=bvLowered; Footer.BevelWidth:=1;
  Title:=TLabel.Create(Self); Title.Parent:=Footer; Title.Align:=alTop; Title.Height:=D(18); Title.Caption:='作りたい効果をメモして送信';
  FNote:=TMemo.Create(Self); FNote.Parent:=Footer; FNote.Top:=D(18); FNote.Align:=alTop; FNote.Height:=D(64);
  FNote.MaxLength:=8000; FNote.ScrollBars:=ssVertical; FNote.OnChange:=NoteChanged;
  FNote.Hint:='例：中央に余白のある集中線／右向きのスピード線／小さなキラキラ'; FNote.ShowHint:=True;
  Buttons:=TPanel.Create(Self); Buttons.Parent:=Footer; Buttons.Top:=D(82); Buttons.Align:=alTop; Buttons.Height:=D(32); Buttons.BevelOuter:=bvNone;
  FStop:=TButton.Create(Self); FStop.Parent:=Buttons; FStop.Align:=alRight; FStop.Width:=D(60); FStop.Caption:='中止'; FStop.OnClick:=CancelClick;
  FSend:=TButton.Create(Self); FSend.Parent:=Buttons; FSend.Align:=alClient; FSend.Caption:='Codexへ送信'; FSend.OnClick:=SendClick;
  FStatus:=TLabel.Create(Self); FStatus.Parent:=Footer; FStatus.AutoSize:=False; FStatus.Align:=alClient; FStatus.WordWrap:=True;
  FStatus.Caption:='PNGを素材一覧へドロップして登録できます。';
  FMaterials:=TComicFileDropList.Create(Self); FMaterials.Parent:=Self; FMaterials.Align:=alClient; FMaterials.Style:=lbOwnerDrawFixed;
  FMaterials.OnFilesDropped:=FilesDropped; FMaterials.DragMode:=dmAutomatic;
  FGroupMenu:=TPopupMenu.Create(Self); FGroupList.PopupMenu:=FGroupMenu; FGroupList.OnContextPopup:=GroupContext;
  FAddGroup:=TMenuItem.Create(Self); FAddGroup.Caption:='グループを追加...'; FAddGroup.OnClick:=AddGroupClick; FGroupMenu.Items.Add(FAddGroup);
  FDeleteGroup:=TMenuItem.Create(Self); FDeleteGroup.Caption:='グループを削除'; FDeleteGroup.OnClick:=DeleteGroupClick; FGroupMenu.Items.Add(FDeleteGroup);
  FMaterialMenu:=TPopupMenu.Create(Self); FMaterials.PopupMenu:=FMaterialMenu; FMaterials.OnContextPopup:=MaterialContext;
  FMoveMenu:=TMenuItem.Create(Self); FMoveMenu.Caption:='グループへ移動'; FMaterialMenu.Items.Add(FMoveMenu);
  FRenameMaterial:=TMenuItem.Create(Self); FRenameMaterial.Caption:='素材名を変更...'; FRenameMaterial.OnClick:=RenameMaterialClick; FMaterialMenu.Items.Add(FRenameMaterial);
  FDeleteMaterial:=TMenuItem.Create(Self); FDeleteMaterial.Caption:='共通素材の登録を削除'; FDeleteMaterial.OnClick:=DeleteMaterialClick; FMaterialMenu.Items.Add(FDeleteMaterial);
  FTimer:=TTimer.Create(Self); FTimer.Enabled:=False; FTimer.Interval:=200; FTimer.OnTimer:=PollGeneration;
  try FGroups.Load;
  except on E: Exception do begin FWritable:=False; FStatus.Caption:='グループを読み込めません。保存を停止しました：'+E.Message; end; end;
  Refresh;
end;
destructor TComicEffectPane.Destroy;
begin
  // 終了後のタイマー登録を防ぎ、所有する要求だけを中止してから共有素材の参照を手放す。
  if FTimer<>nil then FTimer.Enabled:=False;
  if FGroupList<>nil then begin FGroupList.OnItemEdited:=nil; FGroupList.OnClick:=nil; end;
  if FGeneration<>nil then FGeneration.Cancel; FGeneration:=nil;
  FGroups.Free; inherited;
end;
procedure TComicEffectPane.RequireWritable;
begin
  if not FWritable then raise Exception.Create('素材またはグループの読込に失敗したため、登録・変更を停止しています。');
  if FBusy then raise Exception.Create('生成が完了するまで登録・グループ変更はできません。');
end;
procedure TComicEffectPane.UpdateControls;
var Material: TComicEffectMaterial;
begin
  FSend.Enabled:=FWritable and not FBusy and (Trim(FNote.Text)<>''); FStop.Enabled:=FBusy;
  FGroupList.Enabled:=not FBusy; FNote.ReadOnly:=FBusy or not FWritable;
  FAddGroup.Enabled:=FWritable and not FBusy; FDeleteGroup.Enabled:=FAddGroup.Enabled and (FContextGroup<>'') and (FContextGroup<>UngroupedEffectID);
  FMoveMenu.Enabled:=FWritable and not FBusy and (FContextMaterial<>'');
  Material:=FindEffectMaterial(FStore,FContextMaterial);
  FRenameMaterial.Enabled:=FWritable and not FBusy and (Material<>nil);
  if Material<>nil then FRenameMaterial.Enabled:=FRenameMaterial.Enabled and not Material.BuiltIn;
  FDeleteMaterial.Enabled:=FRenameMaterial.Enabled;
end;
procedure TComicEffectPane.Refresh;
var Group: TComicEffectGroup; Material: TComicEffectMaterial; SelectedID: string; I: Integer;
begin
  if FRefreshing then Exit; FRefreshing:=True;
  try
    SelectedID:=''; if FMaterials.ItemIndex>=0 then SelectedID:=TComicEffectMaterial(FMaterials.Items.Objects[FMaterials.ItemIndex]).ID;
    if FGroups.Find(FSelectedGroup)=nil then FSelectedGroup:=UngroupedEffectID;
    FGroupList.Items.BeginUpdate; FMaterials.Items.BeginUpdate;
    try
      FGroupList.Clear;
      for Group in FGroups.Groups do begin I:=FGroupList.Items.AddObject(Group.Name,Group); if Group.ID=FSelectedGroup then FGroupList.ItemIndex:=I; end;
      FMaterials.Clear;
      for Material in FStore do if FGroups.GroupOf(Material.ID)=FSelectedGroup then begin
        I:=FMaterials.Items.AddObject(Material.Name,Material); if Material.ID=SelectedID then FMaterials.ItemIndex:=I;
      end;
      if (FMaterials.ItemIndex<0) and (FMaterials.Count>0) then FMaterials.ItemIndex:=0;
    finally FMaterials.Items.EndUpdate; FGroupList.Items.EndUpdate; end;
    UpdateControls;
  finally FRefreshing:=False; end;
end;
procedure TComicEffectPane.SelectGroup(const ID: string);
begin if FBusy then Exit; if FGroups.Find(ID)=nil then raise Exception.Create('グループがありません。'); FSelectedGroup:=ID; Refresh; end;
procedure TComicEffectPane.GroupChanged(Sender: TObject);
begin if not FRefreshing and (FGroupList.ItemIndex>=0) then SelectGroup(TComicEffectGroup(FGroupList.Items.Objects[FGroupList.ItemIndex]).ID); end;
procedure TComicEffectPane.CanEditGroup(Sender: TObject; Index: Integer; var CanEdit: Boolean);
begin CanEdit:=FWritable and not FBusy and (Index>0) and (Index<FGroupList.Count); end;
function TComicEffectPane.AddGroup(const Name: string): string;
begin RequireWritable; try Result:=FGroups.Add(Name); FSelectedGroup:=Result; finally Refresh; end; end;
procedure TComicEffectPane.RenameGroup(const ID,Name: string);
begin RequireWritable; try FGroups.Rename(ID,Name); finally Refresh; end; end;
procedure TComicEffectPane.RemoveGroup(const ID: string);
begin RequireWritable; try FGroups.Delete(ID); finally Refresh; end; end;
procedure TComicEffectPane.MoveMaterial(const MaterialID,GroupID: string);
begin RequireWritable; if FindEffectMaterial(FStore,MaterialID)=nil then raise Exception.Create('素材がありません。'); try FGroups.Move(MaterialID,GroupID); finally Refresh; end; end;
procedure TComicEffectPane.RenameMaterial(const MaterialID,Name: string);
begin
  RequireWritable; RenameEffectMaterial(FStore,FindEffectMaterial(FStore,MaterialID),Name,FLibraryPath);
  Refresh; if Assigned(FOnChanged) then FOnChanged(Self);
end;
procedure TComicEffectPane.RemoveMaterial(const MaterialID: string);
begin
  RequireWritable;
  // 保存成功時に素材オブジェクトが破棄されるため、一覧の借用参照を先に外す。
  FMaterials.Clear;
  try DeleteEffectMaterial(FStore,FindEffectMaterial(FStore,MaterialID),FLibraryPath);
  finally Refresh; end;
  if Assigned(FOnChanged) then FOnChanged(Self);
end;
procedure TComicEffectPane.GroupEdited(Sender: TObject; const Value: string; const Index: Integer);
var ID: string;
begin
  if (Index<0) or (Index>=FGroupList.Count) then Exit; ID:=TComicEffectGroup(FGroupList.Items.Objects[Index]).ID;
  try RenameGroup(ID,Value); except on E: Exception do begin Refresh; ShowMessage(E.Message); end; end;
end;
procedure TComicEffectPane.GroupContext(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
var Index: Integer;
begin
  Index:=FGroupList.ItemIndex; if MousePos.X>=0 then Index:=FGroupList.ItemAtPos(MousePos,True);
  FContextGroup:=''; if Index>=0 then begin FGroupList.ItemIndex:=Index; GroupChanged(nil); FContextGroup:=TComicEffectGroup(FGroupList.Items.Objects[Index]).ID; end;
  UpdateControls;
end;
procedure TComicEffectPane.AddGroupClick(Sender: TObject);
var Name: string;
begin Name:=''; if InputQuery('グループを追加','名前',Name) then try AddGroup(Name); except on E: Exception do ShowMessage(E.Message); end; end;
procedure TComicEffectPane.DeleteGroupClick(Sender: TObject);
begin
  if MessageDlg('グループを削除し、素材を「未分類」へ戻しますか？',mtConfirmation,[mbYes,mbNo],0)=mrYes then
    try RemoveGroup(FContextGroup); except on E: Exception do ShowMessage(E.Message); end;
end;
procedure TComicEffectPane.MaterialContext(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
var Index: Integer; Group: TComicEffectGroup; Item: TMenuItem;
begin
  Index:=FMaterials.ItemIndex; if MousePos.X>=0 then Index:=FMaterials.ItemAtPos(MousePos,True);
  FContextMaterial:=''; FMoveMenu.Clear;
  if Index>=0 then begin
    FMaterials.ItemIndex:=Index; FContextMaterial:=TComicEffectMaterial(FMaterials.Items.Objects[Index]).ID;
    for Group in FGroups.Groups do begin
      Item:=TMenuItem.Create(FMaterialMenu); Item.Caption:=Group.Name; Item.Hint:=Group.ID;
      Item.Checked:=FGroups.GroupOf(FContextMaterial)=Group.ID; Item.OnClick:=MoveClick; FMoveMenu.Add(Item);
    end;
  end;
  UpdateControls;
end;
procedure TComicEffectPane.MoveClick(Sender: TObject);
begin try MoveMaterial(FContextMaterial,TMenuItem(Sender).Hint); except on E: Exception do ShowMessage(E.Message); end; end;
procedure TComicEffectPane.RenameMaterialClick(Sender: TObject);
var Material: TComicEffectMaterial; Name: string;
begin
  Material:=FindEffectMaterial(FStore,FContextMaterial); if Material=nil then Exit; Name:=Material.Name;
  if InputQuery('素材名を変更','名前',Name) then
    try RenameMaterial(FContextMaterial,Name); except on E: Exception do ShowMessage(E.Message); end;
end;
procedure TComicEffectPane.DeleteMaterialClick(Sender: TObject);
begin
  if MessageDlg('共通素材の登録を削除しますか？配置済み作品とPNGは保持します。',mtConfirmation,[mbYes,mbNo],0)=mrYes then
    try RemoveMaterial(FContextMaterial); except on E: Exception do ShowMessage(E.Message); end;
end;
function TComicEffectPane.PutInGroup(Material: TComicEffectMaterial; const GroupID: string): string;
begin
  Result:='';
  try FGroups.Move(Material.ID,GroupID);
  // 素材本体の保存後に分類だけ失敗しても、登録を取り消して画像を消さない。
  except on E: Exception do begin FSelectedGroup:=UngroupedEffectID; Result:='（未分類へ登録。分類保存に失敗：'+E.Message+'）'; end; end;
end;
procedure TComicEffectPane.ImportFiles(const Files: TArray<string>);
var Path,Warnings,Errors,GroupID: string; Material: TComicEffectMaterial; Registered: Integer;
begin
  RequireWritable; GroupChanged(nil); Warnings:=''; Errors:=''; Registered:=0; GroupID:=FSelectedGroup;
  for Path in Files do try
    Material:=ImportDroppedEffect(FStore,Path,FLibraryPath); Inc(Registered); Warnings:=Warnings+PutInGroup(Material,GroupID);
  except on E: Exception do Errors:=Errors+TPath.GetFileName(Path)+'：'+E.Message+sLineBreak; end;
  Refresh;
  if Registered=0 then raise Exception.Create('登録できません：'+Errors);
  if Assigned(FOnChanged) then FOnChanged(Self);
  FStatus.Caption:=IntToStr(Registered)+'枚のPNGを登録しました。'+Warnings+Errors;
end;
procedure TComicEffectPane.FilesDropped(Sender: TObject; const Files: TArray<string>);
begin try ImportFiles(Files); except on E: Exception do begin Refresh; FStatus.Caption:='登録できません：'+E.Message; end; end; end;
procedure TComicEffectPane.NoteChanged(Sender: TObject);
begin UpdateControls; end;
procedure TComicEffectPane.StartGeneration(const Instruction: string);
var Prompt,ID,Directory: string;
begin
  RequireWritable; GroupChanged(nil); Prompt:=ComicEffectPrompt(Instruction); ID:=NewUID;
  FRequestedGroup:=FSelectedGroup; FRequestedName:=Copy(Trim(StringReplace(StringReplace(Instruction,#13,' ',[rfReplaceAll]),#10,' ',[rfReplaceAll])),1,200);
  Directory:=TPath.Combine(DataRoot,'Runtime\EffectGeneration\'+ID); ForceDirectories(Directory);
  FBusy:=True; UpdateControls; FStatus.Caption:='Codexへ送信中...';
  try
    FGeneration:=FFactory(); if FGeneration=nil then raise Exception.Create('生成サービスを開始できません。');
    FGeneration.Start(ID,Prompt,Directory,TPath.Combine(DataRoot,'Effects')); FTimer.Enabled:=True;
  except FGeneration:=nil; FBusy:=False; FTimer.Enabled:=False; UpdateControls; raise; end;
end;
procedure TComicEffectPane.SendClick(Sender: TObject);
begin try StartGeneration(FNote.Text); except on E: Exception do FStatus.Caption:='送信できません：'+E.Message; end; end;
procedure TComicEffectPane.CancelClick(Sender: TObject);
begin if FGeneration<>nil then begin FGeneration.Cancel; FStatus.Caption:='生成を中止しています...'; end; end;
procedure TComicEffectPane.PollGeneration(Sender: TObject);
var Relative,Error,Warning: string; Material: TComicEffectMaterial; Form: TCustomForm; Registered: Boolean;
begin
  if not FBusy or (FGeneration=nil) then Exit;
  FStatus.Caption:=FGeneration.Stage;
  Form:=GetParentForm(Self);
  // 内側の入力画面や標準ダイアログ中は採用を待ち、無効化された所有画面へ書き込まない。
  if (Application.ModalLevel>0) or ((Form<>nil) and Form.HandleAllocated and not IsWindowEnabled(Form.Handle)) then Exit;
  if not FGeneration.Poll(Relative,Error) then Exit;
  FTimer.Enabled:=False; Registered:=False;
  try
    if Error<>'' then raise Exception.Create(Error);
    Material:=AdoptPreparedEffect(FStore,FRequestedName,Relative,FLibraryPath,True); FGeneration.Adopted; Registered:=True;
    Warning:=PutInGroup(Material,FRequestedGroup); Refresh;
    FStatus.Caption:='効果素材を登録しました。'+Warning;
    if Assigned(FOnChanged) then FOnChanged(Self);
  except on E: Exception do begin
    if Registered then FStatus.Caption:='素材は登録済みです。表示更新に注意：'+E.Message
    else FStatus.Caption:='生成・登録に失敗しました：'+E.Message;
  end; end;
  FGeneration:=nil; FBusy:=False; Refresh; UpdateControls;
end;
end.
