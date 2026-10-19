unit ComicWorkspaceInteraction;

// 責務：マウス編集の開始・途中取消・確定を扱い、1操作を1回のUndoへまとめる。
interface
uses System.Classes, MangaMakerMainForm, Vcl.Controls;
procedure RunWorkspaceMouseDown(Form: TMainForm; Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
procedure RunWorkspaceMouseMove(Form: TMainForm; Sender: TObject; Shift: TShiftState; X,Y: Integer);
procedure RunWorkspaceMouseUp(Form: TMainForm; Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
procedure RunWorkspaceCancelDrag(Form: TMainForm);
procedure RunWorkspaceDeleteObject(Form: TMainForm; Sender: TObject);
procedure RunWorkspaceAssignImage(Form: TMainForm; Sender: TObject);
procedure RunWorkspaceDragOver(Form: TMainForm; Sender,Source: TObject; X,Y: Integer; State: TDragState; var Accept: Boolean);
procedure RunWorkspaceDragDrop(Form: TMainForm; Sender,Source: TObject; X,Y: Integer);
implementation
uses Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.Imm, System.SysUtils, System.Types, System.UITypes, System.Math, System.IOUtils, System.Generics.Collections, System.JSON, System.Hash, System.DateUtils, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus, Vcl.Dialogs, Vcl.Graphics, Vcl.Imaging.pngimage, ComicModel, ComicRender, ComicEditing, ComicGeometry, ComicPanelTransform, ComicEffects, ComicImageSnap, ComicWorkspaceGeometry, ComicDialogueTransform, ComicWorkspaceEffects, ComicDragIntent
  {$IFDEF DEBUG}, ComicPerformance{$ENDIF};
type
  TComicWorkspaceInteractionHelper = class helper for TMainForm
    function ProtectObjectMove: Boolean;
    procedure CapturePanelImages;
    procedure PreserveResizedPanelImages;
    procedure UpdateBalloonCursor(const P: TPointF);
    function HitDialogue(const P: TPointF): Integer;
    procedure ExecuteMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
    procedure ExecuteMouseMove(Sender: TObject; Shift: TShiftState; X,Y: Integer);
    procedure ExecuteMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
    procedure ExecuteCancelDrag;
    procedure ExecuteDeleteObject(Sender: TObject);
    procedure ExecuteAssignImage(Sender: TObject);
    procedure ExecuteDragOver(Sender,Source: TObject; X,Y: Integer; State: TDragState; var Accept: Boolean);
    procedure ExecuteDragDrop(Sender,Source: TObject; X,Y: Integer);
  end;
function TComicWorkspaceInteractionHelper.ProtectObjectMove: Boolean;
begin
  Result:=FDragging and (FTabs.ActivePageIndex in [1,2]) and (FPanelIndex>=0) and
    (FBalloonIndex<0) and (FDragHandle=0) and (FDragVertex<0);
end;
function TComicWorkspaceInteractionHelper.HitDialogue(const P: TPointF): Integer;
var I: Integer; Balloon: TComicBalloon; Panel: TComicPanel; Visible: Boolean; Region: HRGN;
begin
  Result:=-1;
  if (Page=nil) or (P.X<0) or (P.Y<0) or (P.X>=FProject.Width) or (P.Y>=FProject.Height) then Exit;
  if (FBalloonIndex>=0) and (FBalloonIndex<Page.Balloons.Count) and
    (HitHandle(Page.Balloons[FBalloonIndex].Bounds,P,MulDiv(9,CurrentPPI,96)/Max(0.001,FScale))<>0) then Exit;
  for I:=Page.Balloons.Count-1 downto 0 do begin
    Balloon:=Page.Balloons[I]; Visible:=True;
    if not Balloon.Overflow then for Panel in Page.Panels do if Panel.ID=Balloon.PanelID then begin
      Region:=PanelRegion(Panel,Point(0,0),1);
      try Visible:=PtInRegion(Region,Round(P.X),Round(P.Y)); finally Winapi.Windows.DeleteObject(Region); end; Break;
    end;
    if not Visible then Continue;
    if FRenderer.BalloonTextBounds(Balloon).Contains(P) then Exit(I);
    // 上にある不透明な本体を越えて、背後のセリフを選択しない。
    if not Balloon.Transparent and InsideBalloonBody(Balloon,P) then Break;
  end;
end;
procedure TComicWorkspaceInteractionHelper.CapturePanelImages;
var I: Integer; Panel: TComicPanel;
begin
  for I:=0 to High(FDragGroup) do
    for Panel in Page.Panels do if Panel.ID=FDragGroup[I].ID then begin
      FDragGroup[I].ImageBounds:=FRenderer.ImageBounds(FProject,Panel); Break;
    end;
end;

procedure TComicWorkspaceInteractionHelper.PreserveResizedPanelImages;
var Item: TComicPanelTransform; Panel: TComicPanel;
begin
  // 枠だけをリサイズする。押下時の画像範囲を基準にし、反復更新で倍率・位置を累積させない。
  for Item in FDragGroup do
    for Panel in Page.Panels do if Panel.ID=Item.ID then begin
      if not Item.ImageBounds.IsEmpty then begin
        Panel.Zoom:=Item.Zoom; Panel.PanX:=Item.PanX; Panel.PanY:=Item.PanY;
        if Panel.Bounds<>Item.Bounds then PreservePanelImage(Panel,Item.ImageBounds);
      end;
      Break;
    end;
end;

procedure TComicWorkspaceInteractionHelper.UpdateBalloonCursor(const P: TPointF);
const Cursors: array[1..8] of TCursor = (crSizeNWSE,crSizeNS,crSizeNESW,crSizeWE,
  crSizeNWSE,crSizeNS,crSizeNESW,crSizeWE);
var R: TRectF; Handle: Integer;
begin
  FCanvas.Cursor:=crDefault;
  if (FTabs.ActivePageIndex<>3) or (Page=nil) or FFirst then Exit;
  if (FTool=0) and (HitDialogue(P)>=0) then begin FCanvas.Cursor:=crSizeAll; Exit; end;
  if FTool=14 then begin
    if InlineTextActive then begin
      R:=Page.Balloons[FBalloonIndex].Bounds; Handle:=HitHandle(R,P,MulDiv(9,CurrentPPI,96)/Max(0.001,FScale));
      if Handle>0 then FCanvas.Cursor:=Cursors[Handle]
      else if FRenderer.BalloonTextBounds(FInlineText.Preview).Contains(P) then FCanvas.Cursor:=crIBeam
      else if HitBalloon(P)>=0 then FCanvas.Cursor:=crSizeAll;
    end;
    Exit;
  end;
  if not (FTool in [0,13]) or (FBalloonIndex<0) or (FBalloonIndex>=Page.Balloons.Count) then Exit;
  R:=Page.Balloons[FBalloonIndex].Bounds;
  if FTool=13 then R:=FRenderer.BalloonTextBounds(Page.Balloons[FBalloonIndex]);
  // 表示の8点と同じ判定・優先順位を使い、実際に押下できる位置でカーソルを変える。
  Handle:=HitHandle(R,P,MulDiv(9,CurrentPPI,96)/Max(0.001,FScale));
  if FTool=13 then Handle:=HitDialogueHandle(R,P,FScale,CurrentPPI);
  if FDragging then Handle:=FDragHandle;
  if Handle>0 then FCanvas.Cursor:=Cursors[Handle]
  else if FDragging or ((FTool=0) and (HitBalloon(P)=FBalloonIndex)) or
    ((FTool=13) and R.Contains(P)) then FCanvas.Cursor:=crSizeAll;
end;

procedure TComicWorkspaceInteractionHelper.ExecuteMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
{$IFDEF DEBUG}var PerfScope: TComicPerfScope;{$ENDIF}
var P: TPointF; R,Selected: TRectF; Panel: TComicPanel; Balloon: TComicBalloon; Handle: Integer; GroupMove: Boolean;
begin
  {$IFDEF DEBUG}PerfScope.Start(cpMouseDown);{$ENDIF}
  // ダブルクリック後の押下通知でドラッグを再開し、文字入力のフォーカスを奪わないようにする。
  if ssDouble in Shift then Exit;
  if Page=nil then Exit;
  // 吹き出し編集では所属コマの当たり判定だけを使い、コマ選択を持ち越さない。
  if FTabs.ActivePageIndex=3 then begin FPanelIndex:=-1; FSelectedPanels.Clear; end;
  FImageSnap:=Default(TComicImageSnap);
  FDialogueSnap:=Default(TComicDialogueSnap); FDialogueJustSelected:=False;
  if Button=mbMiddle then begin BeginViewPan(Button,X,Y); Exit; end;
  if FViewPanning then Exit;
  if (Button=mbRight) and (FTool=0) and (FTabs.ActivePageIndex=1) then begin
    if Length(SelectedPanelIDs)>1 then begin FStatus.SimpleText:='頂点を編集するコマを1つ選択してください。'; Exit; end;
    CancelDrag; EditVertexContext(ToPage(X,Y)); Exit;
  end;
  if (Button=mbRight) and (FTool in [8,9]) then begin
    if (FTool=8) and (FGeometryPoints.Count>0) then FGeometryPoints.Delete(FGeometryPoints.Count-1);
    if (FTool=9) and (FSplitStage>0) then Dec(FSplitStage);
    FCanvas.Invalidate; FStatus.SimpleText:='直前の指定へ戻りました。Escで全体を中止できます。'; Exit;
  end;
  if Button<>mbLeft then Exit; P:=ToPage(X,Y);
  if (FTabs.ActivePageIndex=3) and (FTool=14) then begin
    R:=TRectF.Empty;
    if InlineTextActive then begin R:=FRenderer.BalloonTextBounds(FInlineText.Preview); R.Inflate(MulDiv(3,CurrentPPI,96)/FScale,MulDiv(3,CurrentPPI,96)/FScale); end;
    if InlineTextActive and R.Contains(P) and
      (HitHandle(Page.Balloons[FBalloonIndex].Bounds,P,MulDiv(9,CurrentPPI,96)/FScale)=0) then begin
      FInlineText.PlaceCaret(P,ssShift in Shift); FInlineText.FocusInput;
      FInlineSelecting:=True; if not FTesting then FCanvas.MouseCapture:=True; Exit;
    end;
    // 文字の外側にある本体・枠を押した場合は、入力を確定して本体選択へ渡す。
    FinishInlineText(True); FTool:=0;
  end;
  FDragMouse:=Point(X,Y); FDragStartedTick:=GetTickCount64;
  if not FDragging and not (ssCtrl in Shift) and EmptyViewPoint(P) then begin BeginViewPan(Button,X,Y); Exit; end;
  ActiveControl:=FView;
  if FTabs.ActivePageIndex=4 then begin RunWorkspaceEffectMouseDown(Self,P); Exit; end;
  if FTool=12 then begin TailEditClick(P); Exit; end;
  if (FTool=0) and (FTabs.ActivePageIndex=3) then begin
    Handle:=HitDialogue(P);
    if Handle>=0 then begin
      FBalloonIndex:=Handle; LoadBalloonControls(Page.Balloons[Handle]);
      FTool:=13; FTextToolVertical:=Page.Balloons[Handle].Vertical; FDialogueJustSelected:=True;
    end;
  end;
  if FTool=13 then begin
    if (FBalloonIndex<0) or (FBalloonIndex>=Page.Balloons.Count) then FBalloonIndex:=HitBalloon(P);
    if FBalloonIndex>=0 then begin
      Balloon:=Page.Balloons[FBalloonIndex]; FDragBounds:=FRenderer.BalloonTextBounds(Balloon);
      if (Balloon.Text='') and (HitBalloon(P)=FBalloonIndex) then begin BeginTextInput(nil); Exit; end;
      FDragHandle:=HitDialogueHandle(FDragBounds,P,FScale,CurrentPPI);
      if FDialogueJustSelected then FDragHandle:=0;
      if (FDragHandle<>0) or FDragBounds.Contains(P) then begin
        FDragSnapshot:=FProject.Snapshot;
        FDragBalloonTransform:=Balloon.CaptureTransform;
        FStart:=P; FLast:=P; FDragMoved:=False; FDragging:=True; FDragTailHandle:=0;
        if not FTesting then FCanvas.MouseCapture:=True; UpdateIconState; FCanvas.Invalidate; Exit;
      end;
    end;
    FTool:=0;
  end;
  if (FTool=0) and (FTabs.ActivePageIndex=1) and (ssCtrl in Shift) then begin
    CancelDrag; TogglePanelSelection(HitPanel(P)); Exit;
  end;
  FDragGroup:=nil;
  Handle:=0; FDragVertex:=-1; Selected:=TRectF.Empty; GroupMove:=False;
  if FTool=0 then begin
    if (FTabs.ActivePageIndex=3) and (FBalloonIndex>=0) and (FBalloonIndex<Page.Balloons.Count) then
      Selected:=Page.Balloons[FBalloonIndex].Bounds
    else if (FTabs.ActivePageIndex in [1,2]) and (FPanelIndex>=0) and (FPanelIndex<Page.Panels.Count) then begin
      Selected:=Page.Panels[FPanelIndex].Bounds;
      if FTabs.ActivePageIndex=1 then Selected:=SelectedPanelBounds;
      if FTabs.ActivePageIndex=2 then Selected:=FRenderer.ImageBounds(FProject,Page.Panels[FPanelIndex]);
    end;
    Handle:=HitHandle(Selected,P,MulDiv(9,CurrentPPI,96)/FScale);
    GroupMove:=(FTabs.ActivePageIndex=1) and (Length(SelectedPanelIDs)>1) and Selected.Contains(P) and (HitPanel(P)<0);
    if (Handle=0) and (FTabs.ActivePageIndex=1) and (FPanelIndex>=0) and (FPanelIndex<Page.Panels.Count) and (Length(SelectedPanelIDs)<=1) then
      FDragVertex:=HitVertex(Page.Panels[FPanelIndex],P);
  end;
  if (Handle=0) and not FPageRect.Contains(Point(X,Y)) and not (FTool in [8,9]) then Exit;
  if FTool=9 then begin SplitClick(P); Exit; end;
  if FTool=8 then begin
    if not (ssAlt in Shift) then P:=SnapCreationPoint(P); PolygonClick(P); Exit;
  end;
  if FTool in [1,2,3,5,6,7,10,11] then begin RunWorkspacePlacementDown(Self,P,Shift); Exit; end;
  if FTool=4 then begin
    FPanelIndex:=HitPanel(P); if FPanelIndex>=0 then begin Checkpoint; Page.Panels[FPanelIndex].Number:=FNumber; Inc(FNumber); Changed; end;
    UpdateIconState; FCanvas.Invalidate; Exit;
  end;
  if (Handle=0) and (FDragVertex<0) and not GroupMove then begin
    FBalloonIndex:=-1; if FTabs.ActivePageIndex=3 then FBalloonIndex:=HitBalloon(P);
    FPanelIndex:=-1; if FTabs.ActivePageIndex in [1,2] then FPanelIndex:=HitPanel(P);
    if (FTabs.ActivePageIndex=1) and ((FPanelIndex<0) or not FSelectedPanels.Contains(Page.Panels[FPanelIndex].ID)) then begin
      FSelectedPanels.Clear; if FPanelIndex>=0 then FSelectedPanels.Add(Page.Panels[FPanelIndex].ID);
    end;
  end;
  if FBalloonIndex>=0 then begin
    Balloon:=Page.Balloons[FBalloonIndex]; FDragBounds:=Balloon.Bounds; LoadBalloonControls(Balloon);
    FDragBalloonTransform:=Balloon.CaptureTransform;
  end else if (FTabs.ActivePageIndex in [1,2]) and (FPanelIndex>=0) then begin
    Panel:=Page.Panels[FPanelIndex]; FDragBounds:=Panel.Bounds; FDragZoom:=Panel.Zoom;
    FDragVertices:=Copy(Panel.Vertices,0,Length(Panel.Vertices));
    if FTabs.ActivePageIndex=1 then begin
      FDragGroup:=CapturePanelTransforms(Page,SelectedPanelIDs); CapturePanelImages;
      if Length(FDragGroup)>1 then begin FDragBounds:=PanelGroupBounds(FDragGroup); FDragVertices:=nil; end;
    end;
    if FDragVertex>=0 then begin FDragVertices:=Panel.Outline; FDragImageBounds:=FRenderer.ImageBounds(FProject,Panel); end;
    if FTabs.ActivePageIndex=2 then begin
      FDragBounds:=FRenderer.ImageBounds(FProject,Panel);
      if FDragBounds.IsEmpty then begin UpdateIconState; FCanvas.Invalidate; Exit; end;
    end;
  end else begin UpdateIconState; FCanvas.Invalidate; Exit; end;
  FDragSnapshot:=FProject.Snapshot; FDragMoved:=False; FDragging:=True;
  if not FTesting then FCanvas.MouseCapture:=True;
  FStart:=P; FLast:=P;
  FDragHandle:=HitHandle(FDragBounds,P,MulDiv(9,CurrentPPI,96)/FScale);
  UpdateIconState; FCanvas.Invalidate;
end;

procedure RunWorkspaceMouseDown(Form: TMainForm; Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
begin Form.ExecuteMouseDown(Sender,Button,Shift,X,Y); end;
procedure TComicWorkspaceInteractionHelper.ExecuteMouseMove(Sender: TObject; Shift: TShiftState; X,Y: Integer);
{$IFDEF DEBUG}var PerfScope: TComicPerfScope;{$ENDIF}
var P,Delta,Q: TPointF; R: TRectF; Panel: TComicPanel; Candidate: TArray<TPointF>; I: Integer;
  Tail,Probe: TComicTail; TailLength: Double;
begin
  {$IFDEF DEBUG}PerfScope.Start(cpMouseMove);{$ENDIF}
  if FInlineSelecting and InlineTextActive then begin
    if ssLeft in Shift then FInlineText.PlaceCaret(ToPage(X,Y),True)
    else begin FInlineSelecting:=False; FCanvas.MouseCapture:=False; end;
    Exit;
  end;
  if FViewPanning then begin
    if (Page=nil) or ((FViewPanButton=mbMiddle) and not (ssMiddle in Shift)) or
      ((FViewPanButton=mbLeft) and not (ssLeft in Shift)) then begin EndViewPan(False); Exit; end;
    if not FViewPanMoved and (Abs(X-FViewPanMouse.X)+Abs(Y-FViewPanMouse.Y)<MulDiv(3,CurrentPPI,96)) then Exit;
    FViewPanMoved:=True;
    FViewPan:=TPointF.Create(FViewPanStart.X+(X-FViewPanMouse.X)*96/CurrentPPI,
      FViewPanStart.Y+(Y-FViewPanMouse.Y)*96/CurrentPPI);
    UpdateViewport; FCanvas.Invalidate; Exit;
  end;
  if Page=nil then begin FCanvas.Cursor:=crDefault; Exit; end;
  if FPlacementDragging and not (ssLeft in Shift) then begin CancelDrag; Exit; end;
  P:=ToPage(X,Y); UpdateBalloonCursor(P); RunWorkspaceUpdateEffectCursor(Self,P);
  if not FDragging then begin
    if FFirst or (FGeometryPoints.Count>0) or (FSplitStage>0) then begin
      if (FTool in [1,2,3,8]) and not (ssAlt in Shift) then P:=SnapCreationPoint(P);
      FLast:=P; FCanvas.Invalidate;
    end;
    Exit;
  end;
  if not (ssLeft in Shift) then begin CancelDrag; Exit; end;
  if (FTabs.ActivePageIndex=3) and (FBalloonIndex<0) then Exit;
  Delta:=TPointF.Create(P.X-FStart.X,P.Y-FStart.Y);
  FImageSnap:=Default(TComicImageSnap);
  FDialogueSnap:=Default(TComicDialogueSnap);
  // 移動閾値は整数画面座標で測り、Singleの丸めで1画素の移動を見落とさないようにする。
  if not FDragMoved and (X=FDragMouse.X) and (Y=FDragMouse.Y) then Exit;
  // コマと画像の移動だけを保護する。拡縮・頂点・しっぽ・文字・素材回転の微調整は即時に扱う。
  if ProtectObjectMove and not FDragMoved and
    not ObjectMoveReady(FDragMouse,Point(X,Y),GetTickCount64-FDragStartedTick,CurrentPPI) then Exit;
  FDragMoved:=True; R:=FDragBounds;
  if FTabs.ActivePageIndex=4 then begin RunWorkspaceMoveEffect(Self,P,Shift); Exit; end;
  if (FTool=13) and (FBalloonIndex>=0) then begin
    if (FDragHandle=0) and FSnap.Checked and not (ssAlt in Shift) then begin
      R.Offset(Delta.X,Delta.Y);
      FDialogueSnap:=SnapDialogueCenter(R,Page.Balloons[FBalloonIndex].Bounds,WorkspaceSnapTolerance(Self));
      Delta.Offset(FDialogueSnap.Bounds.Left-R.Left,FDialogueSnap.Bounds.Top-R.Top);
    end;
    if TransformDialogue(Page.Balloons[FBalloonIndex],FRenderer,FDragBalloonTransform,FDragBounds,Delta,FDragHandle) then begin
      FLast:=P; FCanvas.Invalidate;
    end;
    Exit;
  end;
  if (FDragTailHandle>0) and (FBalloonIndex>=0) and (FTailIndex>=0) then begin
    Tail:=Page.Balloons[FBalloonIndex].Tails[FTailIndex]; Probe:=TComicTail.Create;
    try
      Probe.Root:=FDragTailState.Root; Probe.Tip:=FDragTailState.Tip; Probe.Width:=FDragTailState.Width;
      case FDragTailHandle of
        1: begin Probe.Root.Offset(Delta.X,Delta.Y); if not InsideBalloonBody(Page.Balloons[FBalloonIndex],Probe.Root) then Exit; end;
        2: begin
          Q:=TPointF.Create(Probe.Tip.X-Probe.Root.X,Probe.Tip.Y-Probe.Root.Y); TailLength:=Max(1,Hypot(Q.X,Q.Y));
          Probe.Width:=EnsureRange(Abs(FDragTailState.Width/2+(-Q.Y*Delta.X+Q.X*Delta.Y)/TailLength)*2,1.0,2000.0);
        end;
        3: Probe.Tip.Offset(Delta.X,Delta.Y);
      end;
      if not Probe.Valid then Exit;
      Tail.Root:=Probe.Root; Tail.Tip:=Probe.Tip; Tail.Width:=Probe.Width;
    finally Probe.Free; end;
    FLast:=P; FCanvas.Invalidate; Exit;
  end;
  if Length(FDragGroup)>1 then begin
    if FDragHandle<>0 then R:=ResizePanelGroup(FDragGroup,FDragBounds,Delta,FDragHandle) else R.Offset(Delta.X,Delta.Y);
    if not (ssAlt in Shift) then R:=SnapPanelDragBounds(R);
    if not ApplyPanelGroupTransform(Page,FDragGroup,FDragBounds,R) then begin
      FStatus.SimpleText:='複数選択の変形で無効なコマが生じるため、直前の有効形状を維持します。'; Exit;
    end;
    if FDragHandle<>0 then PreserveResizedPanelImages;
    FLast:=P; FCanvas.Invalidate; Exit;
  end;
  if (FDragVertex>=0) and (FPanelIndex>=0) then begin
    Candidate:=Copy(FDragVertices,0,Length(FDragVertices));
    Candidate[FDragVertex]:=TPointF.Create(FDragVertices[FDragVertex].X+Delta.X,FDragVertices[FDragVertex].Y+Delta.Y);
    if not (ssAlt in Shift) then Candidate[FDragVertex]:=SnapCreationPoint(Candidate[FDragVertex],Page.Panels[FPanelIndex].ID);
    if not ValidPolygon(Candidate) then begin FStatus.SimpleText:='交差やゼロ面積になる頂点移動は確定できません。'; Exit; end;
    Panel:=Page.Panels[FPanelIndex]; Panel.SetVertices(Candidate); PreservePanelImage(Panel,FDragImageBounds);
    FLast:=P; FCanvas.Invalidate; Exit;
  end;
  if (FTabs.ActivePageIndex=2) and (FPanelIndex>=0) then begin
    Panel:=Page.Panels[FPanelIndex];
    if FDragHandle<>0 then R:=ResizeImageRect(FDragBounds,Delta,FDragHandle,0.1/Max(0.1,FDragZoom))
    else R.Offset(Delta.X,Delta.Y);
    if FSnap.Checked and not (ssAlt in Shift) then begin
      FImageSnap:=SnapImageBounds(FDragBounds,R,Panel.Bounds,FDragHandle,WorkspaceSnapTolerance(Self),0.1/Max(0.1,FDragZoom));
      R:=FImageSnap.Bounds;
    end;
    Panel.Zoom:=FDragZoom*R.Width/FDragBounds.Width;
    Panel.PanX:=(R.Left+R.Right-Panel.Bounds.Left-Panel.Bounds.Right)/2;
    Panel.PanY:=(R.Top+R.Bottom-Panel.Bounds.Top-Panel.Bounds.Bottom)/2;
  end else begin
    if FDragHandle<>0 then R:=ResizeRect(FDragBounds,Delta,FDragHandle,30)
    else R.Offset(Delta.X,Delta.Y);
    if (FTabs.ActivePageIndex=1) and (FBalloonIndex<0) and (FPanelIndex>=0) and not (ssAlt in Shift) then R:=SnapPanelDragBounds(R);
    if FBalloonIndex>=0 then begin
      if not Page.Balloons[FBalloonIndex].ApplyTransform(FDragBalloonTransform,R,ssCtrl in Shift) then begin
        FStatus.SimpleText:='本体としっぽの有効な形状を維持できない変形は確定できません。'; Exit;
      end;
    end else if (FTabs.ActivePageIndex=1) and (FPanelIndex>=0) then begin
      Panel:=Page.Panels[FPanelIndex];
      if Length(FDragVertices)>0 then begin
        SetLength(Candidate,Length(FDragVertices));
        for I:=0 to High(Candidate) do Candidate[I]:=TPointF.Create(
          R.Left+(FDragVertices[I].X-FDragBounds.Left)*R.Width/FDragBounds.Width,
          R.Top+(FDragVertices[I].Y-FDragBounds.Top)*R.Height/FDragBounds.Height);
        if not ValidPolygon(Candidate) then begin
          FStatus.SimpleText:='縮小後の多角形が小さすぎるため、直前の有効な形を維持します。'; Exit;
        end;
        Panel.SetVertices(Candidate);
      end else Panel.SetBounds(R);
      if (FTabs.ActivePageIndex=1) and (FDragHandle<>0) then PreserveResizedPanelImages;
    end;
  end;
  FLast:=P; FCanvas.Invalidate;
end;

procedure RunWorkspaceMouseMove(Form: TMainForm; Sender: TObject; Shift: TShiftState; X,Y: Integer);
begin Form.ExecuteMouseMove(Sender,Shift,X,Y); end;
procedure TComicWorkspaceInteractionHelper.ExecuteMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
{$IFDEF DEBUG}var PerfScope: TComicPerfScope;{$ENDIF}
begin
  {$IFDEF DEBUG}PerfScope.Start(cpMouseUp);{$ENDIF}
  if FPlacementDragging and (Button=mbLeft) then begin RunWorkspacePlacementUp(Self,ToPage(X,Y),Shift); Exit; end;
  if FInlineSelecting and (Button=mbLeft) then begin
    FInlineSelecting:=False; FCanvas.MouseCapture:=False; Exit;
  end;
  if FViewPanning then begin
    if Button<>FViewPanButton then Exit;
    EndViewPan(False);
    if (Button=mbLeft) and not FViewPanMoved and (FTool in [0,13]) and FPageRect.Contains(Point(X,Y)) then begin
      FSelectedPanels.Clear; FPanelIndex:=-1; FBalloonIndex:=-1; FEffectIndex:=-1;
      FTool:=0;
      UpdateIconState; FCanvas.Invalidate;
    end;
    Exit;
  end;
  if not FDragging or (Button<>mbLeft) then Exit;
  // 短く動かした後に長押しした場合や、最終MouseMoveが省略された場合も離した位置で判定する。
  if ProtectObjectMove and (not FDragMoved or (FLast<>ToPage(X,Y))) then
    ExecuteMouseMove(Sender,Shift+[ssLeft],X,Y);
  if (FTool=13) and (FDragHandle=0) and not FDragMoved then begin
    FDragging:=False; FCanvas.MouseCapture:=False; FDragSnapshot:='';
    if FDialogueJustSelected then begin FDialogueJustSelected:=False; Exit; end;
    BeginTextInput(nil); FInlineText.PlaceCaret(ToPage(X,Y),ssShift in Shift); Exit;
  end;
  FImageSnap:=Default(TComicImageSnap); FDialogueSnap:=Default(TComicDialogueSnap); FDialogueJustSelected:=False; FCanvas.Invalidate;
  FDragging:=False; FCanvas.MouseCapture:=False;
  if FDragMoved and (FProject.Snapshot<>FDragSnapshot) then begin
    if (FBalloonIndex>=0) and (FDragTailHandle=0) then LoadBalloonControls(Page.Balloons[FBalloonIndex]);
    FUndo.Add(FDragSnapshot); FRedo.Clear; if FUndo.Count>40 then FUndo.Delete(0); Changed;
  end;
  FDragSnapshot:=''; FDragMoved:=False;
  FDragVertex:=-1;
  FDragTailHandle:=0;
  FDragGroup:=nil;
end;

procedure RunWorkspaceMouseUp(Form: TMainForm; Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
begin Form.ExecuteMouseUp(Sender,Button,Shift,X,Y); end;
procedure TComicWorkspaceInteractionHelper.ExecuteCancelDrag;
begin
  FinishInlineText(True);
  if FPlacementDragging then begin FPlacementDragging:=False; FFirst:=False; FCanvas.MouseCapture:=False; end;
  // 未確定の変形は押下時へ戻す。取消を新たな編集履歴として積まず、途中の座標を保存しない。
  EndViewPan(True);
  FCanvas.Cursor:=crDefault;
  FImageSnap:=Default(TComicImageSnap); FDialogueSnap:=Default(TComicDialogueSnap); FDialogueJustSelected:=False; FCanvas.Invalidate;
  if not FDragging then Exit;
  FDragging:=False; FCanvas.MouseCapture:=False;
  FDragVertex:=-1;
  FDragTailHandle:=0;
  if FDragMoved then begin FProject.Restore(FDragSnapshot); RefreshUI; end;
  FDragMoved:=False; FDragSnapshot:=''; FCanvas.Invalidate;
  FDragGroup:=nil;
end;

procedure RunWorkspaceCancelDrag(Form: TMainForm);
begin Form.ExecuteCancelDrag; end;
procedure TComicWorkspaceInteractionHelper.ExecuteDeleteObject(Sender: TObject);
var I: Integer; UID: string; IDs: TArray<string>;
begin
  if Page=nil then Exit;
  if (Sender<>nil) and (TControl(Sender).Tag=1) then begin
    if FBalloonIndex<0 then Exit; Checkpoint; Page.Balloons.Delete(FBalloonIndex); FBalloonIndex:=-1;
  end else begin
    if FTabs.ActivePageIndex=3 then Exit;
    IDs:=SelectedPanelIDs; if Length(IDs)=0 then Exit; Checkpoint;
    for I:=Page.Balloons.Count-1 downto 0 do for UID in IDs do if Page.Balloons[I].PanelID=UID then begin Page.Balloons.Delete(I); Break; end;
    for I:=Page.Panels.Count-1 downto 0 do for UID in IDs do if Page.Panels[I].ID=UID then begin Page.Panels.Delete(I); Break; end;
    FSelectedPanels.Clear; FPanelIndex:=-1; FBalloonIndex:=-1;
  end; Changed;
end;

procedure RunWorkspaceDeleteObject(Form: TMainForm; Sender: TObject);
begin Form.ExecuteDeleteObject(Sender); end;
procedure TComicWorkspaceInteractionHelper.ExecuteAssignImage(Sender: TObject);
var A: TComicAsset; P: TComicPanel;
begin
  // 割当変更を1回のUndoへまとめる。旧画像は素材一覧に残し、参照だけを置き換える。
  if (Page=nil) or (FPanelIndex<0) or (FImages.ItemIndex<0) then Exit;
  Checkpoint; A:=TComicAsset(FImages.Items.Objects[FImages.ItemIndex]); P:=Page.Panels[FPanelIndex];
  P.ImageID:=A.ID; P.Zoom:=1; P.PanX:=0; P.PanY:=0; Changed;
end;

procedure RunWorkspaceAssignImage(Form: TMainForm; Sender: TObject);
begin Form.ExecuteAssignImage(Sender); end;
procedure TComicWorkspaceInteractionHelper.ExecuteDragOver(Sender,Source: TObject; X,Y: Integer; State: TDragState; var Accept: Boolean);
begin
  Accept:=(Page<>nil) and FPageRect.Contains(Point(X,Y)) and
    (((Source=FImages) and (FTabs.ActivePageIndex<>3) and (FImages.ItemIndex>=0) and (HitPanel(ToPage(X,Y))>=0)) or
     ((Source=FLayoutList) and (FLayoutList.ItemIndex>=0)) or
     ((Source=FEffectList) and (FEffectList.ItemIndex>=0) and (FTabs.ActivePageIndex=4) and (FEffectCategory.ItemIndex=0) and (HitPanel(ToPage(X,Y))>=0)));
end;

procedure RunWorkspaceDragOver(Form: TMainForm; Sender,Source: TObject; X,Y: Integer; State: TDragState; var Accept: Boolean);
begin Form.ExecuteDragOver(Sender,Source,X,Y,State,Accept); end;
procedure TComicWorkspaceInteractionHelper.ExecuteDragDrop(Sender,Source: TObject; X,Y: Integer);
begin
  if (Page=nil) or not FPageRect.Contains(Point(X,Y)) then Exit;
  if Source=FLayoutList then begin Template(nil); Exit; end;
  if Source=FEffectList then begin
    if (FTabs.ActivePageIndex=4) and (FEffectCategory.ItemIndex=0) and (FEffectList.ItemIndex>=0) then
      ApplyEffectMaterial(HitPanel(ToPage(X,Y)),TComicEffectMaterial(FEffectList.Items.Objects[FEffectList.ItemIndex])); Exit;
  end;
  if (Source<>FImages) or (FTabs.ActivePageIndex=3) or (FImages.ItemIndex<0) or (HitPanel(ToPage(X,Y))<0) then Exit;
  CancelDrag; SelectSinglePanel(HitPanel(ToPage(X,Y))); AssignImage(nil); ActiveControl:=FView;
end;

procedure RunWorkspaceDragDrop(Form: TMainForm; Sender,Source: TObject; X,Y: Integer);
begin Form.ExecuteDragDrop(Sender,Source,X,Y); end;
end.
