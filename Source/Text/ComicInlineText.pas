unit ComicInlineText;

// 責務：既存の文字編集バッファをページ座標へ接続する。作品は確定まで変更しない。
// IME受取窓だけをキャレットへ移し、文字本体は完成ページと同じ組版で描画する。
interface
uses System.Classes, System.Types, Vcl.Controls, Vcl.Graphics, ComicTextInput,
  ComicModel, ComicTextLayout;
type
  TComicInlineText = class(TComicTextInput)
  private
    FPreview: TComicBalloon;
    FMeasure: TBitmap;
    FTextScale: Double;
    FOnChange,FOnLeave: TNotifyEvent;
    function LocalPoint(const P: TPointF): TPoint;
  protected
    procedure RebuildLayout; override;
    procedure EnsureCaretVisible; override;
    procedure Changed; override;
    procedure Composition(Sender: TObject; const Value: string; Cursor: Integer; Active: Boolean); override;
    procedure InputExit(Sender: TObject); override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Start(Balloon: TComicBalloon; Vertical,Testing: Boolean; const PreferredFont: string; PreferredSize: Integer=0);
    procedure PlaceCaret(const P: TPointF; Extend: Boolean);
    procedure DrawOverlay(C: TCanvas; const Origin: TPoint; Scale: Double;
      const Clip: TRect; Page: TComicPage);
    procedure CompleteComposition;
    property Preview: TComicBalloon read FPreview;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnLeave: TNotifyEvent read FOnLeave write FOnLeave;
  end;
implementation
uses Winapi.Windows, Winapi.Imm, System.SysUtils, System.Math, System.JSON, ComicRender;
constructor TComicInlineText.Create(AOwner: TComponent);
begin
  inherited; Visible:=False; TabStop:=False; FScrollBar.Visible:=False;
  FInput.Color:=$BD7620; FInput.Font.Color:=$BD7620;
  FPreview:=TComicBalloon.Create; FMeasure:=Vcl.Graphics.TBitmap.Create; FMeasure.SetSize(1,1);
end;
destructor TComicInlineText.Destroy;
begin FOnLeave:=nil; FOnChange:=nil; EndSession; FreeAndNil(FPreview); FreeAndNil(FMeasure); inherited; end;
procedure TComicInlineText.Start(Balloon: TComicBalloon; Vertical,Testing: Boolean; const PreferredFont: string; PreferredSize: Integer);
var J: TJSONObject;
begin
  J:=Balloon.Json;
  try FPreview.Read(J); finally J.Free; end;
  FPreview.Vertical:=Vertical;
  if (Balloon.Text='') and (PreferredFont<>'') then begin
    FPreview.FontFamily:=PreferredFont; FPreview.ResetTextLayout;
  end;
  if (Balloon.Text='') and (PreferredSize>=1) and (PreferredSize<=1000) then begin
    FPreview.FontSize:=PreferredSize; FPreview.ResetTextLayout;
  end;
  if Balloon.Vertical<>Vertical then FPreview.ResetTextLayout;
  FPreview.AutoWrap:=False;
  FVertical:=Vertical; Text:=Balloon.Text; FScrollBar.Visible:=False;
  // ネイティブEditは文字を持たず、選択表示や折返しをページから独立させない。
  FInput.SetBounds(0,0,2,Max(2,FPreview.FontSize));
  SetBounds(0,0,2,Max(2,FPreview.FontSize)); Visible:=True;
  // フォーカス可能な窓は維持し、縦書きの横線キャレットへネイティブEditを重ねない。
  SetWindowRgn(Handle,CreateRectRgn(0,0,0,0),True);
  BeginSession(Testing);
end;
procedure TComicInlineText.RebuildLayout;
begin
  if (FPreview=nil) or (FMeasure=nil) then Exit;
  FDisplayBuffer:=FBuffer;
  if FComposing and (FComposition<>'') then
    FDisplayBuffer:=Copy(FBuffer,1,Min(FCaret,FAnchor))+FComposition+
      Copy(FBuffer,Max(FCaret,FAnchor)+1,MaxInt);
  FPreview.Text:=FDisplayBuffer;
  FTextScale:=BuildBalloonTextLayout(FMeasure.Canvas,FPreview,FLayout);
  // 相対位置を保ち、完成表示と同じ自動センタリングを使う。改行は明示入力だけで行う。
end;
procedure TComicInlineText.EnsureCaretVisible;
begin
  // ページの表示倍率・パンを維持する。専用入力画面のスクロール座標は使用しない。
end;
procedure TComicInlineText.Changed;
begin inherited; if Assigned(FOnChange) then FOnChange(Self); end;
procedure TComicInlineText.Composition(Sender: TObject; const Value: string; Cursor: Integer; Active: Boolean);
begin inherited; if Assigned(FOnChange) then FOnChange(Self); end;
procedure TComicInlineText.InputExit(Sender: TObject);
begin
  if FSession and FComposing then CompleteComposition;
  inherited;
  if FSession and Assigned(FOnLeave) then FOnLeave(Self);
