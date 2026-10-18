unit ComicScriptTests;

// 責務：途中の台本を既存画像管理・文字入力へ取り込み、手直し・Undo・保存を壊さないことを検証する。
interface
uses ComicTestSupport;
procedure RunScriptChecks(Host: TComicTestForm);
implementation
uses Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, System.Generics.Collections,
  System.JSON, Vcl.StdCtrls, ComicScriptGeneration, ComicScript, ComicScriptPlan, ComicScriptAssist, ComicModel, ComicAssetDialog, ComicTextInput;
type
  TScriptTestHelper = class helper for TComicTestForm
    procedure CheckScriptIntegration;
  end;
procedure TScriptTestHelper.CheckScriptIntegration;
const
  Text = '[作品]'#13#10'台本ID：SCRIPT-TEST'#13#10'作品名：途中の台本'#13#10+
    '[人物定義：主人公]'#13#10'[登録名：検証人物]'#13#10'[状態名：基本服装]'#13#10+
    '# 1ページ目'#13#10'* B001'#13#10'[内容：夕方の教室]'#13#10+
    '*** I001'#13#10'[人物：主人公]'#13#10'[内容：入口に立つ]'#13#10+
    '[セリフ：D001]'#13#10'[話者：主人公（心の声）]'#13#10'[本文：表示専用のセリフ]'#13#10+
    '*** I002'#13#10'[人物：主人公]'#13#10'[内容：歩く]'#13#10+
    '[セリフ：D002]'#13#10'[話者：主人公]'#13#10'[本文：次のセリフ]'#13#10+
    '*** I003'#13#10'[人物：主人公]'#13#10'[内容：未完の構図]'#13#10'[構図：途中';
var Project,Loaded,OldProject: TComicProject; Characters,OldCharacters: TObjectList<TComicAsset>;
  A,BG,Image: TComicAsset; Script: TComicScript; Imported: TScriptImportResult; Manager: TAssetDialog;
  Choices: TStringList; UID,Before,OldNotes,SnapshotText,Error: string; Failed: Boolean;
  Lock: THandle; Panel: TComicPanel; Balloon: TComicBalloon; D: TComicTextDialog; Combo: TComboBox;
  I: Integer; References: TArray<string>; Plan,Request,Reply: TJSONObject; ReplyText,Fingerprint: string;
