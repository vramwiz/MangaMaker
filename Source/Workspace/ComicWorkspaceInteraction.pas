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
uses Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.Imm, System.SysUtils, System.Types, System.UITypes, System.Math, System.IOUtils, System.Generics.Collections, System.JSON, System.Hash, System.DateUtils, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus, Vcl.Dialogs, Vcl.Graphics, Vcl.Imaging.pngimage, ComicModel, ComicEditing, ComicGeometry, ComicPanelTransform, ComicEffects
  {$IFDEF DEBUG}, ComicPerformance{$ENDIF};
type
  TComicWorkspaceInteractionHelper = class helper for TMainForm
    procedure ExecuteMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
    procedure ExecuteMouseMove(Sender: TObject; Shift: TShiftState; X,Y: Integer);
    procedure ExecuteMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
    procedure ExecuteCancelDrag;
    procedure ExecuteDeleteObject(Sender: TObject);
    procedure ExecuteAssignImage(Sender: TObject);
    procedure ExecuteDragOver(Sender,Source: TObject; X,Y: Integer; State: TDragState; var Accept: Boolean);
    procedure ExecuteDragDrop(Sender,Source: TObject; X,Y: Integer);
  end;
procedure TComicWorkspaceInteractionHelper.ExecuteMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
{$IFDEF DEBUG}var PerfScope: TComicPerfScope;{$ENDIF}
var P: TPointF; R,Selected: TRectF; Panel: TComicPanel; Balloon: TComicBalloon; Handle: Integer; GroupMove: Boolean; Overlay: TComicOverlay;
begin
  {$IFDEF DEBUG}PerfScope.Start(cpMouseDown);{$ENDIF}
  // ダブルクリック後の押下通知でドラッグを再開し、文字入力のフォーカスを奪わないようにする。
  if ssDouble in Shift then Exit;
  if Page=nil then Exit;
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
  FDragMouse:=Point(X,Y);
  if not FDragging and not (ssCtrl in Shift) and EmptyViewPoint(P) then begin BeginViewPan(Button,X,Y); Exit; end;
  ActiveControl:=FView;
  if FTabs.ActivePageIndex=4 then begin
    Overlay:=SelectedEffect; Handle:=0; R:=TRectF.Empty;
    if (FEffectCategory.ItemIndex=0) and (Overlay<>nil) then begin R:=OverlayBounds(Page.Panels[FPanelIndex],Overlay); Handle:=HitHandle(R,P,9/FScale); end;
    if (FEffectCategory.ItemIndex<>0) or ((Handle=0) and not R.Contains(P)) then begin
      FPanelIndex:=HitPanel(P); FEffectIndex:=-1;
      if (FPanelIndex>=0) and (FEffectCategory.ItemIndex=0) then FEffectIndex:=HitEffect(Page.Panels[FPanelIndex],P);
    end;
    FBalloonIndex:=-1; LoadPanelEffectControls; UpdateIconState; FCanvas.Invalidate;
    Overlay:=SelectedEffect; if Overlay=nil then Exit;
    FDragBounds:=OverlayBounds(Page.Panels[FPanelIndex],Overlay); FDragHandle:=HitHandle(FDragBounds,P,9/FScale);
    FDragSnapshot:=FProject.Snapshot; FDragMoved:=False; FDragging:=True; FStart:=P; FLast:=P; FDragVertex:=-1; FDragTailHandle:=0;
    if not FTesting then FCanvas.MouseCapture:=True; Exit;
  end;
  if FTool=12 then begin TailEditClick(P); Exit; end;
  if FTool=13 then begin
    if (FBalloonIndex<0) or (FBalloonIndex>=Page.Balloons.Count) then Exit; Balloon:=Page.Balloons[FBalloonIndex];
    FDragBounds:=FRenderer.BalloonTextBounds(Balloon); if FDragBounds.IsEmpty then Exit;
    FDragHandle:=HitHandle(FDragBounds,P,9/FScale); if (FDragHandle=0) and not FDragBounds.Contains(P) then Exit;
    FDragTextOffset:=Balloon.TextOffset; FDragFontSize:=Balloon.FontSize; FDragSnapshot:=FProject.Snapshot;
    FDragBalloonTransform:=Balloon.CaptureTransform;
    FStart:=P; FLast:=P; FDragMoved:=False; FDragging:=True; FDragTailHandle:=0;
    if not FTesting then FCanvas.MouseCapture:=True; UpdateIconState; FCanvas.Invalidate; Exit;
  end;
  if (FTool=0) and (FTabs.ActivePageIndex=1) and (ssCtrl in Shift) then begin
    CancelDrag; TogglePanelSelection(HitPanel(P)); Exit;
  end;
  FDragGroup:=nil;
  Handle:=0; FDragVertex:=-1; Selected:=TRectF.Empty; GroupMove:=False;
  if FTool=0 then begin
    if (FTabs.ActivePageIndex=3) and (FBalloonIndex>=0) and (FBalloonIndex<Page.Balloons.Count) then
      Selected:=Page.Balloons[FBalloonIndex].Bounds
    else if (FPanelIndex>=0) and (FPanelIndex<Page.Panels.Count) then begin
      Selected:=Page.Panels[FPanelIndex].Bounds;
      if FTabs.ActivePageIndex=1 then Selected:=SelectedPanelBounds;
      if FTabs.ActivePageIndex=2 then Selected:=FRenderer.ImageBounds(FProject,Page.Panels[FPanelIndex]);
    end;
    Handle:=HitHandle(Selected,P,9/FScale);
    GroupMove:=(FTabs.ActivePageIndex=1) and (Length(SelectedPanelIDs)>1) and Selected.Contains(P) and (HitPanel(P)<0);
    if (Handle=0) and (FTabs.ActivePageIndex=1) and (FPanelIndex>=0) and (FPanelIndex<Page.Panels.Count) and (Length(SelectedPanelIDs)<=1) then
      FDragVertex:=HitVertex(Page.Panels[FPanelIndex],P);
  end;
  if (Handle=0) and not FPageRect.Contains(Point(X,Y)) and not (FTool in [8,9]) then Exit;
  if FTool=9 then begin SplitClick(P); Exit; end;
  if FTool=8 then begin
    if FImages.Count=0 then Exit;
    if not (ssAlt in Shift) then P:=SnapCreationPoint(P); PolygonClick(P); Exit;
  end;
  if FTool in [7,11] then begin TailClick(P); Exit; end;
  if FTool in [1,2,3,5,6,10] then begin
    if FImages.Count=0 then begin Notify('画像管理で画像を登録してください。'); Exit; end;
    if (FTool in [1,2,3]) and not (ssAlt in Shift) then P:=SnapCreationPoint(P);
    if not FFirst then begin FStart:=P; FLast:=P; FFirst:=True; FStatus.SimpleText:='2点目をクリックしてください。'; FCanvas.Invalidate; Exit; end;
    R:=TRectF.Create(Min(P.X,FStart.X),Min(P.Y,FStart.Y),Max(P.X,FStart.X),Max(P.Y,FStart.Y));
    if (R.Width<30) or (R.Height<30) then Exit; Checkpoint; FFirst:=False;
    if FTool<5 then begin Panel:=TComicPanel.Create; Panel.Bounds:=R; Panel.Shape:=FTool-1; Panel.Number:=Page.Panels.Count+1;
      Page.Panels.Add(Panel); SelectSinglePanel(Page.Panels.Count-1); end
    else begin Balloon:=TComicBalloon.Create; Balloon.Bounds:=R; Balloon.Contour:=TComicBalloonContour(Max(0,FContour.ItemIndex));
      if FTool=10 then Balloon.Shape:=0 else Balloon.Shape:=FTool-4;
      FPanelIndex:=HitPanel(FStart); if FPanelIndex>=0 then Balloon.PanelID:=Page.Panels[FPanelIndex].ID;
      Page.Balloons.Add(Balloon); FBalloonIndex:=Page.Balloons.Count-1; LoadBalloonControls(Balloon); end;
    Changed; Exit;
  end;
  if FTool=4 then begin
    FPanelIndex:=HitPanel(P); if FPanelIndex>=0 then begin Checkpoint; Page.Panels[FPanelIndex].Number:=FNumber; Inc(FNumber); Changed; end;
    UpdateIconState; FCanvas.Invalidate; Exit;
  end;
  if (Handle=0) and (FDragVertex<0) and not GroupMove then begin
    FBalloonIndex:=-1; if FTabs.ActivePageIndex=3 then FBalloonIndex:=HitBalloon(P);
    FPanelIndex:=HitPanel(P);
    if (FTabs.ActivePageIndex=1) and ((FPanelIndex<0) or not FSelectedPanels.Contains(Page.Panels[FPanelIndex].ID)) then begin
      FSelectedPanels.Clear; if FPanelIndex>=0 then FSelectedPanels.Add(Page.Panels[FPanelIndex].ID);
    end;
  end;
  if FBalloonIndex>=0 then begin
    Balloon:=Page.Balloons[FBalloonIndex]; FDragBounds:=Balloon.Bounds; LoadBalloonControls(Balloon);
    FDragBalloonTransform:=Balloon.CaptureTransform;
  end else if FPanelIndex>=0 then begin
    Panel:=Page.Panels[FPanelIndex]; FDragBounds:=Panel.Bounds; FDragZoom:=Panel.Zoom;
    FDragVertices:=Copy(Panel.Vertices,0,Length(Panel.Vertices));
    if (FTabs.ActivePageIndex=1) and (Length(SelectedPanelIDs)>1) then begin
      FDragGroup:=CapturePanelTransforms(Page,SelectedPanelIDs); FDragBounds:=PanelGroupBounds(FDragGroup); FDragVertices:=nil;
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
  FDragHandle:=HitHandle(FDragBounds,P,9/FScale);
  UpdateIconState; FCanvas.Invalidate;
