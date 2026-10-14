unit ComicPerformance;

// 責務：Debugだけで描画・入力・保存を集計する。ログ書込で編集スレッドを待たせない。

// 計測ユニットと呼出箇所はReleaseから除外し、製品の実行経路に計測を残さない。
{$IFNDEF DEBUG}{$MESSAGE ERROR 'ComicPerformance requires DEBUG'}{$ENDIF}

interface

uses Winapi.Windows;

type
  TComicPerfKind = (cpMouseDown,cpMouseMove,cpMouseUp,cpWheel,cpEmptyHit,
    cpPanelHit,cpBalloonHit,cpPaint,cpThumbnail,cpRender,cpImageLookup,
    cpImageStat,cpImageDecode,cpImageHit,cpFilterLookup,cpFilterBuild,
    cpFilterHit,cpTextBounds,cpTextLayout,cpSnapshot,cpRestore,cpSaveDraft,
    cpChanged,cpRefreshUI,cpUndo,cpRedo,cpOpen,cpSave,cpGenerationTick,
    cpPanelRegion,cpBalloonRegion,cpBalloonBody,cpPanelImage,cpPanelFrame,
    cpBalloonDraw,cpTextDraw,cpFrameRegion,cpFillRegion,cpOverlayDraw);
  TComicPerfScope = record
  private
    FStarted: Int64;
    FKind: TComicPerfKind;
  public
    class operator Initialize(out Dest: TComicPerfScope);
    class operator Finalize(var Dest: TComicPerfScope);
    procedure Start(Kind: TComicPerfKind);
  end;

procedure StartComicPerformance(const DataDirectory: string);
procedure StopComicPerformance;
procedure CountComicPerformance(Kind: TComicPerfKind);
function ComicPerfFileExists(const FileName: string): Boolean;
function ComicPerfFrameRgn(DC: HDC; Region: HRGN; Brush: HBRUSH; W,H: Integer): BOOL;
function ComicPerfFillRgn(DC: HDC; Region: HRGN; Brush: HBRUSH): BOOL;

implementation

uses System.SysUtils, System.Classes, System.SyncObjs,
  System.IOUtils, System.Diagnostics;

const
  Schema = 'MangaMaker.DebugPerformance.v1';
  FileLimit = 256*1024;
  GlobalLimit = 4*1024*1024;
  GlobalFileLimit = 64;
  Names: array[TComicPerfKind] of string = (
    'input.mouse_down','input.mouse_move','input.mouse_up','input.wheel','hit.empty',
    'hit.panel','hit.balloon','ui.paint','ui.thumbnail','render.page','image.lookup',
    'image.file_exists','image.decode','image.cache_hit','filter.lookup','filter.build',
    'filter.cache_hit','text.bounds','text.layout','project.snapshot','project.restore',
    'project.save_draft','ui.changed','ui.refresh','ui.undo','ui.redo','project.open',
    'project.save','generation.tick','region.panel','region.balloon','region.balloon_body',
    'draw.panel_image','draw.panel_frame','draw.balloon','draw.text_cell',
    'gdi.frame_region','gdi.fill_region','draw.overlay');
type
  TCounter = record
    Count,Ticks,Maximum,Slow50: Int64;
  end;
  TCounters = array[TComicPerfKind] of TCounter;
  TPerfWriter = class(TThread)
  private
    FFolder: string;
    FSlot: Integer;
    FStream: TFileStream;
    FRunID: string;
    FCreated: array[0..1] of Boolean;
    FBudget: Int64;
    FFileCount: Integer;
    FQuotaExhausted: Boolean;
    procedure Line(const S: string);
    procedure FlushCounters;
  protected
    procedure Execute; override;
  public
    constructor Create(const Folder: string);
    destructor Destroy; override;
  end;
var
  Counters: TCounters;
  CounterLock: TRTLCriticalSection;
  Active: Integer;
  Dropped: Int64;
  Writer: TPerfWriter;
  Wake: TEvent;
  Frequency: Int64;

