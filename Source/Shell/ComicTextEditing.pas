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
    FOnCommittedText: TScreenLayoutCommittedTextEvent;
    FOnComposition: TScreenLayoutCompositionEvent;
    procedure WMChar(var Message: TWMChar); message WM_CHAR;
    procedure WMImeComposition(var Message: TMessage);
      message WM_IME_COMPOSITION;
    procedure WMImeEndComposition(var Message: TMessage);
      message WM_IME_ENDCOMPOSITION;
    procedure WMImeStartComposition(var Message: TMessage);
      message WM_IME_STARTCOMPOSITION;
  public
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
uses System.Math, Winapi.Imm;
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
  begin
    if CaretIndex > 0 then
      Dec(CaretIndex);
    if (CaretIndex > 0) and (Ord(Text[CaretIndex]) >= $D800) and
      (Ord(Text[CaretIndex]) <= $DBFF) then
      Dec(CaretIndex);
    if (CaretIndex > 0) and (Text[CaretIndex] = #13) and
      (Text[CaretIndex + 1] = #10) then
      Dec(CaretIndex);
  end
  else
  begin
    if CaretIndex < Length(Text) then
      Inc(CaretIndex);
    if (CaretIndex < Length(Text)) and
      (Ord(Text[CaretIndex]) >= $D800) and
      (Ord(Text[CaretIndex]) <= $DBFF) then
      Inc(CaretIndex);
    if (CaretIndex < Length(Text)) and (Text[CaretIndex] = #13) and
      (Text[CaretIndex + 1] = #10) then
      Inc(CaretIndex);
  end;
  if not ExtendSelection then
    SelectionAnchor := CaretIndex;
  PreferredCaretX := -1.0;
end;

procedure TScreenLayoutImeEdit.WMChar(var Message: TWMChar);
begin
  if (Message.CharCode >= 32) and Assigned(FOnCommittedText) then
    FOnCommittedText(Self, string(WideChar(Message.CharCode)));
  // 確定文字はDocument側へ渡し、Edit自身の文字列には残さない。
  Message.Result := 0;
end;

procedure TScreenLayoutImeEdit.WMImeComposition(var Message: TMessage);
var
  ByteCount: Integer;
  CompositionCursor: Integer;
  CompositionText: string;
  InputContext: HIMC;
begin
  CompositionText := '';
  CompositionCursor := 0;
  InputContext := ImmGetContext(Handle);
  if InputContext <> 0 then
  try
    ByteCount := ImmGetCompositionStringW(InputContext, GCS_COMPSTR,
      nil, 0);
    if ByteCount > 0 then
    begin
      SetLength(CompositionText, ByteCount div SizeOf(Char));
      ImmGetCompositionStringW(InputContext, GCS_COMPSTR,
        PChar(CompositionText), ByteCount);
    end;
    CompositionCursor := ImmGetCompositionStringW(InputContext,
      GCS_CURSORPOS, nil, 0);
    if CompositionCursor < 0 then
      CompositionCursor := 0;
  finally
    ImmReleaseContext(Handle, InputContext);
  end;
  inherited;
  if Assigned(FOnComposition) then
    FOnComposition(Self, CompositionText, CompositionCursor, True);
end;

procedure TScreenLayoutImeEdit.WMImeEndComposition(var Message: TMessage);
begin
  inherited;
  if Assigned(FOnComposition) then
    FOnComposition(Self, '', 0, False);
end;

procedure TScreenLayoutImeEdit.WMImeStartComposition(var Message: TMessage);
begin
  inherited;
  if Assigned(FOnComposition) then
    FOnComposition(Self, '', 0, True);
end;


end.
