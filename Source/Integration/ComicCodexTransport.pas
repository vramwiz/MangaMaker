unit ComicCodexTransport;

// 責務：専用Codexとのプロセス通信と画像受信を担当し、所有する要求と子プロセスだけを中止する。

// 専用app-server、または既存サーバーへのproxyを標準入出力パイプで呼ぶ。
// 本編の待受パイプ・作品モデル・設定は参照しない。所有する子プロセスだけを終了する。
interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections, Vcl.Graphics, Winapi.Windows;

type
  TComicCodexMode = (pmDedicated, pmExisting);

  TComicCodexWorker = class(TThread)
  private
    FMode: TComicCodexMode; // 接続先。既存モードではサーバーを自動起動しない。
    FPrompt, FDirectory, FLogPath: string;
    FStage, FAnswer, FError, FThreadId, FTurnId, FExecutable: string;
    FLastDiagnostic, FCompletedTurnId, FCompletedStatus, FCompletedError: string;
    FImagePath, FSourceImagePath, FImageItemId: string;
    FImageGenerated: Boolean; // 正式なimageGeneration完了通知を受信した場合だけTrue。
    FStarted: Boolean;
    FSuccess: Boolean; // turnの正常完了と新しい生成画像の受信時だけTrue。表示確認はフォーム側。
    FProcess, FJob, FInput, FOutput, FStderr: THandle;
    FPendingOutput, FPendingError: RawByteString; // UTF-8を改行までバイトで保持する。
    FLog: TStringList;
    FNextId: Integer;
    FRequestID,FManagedRoot,FManagedPrefix,FPreparedRelative: string;
    FReferences: TArray<string>;
    FTimeoutMS: Cardinal;
    FDeferred: TObjectList<TJSONObject>;
    FDeferredBytes,FLastMessageBytes: Int64;
    FPreparedLock: TFileStream;
    FReferenceLocks: TObjectList<TFileStream>;
    FImageSHA256: string;
    FPreview,FBitmap: Vcl.Graphics.TBitmap;
    FAdopted: Boolean;
    procedure PrepareImage;
    procedure SetStage(const Value: string);
    function GetStage: string;
    procedure Log(const Kind, Value: string);
    procedure StartProcess;
    procedure StopProcess;
    procedure Send(ObjectValue: TJSONObject); // 引数の所有権を受け取り、送信後解放。
    procedure DrainPipe(Pipe: THandle; var Pending: RawByteString);
    function ReadMessage(Deadline: UInt64): TJSONObject; // 呼出側が返却JSONを所有。
    function Request(const Method: string; Params: TJSONObject): TJSONObject;
    procedure HandleNotification(Message: TJSONObject);
    procedure ReceiveImage(Item: TJSONObject);
    procedure RunConversation;
  protected
    procedure Execute; override;
  public
    constructor Create(const RequestID,Prompt,Directory,ManagedRoot,ManagedPrefix: string; const References: TArray<string>; TimeoutMS: Cardinal=600000);
    destructor Destroy; override;
    procedure BeginRun;
    procedure Cancel;
    procedure MarkAdopted;
    function TakeBitmap: Vcl.Graphics.TBitmap;
    property RequestID: string read FRequestID;
    property PreparedRelative: string read FPreparedRelative;
    property Preview: Vcl.Graphics.TBitmap read FPreview;
    property Stage: string read GetStage;
    // 以下の結果はスレッド終了後だけ読む。
    property Success: Boolean read FSuccess;
    property Answer: string read FAnswer;
    property ErrorText: string read FError;
    property ThreadId: string read FThreadId;
    property TurnId: string read FTurnId;
    property Executable: string read FExecutable;
    property LogPath: string read FLogPath;
    property ImagePath: string read FImagePath;
    property SourceImagePath: string read FSourceImagePath;
    property ImageItemId: string read FImageItemId;
    property ImageGenerated: Boolean read FImageGenerated;
    property ImageSHA256: string read FImageSHA256;
  end;

function ComicCodexModeName(Mode: TComicCodexMode): string;

implementation

uses System.IOUtils, System.NetEncoding, System.Math, System.Types, System.Hash, Vcl.Imaging.pngimage, Vcl.Imaging.jpeg, ComicImageAdoption;

