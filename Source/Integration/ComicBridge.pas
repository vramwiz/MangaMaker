unit ComicBridge;

// 責務：同一Windowsユーザーのローカルパイプを受け付け、制限付きI/OとUIスレッドへの受渡しを行う。

interface

uses Winapi.Windows, System.SysUtils, System.Classes;

type
  TComicBridgeHandler = procedure(const Request: string; out Reply: string) of object;
  TComicBridge = class(TThread)
  private
    FPipe,FStop: THandle;
    FName,FManifest,FRequest,FReply: string;
    FHandler: TComicBridgeHandler;
    FLaunched: Boolean;
    procedure DispatchRequest;
  protected
    procedure Execute; override;
  public
    constructor Create(const RuntimeFolder: string; Handler: TComicBridgeHandler);
    destructor Destroy; override;
    procedure Stop;
    property PipeName: string read FName;
    property ManifestPath: string read FManifest;
  end;

function ComicBridgeRequest(const PipeName,Request: string; TimeoutMS: Cardinal=30000): string;

implementation

uses System.JSON, System.IOUtils, ComicModel;

const MaxRequestBytes=1024*1024; MaxReplyBytes=4*1024*1024;

function ConvertStringSecurityDescriptorToSecurityDescriptorW(Text: PWideChar; Revision: DWORD;
  out Descriptor: Pointer; Size: PDWORD): BOOL; stdcall; external 'advapi32.dll';

function UserSecurityDescriptor: Pointer;
var Token: THandle; Size: DWORD; Buffer: TBytes; SidText: PWideChar; SDDL: string;
begin
  Result:=nil; Token:=0; SidText:=nil;
  if not OpenProcessToken(GetCurrentProcess,TOKEN_QUERY,Token) then RaiseLastOSError;
  try
    Size:=0; GetTokenInformation(Token,TokenUser,nil,0,Size); if Size=0 then RaiseLastOSError;
    SetLength(Buffer,Size);
    if not GetTokenInformation(Token,TokenUser,@Buffer[0],Size,Size) then RaiseLastOSError;
    if not ConvertSidToStringSid(PTokenUser(@Buffer[0]).User.Sid,SidText) then RaiseLastOSError;
    try SDDL:='D:P(A;;GA;;;'+string(SidText)+')';
      if not ConvertStringSecurityDescriptorToSecurityDescriptorW(PChar(SDDL),1,Result,nil) then RaiseLastOSError;
    finally LocalFree(HLOCAL(SidText)); end;
  finally CloseHandle(Token); end;
end;

function Remaining(Deadline: UInt64): Cardinal;
var NowTick: UInt64;
begin
  NowTick:=GetTickCount64;
  if NowTick>=Deadline then Result:=0 else Result:=Cardinal(Deadline-NowTick);
end;

procedure FinishIO(Pipe,StopEvent: THandle; var Operation: TOverlapped; Started: Boolean;
  Timeout: Cardinal; out Count: DWORD);
var Error,WaitResult: DWORD; Events: array[0..1] of THandle; EventCount: Cardinal;
begin
  Error:=GetLastError;
  if not Started and (Error<>ERROR_IO_PENDING) then RaiseLastOSError(Error);
  Events[0]:=Operation.hEvent; EventCount:=1;
  if StopEvent<>0 then begin Events[0]:=StopEvent; Events[1]:=Operation.hEvent; EventCount:=2; end;
  if not Started then begin
    WaitResult:=WaitForMultipleObjects(EventCount,@Events[0],False,Timeout);
    if (WaitResult=WAIT_TIMEOUT) or ((StopEvent<>0) and (WaitResult=WAIT_OBJECT_0)) or (WaitResult=WAIT_FAILED) then begin
      // 取消完了まではOVERLAPPEDとバッファを生存させ、遅延したI/Oに解放済みメモリを渡さない。
      CancelIoEx(Pipe,@Operation); GetOverlappedResult(Pipe,Operation,Count,True);
      if WaitResult=WAIT_TIMEOUT then raise Exception.Create('パイプ通信がタイムアウトしました。');
      if WaitResult=WAIT_FAILED then RaiseLastOSError;
      raise EAbort.Create('パイプ通信を停止しました。');
    end;
  end;
  if not GetOverlappedResult(Pipe,Operation,Count,False) then RaiseLastOSError;
end;

