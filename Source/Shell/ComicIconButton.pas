unit ComicIconButton;

interface

uses System.Classes, System.Types, System.Math, Winapi.Windows, Winapi.Messages,
  Vcl.Controls, Vcl.Forms, Vcl.Graphics;

type
  TComicIcon = (ciSelect,ciRectangle,ciEllipse,ciRounded,ciPolygon,ciSplit,ciOrder,ciBalloonEllipse,
    ciBalloonRounded,ciTail,ciLayout,ciPanelEdit,ciImage,ciCharacters,ciNew,ciOpen,
    ciSave,ciUndo,ciRedo,ciExport,ciAddPage,ciDelete,ciUp,ciDown,ciRegister,
    ciApplyLayout,ciInsertLayout,ciAssignImage,ciDetachImage,ciApplyText);
  TComicButtonRole = (brAlways,brProject,brSave,brUndo,brRedo,brExport,brAddPage,
    brDeletePage,brPageUp,brPageDown,brRegister,brApplyLayout,brInsertLayout,
    brMode,brTool,brDeletePanel,brAssignImage,brDetachImage,brTail,brApplyText,brDeleteBalloon);

  // Adapted from MapRaku's TVectArtDarkButton and code-drawn tool palette.
  // Document-specific dependencies are omitted; no MapRaku files are linked or changed.
  TComicIconButton = class(TCustomControl)
  private
    FHover,FPressed,FSelected,FShowText: Boolean;
    FIcon: TComicIcon;
    FOnHelp: TNotifyEvent;
    FOnNavigate: TKeyEvent;
    procedure SetSelected(Value: Boolean);
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure CMEnabledChanged(var Message: TMessage); message CM_ENABLEDCHANGED;
    procedure WMGetDlgCode(var Message: TWMGetDlgCode); message WM_GETDLGCODE;
    procedure CMDialogKey(var Message: TCMDialogKey); message CM_DIALOGKEY;
  protected
    procedure Paint; override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyPress(var Key: Char); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X,Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X,Y: Integer); override;
  public
    Role: TComicButtonRole;
    Context: Integer;
    constructor Create(AOwner: TComponent); override;
    procedure Click; override;
    function Available: Boolean;
    procedure RenderTo(C: TCanvas; const R: TRect);
    property Icon: TComicIcon read FIcon write FIcon;
    property Selected: Boolean read FSelected write SetSelected;
    property ShowText: Boolean read FShowText write FShowText;
    property Hovered: Boolean read FHover;
    property Pressed: Boolean read FPressed;
    property OnHelp: TNotifyEvent read FOnHelp write FOnHelp;
    property OnNavigate: TKeyEvent read FOnNavigate write FOnNavigate;
    property Caption;
    property ParentFont;
    property OnClick;
    property ControlStyle;
  end;

procedure DrawComicIcon(C: TCanvas; const R: TRect; Icon: TComicIcon; Color: TColor);

implementation

// MapRaku palette/button colors: clear blue selection and high-contrast line icons.
const
  ButtonColor=$383838; HoverColor=$484848; PressedColor=$202020;
  DisabledColor=$2E2E2E; BorderColor=$606060; IconColor=$EEEEEE;
  SelectedColor=$CE7818; SelectedBorder=$FFCC6C;

procedure DrawComicIcon(C: TCanvas; const R: TRect; Icon: TComicIcon; Color: TColor);
var S: Double; CX,CY: Integer;
  function X(Value: Double): Integer; begin Result:=CX+Round(Value*S); end;
  function Y(Value: Double): Integer; begin Result:=CY+Round(Value*S); end;
  procedure Line(X1,Y1,X2,Y2: Double);
  begin C.MoveTo(X(X1),Y(Y1)); C.LineTo(X(X2),Y(Y2)); end;
  procedure Box(L,T,Right,Bottom: Double);
  begin C.Rectangle(X(L),Y(T),X(Right),Y(Bottom)); end;
  procedure Bubble(Round: Boolean);
  begin
    if Round then C.RoundRect(X(-10),Y(-9),X(10),Y(5),X(0)-X(-5),Y(0)-Y(-5))
    else C.Ellipse(X(-11),Y(-10),X(11),Y(6));
    Line(-3,5,-6,11); Line(-6,11,3,5);
  end;
  procedure Picture;
  begin Box(-11,-9,11,9); C.Ellipse(X(3),Y(-6),X(7),Y(-2));
    C.Polyline([Point(X(-10),Y(7)),Point(X(-4),Y(-1)),Point(X(1),Y(5)),Point(X(5),Y(1)),Point(X(10),Y(7))]); end;
  procedure Plus(PX,PY: Double);
  begin Line(PX-3,PY,PX+3,PY); Line(PX,PY-3,PX,PY+3); end;
