unit ComicImeFocus;

// 責務：フォーム共通のフォーカス境界で文字入力を識別し、非入力操作へIMEを持ち越さない。
interface
uses Vcl.Controls;
procedure CloseControlIme(Control: TWinControl);
implementation
uses Vcl.StdCtrls, WindowsImeController;
procedure CloseControlIme(Control: TWinControl);
var State: TWindowsImeState;
begin
  if (Control=nil) or (Control is TCustomEdit) then Exit;
  if (Control is TCustomComboBox) and (TComboBox(Control).Style<>csDropDownList) then Exit;
  // 文字欄の終了処理で共有HIMCが開き直っても、移動先の非文字操作で閉じる。
  // 他アプリの窓には触れず、imDisableで外れた自アプリの既定HIMCだけを一時参照する。
  SuspendWindowsIme(Control.Handle,State);
end;
end.