function ReadLine(Pipe,StopEvent: THandle; Limit: Integer; Deadline: UInt64): string;
var Bytes,Chunk: TBytes; Count: DWORD; Operation: TOverlapped; I,N: Integer; Complete: Boolean;
begin
  Result:=''; SetLength(Chunk,4096); Operation:=Default(TOverlapped);
  Operation.hEvent:=CreateEvent(nil,True,False,nil); if Operation.hEvent=0 then RaiseLastOSError;
  try
    Complete:=False;
    while not Complete do begin
      ResetEvent(Operation.hEvent);
      FinishIO(Pipe,StopEvent,Operation,ReadFile(Pipe,Chunk[0],Length(Chunk),Count,@Operation),Remaining(Deadline),Count);
      if Count=0 then raise Exception.Create('パイプ要求が完了前に切断されました。');
      N:=Length(Bytes); if N+Integer(Count)>Limit then raise Exception.Create('パイプ要求がサイズ上限を超えました。');
      SetLength(Bytes,N+Integer(Count)); Move(Chunk[0],Bytes[N],Count);
      for I:=N to High(Bytes) do if Bytes[I]=10 then begin
        if I<>High(Bytes) then raise Exception.Create('1接続では1要求だけを送信してください。');
        SetLength(Bytes,I); Complete:=True; Break;
      end;
    end;
    Result:=TEncoding.UTF8.GetString(Bytes);
    Chunk:=TEncoding.UTF8.GetBytes(Result);
    if (Length(Chunk)<>Length(Bytes)) or ((Length(Bytes)>0) and not CompareMem(@Bytes[0],@Chunk[0],Length(Bytes))) then
      raise Exception.Create('パイプ要求はUTF-8で送信してください。');
  finally CloseHandle(Operation.hEvent); end;
end;