procedure RecordElapsed(Kind: TComicPerfKind; Elapsed: Int64);
begin
  // 入力・描画スレッドは集計ロックを待たず、競合時は欠落件数だけを記録する。
  if not TryEnterCriticalSection(CounterLock) then begin TInterlocked.Increment(Dropped); Exit; end;
  try
    Inc(Counters[Kind].Count); Inc(Counters[Kind].Ticks,Elapsed);
    if Elapsed>Counters[Kind].Maximum then Counters[Kind].Maximum:=Elapsed;
    if Elapsed>=Frequency div 20 then Inc(Counters[Kind].Slow50);
  finally LeaveCriticalSection(CounterLock); end;
end;
class operator TComicPerfScope.Initialize(out Dest: TComicPerfScope);
begin Dest.FStarted:=0; Dest.FKind:=Low(TComicPerfKind); end;
class operator TComicPerfScope.Finalize(var Dest: TComicPerfScope);
begin
  if Dest.FStarted<>0 then RecordElapsed(Dest.FKind,TStopwatch.GetTimeStamp-Dest.FStarted);
end;
procedure TComicPerfScope.Start(Kind: TComicPerfKind);
begin
  FKind:=Kind; FStarted:=0;
  if TInterlocked.CompareExchange(Active,0,0)<>0 then FStarted:=TStopwatch.GetTimeStamp;
end;
procedure CountComicPerformance(Kind: TComicPerfKind);
begin if TInterlocked.CompareExchange(Active,0,0)<>0 then RecordElapsed(Kind,0); end;
function ComicPerfFileExists(const FileName: string): Boolean;
var Scope: TComicPerfScope;
begin Scope.Start(cpImageStat); Result:=FileExists(FileName); end;
function ComicPerfFrameRgn(DC: HDC; Region: HRGN; Brush: HBRUSH; W,H: Integer): BOOL;
var Scope: TComicPerfScope;
begin Scope.Start(cpFrameRegion); Result:=Winapi.Windows.FrameRgn(DC,Region,Brush,W,H); end;
function ComicPerfFillRgn(DC: HDC; Region: HRGN; Brush: HBRUSH): BOOL;
var Scope: TComicPerfScope;
begin Scope.Start(cpFillRegion); Result:=Winapi.Windows.FillRgn(DC,Region,Brush); end;

constructor TPerfWriter.Create(const Folder: string);
var ID: TGUID;
begin
  inherited Create(True); FFolder:=Folder; FreeOnTerminate:=False;
  CreateGUID(ID); FRunID:=GUIDToString(ID).Replace('{','').Replace('}','');
