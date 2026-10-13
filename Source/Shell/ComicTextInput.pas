unit ComicTextInput;
// IME受取/バッファはComicTextEditing、IME状態は参照元WindowsImeControllerを再利用。
// このGDI入力プレビューは初期組版であり、完成ページの組版を置き換えない。
interface
uses Winapi.Windows, Winapi.Messages, Winapi.Imm, System.SysUtils, System.Types,
  System.Classes, System.Math, System.Generics.Collections, Vcl.Controls, Vcl.Forms,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics, Vcl.Clipbrd, ComicTextEditing, WindowsImeController;
type
  TComicCaretStop = record Index: Integer; Point: TPoint; end;
  TComicTextInput = class(TCustomControl)
  private
    FInput: TScreenLayoutImeEdit;
    FBuffer,FComposition: string;
    FCaret,FAnchor: Integer;
    FPreferred: Single;
    FVertical,FSession,FTesting,FComposing: Boolean;
    FPrevious: TWindowsImeState;
    FStops: TList<TComicCaretStop>;
    FCaretBounds: TRect;
    FAccept,FCancel: TNotifyEvent;
    procedure SetText(const Value: string);
    procedure Committed(Sender: TObject; const Value: string);
    procedure Composition(Sender: TObject; const Value: string; Cursor: Integer; Active: Boolean);
    procedure InputKey(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure InputEnter(Sender: TObject);
    procedure InputExit(Sender: TObject);
    procedure Changed;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X,Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure BeginSession(Testing: Boolean=False);
    procedure EndSession;
    procedure FocusInput;
    procedure Command(var Key: Word; Shift: TShiftState);
    property Text: string read FBuffer write SetText;
    property Vertical: Boolean read FVertical write FVertical;
    property Input: TScreenLayoutImeEdit read FInput;
    property CaretIndex: Integer read FCaret;
    property SelectionAnchor: Integer read FAnchor;
    property CaretBounds: TRect read FCaretBounds;
    property SessionActive: Boolean read FSession;
    property Composing: Boolean read FComposing;
    property OnAccept: TNotifyEvent read FAccept write FAccept;
    property OnCancel: TNotifyEvent read FCancel write FCancel;
  end;
  TComicTextDialog = class(TForm)
  private
    FEditor: TComicTextInput;
    procedure Accept(Sender: TObject);
    procedure Cancel(Sender: TObject);
    procedure Shown(Sender: TObject);
  public
    constructor CreateEditor(AOwner: TComponent; const Text: string; Vertical,Testing: Boolean);
    destructor Destroy; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    property Editor: TComicTextInput read FEditor;
  end;
implementation
constructor TComicTextInput.Create(AOwner: TComponent);
begin
  inherited; Width:=600; Height:=340; Color:=$FAFAFA; Font.Name:='Yu Gothic UI'; Font.Size:=14;
  DoubleBuffered:=True; TabStop:=True; ImeMode:=imDisable; FPreferred:=-1;
  FStops:=TList<TComicCaretStop>.Create;
  FInput:=TScreenLayoutImeEdit.Create(Self); FInput.Parent:=Self; FInput.BorderStyle:=bsNone;
  FInput.StyleElements:=[]; FInput.Font.Color:=Color;
  FInput.SetBounds(16,16,2,24); FInput.Color:=Color; FInput.TabStop:=False; FInput.Enabled:=False; FInput.ImeMode:=imDisable;
  FInput.OnCommittedText:=Committed; FInput.OnComposition:=Composition; FInput.OnKeyDown:=InputKey;
  FInput.OnEnter:=InputEnter; FInput.OnExit:=InputExit;
end;
destructor TComicTextInput.Destroy;
begin EndSession; FStops.Free; inherited; end;
procedure TComicTextInput.SetText(const Value: string);
begin FBuffer:=Value; FCaret:=Length(Value); FAnchor:=FCaret; FPreferred:=-1; FComposition:=''; FComposing:=False; Invalidate; end;
procedure TComicTextInput.BeginSession(Testing: Boolean);
begin
  if FSession then Exit; FTesting:=Testing; FSession:=True; FPrevious.Valid:=False;
  FInput.Enabled:=True;
  if not FTesting then SuspendWindowsIme(FInput.Handle,FPrevious);
  FInput.ImeMode:=imOpen; Invalidate;
end;
procedure TComicTextInput.EndSession;
begin
  if not FSession then Exit; FSession:=False;
  FInput.ImeMode:=imDisable; FInput.Enabled:=False;
  // Restore last, after disabling/focus notifications, so the saved open state
  // is not immediately overwritten by the receiver's disabled input mode.
  if not FTesting then RestoreWindowsIme(FInput.Handle,FPrevious);
  FComposition:=''; FComposing:=False;
end;
procedure TComicTextInput.FocusInput;
begin if FSession and not FTesting then FInput.SetFocus; end;
procedure TComicTextInput.InputEnter(Sender: TObject);
begin
  if not FSession then Exit;
  if not FTesting and not FPrevious.Valid then SuspendWindowsIme(FInput.Handle,FPrevious);
  FInput.ImeMode:=imOpen; HideCaret(FInput.Handle); Invalidate;
end;
procedure TComicTextInput.InputExit(Sender: TObject);
var Saved: TWindowsImeState;
begin
  if not FSession then Exit;
  FInput.ImeMode:=imDisable; Saved:=FPrevious;
  if not FTesting then RestoreWindowsIme(FInput.Handle,Saved);
  Invalidate;
end;
procedure TComicTextInput.Changed;
begin FInput.Text:=''; Invalidate; end;
procedure TComicTextInput.Committed(Sender: TObject; const Value: string);
begin
  if not FSession then Exit;
  InsertScreenLayoutTextAtCaret(FBuffer,FCaret,FAnchor,FPreferred,Value); Changed;
end;
procedure TComicTextInput.Composition(Sender: TObject; const Value: string; Cursor: Integer; Active: Boolean);
begin
  if not FSession then Exit;
  FComposition:=Value; FComposing:=Active; Invalidate;
end;
procedure TComicTextInput.InputKey(Sender: TObject; var Key: Word; Shift: TShiftState);
begin Command(Key,Shift); end;
procedure TComicTextInput.Command(var Key: Word; Shift: TShiftState);
var Extend: Boolean;
begin
  if not FSession then Exit;
  if FComposing then Exit; // 未確定中の矢印/Enter/EscはIMEへ渡す。
  Extend:=ssShift in Shift;
  if ssCtrl in Shift then begin
    case Key of
      Ord('A'): begin FAnchor:=0; FCaret:=Length(FBuffer); end;
      Ord('C'): if FCaret<>FAnchor then Clipboard.AsText:=Copy(FBuffer,Min(FCaret,FAnchor)+1,Abs(FCaret-FAnchor));
      Ord('X'): begin
        if FCaret<>FAnchor then Clipboard.AsText:=Copy(FBuffer,Min(FCaret,FAnchor)+1,Abs(FCaret-FAnchor));
        DeleteScreenLayoutTextSelection(FBuffer,FCaret,FAnchor,FPreferred);
      end;
      Ord('V'): InsertScreenLayoutTextAtCaret(FBuffer,FCaret,FAnchor,FPreferred,Clipboard.AsText);
      VK_RETURN: begin if Assigned(FAccept) then FAccept(Self); Key:=0; Exit; end;
      VK_HOME: begin FCaret:=0; if not Extend then FAnchor:=FCaret; end;
      VK_END: begin FCaret:=Length(FBuffer); if not Extend then FAnchor:=FCaret; end;
    else Exit; end;
  end else case Key of
    VK_LEFT,VK_RIGHT: begin
      if Key=VK_LEFT then MoveScreenLayoutTextCaretHorizontal(FBuffer,FCaret,FAnchor,FPreferred,-1,Extend)
      else MoveScreenLayoutTextCaretHorizontal(FBuffer,FCaret,FAnchor,FPreferred,1,Extend);
    end;
    VK_BACK,VK_DELETE: begin
      if FCaret=FAnchor then
        if Key=VK_BACK then MoveScreenLayoutTextCaretHorizontal(FBuffer,FCaret,FAnchor,FPreferred,-1,True)
        else MoveScreenLayoutTextCaretHorizontal(FBuffer,FCaret,FAnchor,FPreferred,1,True);
      DeleteScreenLayoutTextSelection(FBuffer,FCaret,FAnchor,FPreferred);
    end;
    VK_RETURN: InsertScreenLayoutTextAtCaret(FBuffer,FCaret,FAnchor,FPreferred,#13#10);
    VK_ESCAPE: begin if Assigned(FCancel) then FCancel(Self); Key:=0; Exit; end;
    VK_HOME: begin
      while (FCaret>0) and not CharInSet(FBuffer[FCaret],[#13,#10]) do
        MoveScreenLayoutTextCaretHorizontal(FBuffer,FCaret,FAnchor,FPreferred,-1,True);
      if not Extend then FAnchor:=FCaret;
    end;
    VK_END: begin
      while (FCaret<Length(FBuffer)) and not CharInSet(FBuffer[FCaret+1],[#13,#10]) do
        MoveScreenLayoutTextCaretHorizontal(FBuffer,FCaret,FAnchor,FPreferred,1,True);
      if not Extend then FAnchor:=FCaret;
    end;
  else Exit; end;
  Key:=0; Changed;
end;
procedure TComicTextInput.Paint;
var I,N,X,Y,W,H,Start: Integer; S: string; Stop: TComicCaretStop; Caret: TPoint; Cell: TRect;
  procedure AddStop(Index: Integer);
  begin Stop.Index:=Index; Stop.Point:=Point(X,Y); FStops.Add(Stop); if Index=FCaret then Caret:=Stop.Point; end;
  procedure NextLine;
  begin if FVertical then begin Dec(X,H); Y:=16; end else begin X:=16; Inc(Y,H); end; end;
begin
  Canvas.Brush.Color:=Color; Canvas.FillRect(ClientRect); Canvas.Font.Assign(Font);
  H:=Max(16,Canvas.TextHeight('漢')+4); if FVertical then X:=ClientWidth-16-H else X:=16;
  Y:=16; Caret:=Point(X,Y); FStops.Clear; AddStop(0); I:=1;
  while I<=Length(FBuffer) do begin
    Start:=I-1; N:=1;
    if (FBuffer[I]=#13) and (I<Length(FBuffer)) and (FBuffer[I+1]=#10) then N:=2
    else if (Ord(FBuffer[I])>=$D800) and (Ord(FBuffer[I])<=$DBFF) and (I<Length(FBuffer)) and
      (Ord(FBuffer[I+1])>=$DC00) and (Ord(FBuffer[I+1])<=$DFFF) then N:=2;
    S:=Copy(FBuffer,I,N);
    if CharInSet(FBuffer[I],[#13,#10]) then NextLine
    else begin
      if FVertical then W:=H else W:=Max(2,Canvas.TextWidth(S));
      if (not FVertical and (X+W>ClientWidth-16)) or (FVertical and (Y+H>ClientHeight-20)) then begin NextLine; AddStop(Start); end;
      Cell:=Rect(X,Y,X+W,Y+H);
      if (Start>=Min(FCaret,FAnchor)) and (Start<Max(FCaret,FAnchor)) then Canvas.Brush.Color:=$FFE0B0 else Canvas.Brush.Color:=Color;
      Canvas.FillRect(Cell); Canvas.Brush.Style:=bsClear; Canvas.Font.Color:=clBlack; Canvas.TextOut(X,Y,S); Canvas.Brush.Style:=bsSolid;
      if FVertical then Inc(Y,H) else Inc(X,W);
    end;
    Inc(I,N); AddStop(I-1);
  end;
  if FVertical then FCaretBounds:=Rect(Caret.X,Caret.Y,Caret.X+H-2,Caret.Y+2)
  else FCaretBounds:=Rect(Caret.X,Caret.Y,Caret.X+2,Caret.Y+H-2);
  if FSession then begin Canvas.Brush.Color:=$BD7620; Canvas.FillRect(FCaretBounds); end;
  if FComposition<>'' then begin
    Canvas.Font.Style:=[fsUnderline]; Canvas.Brush.Style:=bsClear; Canvas.TextOut(Caret.X,Caret.Y,FComposition); Canvas.Brush.Style:=bsSolid;
  end;
  FInput.SetBounds(EnsureRange(Caret.X,0,Max(0,ClientWidth-2)),EnsureRange(Caret.Y,0,Max(0,ClientHeight-H)),2,H);
  HideCaret(FInput.Handle);
end;
procedure TComicTextInput.MouseDown(Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
var Stop: TComicCaretStop; Best,Distance: Double;
begin
  inherited; if (Button<>mbLeft) or not FSession then Exit;
  Best:=MaxDouble;
  for Stop in FStops do begin Distance:=Hypot(Stop.Point.X-X,Stop.Point.Y-Y);
    if Distance<Best then begin Best:=Distance; FCaret:=Stop.Index; end;
  end;
  if not (ssShift in Shift) then FAnchor:=FCaret; FocusInput; Invalidate;
end;
constructor TComicTextDialog.CreateEditor(AOwner: TComponent; const Text: string; Vertical,Testing: Boolean);
var Bar: TPanel; Button: TButton; PPI: Integer;
begin
  inherited CreateNew(AOwner); Caption:='吹き出しの文字入力（初期プレビュー）'; Position:=poOwnerFormCenter; KeyPreview:=True;
  Font.Name:='Yu Gothic UI'; Font.Size:=10; PPI:=CurrentPPI; ClientWidth:=MulDiv(680,PPI,96); ClientHeight:=MulDiv(440,PPI,96);
  Bar:=TPanel.Create(Self); Bar.Parent:=Self; Bar.Align:=alBottom; Bar.Height:=MulDiv(64,PPI,96); Bar.BevelOuter:=bvNone;
  Button:=TButton.Create(Self); Button.Parent:=Bar; Button.Caption:='確定 (Ctrl+Enter)'; Button.SetBounds(MulDiv(340,PPI,96),MulDiv(16,PPI,96),MulDiv(152,PPI,96),MulDiv(34,PPI,96)); Button.OnClick:=Accept;
  Button:=TButton.Create(Self); Button.Parent:=Bar; Button.Caption:='取消 (Esc)'; Button.SetBounds(MulDiv(504,PPI,96),MulDiv(16,PPI,96),MulDiv(152,PPI,96),MulDiv(34,PPI,96)); Button.OnClick:=Cancel;
  FEditor:=TComicTextInput.Create(Self); FEditor.Parent:=Self; FEditor.Align:=alClient; FEditor.Text:=Text; FEditor.Vertical:=Vertical;
  FEditor.OnAccept:=Accept; FEditor.OnCancel:=Cancel; FEditor.BeginSession(Testing); OnShow:=Shown;
end;
destructor TComicTextDialog.Destroy;
begin FEditor.EndSession; inherited; end;
procedure TComicTextDialog.Shown(Sender: TObject);
begin FEditor.FocusInput; end;
procedure TComicTextDialog.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if FEditor.Composing then Exit;
  if (Key=VK_RETURN) and (ssCtrl in Shift) then begin Accept(Self); Key:=0; Exit; end;
  if Key=VK_ESCAPE then begin Cancel(Self); Key:=0; Exit; end;
  inherited;
end;
procedure TComicTextDialog.Accept(Sender: TObject);
begin
  if FEditor.Composing then begin Caption:='IME変換を確定してから文字全体を確定してください。'; Exit; end;
  FEditor.EndSession; ModalResult:=mrOK;
end;
procedure TComicTextDialog.Cancel(Sender: TObject);
begin FEditor.EndSession; ModalResult:=mrCancel; end;
end.