procedure WriteLine(Pipe,StopEvent: THandle; const Text: string; Deadline: UInt64);
var Bytes: TBytes; Operation: TOverlapped; Count: DWORD; At: Integer;
begin
  Bytes:=TEncoding.UTF8.GetBytes(Text+#10);
  if Length(Bytes)>MaxReplyBytes then raise Exception.Create('パイプ応答がサイズ上限を超えました。');
  Operation:=Default(TOverlapped); Operation.hEvent:=CreateEvent(nil,True,False,nil);
  if Operation.hEvent=0 then RaiseLastOSError;
  try
    At:=0;
    while At<Length(Bytes) do begin
      ResetEvent(Operation.hEvent);
      FinishIO(Pipe,StopEvent,Operation,WriteFile(Pipe,Bytes[At],Length(Bytes)-At,Count,@Operation),Remaining(Deadline),Count);
      if Count=0 then raise Exception.Create('パイプへの書込が中断されました。'); Inc(At,Count);
    end;
  finally CloseHandle(Operation.hEvent); end;
end;

function ErrorReply(const Message: string): string;
var J: TJSONObject;
begin
  J:=TJSONObject.Create;
  try J.AddPair('ok',TJSONBool.Create(False)); J.AddPair('error',Message); Result:=J.ToJSON; finally J.Free; end;
end;

constructor TComicBridge.Create(const RuntimeFolder: string; Handler: TComicBridgeHandler);
var Attributes: TSecurityAttributes; Descriptor: Pointer; J: TJSONObject;
begin
  inherited Create(False); FreeOnTerminate:=False; FPipe:=INVALID_HANDLE_VALUE; FHandler:=Handler;
  FStop:=CreateEvent(nil,True,False,nil); if FStop=0 then RaiseLastOSError;
  FName:='MangaMaker-'+IntToStr(GetCurrentProcessId)+'-'+NewUID;
  Descriptor:=UserSecurityDescriptor;
  try
    Attributes:=Default(TSecurityAttributes); Attributes.nLength:=SizeOf(Attributes); Attributes.lpSecurityDescriptor:=Descriptor;
    FPipe:=CreateNamedPipe(PChar('\\.\pipe\'+FName),PIPE_ACCESS_DUPLEX or FILE_FLAG_OVERLAPPED or FILE_FLAG_FIRST_PIPE_INSTANCE,
      PIPE_TYPE_BYTE or PIPE_READMODE_BYTE or PIPE_WAIT or $8,1,65536,65536,30000,@Attributes);
    if FPipe=INVALID_HANDLE_VALUE then RaiseLastOSError;
  finally LocalFree(HLOCAL(Descriptor)); end;
  ForceDirectories(RuntimeFolder); FManifest:=TPath.Combine(RuntimeFolder,'bridge-'+IntToStr(GetCurrentProcessId)+'.json');
  J:=TJSONObject.Create;
  try
    J.AddPair('version',TJSONNumber.Create(1)); J.AddPair('processId',TJSONNumber.Create(GetCurrentProcessId));
    J.AddPair('pipe',FName); J.AddPair('encoding','UTF-8'); J.AddPair('framing','JSON followed by LF; one request per connection');
    AtomicWrite(FManifest,J.ToJSON);
  finally J.Free; end;
  FLaunched:=True;
end;

procedure TComicBridge.Stop;
begin
  Terminate; if FStop<>0 then SetEvent(FStop);
  if FLaunched then begin WaitFor; FLaunched:=False; end;
end;

destructor TComicBridge.Destroy;
begin
  Stop;
  if FPipe<>INVALID_HANDLE_VALUE then CloseHandle(FPipe);
  if FStop<>0 then CloseHandle(FStop);
  if (FManifest<>'') and FileExists(FManifest) then
    try TFile.Delete(FManifest); except end;
  inherited;
end;

procedure TComicBridge.DispatchRequest;
begin
  if Terminated then begin FReply:=ErrorReply('アプリを終了しています。'); Exit; end;
  try FHandler(FRequest,FReply); except on E: Exception do FReply:=ErrorReply(E.Message); end;
end;

procedure TComicBridge.Execute;
var Operation: TOverlapped; Count,Error: DWORD; Connected: Boolean; Deadline: UInt64; Drain: Byte;
begin
  if (FPipe=INVALID_HANDLE_VALUE) or (FStop=0) then Exit;
  Operation:=Default(TOverlapped); Operation.hEvent:=CreateEvent(nil,True,False,nil);
  if Operation.hEvent=0 then Exit;
  try
    while not Terminated do begin
      Connected:=False;
      try
        ResetEvent(Operation.hEvent);
        if ConnectNamedPipe(FPipe,@Operation) then Connected:=True
        else begin Error:=GetLastError;
          if Error=ERROR_PIPE_CONNECTED then Connected:=True
          else begin SetLastError(Error); FinishIO(FPipe,FStop,Operation,False,INFINITE,Count); Connected:=True; end;
        end;
        if Terminated then Exit;
        Deadline:=GetTickCount64+30000;
        try
          // パイプ側は要求文字列だけを受け持ち、作品とVCLへの書込はUIスレッドで直列化する。
          FRequest:=ReadLine(FPipe,FStop,MaxRequestBytes,Deadline); FReply:=''; Synchronize(DispatchRequest);
        except on E: Exception do FReply:=ErrorReply(E.Message); end;
        if Terminated then Exit;
        WriteLine(FPipe,FStop,FReply,Deadline);
        // 応答を相手が読み終えるまで接続を保持し、成功した処理の応答を切断で失わせない。
        ResetEvent(Operation.hEvent);
        FinishIO(FPipe,FStop,Operation,ReadFile(FPipe,Drain,1,Count,@Operation),Remaining(Deadline),Count);
      except on E: Exception do begin if Terminated then Exit; end; end;
      if Connected then DisconnectNamedPipe(FPipe);
    end;
  finally CloseHandle(Operation.hEvent); end;
end;

function ComicBridgeRequest(const PipeName,Request: string; TimeoutMS: Cardinal): string;
var Pipe: THandle; Path: string; Deadline: UInt64; Error: DWORD;
begin
  if (PipeName='') or (Length(PipeName)>250) or (Pos('\',PipeName)>0) or (Pos('/',PipeName)>0) or
    (Pos(#0,PipeName)>0) then raise Exception.Create('パイプ名が不正です。');
  if (TimeoutMS=0) or (TimeoutMS>60000) then raise Exception.Create('通信の制限時間が不正です。');
  if Length(TEncoding.UTF8.GetBytes(Request))>=MaxRequestBytes then raise Exception.Create('要求がサイズ上限を超えました。');
  if (Pos(#10,Request)>0) or (Pos(#13,Request)>0) then raise Exception.Create('要求JSONは1行で送信してください。');
  Path:='\\.\pipe\'+PipeName; Deadline:=GetTickCount64+TimeoutMS;
  repeat
    Pipe:=CreateFile(PChar(Path),GENERIC_READ or GENERIC_WRITE,0,nil,OPEN_EXISTING,FILE_FLAG_OVERLAPPED,0);
    if Pipe<>INVALID_HANDLE_VALUE then Break;
    Error:=GetLastError; if Error<>ERROR_PIPE_BUSY then RaiseLastOSError(Error);
    if not WaitNamedPipe(PChar(Path),Remaining(Deadline)) then RaiseLastOSError;
  until False;
  try WriteLine(Pipe,0,Request,Deadline); Result:=ReadLine(Pipe,0,MaxReplyBytes,Deadline);
  finally CloseHandle(Pipe); end;
end;

end.
