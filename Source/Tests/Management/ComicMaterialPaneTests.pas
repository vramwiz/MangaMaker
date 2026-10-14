unit ComicMaterialPaneTests;

// 責務：分類・編集・登録と非同期生成の境界を隔離データで検証し、外部生成やユーザー画面を操作しない。
interface
uses ComicTestSupport;
procedure RunMaterialPaneChecks(Host: TComicTestForm);
implementation
uses System.SysUtils, System.Classes, System.Types, System.IOUtils, System.Generics.Collections,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.Graphics, Vcl.Imaging.pngimage,
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, ComicModel, ComicEffects,
  ComicEffectGroups, ComicEffectPane, ComicEffectGeneration;
type
  TTestDropFiles = packed record
    pFiles: DWORD;
    pt: TPoint;
    fNC,fWide: BOOL;
  end;
  PTestDropFiles = ^TTestDropFiles;
  TMockEffectGeneration = class(TInterfacedObject,IComicEffectGeneration)
    Done,WasAdopted: Boolean;
    Starts: Integer;
    Relative,Error,Prompt: string;
    procedure Start(const RequestID,APrompt,WorkDirectory,MaterialRoot: string);
    function Poll(out ARelative,AError: string): Boolean;
    function Stage: string;
    procedure Adopted;
    procedure Cancel;
  end;
var MockService: IComicEffectGeneration;
function MockFactory: IComicEffectGeneration;
begin Result:=MockService; end;
procedure TMockEffectGeneration.Start(const RequestID,APrompt,WorkDirectory,MaterialRoot: string);
begin Inc(Starts); Prompt:=APrompt; if Error='start-failure' then raise Exception.Create(Error); end;
function TMockEffectGeneration.Poll(out ARelative,AError: string): Boolean;
begin Result:=Done; ARelative:=Relative; AError:=Error; end;
function TMockEffectGeneration.Stage: string;
begin Result:='模擬生成中'; end;
procedure TMockEffectGeneration.Adopted;
begin WasAdopted:=True; end;
procedure TMockEffectGeneration.Cancel;
begin Done:=True; Error:='生成を中止しました。'; end;
procedure RunMaterialPaneChecks(Host: TComicTestForm);
var PreviousRoot,Root,Path,GroupA,GroupB,ID,Before,SourceHash,FilesText: string;
  Groups,Reloaded: TComicEffectGroups; Store: TObjectList<TComicEffectMaterial>;
  Form: TForm; Pane,BrokenPane: TComicEffectPane; Mock: TMockEffectGeneration;
  Bitmap: Vcl.Graphics.TBitmap; PNG: TPngImage; Failed,Handled: Boolean; Count,I: Integer;
  Lock: THandle; Edit: TEdit; Rect: TRect; Drop: HGLOBAL; DropData: PTestDropFiles; Point: TPoint;
  procedure Check(Value: Boolean; const Message: string);
  begin Host.Check(Value,'material pane: '+Message); end;
  procedure MakePNG(const Name: string; Alpha: Boolean);
  var Row: Integer;
  begin
    Bitmap.SetSize(64,48); Bitmap.PixelFormat:=pf24bit; Bitmap.Canvas.Brush.Color:=clBlack; Bitmap.Canvas.FillRect(System.Types.Rect(0,0,64,48));
    PNG.Assign(Bitmap); if Alpha then begin PNG.CreateAlpha; for Row:=0 to PNG.Height-1 do FillChar(PNG.AlphaScanline[Row]^,PNG.Width,0); end;
    PNG.SaveToFile(Name);
  end;
  procedure NewMock;
  begin Mock:=TMockEffectGeneration.Create; MockService:=Mock; end;
