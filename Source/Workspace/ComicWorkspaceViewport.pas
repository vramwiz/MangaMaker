unit ComicWorkspaceViewport;

// 責務：保存対象外の表示倍率・パンと編集座標の変換を管理する。
interface
uses System.Classes, MangaMakerMainForm, System.Types, Vcl.Controls;
procedure RunWorkspaceUpdateViewport(Form: TMainForm);
procedure RunWorkspaceResetViewport(Form: TMainForm);
procedure RunWorkspaceBeginViewPan(Form: TMainForm; Button: TMouseButton; X,Y: Integer);
procedure RunWorkspaceEndViewPan(Form: TMainForm; Cancel: Boolean);
procedure RunWorkspaceViewCaptureLost(Form: TMainForm; Sender: TObject);
procedure RunWorkspaceViewWheel(Form: TMainForm; Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
function RunWorkspaceEmptyViewPoint(Form: TMainForm; const P: TPointF): Boolean;
function RunWorkspaceToPage(Form: TMainForm; X,Y: Integer): TPointF;
implementation
uses Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.Imm, System.SysUtils, System.UITypes, System.Math, System.IOUtils, System.Generics.Collections, System.JSON, System.Hash, System.DateUtils, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus, Vcl.Dialogs, Vcl.Graphics, Vcl.Imaging.pngimage, ComicModel, ComicRender, ComicEditing, ComicEffects, ComicOverlayTransform
  {$IFDEF DEBUG}, ComicPerformance{$ENDIF};
type
  TComicWorkspaceViewportHelper = class helper for TMainForm
    procedure ExecuteUpdateViewport;
    procedure ExecuteResetViewport;
    procedure ExecuteBeginViewPan(Button: TMouseButton; X,Y: Integer);
    procedure ExecuteEndViewPan(Cancel: Boolean);
    procedure ExecuteViewCaptureLost(Sender: TObject);
    procedure ExecuteViewWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    function ExecuteEmptyViewPoint(const P: TPointF): Boolean;
    function ExecuteToPage(X,Y: Integer): TPointF;
  end;
procedure TComicWorkspaceViewportHelper.ExecuteUpdateViewport;
var Fit,BaseX,BaseY,DPI: Double; W,H,L,T,KeepX,KeepY,Margin: Integer;
begin
  if (FCanvas=nil) or (Page=nil) then begin FPageRect:=TRect.Empty; FScale:=1; Exit; end;
  if FViewportPageID<>Page.ID then begin
    EndViewPan(False); FViewZoom:=1; FViewPan:=TPointF.Zero; FViewportPageID:=Page.ID;
  end;
  DPI:=CurrentPPI/96; Margin:=MulDiv(24,CurrentPPI,96);
  Fit:=Min(Max(1,FCanvas.Width-2*Margin)/FProject.Width,Max(1,FCanvas.Height-2*Margin)/FProject.Height);
  FViewZoom:=EnsureRange(FViewZoom,0.1,16.0);
  W:=Max(1,Round(FProject.Width*Fit*FViewZoom)); FScale:=W/FProject.Width;
  H:=Max(1,Round(FProject.Height*FScale));
  BaseX:=(FCanvas.Width-W)/2; BaseY:=Margin;
  KeepX:=Max(1,Min(MulDiv(32,CurrentPPI,96),Min(W,FCanvas.Width)));
  KeepY:=Max(1,Min(MulDiv(32,CurrentPPI,96),Min(H,FCanvas.Height)));
  L:=EnsureRange(Round(BaseX+FViewPan.X*DPI),-W+KeepX,Max(-W+KeepX,FCanvas.Width-KeepX));
  T:=EnsureRange(Round(BaseY+FViewPan.Y*DPI),-H+KeepY,Max(-H+KeepY,FCanvas.Height-KeepY));
  FViewPan:=TPointF.Create((L-BaseX)/DPI,(T-BaseY)/DPI);
  FPageRect:=Rect(L,T,L+W,T+H);
end;

procedure RunWorkspaceUpdateViewport(Form: TMainForm);
begin Form.ExecuteUpdateViewport; end;
procedure TComicWorkspaceViewportHelper.ExecuteResetViewport;
begin
  EndViewPan(False); FViewZoom:=1; FViewPan:=TPointF.Zero; FViewportPageID:='';
  FScale:=1; FPageRect:=TRect.Empty;
  if FCanvas<>nil then FCanvas.Invalidate;
end;

procedure RunWorkspaceResetViewport(Form: TMainForm);
begin Form.ExecuteResetViewport; end;
procedure TComicWorkspaceViewportHelper.ExecuteBeginViewPan(Button: TMouseButton; X,Y: Integer);
begin
  if FDragging or FViewPanning then Exit;
  ActiveControl:=FView; UpdateViewport;
  FViewPanStart:=FViewPan; FViewPanMouse:=Point(X,Y); FViewPanButton:=Button;
  FViewPanning:=True; FViewPanMoved:=False; FCanvas.Cursor:=crSizeAll;
  if not FTesting then FCanvas.MouseCapture:=True;
end;

procedure RunWorkspaceBeginViewPan(Form: TMainForm; Button: TMouseButton; X,Y: Integer);
begin Form.ExecuteBeginViewPan(Button,X,Y); end;
procedure TComicWorkspaceViewportHelper.ExecuteEndViewPan(Cancel: Boolean);
begin
  if not FViewPanning then Exit;
  FViewPanning:=False;
  if Cancel then FViewPan:=FViewPanStart;
  FCanvas.Cursor:=crDefault; FCanvas.MouseCapture:=False;
  UpdateViewport; FCanvas.Invalidate;
end;

procedure RunWorkspaceEndViewPan(Form: TMainForm; Cancel: Boolean);
begin Form.ExecuteEndViewPan(Cancel); end;
procedure TComicWorkspaceViewportHelper.ExecuteViewCaptureLost(Sender: TObject);
begin
  FInlineSelecting:=False;
  if FViewPanning then EndViewPan(False);
  if FDragging or FPlacementDragging then CancelDrag;
end;

procedure RunWorkspaceViewCaptureLost(Form: TMainForm; Sender: TObject);
begin Form.ExecuteViewCaptureLost(Sender); end;
procedure TComicWorkspaceViewportHelper.ExecuteViewWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
{$IFDEF DEBUG}var PerfScope: TComicPerfScope;{$ENDIF}
var P: TPoint; Anchor: TPointF; Zoom,DPI: Double;
begin
  {$IFDEF DEBUG}PerfScope.Start(cpWheel);{$ENDIF}
  if (Page=nil) or (FCanvas=nil) or not FView.Visible then Exit;
  P:=FCanvas.ScreenToClient(MousePos);
  if not FCanvas.ClientRect.Contains(P) then Exit;
  Handled:=True;
  // 押下中は座標系を固定し、ホイールによって編集中の位置が飛ばないようにする。
  if FDragging or FPlacementDragging or FViewPanning or FInlineSelecting or (WheelDelta=0) then Exit;
  UpdateViewport; Anchor:=ToPage(P.X,P.Y);
  Zoom:=EnsureRange(FViewZoom*Power(1.15,EnsureRange(WheelDelta/120.0,-32.0,32.0)),0.1,16.0);
  if SameValue(Zoom,FViewZoom,1E-9) then Exit;
  FViewZoom:=Zoom; UpdateViewport; DPI:=CurrentPPI/96;
  FViewPan.Offset((P.X-FPageRect.Left-Anchor.X*FScale)/DPI,(P.Y-FPageRect.Top-Anchor.Y*FScale)/DPI);
  UpdateViewport; FCanvas.Invalidate;
  FStatus.SimpleText:=Format('表示 %.0f%% | ホイール: 拡大縮小 / 中央ドラッグ・空白の左ドラッグ: 移動 / Ctrl+0: 全体表示',[FScale*100]);
end;

procedure RunWorkspaceViewWheel(Form: TMainForm; Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin Form.ExecuteViewWheel(Sender,Shift,WheelDelta,MousePos,Handled); end;
function TComicWorkspaceViewportHelper.ExecuteEmptyViewPoint(const P: TPointF): Boolean;
{$IFDEF DEBUG}var PerfScope: TComicPerfScope;{$ENDIF}
var Balloon: TComicBalloon; Tail: TComicTail; G: HRGN; R: TRectF; Point: TPointF; Overlay: TComicOverlay;
begin
  {$IFDEF DEBUG}PerfScope.Start(cpEmptyHit);{$ENDIF}
  Result:=False;
  if not (FTool in [0,12,13]) then Exit;
  if (HitPanel(P)>=0) or (HitBalloon(P)>=0) then Exit;
  for Balloon in Page.Balloons do begin
    if FRenderer.BalloonTextBounds(Balloon).Contains(P) then Exit;
    for Tail in Balloon.Tails do begin
      G:=TailRegion(Tail,System.Types.Point(0,0),1);
      try if PtInRegion(G,Round(P.X),Round(P.Y)) then Exit; finally Winapi.Windows.DeleteObject(G); end;
    end;
  end;
  if (FPanelIndex>=0) and (FPanelIndex<Page.Panels.Count) then begin
    R:=Page.Panels[FPanelIndex].Bounds;
    if FTabs.ActivePageIndex=1 then begin
      R:=SelectedPanelBounds;
      if (Length(SelectedPanelIDs)>1) and R.Contains(P) then Exit;
      if (Length(SelectedPanelIDs)<=1) and (HitVertex(Page.Panels[FPanelIndex],P)>=0) then Exit;
    end;
    if FTabs.ActivePageIndex=2 then R:=FRenderer.ImageBounds(FProject,Page.Panels[FPanelIndex]);
    if HitHandle(R,P,MulDiv(9,CurrentPPI,96)/FScale)<>0 then Exit;
  end;
  if (FBalloonIndex>=0) and (FBalloonIndex<Page.Balloons.Count) and (FTabs.ActivePageIndex=3) then begin
    Balloon:=Page.Balloons[FBalloonIndex]; R:=Balloon.Bounds;
    if FTool=13 then R:=FRenderer.BalloonTextBounds(Balloon);
    if HitHandle(R,P,MulDiv(9,CurrentPPI,96)/FScale)<>0 then Exit;
    if (FTool=12) and (FTailIndex>=0) and (FTailIndex<Balloon.Tails.Count) then
      for Point in Balloon.Tails[FTailIndex].Handles do
        if Hypot(Point.X-P.X,Point.Y-P.Y)*FScale<=MulDiv(12,CurrentPPI,96) then Exit;
  end;
  if FTabs.ActivePageIndex=4 then begin
    Overlay:=SelectedEffect;
    if (FEffectCategory.ItemIndex=0) and (Overlay<>nil) and
      ((HitOverlayHandle(OverlayBounds(Page.Panels[FPanelIndex],Overlay),Overlay.Rotation,P,FScale,CurrentPPI)<>0) or
      OverlayContains(OverlayBounds(Page.Panels[FPanelIndex],Overlay),Overlay.Rotation,P)) then Exit;
  end;
  Result:=True;
end;


function RunWorkspaceEmptyViewPoint(Form: TMainForm; const P: TPointF): Boolean;
begin Result:=Form.ExecuteEmptyViewPoint(P); end;
function TComicWorkspaceViewportHelper.ExecuteToPage(X,Y: Integer): TPointF;
begin UpdateViewport; Result:=TPointF.Create((X-FPageRect.Left)/FScale,(Y-FPageRect.Top)/FScale); end;

function RunWorkspaceToPage(Form: TMainForm; X,Y: Integer): TPointF;
begin Result:=Form.ExecuteToPage(X,Y); end;
end.
