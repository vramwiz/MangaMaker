unit ComicAssetDialogTests;

// 責務：画像管理の削除確認・参照保護・閉じる保存失敗を、隔離データと無音の確認応答で検証する。
interface
uses ComicTestSupport;
procedure RunAssetDialogChecks(Host: TComicTestForm);
implementation
uses Winapi.Windows, System.SysUtils, System.Types, System.IOUtils, System.Generics.Collections,
  Vcl.Menus, Vcl.StdCtrls, ComicModel, ComicAssetDialog, ComicAssetEditing;
type
  TAssetDialogProbe = class(TAssetDialog)
  public
    AllowRemoval,Reenter,ReentrantClose: Boolean;
    Confirmations,SaveAttempts: Integer;
    Confirmation,SaveError: string;
  protected
    function ConfirmSceneRemoval(const Message: string): Boolean; override;
    procedure ReportSaveError(const Message: string); override;
    procedure PersistChanges; override;
  end;
function TAssetDialogProbe.ConfirmSceneRemoval(const Message: string): Boolean;
begin Inc(Confirmations); Confirmation:=Message; Result:=AllowRemoval; end;
procedure TAssetDialogProbe.ReportSaveError(const Message: string);
begin SaveError:=Message; end;
procedure TAssetDialogProbe.PersistChanges;
begin
  Inc(SaveAttempts);
  if Reenter then begin Reenter:=False; ReentrantClose:=True; OnCloseQuery(Self,ReentrantClose); end;
  inherited;
end;
procedure RunAssetDialogChecks(Host: TComicTestForm);
var Project,Reloaded: TComicProject; Manager: TAssetDialogProbe; Root,Child,Other: TComicAsset;
  Panel: TComicPanel; Info: TComicSceneRemoval; Before,DraftPath,DraftBefore,ImagePath,FormalBefore,OtherID: string;
  Lock: THandle; CanClose,Failed: Boolean;
  function Menu(const Name: string): TMenuItem;
  var Item: TMenuItem; I: Integer;
  begin
    for I:=0 to Manager.AssetTree.PopupMenu.Items.Count-1 do begin
      Item:=Manager.AssetTree.PopupMenu.Items[I]; if Item.Caption=Name then Exit(Item);
    end;
    raise Exception.Create('Missing image management command: '+Name);
  end;
  procedure Popup;
  begin Manager.AssetTree.PopupMenu.OnPopup(Manager.AssetTree.PopupMenu); end;
