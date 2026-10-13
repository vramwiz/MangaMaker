unit ComicTextEditing;
// ScreenDesignMaker/ScreenLayoutTextEditing.pasからIME受取と編集バッファ部分を再利用。
// Skia依存の組版/座標関数はこの基礎統合には含めない。参照元は変更しない。
interface
uses System.Types, Winapi.Messages, Vcl.Graphics, Vcl.StdCtrls;
type
  TScreenLayoutCommittedTextEvent = procedure(Sender: TObject;
    const Text: string) of object;
  TScreenLayoutCompositionEvent = procedure(Sender: TObject;
    const Text: string; CursorPosition: Integer; Active: Boolean) of object;

  TScreenLayoutImeEdit = class(TEdit)
  private
    FPendingHigh: WideChar;
    FCompositionText: string;
    FCompositionCursor: Integer;
    FInsideComposition: Boolean;
    FOnCommittedText: TScreenLayoutCommittedTextEvent;
    FOnComposition: TScreenLayoutCompositionEvent;
    procedure WMChar(var Message: TWMChar); message WM_CHAR;
    procedure WMUniChar(var Message: TMessage); message WM_UNICHAR;
    procedure WMImeChar(var Message: TMessage); message WM_IME_CHAR;
    procedure WMImeSetContext(var Message: TMessage); message WM_IME_SETCONTEXT;
    procedure CommitCodeUnit(Value: WideChar);
    procedure WMImeComposition(var Message: TMessage);
      message WM_IME_COMPOSITION;
    procedure WMImeEndComposition(var Message: TMessage);
      message WM_IME_ENDCOMPOSITION;
    procedure WMImeStartComposition(var Message: TMessage);
      message WM_IME_STARTCOMPOSITION;
  public
    procedure ResetPendingInput;
    procedure DeliverComposition(const ResultText,Preedit: string; Cursor: Integer; Active: Boolean);
    // IMEまたは通常キー入力が確定した文字列を通知する。
    property OnCommittedText: TScreenLayoutCommittedTextEvent
      read FOnCommittedText write FOnCommittedText;
    // IME未確定文字列、変換カーソル位置、変換中かどうかを通知する。
    property OnComposition: TScreenLayoutCompositionEvent
      read FOnComposition write FOnComposition;
  end;


// 選択範囲を削除してカーソルを範囲先頭へ移し、削除した場合にTrueを返す。
function DeleteScreenLayoutTextSelection(var Text: string;
  var CaretIndex, SelectionAnchor: Integer;
  var PreferredCaretX: Single): Boolean;
// 選択範囲を置換してTextを挿入し、カーソルを挿入末尾へ移す。
procedure InsertScreenLayoutTextAtCaret(var Buffer: string;
  var CaretIndex, SelectionAnchor: Integer; var PreferredCaretX: Single;
  const Text: string);
// サロゲートペアとCRLFを分割せず左右へ移動し、必要なら選択を拡張する。
procedure MoveScreenLayoutTextCaretHorizontal(const Text: string;
  var CaretIndex, SelectionAnchor: Integer; var PreferredCaretX: Single;
  Direction: Integer; ExtendSelection: Boolean);


implementation
uses System.Math, System.Character, Winapi.Windows, Winapi.Imm, ComicTextUnits;
function DeleteScreenLayoutTextSelection(var Text: string;
  var CaretIndex, SelectionAnchor: Integer;
  var PreferredCaretX: Single): Boolean;
var
  SelectionEnd: Integer;
  SelectionStart: Integer;
begin
  SelectionStart := Min(CaretIndex, SelectionAnchor);
  SelectionEnd := Max(CaretIndex, SelectionAnchor);
  Result := SelectionStart <> SelectionEnd;
  if not Result then
    Exit;
  Delete(Text, SelectionStart + 1, SelectionEnd - SelectionStart);
  CaretIndex := SelectionStart;
  SelectionAnchor := SelectionStart;
  PreferredCaretX := -1.0;
end;

procedure InsertScreenLayoutTextAtCaret(var Buffer: string;
  var CaretIndex, SelectionAnchor: Integer; var PreferredCaretX: Single;
  const Text: string);
begin
  if Text = '' then
    Exit;
  DeleteScreenLayoutTextSelection(Buffer, CaretIndex, SelectionAnchor,
    PreferredCaretX);
  Insert(Text, Buffer, CaretIndex + 1);
  Inc(CaretIndex, Length(Text));
  SelectionAnchor := CaretIndex;
  PreferredCaretX := -1.0;
end;

procedure MoveScreenLayoutTextCaretHorizontal(const Text: string;
  var CaretIndex, SelectionAnchor: Integer; var PreferredCaretX: Single;
  Direction: Integer; ExtendSelection: Boolean);
var
  SelectionEnd: Integer;
  SelectionStart: Integer;