begin
  PreviousRoot:=GetEnvironmentVariable('MANGAMAKER_DATA_ROOT'); Root:=TPath.Combine(Host.TestFolder,'MaterialPaneData');
  Groups:=nil; Reloaded:=nil; Store:=nil; Form:=nil; Pane:=nil; BrokenPane:=nil; Bitmap:=nil; PNG:=nil;
  SetEnvironmentVariable('MANGAMAKER_DATA_ROOT',PChar(Root));
  try
    ForceDirectories(TPath.Combine(Root,'Effects')); Path:=TPath.Combine(Root,'Effects\Groups.json');
    Groups:=TComicEffectGroups.Create(Path); Reloaded:=TComicEffectGroups.Create(Path);
    Check((Groups.Groups.Count=1) and (Groups.GroupOf('builtin-focus')=UngroupedEffectID),'old libraries start in unclassified');
    GroupA:=Groups.Add('線'); GroupB:=Groups.Add('星'); Groups.Rename(GroupA,'集中線'); Groups.Move('builtin-focus',GroupA);
    Reloaded.Load; Check((Reloaded.Find(GroupA).Name='集中線') and (Reloaded.GroupOf('builtin-focus')=GroupA),'names and built-in memberships persist by ID');
    Before:=Groups.Snapshot; Failed:=False; try Groups.Add('星'); except Failed:=True; end;
    Check(Failed and (Groups.Snapshot=Before),'duplicate name rejected without changing groups');
    Failed:=False; try Groups.Delete(UngroupedEffectID); except Failed:=True; end; Check(Failed,'default group cannot be deleted');
    Lock:=CreateFile(PChar(Path),GENERIC_READ,FILE_SHARE_READ,nil,OPEN_EXISTING,0,0);
    if Lock=INVALID_HANDLE_VALUE then RaiseLastOSError;
    try
      Failed:=False; try Groups.Move('builtin-focus',GroupB); except Failed:=True; end;
      Check(Failed and (Groups.GroupOf('builtin-focus')=GroupA),'failed save rolls membership back');
      Failed:=False; try Groups.Rename(GroupA,'失敗'); except Failed:=True; end;
      Check(Failed and (Groups.Find(GroupA).Name='集中線'),'failed rename restores the group');
    finally CloseHandle(Lock); end;
    Groups.Delete(GroupA); Check(Groups.GroupOf('builtin-focus')=UngroupedEffectID,'deleting a group preserves material in unclassified');
    Groups.Free; Groups:=nil;
    Store:=TObjectList<TComicEffectMaterial>.Create; SeedEffectMaterials(Store); EnsureBuiltInMaterialFiles(Store);
    Form:=TForm.CreateNew(nil); Form.Width:=420; Form.Height:=720; Form.HandleNeeded;
    Pane:=TComicEffectPane.CreatePane(Form,Form,Store,True,nil); Pane.Align:=alClient; Pane.MaterialList.ItemHeight:=104;
    Check((Pane.MaterialList.Count=3) and not Pane.SendButton.Enabled,'initial group and empty instruction state');
    GroupA:=Pane.AddGroup('線'); Check(Pane.MaterialList.Count=0,'new group displays only its own materials');
    Pane.MoveMaterial('builtin-focus',GroupA); Check(Pane.MaterialList.Count=1,'moving material filters the current group');
    Pane.GroupList.ItemIndex:=Pane.GroupList.Count-1; Rect:=Pane.GroupList.ItemRect(Pane.GroupList.ItemIndex);
    Pane.GroupList.Perform(WM_LBUTTONDBLCLK,MK_LBUTTON,MakeLParam(Rect.Left+4,Rect.Top+4));
    Edit:=nil; for I:=0 to Pane.GroupList.ControlCount-1 do if Pane.GroupList.Controls[I] is TEdit then Edit:=TEdit(Pane.GroupList.Controls[I]);
    Check((Edit<>nil) and Edit.Visible,'double click enters inline editing');
    Edit.Text:='縦の集中線'; Edit.Perform(WM_KEYDOWN,VK_RETURN,0);
    Check(not Edit.Visible and (Pane.GroupList.Items[Pane.GroupList.ItemIndex]='縦の集中線'),'Enter commits the Japanese group name');
    Pane.GroupList.Perform(WM_LBUTTONDBLCLK,MK_LBUTTON,MakeLParam(Rect.Left+4,Rect.Top+4)); Edit.Text:='取消'; Edit.Perform(WM_KEYDOWN,VK_ESCAPE,0);
    Check(Pane.GroupList.Items[Pane.GroupList.ItemIndex]='縦の集中線','Escape preserves the name');
    Pane.MaterialList.ItemIndex:=0; Rect:=Pane.MaterialList.ItemRect(0); Point:=System.Types.Point(Rect.Left+4,Rect.Top+4); Handled:=False;
    Pane.MaterialList.OnContextPopup(Pane.MaterialList,Point,Handled);
    Count:=0; for I:=0 to Pane.MaterialList.PopupMenu.Items[0].Count-1 do if Pane.MaterialList.PopupMenu.Items[0].Items[I].Checked then Inc(Count);
    Check((Count=1) and (Pane.MaterialList.PopupMenu.Items[0].Count=Pane.GroupList.Count),'move submenu lists all groups and checks exactly the current group');
    Pane.MaterialList.PopupMenu.Items[0].Items[0].Click; Check(Pane.MaterialList.Count=0,'move menu changes membership');
    Bitmap:=Vcl.Graphics.TBitmap.Create; PNG:=TPngImage.Create; ID:=TPath.Combine(Host.TestFolder,'drop-material.png'); MakePNG(ID,True);
    SourceHash:=TFile.ReadAllText(Path,TEncoding.UTF8); FilesText:=ID+#0+#0;
    Drop:=GlobalAlloc(GMEM_MOVEABLE or GMEM_ZEROINIT,SizeOf(TTestDropFiles)+Length(FilesText)*SizeOf(Char)); if Drop=0 then RaiseLastOSError;
    DropData:=GlobalLock(Drop); DropData.pFiles:=SizeOf(TTestDropFiles); DropData.fWide:=True;
    Move(PChar(FilesText)^,PByte(DropData)[SizeOf(TTestDropFiles)],Length(FilesText)*SizeOf(Char)); GlobalUnlock(Drop);
    Pane.MaterialList.Perform(WM_DROPFILES,Drop,0);
    Check((Store.Count=4) and FileExists(ID) and FileExists(EffectMaterialPath(Store.Last)),'native file drop copies and registers PNG while preserving source');
    Check(Pane.MaterialList.Count=1,'dropped file belongs to selected group');
    Check(TFile.ReadAllText(Path,TEncoding.UTF8)<>SourceHash,'dropped file group persisted');
    Pane.GenerationFactory:=MockFactory; Pane.Instruction.Text:='中央に余白のある集中線'; NewMock; Count:=Store.Count;
    Pane.StartGeneration(Pane.Instruction.Text);
    Check(Pane.Busy and not Pane.SendButton.Enabled and not Pane.GroupList.Enabled,'send and group changes stay locked while generating');
    Check((Pos('transparent_background=true',Mock.Prompt)>0) and (Pos('横4:縦3',Mock.Prompt)>0),'short instruction receives manga and transparency constraints');
    Failed:=False; try Pane.StartGeneration('二重送信'); except Failed:=True; end; Check(Failed and (Mock.Starts=1),'repeated send cannot start a second request');
    Mock.Done:=True; Mock.Error:='画像生成が利用できません'; Pane.PollGeneration(nil);
    Check(not Pane.Busy and Pane.SendButton.Enabled and (Store.Count=Count),'error enables retry without registering an image');
    NewMock; Mock.Relative:='generated-opaque.png'; MakePNG(TPath.Combine(Root,'Effects\'+Mock.Relative),False);
    Pane.StartGeneration('透明な星'); Mock.Done:=True; Pane.PollGeneration(nil);
    Check((Store.Count=Count) and not Pane.Busy and not Mock.WasAdopted,'opaque generated image is rejected without adoption');
    NewMock; Mock.Relative:='generated-alpha.png'; MakePNG(TPath.Combine(Root,'Effects\'+Mock.Relative),True);
    Pane.StartGeneration('小さな星'); Mock.Done:=True; Form.Enabled:=False; Pane.PollGeneration(nil);
    Check(Pane.Busy and (Store.Count=Count),'disabled owner defers adoption'); Form.Enabled:=True; Pane.PollGeneration(nil);
    Check(not Pane.Busy and Pane.SendButton.Enabled and Mock.WasAdopted and (Store.Count=Count+1),'completed transparent image registers once and unlocks send');
    Check(FileExists(EffectMaterialPath(Store.Last)) and (Pane.MaterialList.Count=2),'registered image is in its captured group');
    Pane.PollGeneration(nil); Check(Store.Count=Count+1,'late duplicate poll does not register again');
    NewMock; Pane.StartGeneration('速度線'); Pane.CancelButton.Click; Pane.PollGeneration(nil);
    Check(not Pane.Busy and (Store.Count=Count+1),'cancel completes without adopting an image');
    NewMock; Mock.Error:='start-failure'; Failed:=False; try Pane.StartGeneration('速度線'); except Failed:=True; end;
    Check(Failed and not Pane.Busy and Pane.SendButton.Enabled,'start failure restores the send state');
    Pane.RemoveGroup(GroupA); Pane.SelectGroup(UngroupedEffectID); Check(Pane.MaterialList.Count=Store.Count,'group deletion preserves every registered material');
    ID:=Store.Last.ID; Before:=EffectMaterialPath(Store.Last); Pane.RenameMaterial(ID,'登録した星');
    Check((Store.Last.Name='登録した星') and FileExists(Before),'material rename preserves its PNG');
    Count:=Store.Count; Pane.RemoveMaterial(ID);
    Check((Store.Count=Count-1) and (Pane.MaterialList.Count=Store.Count) and FileExists(Before),'material removal clears borrowed rows and preserves PNG');
    Failed:=False; try Pane.RemoveMaterial('builtin-focus'); except Failed:=True; end;
    Check(Failed and (Store.Count=Count-1) and (Pane.MaterialList.Count=Store.Count),'built-in removal is rejected and restores the list');
    Before:=TFile.ReadAllText(Path,TEncoding.UTF8); TFile.WriteAllText(Path,'invalid',TEncoding.UTF8);
    BrokenPane:=TComicEffectPane.CreatePane(Form,Form,Store,True,nil); BrokenPane.Instruction.Text:='集中線';
    Check(not BrokenPane.SendButton.Enabled,'corrupt group file disables writing');
    Failed:=False; try BrokenPane.AddGroup('上書き'); except Failed:=True; end;
    Check(Failed and (TFile.ReadAllText(Path,TEncoding.UTF8)='invalid'),'corrupt group file remains unchanged');
    TFile.WriteAllText(Path,Before,TEncoding.UTF8);
  finally
    MockService:=nil; BrokenPane.Free; Pane.Free; Form.Free; Store.Free; Groups.Free; Reloaded.Free; Bitmap.Free; PNG.Free;
    SetEnvironmentVariable('MANGAMAKER_DATA_ROOT',PChar(PreviousRoot));
  end;
end;
end.