function ComicCodexModeName(Mode: TComicCodexMode): string;
begin
  if Mode = pmDedicated then Result := 'dedicated' else Result := 'existing';
end;

function JsonObject(Parent: TJSONObject; const Key: string): TJSONObject;
begin
  Result := nil;
  if (Parent <> nil) and (Parent.GetValue(Key) is TJSONObject) then
    Result := TJSONObject(Parent.GetValue(Key));
end;

function JsonText(Parent: TJSONObject; const Key: string): string;
var Value: TJSONValue;
begin
  Result := '';
  if Parent = nil then Exit;
  Value := Parent.GetValue(Key);
  if (Value <> nil) and not (Value is TJSONNull) then Result := Value.Value;
end;

procedure RedactImageData(Value: TJSONValue);
begin
  if Value is TJSONObject then begin
    var ObjectValue := TJSONObject(Value);
    if JsonText(ObjectValue, 'type') = 'imageGeneration' then begin
      var ImageData := ObjectValue.GetValue('result');
      if ImageData is TJSONString then begin
        var CharCount := Length(ImageData.Value);
        ObjectValue.RemovePair('result').Free;
        ObjectValue.AddPair('result', Format('<image result omitted: %d characters>', [CharCount]));
      end;
    end;
    for var Pair in ObjectValue do RedactImageData(Pair.JsonValue);
  end else if Value is TJSONArray then
    for var Element in TJSONArray(Value) do RedactImageData(Element);
end;

function MessageForLog(Message: TJSONObject): string;
var Params,Item: TJSONObject;
begin
  Params:=JsonObject(Message,'params'); Item:=JsonObject(Params,'item');
  Result:=Format('method=%s id=%s thread=%s turn=%s item=%s type=%s status=%s imageDataChars=%d',
    [JsonText(Message,'method'),JsonText(Message,'id'),JsonText(Params,'threadId'),JsonText(Params,'turnId'),
     JsonText(Item,'id'),JsonText(Item,'type'),JsonText(Item,'status'),Length(JsonText(Item,'result'))]);
end;
function FindCodex: string;
var Buffer: array[0..32767] of Char; Count: DWORD; FilePart: PChar;
begin
  Result := GetEnvironmentVariable('CODEX_PIPE_EXE');
  if Result <> '' then begin
    Result := TPath.GetFullPath(Result);
    if not FileExists(Result) then raise Exception.Create('CODEX_PIPE_EXEのファイルがありません。');
    Exit;
  end;
  FilePart := nil;
  Count := SearchPath(nil, 'codex.exe', nil, Length(Buffer), Buffer, FilePart);
  if (Count>0) and (Count<DWORD(Length(Buffer))) then Exit(string(Buffer));
  // 明示指定を優先し、既存CLIをPATH・認証・ユーザー設定を変えずに利用する。
  var BestTime: TDateTime := 0;
  var Root := TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'),'OpenAI\Codex\bin');
  if DirectoryExists(Root) then
    for var Folder in TDirectory.GetDirectories(Root) do begin
      var Candidate := TPath.Combine(Folder,'codex.exe');
      if FileExists(Candidate) and (TFile.GetLastWriteTimeUtc(Candidate)>BestTime) then begin Result:=Candidate; BestTime:=TFile.GetLastWriteTimeUtc(Candidate); end;
    end;
  if Result<>'' then Exit;
  Root:=TPath.Combine(GetEnvironmentVariable('USERPROFILE'),'.vscode\extensions');
  if DirectoryExists(Root) then
    for var Folder in TDirectory.GetDirectories(Root,'openai.chatgpt-*') do begin
      var Candidate := TPath.Combine(Folder,'bin\windows-x86_64\codex.exe');
      if FileExists(Candidate) and (TFile.GetLastWriteTimeUtc(Candidate)>BestTime) then begin Result:=Candidate; BestTime:=TFile.GetLastWriteTimeUtc(Candidate); end;
    end;
  if Result='' then raise Exception.Create('codex.exeが見つかりません。PATHまたはCODEX_PIPE_EXEで指定してください。');
end;