end;

procedure RunWorkspaceMouseDown(Form: TMainForm; Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
begin Form.ExecuteMouseDown(Sender,Button,Shift,X,Y); end;
procedure TComicWorkspaceInteractionHelper.ExecuteMouseMove(Sender: TObject; Shift: TShiftState; X,Y: Integer);
{$IFDEF DEBUG}var PerfScope: TComicPerfScope;{$ENDIF}
var P,Delta,Q: TPointF; R,Actual: TRectF; Panel: TComicPanel; Candidate: TArray<TPointF>; I,FontSize: Integer;
  Balloon,TextProbe: TComicBalloon; Offset: TPointF;
  TextLayoutSize: TSizeF; TextLayoutFontSize: Integer;
  Tail,Probe: TComicTail; TailLength: Double; Overlay: TComicOverlay;
begin
  {$IFDEF DEBUG}PerfScope.Start(cpMouseMove);{$ENDIF}
  if FViewPanning then begin
    if (Page=nil) or ((FViewPanButton=mbMiddle) and not (ssMiddle in Shift)) or
      ((FViewPanButton=mbLeft) and not (ssLeft in Shift)) then begin EndViewPan(False); Exit; end;
    if not FViewPanMoved and (Abs(X-FViewPanMouse.X)+Abs(Y-FViewPanMouse.Y)<MulDiv(3,CurrentPPI,96)) then Exit;
    FViewPanMoved:=True;
    FViewPan:=TPointF.Create(FViewPanStart.X+(X-FViewPanMouse.X)*96/CurrentPPI,
      FViewPanStart.Y+(Y-FViewPanMouse.Y)*96/CurrentPPI);
    UpdateViewport; FCanvas.Invalidate; Exit;
  end;
  if Page=nil then Exit; P:=ToPage(X,Y);
  if not FDragging then begin
    if FFirst or (FGeometryPoints.Count>0) or (FSplitStage>0) then begin
      if (FTool in [1,2,3,8]) and not (ssAlt in Shift) then P:=SnapCreationPoint(P);
      FLast:=P; FCanvas.Invalidate;
    end;
    Exit;
  end;
  if not (ssLeft in Shift) then begin CancelDrag; Exit; end;
  Delta:=TPointF.Create(P.X-FStart.X,P.Y-FStart.Y);
  // 移動閾値は整数画面座標で測り、Singleの丸めで1画素の移動を見落とさないようにする。
  if not FDragMoved and (X=FDragMouse.X) and (Y=FDragMouse.Y) then Exit;
  FDragMoved:=True; R:=FDragBounds;
  if FTabs.ActivePageIndex=4 then begin
    Overlay:=SelectedEffect; if Overlay=nil then Exit; Panel:=Page.Panels[FPanelIndex];
    if FDragHandle<>0 then R:=ResizeImageRect(FDragBounds,Delta,FDragHandle,0.01) else R.Offset(Delta.X,Delta.Y);
    R:=TRectF.Create((R.Left-Panel.Bounds.Left)/Panel.Bounds.Width,(R.Top-Panel.Bounds.Top)/Panel.Bounds.Height,
      (R.Right-Panel.Bounds.Left)/Panel.Bounds.Width,(R.Bottom-Panel.Bounds.Top)/Panel.Bounds.Height);
    if IsNan(R.Left) or IsNan(R.Top) or IsNan(R.Width) or IsNan(R.Height) or IsInfinite(R.Left) or IsInfinite(R.Top) or
      IsInfinite(R.Width) or IsInfinite(R.Height) or (Abs(R.Left)>1000) or (Abs(R.Top)>1000) or
      (R.Width<=0) or (R.Height<=0) or (R.Width>1000) or (R.Height>1000) then Exit;
    Overlay.Bounds:=R; FLast:=P; FCanvas.Invalidate; Exit;
  end;
  if (FTool=13) and (FBalloonIndex>=0) then begin
    Balloon:=Page.Balloons[FBalloonIndex]; FontSize:=FDragFontSize; Offset:=FDragTextOffset;
    TextLayoutSize:=FDragBalloonTransform.TextLayoutSize; TextLayoutFontSize:=FDragBalloonTransform.TextLayoutFontSize;
    if FDragHandle=0 then Offset.Offset(Delta.X,Delta.Y)
    else begin
      R:=ResizeImageRect(FDragBounds,Delta,FDragHandle,1/Max(1,FDragFontSize));
      FontSize:=EnsureRange(Round(FDragFontSize*R.Width/FDragBounds.Width),1,1000); TextProbe:=TComicBalloon.Create;
      try
        TextProbe.Bounds:=Balloon.Bounds; TextProbe.Text:=Balloon.Text; TextProbe.Vertical:=Balloon.Vertical;
        TextProbe.FontFamily:=Balloon.FontFamily; TextProbe.FontStyle:=Balloon.FontStyle; TextProbe.FontSize:=FontSize; TextProbe.TextOffset:=FDragTextOffset;
        TextProbe.TextLayoutSize:=FDragBalloonTransform.TextLayoutSize; TextProbe.TextLayoutFontSize:=FDragBalloonTransform.TextLayoutFontSize;
        if TextProbe.TextLayoutFontSize=0 then begin
          TextProbe.TextLayoutSize:=TSizeF.Create(Max(1,Round(Balloon.Bounds.Right)-Round(Balloon.Bounds.Left)-36),Max(1,Round(Balloon.Bounds.Bottom)-Round(Balloon.Bounds.Top)-36));
          TextProbe.TextLayoutFontSize:=FDragFontSize;
        end;
        Actual:=FRenderer.BalloonTextBounds(TextProbe); Offset.Offset(R.CenterPoint.X-Actual.CenterPoint.X,R.CenterPoint.Y-Actual.CenterPoint.Y);
        TextLayoutSize:=TextProbe.TextLayoutSize; TextLayoutFontSize:=TextProbe.TextLayoutFontSize;
      finally TextProbe.Free; end;
    end;
    if IsNan(Offset.X) or IsInfinite(Offset.X) or IsNan(Offset.Y) or IsInfinite(Offset.Y) or (Abs(Offset.X)>80000) or (Abs(Offset.Y)>80000) then Exit;
    Balloon.TextOffset:=Offset; Balloon.FontSize:=FontSize; Balloon.TextLayoutSize:=TextLayoutSize;
    Balloon.TextLayoutFontSize:=TextLayoutFontSize; FLast:=P; FCanvas.Invalidate; Exit;
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
    Panel.Zoom:=FDragZoom*R.Width/FDragBounds.Width;
    Panel.PanX:=(R.Left+R.Right-Panel.Bounds.Left-Panel.Bounds.Right)/2;
    Panel.PanY:=(R.Top+R.Bottom-Panel.Bounds.Top-Panel.Bounds.Bottom)/2;
  end else begin
    if FDragHandle<>0 then R:=ResizeRect(FDragBounds,Delta,FDragHandle,30)
    else R.Offset(Delta.X,Delta.Y);
    if (FTabs.ActivePageIndex=1) and (FBalloonIndex<0) and (FPanelIndex>=0) and not (ssAlt in Shift) then R:=SnapPanelDragBounds(R);
    if FBalloonIndex>=0 then begin
      if not Page.Balloons[FBalloonIndex].ApplyTransform(FDragBalloonTransform,R) then begin
        FStatus.SimpleText:='本体としっぽの有効な形状を維持できない変形は確定できません。'; Exit;
      end;
    end else if FPanelIndex>=0 then begin
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
  if FViewPanning then begin
    if Button<>FViewPanButton then Exit;
    EndViewPan(False);
    if (Button=mbLeft) and not FViewPanMoved and (FTool=0) and FPageRect.Contains(Point(X,Y)) then begin
      FSelectedPanels.Clear; FPanelIndex:=-1; FBalloonIndex:=-1; FEffectIndex:=-1;
      UpdateIconState; FCanvas.Invalidate;
    end;
    Exit;
  end;
  if not FDragging or (Button<>mbLeft) then Exit;
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
  // 未確定の変形は押下時へ戻す。取消を新たな編集履歴として積まず、途中の座標を保存しない。
  EndViewPan(True);
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
  Accept:=(Page<>nil) and ((Source=FImages) or HasCharacter) and FPageRect.Contains(Point(X,Y)) and
    (((Source=FImages) and (FImages.ItemIndex>=0) and (HitPanel(ToPage(X,Y))>=0)) or
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
  if (Source<>FImages) or (FImages.ItemIndex<0) or (HitPanel(ToPage(X,Y))<0) then Exit;
  CancelDrag; SelectSinglePanel(HitPanel(ToPage(X,Y))); AssignImage(nil); ActiveControl:=FView;
end;

procedure RunWorkspaceDragDrop(Form: TMainForm; Sender,Source: TObject; X,Y: Integer);
begin Form.ExecuteDragDrop(Sender,Source,X,Y); end;
end.
