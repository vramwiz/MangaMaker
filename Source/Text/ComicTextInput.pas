unit ComicTextInput;

// 責務：確定前の文字編集を作品から隔離し、確定時だけUndo対象へ反映する。
// IME受取/バッファはComicTextEditing、IME状態は参照元WindowsImeControllerを再利用。
// 入力と完成ページはComicTextLayoutを共有する。表示領域/文字サイズは各画面の設定に従う。
interface
uses ComicDpi, Winapi.Windows, Winapi.Messages, Winapi.Imm, System.SysUtils, System.Types,
  System.Classes, System.Math, System.UITypes, System.Generics.Collections, Vcl.Controls, Vcl.Forms,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics, Vcl.Clipbrd, ComicTextEditing, WindowsImeController,
  ComicTextLayout, ComicTextUnits, ComicModel;
type
  TComicTextUndoState = record Text: string; Caret,Anchor: Integer; end;
  TComicTextInput = class(TCustomControl)
  protected
    FInput: TScreenLayoutImeEdit;
    FBuffer,FComposition: string;
    FDisplayBuffer: string;
    FCaret,FAnchor: Integer;
    FPreferred: Single;
    FPreferredValid: Boolean;
    FCharacterSpacing,FLineSpacing: Double;
    FVertical,FSession,FTesting,FComposing,FAutoWrap: Boolean;
    FPrevious: TWindowsImeState;
    FLayout: TComicTextLayout;
    FUndo,FRedo: TList<TComicTextUndoState>;
    FScrollBar: TScrollBar;
    FScroll,FLineAffinity,FCompositionCursor: Integer;
    FUpdatingScroll: Boolean;
    FCaretBounds: TRect;
    FAccept,FCancel: TNotifyEvent;
    procedure SetText(const Value: string);
    procedure SetVertical(Value: Boolean);
    procedure RebuildLayout; virtual;
    procedure EnsureCaretVisible; virtual;
    procedure ScrollChanged(Sender: TObject);
    procedure Remember;
    procedure RestoreHistory(Undo: Boolean);
    procedure MoveLine(Direction: Integer; Extend: Boolean);
    function DisplayPoint(const P: TPoint): TPoint;
    function DisplayCaretIndex: Integer;
    procedure Committed(Sender: TObject; const Value: string);
    procedure Composition(Sender: TObject; const Value: string; Cursor: Integer; Active: Boolean); virtual;
    procedure InputKey(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure InputEnter(Sender: TObject);
    procedure InputExit(Sender: TObject); virtual;
    procedure Changed; virtual;
    procedure UpdateImePosition;
    procedure CMFontChanged(var Message: TMessage); message CM_FONTCHANGED;
  protected
    procedure Paint; override;
    procedure Resize; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X,Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure BeginSession(Testing: Boolean=False);
    procedure EndSession;
    procedure FocusInput;
    procedure Command(var Key: Word; Shift: TShiftState);
    property Text: string read FBuffer write SetText;
    property Font;
    property Vertical: Boolean read FVertical write SetVertical;
    property AutoWrap: Boolean read FAutoWrap write FAutoWrap;
    property CharacterSpacing: Double read FCharacterSpacing write FCharacterSpacing;
    property LineSpacing: Double read FLineSpacing write FLineSpacing;
    property ScrollPosition: Integer read FScroll;
    property Layout: TComicTextLayout read FLayout;
    property Input: TScreenLayoutImeEdit read FInput;
    property CaretIndex: Integer read FCaret;
    property SelectionAnchor: Integer read FAnchor;
    property CaretBounds: TRect read FCaretBounds;
    property SessionActive: Boolean read FSession;
    property Composing: Boolean read FComposing;
    property CompositionText: string read FComposition;
    property CompositionCursor: Integer read FCompositionCursor;
    property OnAccept: TNotifyEvent read FAccept write FAccept;
    property OnCancel: TNotifyEvent read FCancel write FCancel;
  end;
  TComicTextDialog = class(TForm)
  private
    FEditor: TComicTextInput;
    FScriptChoice: TComboBox;
    FScriptProject: TComicProject;
    procedure ScriptSelected(Sender: TObject);
    procedure Accept(Sender: TObject);
    procedure Cancel(Sender: TObject);
    procedure Shown(Sender: TObject);
    procedure CMFocusChanged(var Message: TCMFocusChanged); message CM_FOCUSCHANGED;
  public
    constructor CreateEditor(AOwner: TComponent; const Text: string; Vertical,Testing: Boolean);
    destructor Destroy; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure UseScript(Project: TComicProject; const ImageID: string);
    property Editor: TComicTextInput read FEditor;
  end;
implementation
uses ComicScriptAssist, ComicImeFocus;
procedure TComicTextDialog.CMFocusChanged(var Message: TCMFocusChanged);
begin inherited; if not (csDestroying in ComponentState) then CloseControlIme(Message.Sender); end;
procedure TComicTextDialog.UseScript(Project: TComicProject; const ImageID: string);
begin
  if (Project=nil) or (Project.ScriptSource='') then Exit; FScriptProject:=Project;
  if FScriptChoice=nil then begin
    FScriptChoice:=TComboBox.Create(Self); FScriptChoice.Parent:=Self; FScriptChoice.Align:=alTop;
    FScriptChoice.Style:=csDropDownList; FScriptChoice.OnChange:=ScriptSelected;
  end;
  ScriptDialogueChoices(Project,ImageID,FScriptChoice.Items); FScriptChoice.ItemIndex:=0;
end;
procedure TComicTextDialog.ScriptSelected(Sender: TObject);
begin
  if (FScriptChoice=nil) or (FScriptChoice.ItemIndex<1) then Exit;
  FEditor.Text:=ScriptDialogueText(FScriptProject,FScriptChoice.Text);
end;
constructor TComicTextInput.Create(AOwner: TComponent);
begin
  inherited; Width:=600; Height:=340; Color:=$FAFAFA; Font.Name:='Yu Gothic UI'; Font.Size:=14;
  FCharacterSpacing:=1; FLineSpacing:=1; FAutoWrap:=True;
  DoubleBuffered:=True; TabStop:=True; ImeMode:=imDisable; FPreferred:=-1;
  FLayout:=TComicTextLayout.Create; FLineAffinity:=-1;
  FUndo:=TList<TComicTextUndoState>.Create; FRedo:=TList<TComicTextUndoState>.Create;
  FScrollBar:=TScrollBar.Create(Self); FScrollBar.Parent:=Self; FScrollBar.Kind:=sbVertical;
  FScrollBar.Align:=alRight; FScrollBar.Width:=GetSystemMetrics(SM_CXVSCROLL); FScrollBar.TabStop:=False;
  FScrollBar.OnChange:=ScrollChanged;
  FInput:=TScreenLayoutImeEdit.Create(Self); FInput.Parent:=Self; FInput.BorderStyle:=bsNone;
  FInput.StyleElements:=[]; FInput.Font.Color:=Color;
  FInput.SetBounds(16,16,2,24); FInput.Color:=Color; FInput.TabStop:=False; FInput.Enabled:=False; FInput.ImeMode:=imDisable;
  FInput.OnCommittedText:=Committed; FInput.OnComposition:=Composition; FInput.OnKeyDown:=InputKey;
  FInput.OnEnter:=InputEnter; FInput.OnExit:=InputExit;
end;
destructor TComicTextInput.Destroy;
begin EndSession; FreeAndNil(FLayout); FUndo.Free; FRedo.Free; inherited; end;
procedure TComicTextInput.SetText(const Value: string);
begin
  FBuffer:=Value; FCaret:=Length(Value); FAnchor:=FCaret; FPreferred:=-1; FPreferredValid:=False; FLineAffinity:=-1;
  FComposition:=''; FComposing:=False; FUndo.Clear; FRedo.Clear; FScroll:=0; Changed;
end;
procedure TComicTextInput.SetVertical(Value: Boolean);
begin
  if Value=FVertical then Exit; FVertical:=Value; FScroll:=0; FPreferred:=-1; FPreferredValid:=False; FLineAffinity:=-1;
  if Value then begin FScrollBar.Kind:=sbHorizontal; FScrollBar.Align:=alBottom; FScrollBar.Height:=GetSystemMetrics(SM_CYHSCROLL); end
  else begin FScrollBar.Kind:=sbVertical; FScrollBar.Align:=alRight; FScrollBar.Width:=GetSystemMetrics(SM_CXVSCROLL); end;
  Changed;
end;
function TComicTextInput.DisplayPoint(const P: TPoint): TPoint;
begin Result:=P; if FVertical then Inc(Result.X,FScroll) else Dec(Result.Y,FScroll); end;
procedure TComicTextInput.RebuildLayout;
var Area: TRect; Padding: Integer;
begin
  if FLayout=nil then Exit; Canvas.Font.Assign(Font); Padding:=MulDiv(16,CurrentPPI,96);
  Area:=Rect(Padding,Padding,Max(Padding+1,ClientWidth-Padding),Max(Padding+1,ClientHeight-Padding));
  if FVertical then Dec(Area.Bottom,FScrollBar.Height) else Dec(Area.Right,FScrollBar.Width);
  FDisplayBuffer:=FBuffer;
  if FComposing and (FComposition<>'') then FDisplayBuffer:=Copy(FBuffer,1,Min(FCaret,FAnchor))+FComposition+
    Copy(FBuffer,Max(FCaret,FAnchor)+1,MaxInt);
  FLayout.Build(Canvas,FDisplayBuffer,Area,FVertical,FAutoWrap);
  FLayout.ApplySpacing(FCharacterSpacing,FLineSpacing,FVertical);
end;
function TComicTextInput.DisplayCaretIndex: Integer;
var At,Next: Integer;
begin
  Result:=FCaret;
  if not FComposing or (FComposition='') then Exit;
  At:=0;
  while At<FCompositionCursor do begin
    Next:=NextComicTextBoundary(FComposition,At); if Next>FCompositionCursor then Break; At:=Next;
  end;
  Result:=Min(FCaret,FAnchor)+At;
end;
procedure TComicTextInput.EnsureCaretVisible;
var P: TPoint; Step,Padding,Visible,Limit: Integer;
begin
  if FLayout=nil then Exit; Padding:=MulDiv(16,CurrentPPI,96); Step:=FLayout.Step;
  P:=FLayout.CaretStop(DisplayCaretIndex,FLineAffinity).Point;
  if FVertical then begin
    Visible:=Max(1,ClientWidth-2*Padding); Limit:=Max(0,Round((FLayout.LineCount-1)*Step*FLineSpacing)+Step-Visible);
    if P.X+FScroll<Padding then FScroll:=Padding-P.X;
    if P.X+Step+FScroll>ClientWidth-Padding then FScroll:=ClientWidth-Padding-P.X-Step;
  end else begin
    Visible:=Max(1,ClientHeight-2*Padding); Limit:=Max(0,Round((FLayout.LineCount-1)*Step*FLineSpacing)+Step-Visible);
    if P.Y-FScroll<Padding then FScroll:=P.Y-Padding;
    if P.Y+Step-FScroll>ClientHeight-Padding then FScroll:=P.Y+Step-ClientHeight+Padding;
  end;
  FScroll:=EnsureRange(FScroll,0,Limit); FUpdatingScroll:=True;
  try FScrollBar.PageSize:=0; FScrollBar.Max:=Limit+Visible-1; FScrollBar.PageSize:=Visible; FScrollBar.Position:=FScroll;
  finally FUpdatingScroll:=False; end;
end;
procedure TComicTextInput.ScrollChanged(Sender: TObject);
begin if FUpdatingScroll then Exit; FScroll:=FScrollBar.Position; Invalidate; end;
procedure TComicTextInput.Resize;
begin inherited; if FScrollBar<>nil then begin RebuildLayout; EnsureCaretVisible; Invalidate; end; end;
procedure TComicTextInput.CMFontChanged(var Message: TMessage);
begin
  inherited;
  if FInput<>nil then begin FInput.Font.Assign(Font); FInput.Font.Color:=Color; end;
  if FScrollBar<>nil then begin RebuildLayout; EnsureCaretVisible; Invalidate; end;
end;
function TComicTextInput.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  Result:=FSession; if not Result then Exit;
  FScrollBar.Position:=EnsureRange(FScrollBar.Position-WheelDelta div WHEEL_DELTA*FLayout.Step*3,0,
    Max(0,FScrollBar.Max-Integer(FScrollBar.PageSize)+1));
end;
procedure TComicTextInput.Remember;
var State: TComicTextUndoState;
begin
  State.Text:=FBuffer; State.Caret:=FCaret; State.Anchor:=FAnchor; FUndo.Add(State); FRedo.Clear;
  if FUndo.Count>100 then FUndo.Delete(0);
end;
procedure TComicTextInput.RestoreHistory(Undo: Boolean);
var Source,Target: TList<TComicTextUndoState>; State: TComicTextUndoState;
begin
  if Undo then begin Source:=FUndo; Target:=FRedo; end else begin Source:=FRedo; Target:=FUndo; end;
  if Source.Count=0 then Exit;
  State.Text:=FBuffer; State.Caret:=FCaret; State.Anchor:=FAnchor; Target.Add(State);
  State:=Source.Last; Source.Delete(Source.Count-1); FBuffer:=State.Text; FCaret:=State.Caret; FAnchor:=State.Anchor;
  FPreferred:=-1; FLineAffinity:=-1;
end;
procedure TComicTextInput.MoveLine(Direction: Integer; Extend: Boolean);
var Stop: TComicCaretStop;
begin
  RebuildLayout; Stop:=FLayout.CaretStop(FCaret,FLineAffinity);
  // 中央配置では負の文字位置も有効なため、未設定を座標の符号で判定しない。
  if not FPreferredValid then begin
    if FVertical then FPreferred:=Stop.Point.Y else FPreferred:=Stop.Point.X;
    FPreferredValid:=True;
  end;
  Stop:=FLayout.AtLine(Stop.Line+Direction,Round(FPreferred),FVertical);
  FCaret:=Stop.Index; FLineAffinity:=Stop.Line; if not Extend then FAnchor:=FCaret;
end;
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
  FInput.ResetPendingInput;
  FInput.ImeMode:=imDisable; FInput.Enabled:=False;
  // 入力無効化とフォーカス通知の後に復元し、退避した開閉状態をimDisableで再び上書きしない。
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
begin FInput.Text:=''; RebuildLayout; EnsureCaretVisible; Invalidate; end;
procedure TComicTextInput.Committed(Sender: TObject; const Value: string);
begin
  if not FSession then Exit;
  if Value='' then Exit; Remember;
  InsertScreenLayoutTextAtCaret(FBuffer,FCaret,FAnchor,FPreferred,Value); FPreferredValid:=False; FLineAffinity:=-1; Changed;
end;
procedure TComicTextInput.Composition(Sender: TObject; const Value: string; Cursor: Integer; Active: Boolean);
begin
  if not FSession then Exit;
  FComposition:=Value; FCompositionCursor:=EnsureRange(Cursor,0,Length(Value)); FComposing:=Active;
  FLineAffinity:=-1; FPreferredValid:=False; RebuildLayout; EnsureCaretVisible; Invalidate;
end;
procedure TComicTextInput.UpdateImePosition;
var Context: HIMC; Form: TCompositionForm; Candidate: TCandidateForm; LogFont: TLogFont;
begin
  if FTesting or not FSession then Exit;
  Context:=ImmGetContext(FInput.Handle); if Context=0 then Exit;
  try
    Form:=Default(TCompositionForm); Form.dwStyle:=CFS_POINT; Form.ptCurrentPos:=Point(0,0);
    ImmSetCompositionWindow(Context,@Form);
    Candidate:=Default(TCandidateForm); Candidate.dwStyle:=CFS_EXCLUDE;
    Candidate.ptCurrentPos:=Point(0,FInput.Height); Candidate.rcArea:=Rect(0,0,Max(2,FCaretBounds.Width),FInput.Height);
    ImmSetCandidateWindow(Context,@Candidate);
    if GetObject(FInput.Font.Handle,SizeOf(LogFont),@LogFont)<>0 then ImmSetCompositionFontW(Context,@LogFont);
  finally ImmReleaseContext(FInput.Handle,Context); end;
end;
procedure TComicTextInput.InputKey(Sender: TObject; var Key: Word; Shift: TShiftState);
begin Command(Key,Shift); end;
procedure TComicTextInput.Command(var Key: Word; Shift: TShiftState);
var Extend: Boolean; Direction,Along: Integer; Stop: TComicCaretStop; Value: string;
begin
  if not FSession then Exit;
  if FComposing then Exit; // 未確定中の矢印/Enter/EscはIMEへ渡す。
  if (ssCtrl in Shift) or not (((not FVertical) and (Key in [VK_UP,VK_DOWN])) or
    (FVertical and (Key in [VK_LEFT,VK_RIGHT]))) then FPreferredValid:=False;
  Extend:=ssShift in Shift;
  if ssCtrl in Shift then begin
    case Key of
      Ord('A'): begin FAnchor:=0; FCaret:=Length(FBuffer); FLineAffinity:=-1; FPreferred:=-1; end;
      Ord('Z'): RestoreHistory(not Extend);
      Ord('Y'): RestoreHistory(False);
      Ord('C'): if FCaret<>FAnchor then Clipboard.AsText:=Copy(FBuffer,Min(FCaret,FAnchor)+1,Abs(FCaret-FAnchor));
      Ord('X'): begin
        if FCaret<>FAnchor then begin
          Clipboard.AsText:=Copy(FBuffer,Min(FCaret,FAnchor)+1,Abs(FCaret-FAnchor)); Remember;
          DeleteScreenLayoutTextSelection(FBuffer,FCaret,FAnchor,FPreferred); FLineAffinity:=-1;
        end;
      end;
      Ord('V'): begin Value:=Clipboard.AsText; if Value<>'' then begin Remember;
        InsertScreenLayoutTextAtCaret(FBuffer,FCaret,FAnchor,FPreferred,Value); FLineAffinity:=-1; end; end;
      VK_RETURN: begin if Assigned(FAccept) then FAccept(Self); Key:=0; Exit; end;
      VK_HOME: begin FCaret:=0; FLineAffinity:=-1; FPreferred:=-1; if not Extend then FAnchor:=FCaret; end;
      VK_END: begin FCaret:=Length(FBuffer); FLineAffinity:=-1; FPreferred:=-1; if not Extend then FAnchor:=FCaret; end;
      VK_LEFT,VK_RIGHT,VK_UP,VK_DOWN: begin
        if Key in [VK_LEFT,VK_UP] then Direction:=-1 else Direction:=1;
        FCaret:=ComicTextWordBoundary(FBuffer,FCaret,Direction); FLineAffinity:=-1; FPreferred:=-1;
        if not Extend then FAnchor:=FCaret;
      end;
      VK_BACK,VK_DELETE: begin
        if FCaret=FAnchor then begin
          if Key=VK_BACK then Direction:=-1 else Direction:=1;
          Along:=ComicTextWordBoundary(FBuffer,FCaret,Direction);
          if Along<>FCaret then begin Remember; FCaret:=Along; end;
        end else Remember;
        DeleteScreenLayoutTextSelection(FBuffer,FCaret,FAnchor,FPreferred); FLineAffinity:=-1;
      end;
    else Exit; end;
  end else case Key of
    VK_LEFT,VK_RIGHT,VK_UP,VK_DOWN: begin
      if (not FVertical and (Key in [VK_UP,VK_DOWN])) or (FVertical and (Key in [VK_LEFT,VK_RIGHT])) then begin
        if Key in [VK_UP,VK_RIGHT] then Direction:=-1 else Direction:=1;
        MoveLine(Direction,Extend);
      end else begin
        if Key in [VK_LEFT,VK_UP] then Direction:=-1 else Direction:=1;
        MoveScreenLayoutTextCaretHorizontal(FBuffer,FCaret,FAnchor,FPreferred,Direction,Extend); FLineAffinity:=-1;
      end;
    end;
    VK_BACK,VK_DELETE: begin
      if (FCaret<>FAnchor) or ((Key=VK_BACK) and (FCaret>0)) or ((Key=VK_DELETE) and (FCaret<Length(FBuffer))) then Remember;
      if FCaret=FAnchor then
        if Key=VK_BACK then MoveScreenLayoutTextCaretHorizontal(FBuffer,FCaret,FAnchor,FPreferred,-1,True)
        else MoveScreenLayoutTextCaretHorizontal(FBuffer,FCaret,FAnchor,FPreferred,1,True);
      DeleteScreenLayoutTextSelection(FBuffer,FCaret,FAnchor,FPreferred); FLineAffinity:=-1;
    end;
    VK_RETURN: begin Remember; InsertScreenLayoutTextAtCaret(FBuffer,FCaret,FAnchor,FPreferred,#13#10); FLineAffinity:=-1; end;
    VK_ESCAPE: begin if Assigned(FCancel) then FCancel(Self); Key:=0; Exit; end;
    VK_HOME,VK_END: begin
      RebuildLayout; Stop:=FLayout.CaretStop(FCaret,FLineAffinity);
      Stop:=FLayout.LineEdge(Stop.Line,Key=VK_END); FCaret:=Stop.Index; FLineAffinity:=Stop.Line; FPreferred:=-1;
      if not Extend then FAnchor:=FCaret;
    end;
  else Exit; end;
  Key:=0; Changed;
end;
procedure TComicTextInput.Paint;
var Cell: TComicTextCell; Caret,P: TPoint; R,Viewport: TRect; Padding,H: Integer;
begin
  Canvas.Brush.Color:=Color; Canvas.FillRect(ClientRect); Canvas.Font.Assign(Font);
  RebuildLayout; Padding:=MulDiv(16,CurrentPPI,96); H:=FLayout.Step;
  Viewport:=ClientRect;
  if FVertical then Dec(Viewport.Bottom,FScrollBar.Height) else Dec(Viewport.Right,FScrollBar.Width);
  for Cell in FLayout.Cells do begin
    P:=DisplayPoint(Cell.Bounds.TopLeft); R:=Rect(P.X,P.Y,P.X+Cell.Bounds.Width,P.Y+Cell.Bounds.Height);
    if (R.Right<0) or (R.Left>Viewport.Right) or (R.Bottom<0) or (R.Top>Viewport.Bottom) then Continue;
    if not FComposing and (Cell.Index<Max(FCaret,FAnchor)) and (Cell.Index+Cell.Count>Min(FCaret,FAnchor)) then
      Canvas.Brush.Color:=$FFE0B0 else Canvas.Brush.Color:=Color;
    Canvas.FillRect(R); Canvas.Brush.Style:=bsClear; Canvas.Font.Color:=Font.Color;
    Canvas.Font.Style:=Font.Style;
    if FComposing and (Cell.Index>=Min(FCaret,FAnchor)) and
      (Cell.Index<Min(FCaret,FAnchor)+Length(FComposition)) then Canvas.Font.Style:=Canvas.Font.Style+[fsUnderline];
    DrawComicTextCell(Canvas,FDisplayBuffer,Cell,R,FVertical); Canvas.Brush.Style:=bsSolid;
  end;
  Caret:=DisplayPoint(FLayout.CaretStop(DisplayCaretIndex,FLineAffinity).Point);
  if FVertical then FCaretBounds:=Rect(Caret.X,Caret.Y,Caret.X+H-2,Caret.Y+2)
  else FCaretBounds:=Rect(Caret.X,Caret.Y,Caret.X+2,Caret.Y+H-2);
  if FSession then begin Canvas.Brush.Color:=$BD7620; Canvas.FillRect(FCaretBounds); end;
  FInput.SetBounds(EnsureRange(Caret.X,Padding,Max(Padding,Viewport.Right-2)),
    EnsureRange(Caret.Y,Padding,Max(Padding,Viewport.Bottom-H)),2,H);
  UpdateImePosition;
  HideCaret(FInput.Handle);
end;
procedure TComicTextInput.MouseDown(Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
var Stop: TComicCaretStop; P: TPoint;
begin
  inherited; if (Button<>mbLeft) or not FSession or FComposing then Exit;
  RebuildLayout; P:=Point(X,Y);
  if FVertical then Dec(P.X,FScroll) else Inc(P.Y,FScroll);
  Stop:=FLayout.HitTest(P,FVertical); FCaret:=Stop.Index; FLineAffinity:=Stop.Line; FPreferred:=-1; FPreferredValid:=False;
  if not (ssShift in Shift) then FAnchor:=FCaret;
  FocusInput; EnsureCaretVisible; Invalidate;
end;
constructor TComicTextDialog.CreateEditor(AOwner: TComponent; const Text: string; Vertical,Testing: Boolean);
var Bar: TPanel; Button: TButton; PPI: Integer;
begin
  inherited CreateScaledNew(AOwner,OwnerControlPPI(AOwner)); Caption:='吹き出しの文字入力（初期プレビュー）'; Position:=poOwnerFormCenter; KeyPreview:=True;
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