end;
destructor TPerfWriter.Destroy;
begin FStream.Free; inherited; end;
procedure TPerfWriter.Line(const S: string);
var Bytes,HeaderBytes: TBytes; Path,Header: string; Additional,OldSize: Int64;
begin
  if FQuotaExhausted then Exit;
  Bytes:=TEncoding.UTF8.GetBytes(S+#10);
  if (FStream<>nil) and (FStream.Size+Length(Bytes)>FileLimit) then begin
    FreeAndNil(FStream); FSlot:=1-FSlot;
  end;
  Additional:=Length(Bytes); OldSize:=0;
  if FStream=nil then begin
    Path:=TPath.Combine(FFolder,Format('performance-%d-%s-%d.jsonl',[GetCurrentProcessId,FRunID,FSlot]));
    // 循環書込で上書きできるのは自分が作成したログ枠だけで、他の実行の記録を壊さない。
    if FCreated[FSlot] then OldSize:=TFile.GetSize(Path)
    else if FileExists(Path) then begin FQuotaExhausted:=True; TInterlocked.Exchange(Active,0); Exit; end;
    Header:=Format('{"schema":"%s","pid":%d,"frequency":%d,"inclusive":true,"fileLimitBytes":%d,"globalLimitBytes":%d,"globalFileLimit":%d}',
      [Schema,GetCurrentProcessId,Frequency,FileLimit,GlobalLimit,GlobalFileLimit])+#10;
    HeaderBytes:=TEncoding.UTF8.GetBytes(Header);
    Inc(Additional,Length(HeaderBytes)-OldSize);
  end;
  if (Additional>FBudget) or ((FStream=nil) and not FCreated[FSlot] and (FFileCount>=GlobalFileLimit)) then begin
    FQuotaExhausted:=True; TInterlocked.Exchange(Active,0); Exit;
  end;
  if FStream=nil then begin
    FStream:=TFileStream.Create(Path,fmCreate or fmShareDenyWrite);
    if not FCreated[FSlot] then begin FCreated[FSlot]:=True; Inc(FFileCount); end;
    FStream.WriteBuffer(HeaderBytes,Length(HeaderBytes));
  end;
  FStream.WriteBuffer(Bytes,Length(Bytes));
  Dec(FBudget,Additional);
end;
procedure TPerfWriter.FlushCounters;
var Snapshot: TCounters; Kind: TComicPerfKind; Lost: Int64; Stamp: UInt64;
  QuotaHandle: THandle; Files: TArray<string>; Path: string;
begin
  // 待ちを伴うロック取得は背景ライターだけに限定し、編集操作を止めない。
  EnterCriticalSection(CounterLock);
  try Snapshot:=Counters; FillChar(Counters,SizeOf(Counters),0);
  finally LeaveCriticalSection(CounterLock); end;
  Lost:=TInterlocked.Exchange(Dropped,0); Stamp:=GetTickCount64;
  // 同じデータ領域の容量制限はファイルロックでプロセス間・Windowsセッション間を調整し、I/Oは背景ライターだけで行う。
  ForceDirectories(FFolder);
  QuotaHandle:=CreateFile(PChar(TPath.Combine(FFolder,'performance-quota.lock')),
    GENERIC_READ or GENERIC_WRITE,0,nil,OPEN_ALWAYS,FILE_ATTRIBUTE_NORMAL,0);
  if QuotaHandle=INVALID_HANDLE_VALUE then begin
    for Kind:=Low(Kind) to High(Kind) do if Snapshot[Kind].Count>0 then TInterlocked.Add(Dropped,Snapshot[Kind].Count);
    Exit;
  end;
  try
    Files:=TDirectory.GetFiles(FFolder,'*.jsonl'); FFileCount:=Length(Files); FBudget:=GlobalLimit;
    for Path in Files do Dec(FBudget,TFile.GetSize(Path));
  for Kind:=Low(Kind) to High(Kind) do if Snapshot[Kind].Count>0 then
    Line(Format('{"uptimeMs":%d,"kind":"%s","count":%d,"totalTicks":%d,"maxTicks":%d,"slow50ms":%d}',
      [Stamp,Names[Kind],Snapshot[Kind].Count,Snapshot[Kind].Ticks,Snapshot[Kind].Maximum,Snapshot[Kind].Slow50]));
  if Lost>0 then Line(Format('{"uptimeMs":%d,"droppedSamples":%d}',[Stamp,Lost]));
  finally CloseHandle(QuotaHandle); end;
end;
procedure TPerfWriter.Execute;
begin
  repeat
    Wake.WaitFor(2000);
    try FlushCounters; except FreeAndNil(FStream); end; // ログ失敗を編集処理の失敗へ波及させない。
  until Terminated or FQuotaExhausted;
end;
procedure StartComicPerformance(const DataDirectory: string);
begin
  if (Writer<>nil) or (GetEnvironmentVariable('MANGAMAKER_PERF')='0') then Exit;
  try
    Writer:=TPerfWriter.Create(TPath.Combine(DataDirectory,'Runtime\Performance'));
    TInterlocked.Exchange(Active,1); Writer.Start;
  except TInterlocked.Exchange(Active,0); FreeAndNil(Writer); end;
end;
procedure StopComicPerformance;
begin
  TInterlocked.Exchange(Active,0);
  if Writer=nil then Exit;
  Writer.Terminate; Wake.SetEvent; Writer.WaitFor; FreeAndNil(Writer);
end;
initialization
  InitializeCriticalSection(CounterLock); Frequency:=TStopwatch.Frequency;
  Wake:=TEvent.Create(nil,False,False,'');
finalization
  StopComicPerformance; Wake.Free; DeleteCriticalSection(CounterLock);
end.
