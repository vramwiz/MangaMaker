// Windows IMEの開閉状態を編集セッションの境界で一時退避・復元する。
unit WindowsImeController;

// 責務：文字入力セッションの境界でIME状態を退避・復元し、他の入力欄へ状態を漏らさない。

interface

uses
  Winapi.Windows, Winapi.Imm;

type
  TWindowsImeState = record
    WasOpen: Boolean; // 退避時にIMEが開いていた場合はTrue。
    Valid: Boolean;   // WasOpenを復元可能な状態ならTrue。
    Context: HIMC;
    ConversionMode,SentenceMode: DWORD;
    HasConversionMode: Boolean;
  end;

// WindowHandleに関連付いたIMEの状態をStateへ保存し、IMEを閉じる。
procedure SuspendWindowsIme(WindowHandle: HWND;
  var State: TWindowsImeState);
// 保存済みの状態をWindowHandleのIMEへ復元する。未保存なら何もしない。
procedure RestoreWindowsIme(WindowHandle: HWND;
  var State: TWindowsImeState);

implementation

procedure SuspendWindowsIme(WindowHandle: HWND;
  var State: TWindowsImeState);
var
  InputContext: HIMC;
  TemporaryAssociation: Boolean;
begin
  State.Valid := False;
  if (WindowHandle = 0) or not IsWindow(WindowHandle) then
    Exit;
  InputContext := ImmGetContext(WindowHandle);
  TemporaryAssociation:=InputContext=0;
  if TemporaryAssociation then begin
    // imDisableでHIMCが外れている場合も、既存コンテキストを一時関連付けして開閉・変換状態を先に退避する。
    if not ImmAssociateContextEx(WindowHandle,0,IACE_DEFAULT) then Exit;
    InputContext:=ImmGetContext(WindowHandle);
    if InputContext=0 then begin ImmAssociateContext(WindowHandle,0); Exit; end;
  end;
  try
    State.WasOpen := ImmGetOpenStatus(InputContext);
    State.Context:=InputContext;
    State.HasConversionMode:=ImmGetConversionStatus(InputContext,State.ConversionMode,State.SentenceMode);
    State.Valid := True;
    if State.WasOpen then
      ImmSetOpenStatus(InputContext, False);
  finally
    ImmReleaseContext(WindowHandle, InputContext);
    if TemporaryAssociation then ImmAssociateContext(WindowHandle,0);
  end;
end;

procedure RestoreWindowsIme(WindowHandle: HWND;
  var State: TWindowsImeState);
var
  InputContext: HIMC;
begin
  if not State.Valid or (WindowHandle = 0) or
    not IsWindow(WindowHandle) then
    Exit;
  // 現在のHIMCが外れていても退避済みコンテキストを復元し、入力終了時に元のIME状態を失わない。
  InputContext := State.Context;
  if InputContext = 0 then
    Exit;
  if State.HasConversionMode then ImmSetConversionStatus(InputContext,State.ConversionMode,State.SentenceMode);
  ImmSetOpenStatus(InputContext, State.WasOpen);
  State.Valid := False;
end;

end.