begin
  S:=Min(R.Width,R.Height)/28; CX:=(R.Left+R.Right) div 2; CY:=(R.Top+R.Bottom) div 2;
  C.Pen.Color:=Color; C.Pen.Width:=Max(1,Round(1.7*S)); C.Pen.Style:=psSolid;
  C.Brush.Style:=bsClear; C.Font.Color:=Color;
  case Icon of
    ciSelect: begin
      // Same cursor outline as MapRakuToolPalette's selection tool.
      C.Polyline([Point(X(-8),Y(-11)),Point(X(7),Y(2)),Point(X(0),Y(4)),Point(X(4),Y(12)),
        Point(X(0),Y(14)),Point(X(-4),Y(6)),Point(X(-9),Y(10)),Point(X(-8),Y(-11))]);
    end;
    ciRectangle: Box(-10,-8,10,8);
    ciEllipse: C.Ellipse(X(-12),Y(-9),X(12),Y(9));
    ciRounded: C.RoundRect(X(-11),Y(-9),X(11),Y(9),Round(8*S),Round(8*S));
    ciPolygon: begin
      C.Polygon([Point(X(-11),Y(8)),Point(X(-5),Y(-10)),Point(X(11),Y(-4)),Point(X(7),Y(10))]);
      C.Brush.Style:=bsSolid; C.Brush.Color:=Color;
      C.Rectangle(X(-13),Y(6),X(-9),Y(10)); C.Rectangle(X(-7),Y(-12),X(-3),Y(-8));
      C.Rectangle(X(9),Y(-6),X(13),Y(-2)); C.Rectangle(X(5),Y(8),X(9),Y(12));
    end;
    ciSplit: begin Box(-11,-10,11,10); Line(-10,-6,9,8); Line(-9,-10,10,4); end;
    ciOrder: begin
      Box(-11,-10,-1,0); Box(1,2,11,12); Line(-5,2,-5,9); Line(-5,9,0,9);
      C.Font.Name:='Segoe UI'; C.Font.Height:=-Max(8,Round(8*S));
      C.TextOut(X(-8),Y(-9),'1'); C.TextOut(X(4),Y(3),'2');
    end;
    ciBalloonEllipse: Bubble(False);
    ciBalloonRounded: Bubble(True);
    ciTail: begin C.Ellipse(X(-11),Y(-11),X(5),Y(1));
      C.Polyline([Point(X(-3),Y(-1)),Point(X(10),Y(11)),Point(X(2),Y(-3))]); end;
    ciLayout,ciPanelEdit,ciRegister,ciApplyLayout,ciInsertLayout: begin
      Box(-10,-11,10,11); Line(-10,-2,10,-2); Line(0,-2,0,11);
      if Icon=ciPanelEdit then begin Line(3,-7,12,2); Line(12,2,10,6); end;
      if Icon=ciRegister then Plus(8,8);
      if Icon=ciApplyLayout then begin Line(3,7,6,10); Line(6,10,12,3); end;
      if Icon=ciInsertLayout then begin Line(-13,0,-6,0); Line(-9,-3,-6,0); Line(-9,3,-6,0); end;
    end;
    ciImage,ciAssignImage,ciDetachImage: begin
      Picture;
      if Icon=ciAssignImage then Plus(7,8);
      if Icon=ciDetachImage then begin Line(4,4,11,11); Line(11,4,4,11); end;
    end;
    ciCharacters: begin C.Ellipse(X(-4),Y(-11),X(4),Y(-3));
      C.Arc(X(-10),Y(-1),X(10),Y(17),X(-10),Y(7),X(10),Y(7)); Line(-10,7,10,7); end;
    ciNew,ciAddPage: begin Box(-9,-11,7,11); Plus(0,1); end;
    ciOpen: begin C.Polyline([Point(X(-11),Y(9)),Point(X(-11),Y(-8)),Point(X(-3),Y(-8)),
      Point(X(0),Y(-4)),Point(X(10),Y(-4)),Point(X(10),Y(0))]);
      C.Polyline([Point(X(-11),Y(9)),Point(X(-7),Y(-1)),Point(X(12),Y(-1)),Point(X(8),Y(9)),Point(X(-11),Y(9))]); end;
    ciSave: begin Box(-10,-10,10,10); Box(-5,-10,5,-2); Box(-5,3,5,10); Line(2,-8,2,-4); end;
    ciUndo,ciRedo: begin
      if Icon=ciUndo then begin Line(-10,-2,3,-2); Line(-10,-2,-4,-8); Line(-10,-2,-4,4);
        Line(3,-2,9,3); Line(9,3,9,8); Line(9,8,0,8); end
      else begin Line(10,-2,-3,-2); Line(10,-2,4,-8); Line(10,-2,4,4);
        Line(-3,-2,-9,3); Line(-9,3,-9,8); Line(-9,8,0,8); end;
    end;
    ciExport: begin Box(-10,0,10,10); Line(0,-12,0,5); Line(0,5,-5,0); Line(0,5,5,0); end;
    ciDelete: begin
      // MapRakuFilterFrame's delete/trash outline, centered and DPI-scaled.
      Line(-6,-3,-5,6); Line(-5,6,5,6); Line(5,6,6,-3); Line(-7,-4,7,-4); Line(-2,-6,2,-6);
    end;
    ciUp: begin Line(0,9,0,-9); Line(0,-9,-7,-2); Line(0,-9,7,-2); end;
    ciDown: begin Line(0,-9,0,9); Line(0,9,-7,2); Line(0,9,7,2); end;
    ciApplyText: begin Line(-9,-9,5,-9); Line(-2,-9,-2,8); Line(-7,8,2,8);
      Line(3,5,6,8); Line(6,8,12,1); end;
  end;
  C.Brush.Style:=bsSolid; C.Pen.Width:=1;