begin
  Project:=CreateFixtureProject; Manager:=nil;
  try
    Project.Initialize('画像管理の削除と保存 fixture','1');
    Manager:=TAssetDialogProbe.CreateManager(Host,Project.Assets,Project,False); Popup;
    Host.Check((Manager.AssetTree.PopupMenu.Items[0].Caption='新規場面') and
      (Manager.AssetTree.PopupMenu.Items[1].Caption='場面移動') and
      (Manager.AssetTree.PopupMenu.Items[2].Caption='コマを作成'),'image popup starts with scene creation movement and panel creation in order');
    Host.Check((Menu('削除').ShortCut=ShortCut(VK_DELETE,[])) and (Manager.PopupMenu=nil) and
      (Manager.DraftName.PopupMenu=nil) and (Manager.DraftNotes.PopupMenu=nil),
      'Delete shortcut belongs only to the tree popup and is not assigned to text fields or form');
    Host.Check(Menu('新規場面').Enabled and Assigned(Menu('新規場面').OnClick) and
      not Menu('削除').Enabled,'empty image manager keeps add menu accessible and disables deletion');
    Host.Check(Assigned(Menu('台本を読み込む／補完...').OnClick) and
      Assigned(Menu('選択項目に画像を登録...').OnClick) and Assigned(Menu('参照する人物・服装: 0件').OnClick),
      'former image-management buttons remain available as popup actions');
    Menu('新規場面').Click;
    Host.Check((Project.Assets.Count=1) and (Manager.CurrentAsset=Project.Assets[0]),'empty-tree popup creates a scene through the real menu handler');
    Manager.AllowRemoval:=True; Manager.DeleteSelectedScene;
    Host.Check((Project.Assets.Count=0) and (Manager.CurrentAsset=nil),'last unused scene can be removed without leaving a stale selection');
    Manager.AllowRemoval:=False; Manager.Confirmations:=0;
    Root:=Project.ImportImage(TPath.Combine(Host.TestFolder,'reference.bmp'),''); Root.Name:='削除する場面';
    ImagePath:=Project.ImagePath(Root.ID);
    Child:=NewSceneAsset(Project.Assets,Root,'child','派生画像','','',''); Project.Assets.Add(Child);
    Other:=NewSceneAsset(Project.Assets,nil,'scene','保持する場面','','',''); Project.Assets.Add(Other); OtherID:=Other.ID;
    Panel:=TComicPanel.Create; Project.Pages[0].Panels.Add(Panel); Panel.ImageID:=Child.ID;
    Info:=SceneRemoval(Project,Root); Host.Check(not Info.CanRemove and (Info.AssignedPanels=1),'scene removal protects panels assigned to child images');
    Before:=Project.Snapshot; Failed:=False;
    try RemoveSceneRegistration(Project,Root); except Failed:=True; end;
    Host.Check(Failed and (Project.Snapshot=Before),'used scene removal fails before changing any project data');
    Panel.ImageID:=''; Other.SourceID:=Root.ID; Info:=SceneRemoval(Project,Root);
    Host.Check(not Info.CanRemove and (Info.DependentAssets=1),'scene removal protects alternate and title source references');
    Other.SourceID:=''; Project.ScriptProgress:='{"main/I001":{"uid":"'+Child.ID+'"}}'; Info:=SceneRemoval(Project,Root);
    Host.Check(not Info.CanRemove and (Info.ScriptBindings=1),'scene removal protects script image bindings'); Project.ScriptProgress:='';
    Manager.RefreshFromExternal; Manager.SelectAsset(Root.ID); Manager.DraftName.Text:='未確定の場面名'; Before:=Project.Snapshot;
    Host.Check(Menu('削除').Enabled,'tree selection enables Delete without first opening a popup');
    Menu('削除').Click;
    Host.Check((Manager.Confirmations=1) and Manager.Confirmation.Contains('未確定の場面名') and
      Manager.Confirmation.Contains('計2件') and (Project.Snapshot=Before) and (Manager.DraftName.Text='未確定の場面名'),
      'declined deletion names the scene and child scope while retaining exact data and pending input');
    Manager.AllowRemoval:=True; Manager.DeleteSelectedScene;
    Host.Check((Project.Assets.Count=1) and (Project.Assets[0].ID=OtherID) and FileExists(ImagePath) and
      (Manager.CurrentAsset=nil),'confirmed deletion removes scene registrations and children while retaining original files and unrelated assets');
    Popup; Host.Check(Menu('新規場面').Enabled and not Menu('コマを作成').Enabled,'unselected image manager still supports new scenes');
    Manager.SetGenerationBusy(True,'模擬生成'); Popup;
    Host.Check(not Menu('新規場面').Enabled and not Menu('削除').Enabled,'generation disables structural popup mutations');
    Manager.SetGenerationBusy(False,''); Manager.SelectAsset(OtherID); Manager.DraftName.Text:='閉じるときの入力';
    FormalBefore:=TFile.ReadAllText(TPath.Combine(Project.Folder,'Project.json'),TEncoding.UTF8);
    DraftPath:=TPath.Combine(Project.Folder,'Draft.json'); DraftBefore:=TFile.ReadAllText(DraftPath,TEncoding.UTF8);
    Lock:=CreateFile(PChar(DraftPath),GENERIC_READ,FILE_SHARE_READ,nil,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0);
    Host.Check(Lock<>INVALID_HANDLE_VALUE,'image manager draft is locked for close failure');
    try
      CanClose:=True; Manager.OnCloseQuery(Manager,CanClose);
      Host.Check(not CanClose and (Manager.SaveAttempts=1) and (Manager.SaveError<>'') and
        (Manager.DraftName.Text='閉じるときの入力') and (TFile.ReadAllText(DraftPath,TEncoding.UTF8)=DraftBefore),
        'failed close save keeps dialog input and existing draft intact');
    finally CloseHandle(Lock); end;
    Manager.Reenter:=True; CanClose:=False; Manager.OnCloseQuery(Manager,CanClose);
    Host.Check(CanClose and not Manager.ReentrantClose and (Manager.SaveAttempts=2),'close retry saves once and rejects a reentrant close');
    Manager.OnCloseQuery(Manager,CanClose); Host.Check(CanClose and (Manager.SaveAttempts=2),'repeated close queries do not save twice');
    Reloaded:=CreateFixtureProject;
    try Reloaded.Load(DraftPath); Host.Check(Reloaded.Snapshot=Project.Snapshot,'closing persists deletions and pending fields in the complete draft'); finally Reloaded.Free; end;
    Host.Check(TFile.ReadAllText(TPath.Combine(Project.Folder,'Project.json'),TEncoding.UTF8)=FormalBefore,
      'manager close retains explicit project-save semantics');
  finally Manager.Free; Project.Free; end;
end;
end.