begin
  Project:=CreateFixtureProject; Loaded:=CreateFixtureProject; Characters:=TObjectList<TComicAsset>.Create;
  Script:=TComicScript.Create; Choices:=TStringList.Create; Manager:=nil;
  OldProject:=FProject; OldCharacters:=FCharacters;
  try
    A:=TComicAsset.Create; A.Name:='検証人物'; A.CharacterName:=A.Name; A.StateName:='基本服装'; A.FileName:='reference.bmp'; Characters.Add(A);
    Project.Initialize('途中の台本','第1話');
    Script.Read(Text);
    Check((Script.Errors.Count=1) and (Script.FatalErrors.Count=0) and (Script.Find('I003').Problems.Count=1),
      'partial script isolates an unfinished final image without rejecting the document');
    Check((Script.Find('D001').Get('話者')='主人公') and (Script.Find('D001').Get('種別')='心の声'),
      'script legacy thought speaker normalizes for existing text input');
    Script.Read(Text.Replace('# 1ページ目','[人物定義：通行人・客・配信者]'#13#10'[参照方式：説明のみ]'#13#10'[外見：モブ人物]'#13#10'# 1ページ目'));
    Check((Script.FindCharacter('客')<>nil) and (Script.FindCharacter('他の配信者たち')<>nil),
      'script grouped mob declaration resolves its members and plural streaming role');
    Check(Script.FindCharacter('未定義人物')=nil,'script grouped roles do not guess unrelated characters');
    Script.Read(Text+#13#10'* B001');
    Check((Script.Find('B001').Problems.Count>0) and (Script.Errors.Count>1),'script duplicate ID marks the first definition too');
    Script.Read('作品名：試験'#13#10'登場人物：'#13#10'主人公：提供された三面図を参照'#13#10'※人物'#13#10+
      '* B001'#13#10'[内容：背景]'#13#10'*** I001'#13#10'[人物：主人公]'#13#10'[内容：立つ]');
    BindScriptReference(Script,Characters);
    Check(Script.Find('主人公').Get('参照ID')=A.ID,'script supplied protagonist reference binds the unique registered base state');
    Imported:=ImportComicScript(Project,Characters,Text);
    Check((Imported.Added=3) and (Imported.Deferred=1) and (Project.Assets.Count=3),
      'partial script imports completed background and two panels into ordinary assets');
    Check(Project.ScriptSource=Text,'script original incomplete source is stored unchanged');
    UID:=Project.Assets[1].ID; BG:=Project.Assets[0]; Image:=Project.Assets[1];
    Plan:=ScriptGenerationPlan(Project,Characters);
    try
      Check((JNum(Plan,'ready',0)=1) and (JNum(Plan,'waiting',0)=2) and (JNum(Plan,'deferred',0)=1),
        'sequence plan distinguishes background ready dependent panels and incomplete definition');
      Check(NextScriptGenerationAsset(Plan)=BG.ID,'sequence begins with its existing background UID');
    finally Plan.Free; end;
    Check((Image.ParentID=BG.ID) and (Length(Image.CharacterRefs)=1) and (Image.CharacterRefs[0]=A.ID),
      'ordinary image assets retain script background and registered character references');
    Check(Image.Notes.Contains('入口に立つ') and not Image.Notes.Contains('表示専用のセリフ'),
      'script fills readable generation notes without drawing dialogue into the image');
    Manager:=TAssetDialog.CreateManager(Self,Project.Assets,Project,False,True,nil,Characters);
    Manager.SelectAsset(UID);
    Check(Pos('入口に立つ',Manager.DraftNotes.Text)>0,'existing image manager shows the script scene in its ordinary description field');
    OldNotes:=Manager.DraftNotes.Text; Manager.DraftNotes.Text:='手動で調整した構図'; Manager.FlushDraft;
    Imported:=Manager.LoadScriptText(Text.Replace('入口に立つ','入口で振り向く'));
    Check((Imported.Added=0) and (Project.Assets.Count=3) and (Project.Assets[1].ID=UID),
      'reimport preserves image UID and avoids duplicate ordinary assets');
    Check(Project.Asset(UID).Notes='手動で調整した構図','script supplementation preserves manually edited generation notes');
    Imported:=Manager.LoadScriptText(Text.Replace('*** I001','* B002'#13#10'[内容：別の教室]'#13#10'*** I001'));
    Check((Imported.Added=1) and (Project.Asset(UID).ParentID=Project.Assets.Last.ID),
      'script reimport updates an unchanged automatic background association');
    Imported:=Manager.LoadScriptText(Text);
    Imported:=Manager.LoadScriptText(Text.Replace('台本ID：SCRIPT-TEST',''));
    Check((Imported.Added=0) and (Project.Asset(UID)<>nil),'omitting a previously assigned script ID preserves existing image associations');
    Imported:=Manager.LoadScriptText(Text);
    Before:=Project.Snapshot;
    Lock:=CreateFile(PChar(TPath.Combine(Project.Folder,'Draft.json')),GENERIC_READ,0,nil,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0);
    try Failed:=False; try Manager.LoadScriptText(Text); except Failed:=True; end; finally CloseHandle(Lock); end;
    Check(Failed and (Project.Snapshot=Before),'script import rolls back assets and source when draft saving fails');
    FreeAndNil(Manager);
    ScriptDialogueChoices(Project,UID,Choices);
    Check((Choices.Count=2) and Choices[1].StartsWith('D001 '),'existing balloon input offers dialogue for its placed panel image');
    Check(ScriptDialogueText(Project,Choices[1])='表示専用のセリフ','script dialogue selection returns only its body');
    ScriptDialogueChoices(Project,'',Choices); Check(Choices.Count=3,'unassigned balloons can choose among all completed dialogue');
    Project.Save; Loaded.Load(TPath.Combine(Project.Folder,'Project.json'));
    Check((Loaded.ScriptSource=Project.ScriptSource) and (Loaded.ScriptProgress=Project.ScriptProgress),
      'script source and image associations persist with ordinary project saving');
    FProject:=Project; FCharacters:=Characters; FPageIndex:=0; FBalloonIndex:=-1;
    Failed:=False; try GenerationSnapshot('images',Project.ID,UID,References); except on E: Exception do begin Error:=E.Message; Failed:=True; end; end;
    Check(Failed and Error.Contains('参照背景'),'existing generation path requires a script background before generating its child');
    BG:=Project.Assets[0]; BG.FileName:='Images\script-background.bmp';
    TFile.Copy(TPath.Combine(TestFolder,'reference.bmp'),SafeChild(Project.Folder,BG.FileName),True);
    SnapshotText:=GenerationSnapshot('images',Project.ID,UID,References);
    Check((Length(References)=2) and (SnapshotText<>''),'existing Codex generation snapshot includes script background and character images');
    Plan:=ScriptGenerationPlan(Project,Characters);
    try
      Check((JNum(Plan,'completed',0)=1) and (NextScriptGenerationAsset(Plan)=UID),
        'sequence skips an obtained background and chooses its first missing panel');
    finally Plan.Free; end;
    Request:=TJSONObject.Create.AddPair('version',TJSONNumber.Create(1)).AddPair('action','read_script').AddPair('projectId',Project.ID);
    try BridgeRequest(Request.ToJSON,ReplyText); finally Request.Free; end;
    Reply:=TJSONObject.ParseJSONValue(ReplyText) as TJSONObject;
    try Check((JStr(Reply,'ok','')='true') and (JStr(Reply.GetValue<TJSONObject>('data'),'source','')=Text),
      'Codex bridge reads original partial script and live sequence plan'); finally Reply.Free; end;
    Request:=TJSONObject.Create.AddPair('version',TJSONNumber.Create(1)).AddPair('action','generation_context').AddPair('projectId',Project.ID).AddPair('assetId',UID);
    try BridgeRequest(Request.ToJSON,ReplyText); finally Request.Free; end;
    Reply:=TJSONObject.ParseJSONValue(ReplyText) as TJSONObject;
    try
      Fingerprint:=JStr(Reply.GetValue<TJSONObject>('data'),'fingerprint','');
      Check((JStr(Reply,'ok','')='true') and (Fingerprint=SnapshotText),'Codex bridge exposes the same context and references as ordinary generation');
    finally Reply.Free; end;
    Before:=Project.Snapshot;
    Request:=TJSONObject.Create.AddPair('version',TJSONNumber.Create(1)).AddPair('action','register_image').AddPair('projectId',Project.ID)
      .AddPair('library','images').AddPair('assetId',UID).AddPair('sourcePath',TPath.Combine(TestFolder,'reference.bmp')).AddPair('expectedContext','old-context');
    try BridgeRequest(Request.ToJSON,ReplyText); finally Request.Free; end;
    Reply:=TJSONObject.ParseJSONValue(ReplyText) as TJSONObject;
    try Check((JStr(Reply,'ok','')='false') and (Project.Snapshot=Before),'external Codex adoption rejects changed generation conditions without overwriting'); finally Reply.Free; end;
    Request:=TJSONObject.Create.AddPair('version',TJSONNumber.Create(1)).AddPair('action','start_script_generation').AddPair('projectId','wrong-project');
    try BridgeRequest(Request.ToJSON,ReplyText); finally Request.Free; end;
    Reply:=TJSONObject.ParseJSONValue(ReplyText) as TJSONObject;
    try Check(JStr(Reply,'ok','')='false','sequence bridge rejects another project before starting a worker'); finally Reply.Free; end;
    Request:=TJSONObject.Create.AddPair('version',TJSONNumber.Create(1)).AddPair('action','start_script_generation').AddPair('projectId',Project.ID);
    try BridgeRequest(Request.ToJSON,ReplyText); finally Request.Free; end;
    Reply:=TJSONObject.ParseJSONValue(ReplyText) as TJSONObject;
    try Check(JStr(Reply,'ok','')='false','sequence bridge requires the ordinary image manager to be open'); finally Reply.Free; end;
    Image:=Project.Asset(UID); Image.FileName:='Images\script-first.bmp'; TFile.Copy(TPath.Combine(TestFolder,'reference.bmp'),SafeChild(Project.Folder,Image.FileName),True);
    Plan:=ScriptGenerationPlan(Project,Characters);
    try Check((JNum(Plan,'completed',0)=2) and (NextScriptGenerationAsset(Plan)=Project.Assets[2].ID),
      'restarted sequence keeps completed files and continues from the remaining panel'); finally Plan.Free; end;
    Image.FileName:='Images\deleted.bmp';
    Plan:=ScriptGenerationPlan(Project,Characters);
    try Check(NextScriptGenerationAsset(Plan)=UID,'missing managed image file becomes eligible for acquisition again'); finally Plan.Free; end;
    Image.FileName:='';
    Panel:=TComicPanel.Create; Panel.ImageID:=UID; Project.Pages[0].Panels.Add(Panel);
    Balloon:=TComicBalloon.Create; Balloon.PanelID:=Panel.ID; Balloon.Text:='元のセリフ'; Project.Pages[0].Balloons.Add(Balloon);
    FBalloonIndex:=0; LoadBalloonControls(Balloon); ScriptLinesDropDown(nil);
    Check(FScriptLines.Items.Count=2,'existing right-side balloon field filters script dialogue to the selected panel');
    FScriptLines.ItemIndex:=1; ScriptLineSelected(nil);
    Check((FText.Text='表示専用のセリフ') and (Balloon.Text='表示専用のセリフ'),
      'choosing script dialogue immediately updates the selected balloon');
    Before:=Project.Snapshot;
    D:=CreateBalloonTextDialog;
    try
      Combo:=nil; for I:=0 to D.ComponentCount-1 do if D.Components[I] is TComboBox then Combo:=TComboBox(D.Components[I]);
      Check((Combo<>nil) and (Combo.Items.Count=2),'existing dedicated text editor also offers the panel dialogue');
      Combo.ItemIndex:=1; Combo.OnChange(Combo);
      Check((D.Editor.Text='表示専用のセリフ') and (Project.Snapshot=Before),
        'script text selection in the existing editor remains provisional until confirmation');
    finally D.Free; end;
    Check(OldNotes<>Project.Asset(UID).Notes,'manual notes remain independently editable after script integration');
  finally
    FProject:=OldProject; FCharacters:=OldCharacters; FPageIndex:=-1; FBalloonIndex:=-1; FText.Clear;
    Manager.Free; Choices.Free; Script.Free; Characters.Free; Loaded.Free; Project.Free;
  end;
end;
procedure RunScriptChecks(Host: TComicTestForm);
begin Host.CheckScriptIntegration; end;
end.