function LineBreakPosition(const Bytes: RawByteString): Integer;
begin
  for Result := 1 to Length(Bytes) do
    if Bytes[Result] = AnsiChar(#10) then Exit;
  Result := 0;
end;

procedure CloseOwnedHandle(var Handle: THandle);
begin
  if (Handle <> 0) and (Handle <> INVALID_HANDLE_VALUE) then CloseHandle(Handle);
  Handle := 0;
end;

constructor TComicCodexWorker.Create(const RequestID,Prompt,Directory,ManagedRoot,ManagedPrefix: string; const References: TArray<string>; TimeoutMS: Cardinal);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FMode := pmDedicated; FRequestID:=RequestID; FManagedRoot:=ManagedRoot; FManagedPrefix:=ManagedPrefix;
  FReferences:=Copy(References); FTimeoutMS:=TimeoutMS; FDeferred:=TObjectList<TJSONObject>.Create(True); FReferenceLocks:=TObjectList<TFileStream>.Create(True);
  FPrompt := Prompt;
  FDirectory := TPath.GetFullPath(Directory);
  ForceDirectories(FDirectory);
  FLogPath := TPath.Combine(FDirectory, 'protocol.log');
  FLog := TStringList.Create;
  FStage := '準備中';
end;

destructor TComicCodexWorker.Destroy;
begin
  Cancel;
  if Handle <> 0 then begin
    if not FStarted then BeginRun;
    WaitFor;
  end;
  FPreparedLock.Free; FReferenceLocks.Free;
  if not FAdopted and (FPreparedRelative<>'') then DeleteFile(PChar(TPath.Combine(FManagedRoot,FPreparedRelative)));
  if FAdopted and (FImagePath<>'') and SameText(ExtractFileDir(FImagePath),FDirectory) then DeleteFile(PChar(FImagePath));
  FPreview.Free; FBitmap.Free; FDeferred.Free; FLog.Free;
  inherited;
end;

procedure TComicCodexWorker.Cancel;
begin Terminate; if Handle<>0 then CancelSynchronousIo(Handle); end;
procedure TComicCodexWorker.MarkAdopted;
begin FAdopted:=True; end;
function TComicCodexWorker.TakeBitmap: Vcl.Graphics.TBitmap;
begin Result:=FBitmap; FBitmap:=nil; end;
procedure TComicCodexWorker.PrepareImage;
var Picture: TPicture; S: Double;
begin
  if Terminated then raise EAbort.Create('生成を中止しました。');
  SetStage('受信画像を管理フォルダーで検証中');
  FPreparedRelative:=CopyValidatedComicImage(FImagePath,FManagedRoot,FManagedPrefix);
  FPreparedLock:=TFileStream.Create(TPath.Combine(FManagedRoot,FPreparedRelative),fmOpenRead or fmShareDenyWrite);
  FPreparedLock.Position:=0; FImageSHA256:=THashSHA2.GetHashString(FPreparedLock);
  FPreparedLock.Position:=0;
  Picture:=TPicture.Create;
  try
    Picture.LoadFromFile(TPath.Combine(FManagedRoot,FPreparedRelative));
    FBitmap:=Vcl.Graphics.TBitmap.Create; FBitmap.SetSize(Picture.Width,Picture.Height);
    FBitmap.Canvas.Brush.Color:=clWhite; FBitmap.Canvas.FillRect(Rect(0,0,FBitmap.Width,FBitmap.Height)); FBitmap.Canvas.Draw(0,0,Picture.Graphic);
    S:=Min(1.0,Min(840.0/Picture.Width,640.0/Picture.Height));
    FPreview:=Vcl.Graphics.TBitmap.Create; FPreview.SetSize(Max(1,Round(Picture.Width*S)),Max(1,Round(Picture.Height*S)));
    FPreview.Canvas.Brush.Color:=clWhite; FPreview.Canvas.FillRect(Rect(0,0,FPreview.Width,FPreview.Height));
    SetStretchBltMode(FPreview.Canvas.Handle,HALFTONE); FPreview.Canvas.StretchDraw(Rect(0,0,FPreview.Width,FPreview.Height),Picture.Graphic);
  finally Picture.Free; end;
  // 復号した画素をUIへ渡す前にワーカースレッドのDCを手放し、GDIの所有スレッドを混在させない。
  FBitmap.Dormant; FPreview.Dormant;
  if Terminated then raise EAbort.Create('生成を中止しました。');
  SetStage('画像検証完了・登録待ち');
end;
procedure TComicCodexWorker.BeginRun;
begin
  FStarted := True;
  Start;
end;

procedure TComicCodexWorker.SetStage(const Value: string);
begin
  TMonitor.Enter(Self);
  try FStage := Value; finally TMonitor.Exit(Self); end;
end;

function TComicCodexWorker.GetStage: string;
begin
  TMonitor.Enter(Self);
  try Result := FStage; finally TMonitor.Exit(Self); end;
end;

procedure TComicCodexWorker.Log(const Kind, Value: string);
begin
  if FLog.Count>=128 then FLog.Delete(0);
  FLog.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' ' + Kind + ' ' + Copy(Value,1,1024));
  FLog.SaveToFile(FLogPath, TEncoding.UTF8);