end;
procedure TComicInlineText.Paint;
begin
  Canvas.Brush.Color:=$BD7620; Canvas.FillRect(ClientRect);
end;
function TComicInlineText.LocalPoint(const P: TPointF): TPoint;
var Center: TPointF;
begin
  Center:=FPreview.Bounds.CenterPoint;
  Result:=Point(Round((P.X-Center.X-FPreview.TextOffset.X)/FTextScale),
    Round((P.Y-Center.Y-FPreview.TextOffset.Y)/FTextScale));
end;
procedure TComicInlineText.PlaceCaret(const P: TPointF; Extend: Boolean);
var Stop: TComicCaretStop;
begin
  if not FSession or FComposing then Exit;
  RebuildLayout; Stop:=FLayout.HitTest(LocalPoint(P),FVertical);
  FCaret:=Stop.Index; FLineAffinity:=Stop.Line; FPreferred:=-1; FPreferredValid:=False;
  if not Extend then FAnchor:=FCaret;
  if Assigned(FOnChange) then FOnChange(Self);
end;
procedure TComicInlineText.CompleteComposition;
var Context: HIMC;
begin
  if not FComposing then Exit;
  Context:=ImmGetContext(FInput.Handle);
  if Context<>0 then
    try ImmNotifyIME(Context,NI_COMPOSITIONSTR,CPS_COMPLETE,0);
    finally ImmReleaseContext(FInput.Handle,Context); end;
  if FComposing then raise Exception.Create('IME変換を確定してから操作してください。');
end;
procedure TComicInlineText.DrawOverlay(C: TCanvas; const Origin: TPoint; Scale: Double;
  const Clip: TRect; Page: TComicPage);
var Cell: TComicTextCell; R: TRect; P: TPoint; CX,CY,S: Double; H,Saved: Integer;
  Panel: TComicPanel; Region: HRGN; HasOwner: Boolean;
  function Map(const R: TRect): TRect;
  begin Result:=Rect(Round(CX+R.Left*S),Round(CY+R.Top*S),
    Round(CX+R.Right*S),Round(CY+R.Bottom*S)); end;
begin
  if not SessionActive then Exit; RebuildLayout;
  S:=FTextScale*Scale; CX:=Origin.X+(FPreview.Bounds.CenterPoint.X+FPreview.TextOffset.X)*Scale;
  CY:=Origin.Y+(FPreview.Bounds.CenterPoint.Y+FPreview.TextOffset.Y)*Scale;
  Saved:=SaveDC(C.Handle);
  try
    IntersectClipRect(C.Handle,Clip.Left,Clip.Top,Clip.Right,Clip.Bottom);
    if not FPreview.Overflow then begin
      HasOwner:=False;
      for Panel in Page.Panels do if Panel.ID=FPreview.PanelID then begin
        Region:=PanelRegion(Panel,Origin,Scale,C);
        try ExtSelectClipRgn(C.Handle,Region,RGN_AND); finally DeleteObject(Region); end;
        HasOwner:=True; Break;
      end;
      if not HasOwner then Exit;
    end;
    C.Font.Assign(FMeasure.Canvas.Font); C.Font.Height:=-Max(1,Round(FPreview.FontSize*Scale));
    for Cell in FLayout.Cells do begin
      R:=Map(Cell.Bounds);
      if not FComposing and (Cell.Index<Max(FCaret,FAnchor)) and
        (Cell.Index+Cell.Count>Min(FCaret,FAnchor)) then begin
        C.Brush.Style:=bsSolid; C.Brush.Color:=$FFE0B0; C.FillRect(R);
        C.Brush.Style:=bsClear; DrawComicTextCell(C,FDisplayBuffer,Cell,R,FVertical);
      end;
      // IME未確定文字にも本文の書式だけを使う。変換中の目印はキャレットと候補UIへ任せる。
    end;
    P:=FLayout.CaretStop(DisplayCaretIndex,FLineAffinity).Point; H:=Max(2,Round(FLayout.Step*S));
    P:=Point(Round(CX+P.X*S),Round(CY+P.Y*S));
    if FVertical then FCaretBounds:=Rect(P.X,P.Y,P.X+H,P.Y+2)
    else FCaretBounds:=Rect(P.X,P.Y,P.X+2,P.Y+H);
    C.Brush.Style:=bsSolid; C.Brush.Color:=$BD7620; C.FillRect(FCaretBounds);
    // 入力窓と候補位置は画面座標へ変換したキャレットへ追従する。
    SetBounds(EnsureRange(P.X,0,Max(0,Parent.ClientWidth-2)),
      EnsureRange(P.Y,0,Max(0,Parent.ClientHeight-H)),2,H);
    FInput.SetBounds(0,0,2,H); FInput.Font.Assign(C.Font); FInput.Font.Color:=FInput.Color;
    UpdateImePosition; HideCaret(FInput.Handle);
  finally RestoreDC(C.Handle,Saved); C.Refresh; end;
end;
end.
