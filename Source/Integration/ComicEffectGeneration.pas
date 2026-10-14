unit ComicEffectGeneration;

// 責務：効果素材の非同期生成を既存Codex通信へ接続し、結果はスレッド終了後だけ受け取る。
interface
uses System.SysUtils;
type
  IComicEffectGeneration = interface
    ['{B6DA1FE8-0AC6-4C65-A7E8-25E9B3EB9441}']
    procedure Start(const RequestID,Prompt,WorkDirectory,MaterialRoot: string);
    function Poll(out Relative,Error: string): Boolean;
    function Stage: string;
    procedure Adopted;
    procedure Cancel;
  end;
  TComicEffectGenerationFactory = function: IComicEffectGeneration;
function NewComicEffectGeneration: IComicEffectGeneration;
implementation
uses ComicCodexTransport;
type
  TComicEffectGeneration = class(TInterfacedObject,IComicEffectGeneration)
  private
    FWorker: TComicCodexWorker;
  public
    destructor Destroy; override;
    procedure Start(const RequestID,Prompt,WorkDirectory,MaterialRoot: string);
    function Poll(out Relative,Error: string): Boolean;
    function Stage: string;
    procedure Adopted;
    procedure Cancel;
  end;
function NewComicEffectGeneration: IComicEffectGeneration;
begin Result:=TComicEffectGeneration.Create; end;
destructor TComicEffectGeneration.Destroy;
begin Cancel; FWorker.Free; inherited; end;
procedure TComicEffectGeneration.Start(const RequestID,Prompt,WorkDirectory,MaterialRoot: string);
begin
  if FWorker<>nil then raise Exception.Create('生成はすでに開始されています。');
  FWorker:=TComicCodexWorker.Create(RequestID,Prompt,WorkDirectory,MaterialRoot,'generated-',[],600000);
  FWorker.BeginRun;
end;
function TComicEffectGeneration.Poll(out Relative,Error: string): Boolean;
begin
  Relative:=''; Error:=''; Result:=(FWorker<>nil) and FWorker.Finished;
  if not Result then Exit;
  if FWorker.Success then Relative:=FWorker.PreparedRelative else Error:=FWorker.ErrorText;
end;
function TComicEffectGeneration.Stage: string;
begin if FWorker=nil then Result:='' else Result:=FWorker.Stage; end;
procedure TComicEffectGeneration.Adopted;
begin if FWorker<>nil then FWorker.MarkAdopted; end;
procedure TComicEffectGeneration.Cancel;
begin if FWorker<>nil then FWorker.Cancel; end;
end.