begin
  SelectionStart := Min(CaretIndex, SelectionAnchor);
  SelectionEnd := Max(CaretIndex, SelectionAnchor);
  if not ExtendSelection and (SelectionStart <> SelectionEnd) then
  begin
    if Direction < 0 then
      CaretIndex := SelectionStart
    else
      CaretIndex := SelectionEnd;
  end
  else if Direction < 0 then
    CaretIndex:=PreviousComicTextBoundary(Text,CaretIndex)
  else
    CaretIndex:=NextComicTextBoundary(Text,CaretIndex);
  if not ExtendSelection then
    SelectionAnchor := CaretIndex;
  PreferredCaretX := -1.0;
end;

procedure TScreenLayoutImeEdit.WMChar(var Message: TWMChar);
begin
  if Message.CharCode>=32 then CommitCodeUnit(WideChar(Message.CharCode));
  // 確定文字はDocument側へ渡し、Edit自身の文字列には残さない。
  Message.Result := 0;
end;

procedure TScreenLayoutImeEdit.ResetPendingInput;
begin FPendingHigh:=#0; FCompositionText:=''; FCompositionCursor:=0; FInsideComposition:=False; end;

procedure TScreenLayoutImeEdit.CommitCodeUnit(Value: WideChar);
var Text: string;
begin
  if (Ord(Value)>=$D800) and (Ord(Value)<=$DBFF) then begin FPendingHigh:=Value; Exit; end;
  Text:=Value;
  if FPendingHigh<>#0 then begin Text:=FPendingHigh+Text; FPendingHigh:=#0; end;
  if Assigned(FOnCommittedText) then FOnCommittedText(Self,Text);
end;

procedure TScreenLayoutImeEdit.WMUniChar(var Message: TMessage);
begin
  if Message.WParam=$FFFF then begin Message.Result:=1; Exit; end;
  if (Message.WParam<=$10FFFF) and not ((Message.WParam>=$D800) and (Message.WParam<=$DFFF)) and
    Assigned(FOnCommittedText) then FOnCommittedText(Self,Char.ConvertFromUtf32(Message.WParam));
  Message.Result:=0;
end;

procedure TScreenLayoutImeEdit.WMImeChar(var Message: TMessage);
begin CommitCodeUnit(WideChar(Message.WParam)); Message.Result:=0; end;

procedure TScreenLayoutImeEdit.WMImeSetContext(var Message: TMessage);
begin
  // The external control renders preedit text; let Windows retain candidate UI.
  Message.LParam:=Message.LParam and not LPARAM(ISC_SHOWUICOMPOSITIONWINDOW);
  inherited;
end;

procedure TScreenLayoutImeEdit.WMImeComposition(var Message: TMessage);
var
  InputContext: HIMC;
  ResultText: string;
  function ReadString(Kind: DWORD): string;
  var ByteCount: Integer;
  begin
    Result:=''; ByteCount:=ImmGetCompositionStringW(InputContext,Kind,nil,0);
    if (ByteCount<=0) or (ByteCount>1048576) then Exit;
    SetLength(Result,ByteCount div SizeOf(Char));
    ImmGetCompositionStringW(InputContext,Kind,PChar(Result),Length(Result)*SizeOf(Char));
  end;
begin
  ResultText:='';
  InputContext := ImmGetContext(Handle);
  if InputContext <> 0 then
  try
    if (Message.LParam and GCS_RESULTSTR)<>0 then begin
      ResultText:=ReadString(GCS_RESULTSTR); FCompositionText:=''; FCompositionCursor:=0;
    end;
    if (Message.LParam and GCS_COMPSTR)<>0 then FCompositionText:=ReadString(GCS_COMPSTR);
    if (Message.LParam and GCS_CURSORPOS)<>0 then FCompositionCursor:=EnsureRange(
      ImmGetCompositionStringW(InputContext,GCS_CURSORPOS,nil,0),0,Length(FCompositionText));
  finally
    ImmReleaseContext(Handle, InputContext);
  end;
  // Consume the result here as one edit. Passing it to DefWindowProc would
  // also generate WM_IME_CHAR/WM_CHAR and insert the result a second time.
  if Message.LParam=0 then ResetPendingInput;
  DeliverComposition(ResultText,FCompositionText,FCompositionCursor,FInsideComposition);
  Message.Result:=0;
end;

procedure TScreenLayoutImeEdit.DeliverComposition(const ResultText,Preedit: string; Cursor: Integer; Active: Boolean);
begin
  if (ResultText<>'') and Assigned(FOnCommittedText) then FOnCommittedText(Self,ResultText);
  if Assigned(FOnComposition) then
    FOnComposition(Self,Preedit,Cursor,Active);
end;

procedure TScreenLayoutImeEdit.WMImeEndComposition(var Message: TMessage);
begin
  ResetPendingInput; inherited;
  if Assigned(FOnComposition) then
    FOnComposition(Self, '', 0, False);
end;

procedure TScreenLayoutImeEdit.WMImeStartComposition(var Message: TMessage);
begin
  ResetPendingInput; FInsideComposition:=True; inherited;
  if Assigned(FOnComposition) then
    FOnComposition(Self, '', 0, True);
end;


end.