end;

procedure TComicCodexWorker.StartProcess;
var
  Security: TSecurityAttributes;
  Startup: TStartupInfo;
  ProcessInfo: TProcessInformation;
  Limits: TJobObjectExtendedLimitInformation;
  ChildInput, ChildOutput, ChildError: THandle;
  Command, SocketPath: string;
begin
  FExecutable := FindCodex;
  if FMode = pmDedicated then Command := 'app-server --listen stdio://'
  else begin
    Command := 'app-server proxy';
    SocketPath := GetEnvironmentVariable('CODEX_PIPE_SOCKET');
    if SocketPath <> '' then begin
      if Pos('"', SocketPath) <> 0 then raise Exception.Create('接続先パスに引用符は指定できません。');
      Command := Command + ' --sock "' + SocketPath + '"';
    end;
  end;
  Log('START', FExecutable + ' ' + Command);
  Command := '"' + FExecutable + '" ' + Command;
  UniqueString(Command);
  ChildInput := 0; ChildOutput := 0; ChildError := 0;
  ZeroMemory(@Security, SizeOf(Security));
  Security.nLength := SizeOf(Security);
  Security.bInheritHandle := True;
  try
    if not CreatePipe(ChildInput, FInput, @Security, 0) then RaiseLastOSError;
    if not SetHandleInformation(FInput, HANDLE_FLAG_INHERIT, 0) then RaiseLastOSError;
    if not CreatePipe(FOutput, ChildOutput, @Security, 0) then RaiseLastOSError;
    if not SetHandleInformation(FOutput, HANDLE_FLAG_INHERIT, 0) then RaiseLastOSError;
    if not CreatePipe(FStderr, ChildError, @Security, 0) then RaiseLastOSError;
    if not SetHandleInformation(FStderr, HANDLE_FLAG_INHERIT, 0) then RaiseLastOSError;
    FJob := CreateJobObject(nil, nil);
    if FJob = 0 then RaiseLastOSError;
    ZeroMemory(@Limits, SizeOf(Limits));
    Limits.BasicLimitInformation.LimitFlags := JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    if not SetInformationJobObject(FJob, JobObjectExtendedLimitInformation, @Limits, SizeOf(Limits)) then RaiseLastOSError;
    ZeroMemory(@Startup, SizeOf(Startup));
    Startup.cb := SizeOf(Startup);
    Startup.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    Startup.wShowWindow := SW_HIDE;
    Startup.hStdInput := ChildInput;
    Startup.hStdOutput := ChildOutput;
    Startup.hStdError := ChildError;
    ZeroMemory(@ProcessInfo, SizeOf(ProcessInfo));
    if not CreateProcess(PChar(FExecutable), PChar(Command), nil, nil, True,
      CREATE_NO_WINDOW or CREATE_SUSPENDED, nil, PChar(FDirectory), Startup, ProcessInfo) then RaiseLastOSError;
    FProcess := ProcessInfo.hProcess;
    try
      if not AssignProcessToJobObject(FJob, FProcess) then begin
        TerminateProcess(FProcess, 1);
        RaiseLastOSError;
      end;
      if ResumeThread(ProcessInfo.hThread) = DWORD(-1) then RaiseLastOSError;
    finally CloseHandle(ProcessInfo.hThread); end;
  finally
    CloseOwnedHandle(ChildInput);
    CloseOwnedHandle(ChildOutput);
    CloseOwnedHandle(ChildError);
  end;