end;

constructor TComicIconButton.Create(AOwner: TComponent);
begin
  inherited; TabStop:=True; DoubleBuffered:=True; ShowHint:=True; Cursor:=crHandPoint;
  ControlStyle:=ControlStyle+[csOpaque]-[csDoubleClicks];
  Font.Name:='Yu Gothic UI'; Font.Size:=10; Font.Color:=IconColor; Context:=-1;
end;
function TComicIconButton.Available: Boolean;
var C: TControl;
begin
  Result:=True; C:=Self;
  while C<>nil do begin if not C.Enabled then Exit(False); C:=C.Parent; end;
end;
procedure TComicIconButton.Click;
begin if Available then inherited Click; end;
procedure TComicIconButton.SetSelected(Value: Boolean);
begin if FSelected=Value then Exit; FSelected:=Value; Invalidate; end;
procedure TComicIconButton.CMMouseEnter(var Message: TMessage);
begin inherited; FHover:=True; Invalidate; if Available and Assigned(FOnHelp) then FOnHelp(Self); end;
procedure TComicIconButton.CMMouseLeave(var Message: TMessage);
begin inherited; FHover:=False; FPressed:=False; Invalidate; end;
procedure TComicIconButton.CMEnabledChanged(var Message: TMessage);
begin inherited; FPressed:=False; Invalidate; end;
procedure TComicIconButton.DoEnter;
begin inherited; Invalidate; if Assigned(FOnHelp) then FOnHelp(Self); end;
procedure TComicIconButton.DoExit;
begin inherited; FPressed:=False; Invalidate; end;
procedure TComicIconButton.WMGetDlgCode(var Message: TWMGetDlgCode);
begin inherited; Message.Result:=Message.Result or DLGC_BUTTON or DLGC_WANTARROWS; end;
procedure TComicIconButton.CMDialogKey(var Message: TCMDialogKey);
var Form: TCustomForm;
begin
  Form:=GetParentForm(Self);
  if Available and (Form<>nil) and (Form.ActiveControl=Self) and
    (Message.CharCode in [VK_RETURN,VK_SPACE]) then begin Click; Message.Result:=1; end
  else inherited;
