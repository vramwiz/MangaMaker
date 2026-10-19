unit ComicDpi;

// 責務：実行時フォームの構築前に所有画面のDPIを決め、途中のHWND生成による基準混在を防ぐ。
interface
uses System.Classes;
function OwnerControlPPI(AOwner: TComponent): Integer;
implementation
uses Vcl.Controls, Vcl.Forms;
function OwnerControlPPI(AOwner: TComponent): Integer;
begin
  if AOwner is TControl then Result:=TControl(AOwner).CurrentPPI
  else if Screen.ActiveCustomForm<>nil then Result:=Screen.ActiveCustomForm.CurrentPPI
  else Result:=Screen.MonitorFromPoint(Mouse.CursorPos).PixelsPerInch;
end;
end.