end;

procedure TComicCodexWorker.StopProcess;
begin
  CloseOwnedHandle(FInput);
  if FProcess <> 0 then WaitForSingleObject(FProcess, 500);
  // 専用モードは自分のサーバー群、既存モードはproxyのみ。既存サーバーはJobに属さない。
  CloseOwnedHandle(FJob);
  CloseOwnedHandle(FProcess);
  CloseOwnedHandle(FOutput);
  CloseOwnedHandle(FStderr);
end;

procedure TComicCodexWorker.Send(ObjectValue: TJSONObject);
var Bytes: TBytes; Written,Offset: DWORD; Done: THandle; Watcher: TThread; TimedOut: Integer;
begin
  Done:=0; Watcher:=nil; TimedOut:=0;
  try
    if Terminated then raise EAbort.Create('生成を中止しました。');
    Log('SEND',MessageForLog(ObjectValue)); Bytes:=TEncoding.UTF8.GetBytes(ObjectValue.ToJSON+#10);
    Done:=CreateEvent(nil,True,False,nil); if Done=0 then RaiseLastOSError;
    Watcher:=TThread.CreateAnonymousThread(
      procedure
      begin
        if WaitForSingleObject(Done,Min(FTimeoutMS,Cardinal(30000)))=WAIT_TIMEOUT then begin
          InterlockedExchange(TimedOut,1);
          // 送信が取消を認識するまで要求を続け、状態確認とWriteFile開始の競合による待ち残りを防ぐ。
          repeat
            CancelSynchronousIo(Handle);
          until WaitForSingleObject(Done,10)<>WAIT_TIMEOUT;
        end;
      end);
    Watcher.FreeOnTerminate:=False; Watcher.Start;
    try
      Offset:=0;
      while Offset<DWORD(Length(Bytes)) do begin
        if Terminated then raise EAbort.Create('生成を中止しました。');
        if InterlockedCompareExchange(TimedOut,0,0)<>0 then raise Exception.Create('Codexへの送信がタイムアウトしました。');
        if not WriteFile(FInput,Bytes[Offset],Length(Bytes)-Offset,Written,nil) then begin
          if InterlockedCompareExchange(TimedOut,0,0)<>0 then raise Exception.Create('Codexへの送信がタイムアウトしました。');
          if Terminated then raise EAbort.Create('生成を中止しました。');
          RaiseLastOSError;
        end;
        if Written=0 then raise Exception.Create('Codexへの送信が途中で終了しました。');
        Inc(Offset,Written);
      end;
    finally
      SetEvent(Done); Watcher.WaitFor;
    end;
  finally Watcher.Free; if Done<>0 then CloseHandle(Done); ObjectValue.Free; end;
end;
procedure TComicCodexWorker.DrainPipe(Pipe: THandle; var Pending: RawByteString);
var Available, Count: DWORD; Buffer: array[0..8191] of Byte; Part: RawByteString;
begin
  if not PeekNamedPipe(Pipe, nil, 0, nil, @Available, nil) then Exit;
  if Available = 0 then Exit;
  if Available > SizeOf(Buffer) then Available := SizeOf(Buffer);
  if not ReadFile(Pipe, Buffer[0], Available, Count, nil) then RaiseLastOSError;
  SetString(Part, PAnsiChar(@Buffer[0]), Count);
  Pending := Pending + Part;
  if Length(Pending) > 64 * 1024 * 1024 then raise Exception.Create('パイプの1行が64MBを超えました。');
end;

function TComicCodexWorker.ReadMessage(Deadline: UInt64): TJSONObject;
var Position: Integer; Line: RawByteString; Text: string; ExitStatus: DWORD; Parsed: TJSONValue;
begin
  repeat
    if Terminated then raise EAbort.Create('中止しました。');
    DrainPipe(FStderr, FPendingError);
    Position := LineBreakPosition(FPendingError);
    while Position > 0 do begin
      Line := Copy(FPendingError, 1, Position - 1);
      Delete(FPendingError, 1, Position);
      Log('STDERR', 'diagnostic received');
      if Trim(UTF8ToString(Line)) <> '' then FLastDiagnostic := Trim(UTF8ToString(Line));
      Position := LineBreakPosition(FPendingError);
    end;
    DrainPipe(FOutput, FPendingOutput);
    Position := LineBreakPosition(FPendingOutput);
    if Position > 0 then begin
      Line := Copy(FPendingOutput, 1, Position - 1);
      Delete(FPendingOutput, 1, Position);
      Text := UTF8ToString(Line).Trim;
      if Text = '' then Continue;
      FLastMessageBytes:=Length(Line);
      Parsed := TJSONObject.ParseJSONValue(Text);
      if not (Parsed is TJSONObject) then begin
        Parsed.Free;
        raise Exception.Create('CodexがJSONオブジェクト以外を返しました。ログを確認してください。');
      end;
      Log('RECV', MessageForLog(TJSONObject(Parsed)));
      Exit(TJSONObject(Parsed));
    end;
    if WaitForSingleObject(FProcess, 0) = WAIT_OBJECT_0 then begin
      // 残りのstdoutがある場合は次の巡回で読み切る。
      var Available: DWORD := 0;
      PeekNamedPipe(FOutput, nil, 0, nil, @Available, nil);
      if Available > 0 then Continue;
      if FPendingError <> '' then begin
        FLastDiagnostic := Trim(UTF8ToString(FPendingError));
        Log('STDERR', FLastDiagnostic);
      end;
      GetExitCodeProcess(FProcess, ExitStatus);
      raise Exception.CreateFmt('Codex接続プロセスが終了しました（終了コード%d）。%s', [ExitStatus, FLastDiagnostic]);
    end;
    if GetTickCount64 >= Deadline then raise Exception.Create('Codex応答がタイムアウトしました。');
    Sleep(10);
  until False;
end;

procedure TComicCodexWorker.ReceiveImage(Item: TJSONObject);
var Source, Data, Extension: string; Bytes: TBytes;
begin
  if JsonText(Item,'id')='' then raise Exception.Create('画像生成通知にIDがありません。');
  if FImageGenerated then begin
    if JsonText(Item,'id')=FImageItemId then Exit;
    raise Exception.Create('1要求に複数の画像生成結果があり、採用先を確定できません。');
  end;
  if JsonText(Item, 'status') <> 'completed' then
    raise Exception.Create('画像生成に失敗しました: ' + MessageForLog(Item));
  if (Item.GetValue('failure') <> nil) and not (Item.GetValue('failure') is TJSONNull) then
    raise Exception.Create('画像生成エラー: ' + Item.GetValue('failure').ToJSON);
  Source := JsonText(Item, 'savedPath');
  if Source <> '' then begin
    RequireLocalImagePath(Source);
    if not FileExists(Source) then
      raise Exception.Create('Codexから返された画像ファイルを読み取れません: ' + Source);
    FSourceImagePath := TPath.GetFullPath(Source);
    Extension := LowerCase(TPath.GetExtension(Source));
    if (Extension <> '.png') and (Extension <> '.jpg') and (Extension <> '.jpeg') and (Extension <> '.bmp') then
      raise Exception.Create('未対応の生成画像形式: ' + Extension);
    if TFile.GetSize(FSourceImagePath)>64*1024*1024 then raise Exception.Create('生成画像が64MBを超えました。');
    FImagePath := TPath.Combine(FDirectory, 'received-image' + Extension);
    TFile.Copy(FSourceImagePath, FImagePath, False);
  end else begin
    Data := JsonText(Item, 'result');
    if Data = '' then raise Exception.Create('画像生成完了通知に保存先も画像データもありません。');
    Extension := '.png';
    if Data.StartsWith('data:') then begin
      if Data.StartsWith('data:image/jpeg;base64,') then Extension := '.jpg'
      else if not Data.StartsWith('data:image/png;base64,') then
        raise Exception.Create('未対応の画像データ形式です。');
      Delete(Data, 1, Pos(',', Data));
    end;
    Bytes := TNetEncoding.Base64.DecodeStringToBytes(Data);
    FImagePath := TPath.Combine(FDirectory, 'received-image' + Extension);
    TFile.WriteAllBytes(FImagePath, Bytes);
  end;
  ValidateComicImage(FImagePath);
  if TFile.GetSize(FImagePath) = 0 then raise Exception.Create('返された画像ファイルが空です。');
  FImageItemId := JsonText(Item, 'id');
  FImageGenerated := True;
  Log('IMAGE', FImagePath);
  SetStage('生成画像をパイプで受信しました');
end;

procedure TComicCodexWorker.HandleNotification(Message: TJSONObject);
var Method: string; Params, Item: TJSONObject;
begin
  Method := JsonText(Message, 'method');
  Params := JsonObject(Message, 'params');
  if (Method <> '') and (Message.GetValue('id') <> nil) then begin
    // この小型クライアントは承認画面や動的ツールを提供しない。
    var Reply := TJSONObject.Create;
    Reply.AddPair('id', Message.GetValue('id').Clone as TJSONValue);
    Reply.AddPair('error', TJSONObject.Create.AddPair('code', TJSONNumber.Create(-32601))
      .AddPair('message', 'This probe does not implement client tools or approvals.'));
    Send(Reply);
    Exit;
  end;
  if (Params = nil) or (JsonText(Params, 'threadId') <> FThreadId) then Exit;
  if FTurnId='' then begin
    if (FDeferred.Count>=16) or (FDeferredBytes+FLastMessageBytes>64*1024*1024) then raise Exception.Create('先行通知が上限を超えました。');
    FDeferred.Add(Message.Clone as TJSONObject); Inc(FDeferredBytes,FLastMessageBytes); Exit;
  end;
  if Method='turn/completed' then begin
    if JsonText(JsonObject(Params,'turn'),'id')<>FTurnId then Exit;
  end else if JsonText(Params,'turnId')<>FTurnId then Exit;
  if Method = 'turn/completed' then begin
    var CompletedTurn := JsonObject(Params, 'turn');
    FCompletedTurnId := JsonText(CompletedTurn, 'id');
    FCompletedStatus := JsonText(CompletedTurn, 'status');
    FCompletedError := FCompletedStatus+': '+Copy(JsonText(JsonObject(CompletedTurn,'error'),'message'),1,512);
  end;
  if Method = 'item/started' then begin
    Item := JsonObject(Params, 'item');
    if JsonText(Item, 'type') = 'imageGeneration' then SetStage('専用Codexで画像生成中');
  end;
  if Method = 'item/completed' then begin
    Item := JsonObject(Params, 'item');
    if JsonText(Item, 'type') = 'imageGeneration' then ReceiveImage(Item);
    if JsonText(Item, 'type') = 'agentMessage' then begin
      // commentaryは進捗。最終回答があれば最終回答で上書きする。
      if JsonText(Item, 'phase') <> 'commentary' then FAnswer := JsonText(Item, 'text');
    end;
  end;
end;

function TComicCodexWorker.Request(const Method: string; Params: TJSONObject): TJSONObject;
var Id: Integer; Message: TJSONObject; Deadline: UInt64;
begin
  Inc(FNextId); Id := FNextId;
  Send(TJSONObject.Create.AddPair('id', TJSONNumber.Create(Id)).AddPair('method', Method).AddPair('params', Params));
  Deadline := GetTickCount64 + Min(FTimeoutMS,Cardinal(30000));
  repeat
    Message := ReadMessage(Deadline);
    if (JsonText(Message, 'id') = IntToStr(Id)) and (JsonText(Message, 'method') = '') then begin
      if Message.GetValue('error') <> nil then begin
        var Failure := Message.GetValue('error').ToJSON;
        Message.Free;
        raise Exception.Create(Method + ': ' + Failure);
      end;
      Exit(Message);
    end;
    try HandleNotification(Message); finally Message.Free; end;
  until False;
end;

procedure TComicCodexWorker.RunConversation;
var Reply, Params, Thread, Message, Turn: TJSONObject; InputItems: TJSONArray; Deadline: UInt64;
begin
  SetStage('Codexへ接続・初期化中');
  Reply := Request('initialize', TJSONObject.Create.AddPair('clientInfo',
    TJSONObject.Create.AddPair('name', 'mangamaker_image_generation').AddPair('title', 'MangaMaker Image Generation').AddPair('version', '1.0.0')));
  Reply.Free;
  Send(TJSONObject.Create.AddPair('method', 'initialized'));
  SetStage('確認用セッションを準備中');
  Params := TJSONObject.Create.AddPair('cwd', FDirectory).AddPair('approvalPolicy', 'never')
    .AddPair('sandbox', 'read-only').AddPair('ephemeral', TJSONBool.Create(True))
    .AddPair('developerInstructions', 'This is a MangaMaker image-generation request. Read the user prompt and use the built-in image generation tool to generate exactly one new raster image. Use the native image tool, not Python, SVG, drawing code, shell scripts, external APIs, or existing files. Do not browse, edit code, or delegate. The native tool saves its output automatically. After generation, give a brief completion message with the saved image path if available. If image generation is unavailable or fails, report the actual error; never pretend to have generated an image.')
    .AddPair('config', TJSONObject.Create.AddPair('features.image_generation', TJSONBool.Create(True)));
  // モデルは利用者の設定を使用。必要な場合だけ環境変数で明示する。
  var Model := GetEnvironmentVariable('CODEX_PIPE_MODEL');
  if Model <> '' then Params.AddPair('model', Model);
  Reply := Request('thread/start', Params);
  try
    Thread := JsonObject(JsonObject(Reply, 'result'), 'thread');
    FThreadId := JsonText(Thread, 'id');
    if FThreadId = '' then raise Exception.Create('thread/startにthread.idがありません。');
  finally Reply.Free; end;
  SetStage('Codexへプロンプト送信中');
  InputItems := TJSONArray.Create;
  InputItems.AddElement(TJSONObject.Create.AddPair('type', 'text').AddPair('text', FPrompt));
  for var Reference in FReferences do begin
    ValidateComicImage(Reference);
    InputItems.AddElement(TJSONObject.Create.AddPair('type','localImage').AddPair('path',Reference));
  end;
  Reply := Request('turn/start', TJSONObject.Create.AddPair('threadId', FThreadId).AddPair('clientUserMessageId',FRequestID).AddPair('input', InputItems));
  try
    Turn := JsonObject(JsonObject(Reply, 'result'), 'turn');
    FTurnId := JsonText(Turn, 'id');
    if FTurnId = '' then raise Exception.Create('turn/startにturn.idがありません。');
  finally Reply.Free; end;
  for var Early in FDeferred do HandleNotification(Early);
  FDeferred.Clear; FDeferredBytes:=0;
  SetStage('Codexの画像生成待ち');
  Deadline := GetTickCount64 + FTimeoutMS;
  repeat
    // 完了がturn/startの応答より先に届いた場合も、受信済みの通知を失わない。
    if FCompletedTurnId = FTurnId then begin
      if FCompletedStatus <> 'completed' then
        raise Exception.Create('Codexの処理は成功していません: ' + FCompletedError);
      if not FImageGenerated then
        raise Exception.Create('ターンは終了しましたが、画像生成完了通知を受信していません。回答: ' + FAnswer);
      FSuccess := True;
      SetStage('生成画像の受信完了。アプリで表示確認中');
      Exit;
    end;
    Message := ReadMessage(Deadline);
    try
      HandleNotification(Message);
    finally Message.Free; end;
  until False;
end;

procedure TComicCodexWorker.Execute;
begin
  if Terminated then Exit;
  try
    try
      for var Reference in FReferences do begin
        FReferenceLocks.Add(TFileStream.Create(Reference,fmOpenRead or fmShareDenyWrite));
        ValidateComicImage(Reference);
      end;
      StartProcess;
      RunConversation;
      PrepareImage;
    except
      on E: Exception do begin
        FSuccess:=False; FError := Copy(E.Message,1,1024);
        SetStage('失敗：' + FError);
        Log('ERROR', E.ClassName + ': ' + FError);
        // 既存サーバーの処理を残さないよう、自分が開始したturnだけを中断する。
        if (FTurnId <> '') and not FSuccess then
          try Send(TJSONObject.Create.AddPair('id', TJSONNumber.Create(9999)).AddPair('method', 'turn/interrupt')
            .AddPair('params', TJSONObject.Create.AddPair('threadId', FThreadId).AddPair('turnId', FTurnId)));
          except end;
      end;
    end;
  finally StopProcess; end;
end;

end.