end;
procedure TComicIconButton.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if Available and Assigned(FOnNavigate) then FOnNavigate(Self,Key,Shift);
  if Available and (Key in [VK_RETURN,VK_SPACE]) then begin Click; Key:=0; end;
  inherited;
end;
procedure TComicIconButton.KeyPress(var Key: Char);
begin if (Key=#13) or (Key=#32) then Key:=#0; inherited; end;
procedure TComicIconButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
var Form: TCustomForm;
begin
  if Available and (Button=mbLeft) then begin
    Form:=GetParentForm(Self); if Form<>nil then Form.ActiveControl:=Self;
    FPressed:=True; Invalidate;
  end;
  inherited;
end;
procedure TComicIconButton.MouseUp(Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
begin FPressed:=False; Invalidate; inherited; end;
procedure TComicIconButton.RenderTo(C: TCanvas; const R: TRect);
var Bounds,Glyph,TextRect: TRect; Background,Foreground,Border: TColor; Size,Gap: Integer; Form: TCustomForm;
begin
  Background:=ButtonColor; Border:=BorderColor; Foreground:=IconColor;
  if not Available then begin Background:=DisabledColor; Foreground:=BorderColor; end
  else if FPressed then Background:=PressedColor
  else if FSelected then begin Background:=SelectedColor; Border:=SelectedBorder; end
  else if FHover then Background:=HoverColor;
  C.Brush.Style:=bsSolid; C.Brush.Color:=Background; C.FillRect(R);
  Bounds:=R; Dec(Bounds.Right); Dec(Bounds.Bottom); C.Pen.Width:=1; C.Pen.Color:=Border;
  C.RoundRect(Bounds,Max(2,MulDiv(5,CurrentPPI,96)),Max(2,MulDiv(5,CurrentPPI,96)));
  Size:=Min(MulDiv(28,CurrentPPI,96),R.Height-MulDiv(12,CurrentPPI,96)); Gap:=MulDiv(8,CurrentPPI,96);
  if FShowText then Glyph:=Rect(R.Left+Gap,R.Top+(R.Height-Size) div 2,R.Left+Gap+Size,0)
  else Glyph:=Rect(R.Left+(R.Width-Size) div 2,R.Top+(R.Height-Size) div 2,0,0);
  Glyph.Right:=Glyph.Left+Size; Glyph.Bottom:=Glyph.Top+Size;
  DrawComicIcon(C,Glyph,FIcon,Foreground);
  if FShowText then begin
    TextRect:=Rect(Glyph.Right+Gap,R.Top+2,R.Right-Gap,R.Bottom-2);
    C.Brush.Style:=bsClear; C.Font.Assign(Font); C.Font.Color:=Foreground;
    DrawText(C.Handle,PChar(Caption),Length(Caption),TextRect,DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_END_ELLIPSIS or DT_NOPREFIX);
  end;
  Form:=GetParentForm(Self);
  if Available and (Form<>nil) and (Form.ActiveControl=Self) then begin
    Bounds:=R; InflateRect(Bounds,-MulDiv(3,CurrentPPI,96),-MulDiv(3,CurrentPPI,96));
    C.Brush.Style:=bsClear; C.Pen.Color:=SelectedBorder; C.Pen.Style:=psDot; C.Rectangle(Bounds); C.Pen.Style:=psSolid;
  end;
  C.Brush.Style:=bsSolid;
end;
procedure TComicIconButton.Paint;
begin RenderTo(Canvas,ClientRect); end;

end.
