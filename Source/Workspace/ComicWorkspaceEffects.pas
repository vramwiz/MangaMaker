unit ComicWorkspaceEffects;

// 責務：素材・フィルター・枠装飾の適用を扱い、共通素材と作品内の配置を分ける。
interface
uses MangaMakerMainForm, System.Types, System.Classes, Vcl.Controls, Vcl.StdCtrls, ComicModel, ComicEffects;
procedure RunWorkspaceRefreshEffectMaterials(Form: TMainForm);
procedure RunWorkspaceEffectMaterials(Form: TMainForm; Sender: TObject);
procedure RunWorkspaceEffectLibraryChanged(Form: TMainForm; Sender: TObject);
procedure RunWorkspaceEffectCategoryChanged(Form: TMainForm; Sender: TObject);
procedure RunWorkspaceDrawEffectItem(Form: TMainForm; Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
function RunWorkspaceSelectedEffect(Form: TMainForm): TComicOverlay;
function RunWorkspaceHitEffect(Form: TMainForm; Panel: TComicPanel; const P: TPointF): Integer;
procedure RunWorkspaceApplyEffectMaterial(Form: TMainForm; PanelIndex: Integer; Material: TComicEffectMaterial);
procedure RunWorkspaceLoadPanelEffectControls(Form: TMainForm);
procedure RunWorkspaceApplyFilter(Form: TMainForm; Sender: TObject);
procedure RunWorkspaceApplyFrame(Form: TMainForm; Sender: TObject);
procedure RunWorkspaceChoosePanelBorderColor(Form: TMainForm; Sender: TObject);
procedure RunWorkspaceDeleteEffect(Form: TMainForm; Sender: TObject);
procedure RunWorkspaceEffectMouseDown(Form: TMainForm; const P: TPointF);
procedure RunWorkspaceMoveEffect(Form: TMainForm; const P: TPointF; Shift: TShiftState);
procedure RunWorkspaceUpdateEffectCursor(Form: TMainForm; const P: TPointF);
implementation
uses Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.Imm, System.SysUtils, System.UITypes, System.Math, System.IOUtils, System.Generics.Collections, System.JSON, System.Hash, System.DateUtils, Vcl.Forms, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus, Vcl.Dialogs, Vcl.Graphics, Vcl.Imaging.pngimage, ComicEffectDialog, ComicOverlayTransform;
type
  TComicWorkspaceEffectsHelper = class helper for TMainForm
    procedure EffectMouseDown(const P: TPointF);
    procedure MoveEffect(const P: TPointF; Shift: TShiftState);
    procedure UpdateEffectCursor(const P: TPointF);
    procedure ExecuteRefreshEffectMaterials;
    procedure ExecuteEffectMaterials(Sender: TObject);
    procedure ExecuteEffectLibraryChanged(Sender: TObject);
    procedure ExecuteEffectCategoryChanged(Sender: TObject);
    procedure ExecuteDrawEffectItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    function ExecuteSelectedEffect: TComicOverlay;
    function ExecuteHitEffect(Panel: TComicPanel; const P: TPointF): Integer;
    procedure ExecuteApplyEffectMaterial(PanelIndex: Integer; Material: TComicEffectMaterial);
    procedure ExecuteLoadPanelEffectControls;
    procedure ExecuteApplyFilter(Sender: TObject);
    procedure ExecuteApplyFrame(Sender: TObject);
    procedure ExecuteChoosePanelBorderColor(Sender: TObject);
    procedure ExecuteDeleteEffect(Sender: TObject);
  end;
procedure TComicWorkspaceEffectsHelper.ExecuteRefreshEffectMaterials;
var Material: TComicEffectMaterial; At: Integer;
begin
  if FEffectPane<>nil then begin FEffectPane.Refresh; Exit; end;
  At:=FEffectList.ItemIndex; FEffectList.Items.BeginUpdate;
  try FEffectList.Clear; for Material in FEffectMaterials do FEffectList.Items.AddObject(Material.Name,Material);
    FEffectList.ItemIndex:=Max(0,Min(At,FEffectList.Count-1));
  finally FEffectList.Items.EndUpdate; end;
end;

procedure RunWorkspaceRefreshEffectMaterials(Form: TMainForm);
begin Form.ExecuteRefreshEffectMaterials; end;
procedure TComicWorkspaceEffectsHelper.ExecuteEffectMaterials(Sender: TObject);
begin
  FModeButtons[4].Click; FEffectCategory.ItemIndex:=0; EffectCategoryChanged(nil);
  if FEffectPane.GroupList.CanFocus then FEffectPane.GroupList.SetFocus;
end;
procedure RunWorkspaceEffectMaterials(Form: TMainForm; Sender: TObject);
begin Form.ExecuteEffectMaterials(Sender); end;
procedure TComicWorkspaceEffectsHelper.ExecuteEffectLibraryChanged(Sender: TObject);
begin RefreshEffectMaterials; FRenderer.ClearCache; FCanvas.Invalidate; end;

procedure RunWorkspaceEffectLibraryChanged(Form: TMainForm; Sender: TObject);
begin Form.ExecuteEffectLibraryChanged(Sender); end;
procedure TComicWorkspaceEffectsHelper.ExecuteEffectCategoryChanged(Sender: TObject);
begin CancelDrag; FEffectIndex:=-1; FEffectPages.ActivePageIndex:=FEffectCategory.ItemIndex; LoadPanelEffectControls; UpdateIconState; FCanvas.Invalidate; end;

procedure RunWorkspaceEffectCategoryChanged(Form: TMainForm; Sender: TObject);
begin Form.ExecuteEffectCategoryChanged(Sender); end;
procedure TComicWorkspaceEffectsHelper.ExecuteDrawEffectItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
var R,TextRect: TRect; Material: TComicEffectMaterial; C: TCanvas; X,Y,Step: Integer;
  function D(Value: Integer): Integer; begin Result:=MulDiv(Value,CurrentPPI,96); end;
begin
  C:=FEffectList.Canvas; C.Brush.Color:=$302B28; C.FillRect(Rect); Material:=TComicEffectMaterial(FEffectList.Items.Objects[Index]);
  // 4:3のプレビューを左に固定し、一覧幅が変わっても名称欄を画像の右に確保する。
  Step:=D(8); R:=System.Types.Rect(Rect.Left+D(8),Rect.Top+D(8),Rect.Left+D(120),Rect.Top+D(92));
  Y:=R.Top;
  while Y<R.Bottom do begin X:=R.Left; while X<R.Right do begin
    if (((X-R.Left) div Step+(Y-R.Top) div Step) mod 2)=0 then C.Brush.Color:=clWhite else C.Brush.Color:=$CCCCCC;
    C.FillRect(System.Types.Rect(X,Y,Min(R.Right,X+Step),Min(R.Bottom,Y+Step))); Inc(X,Step); end; Inc(Y,Step); end;
  // 壊れた素材でも名称と透明領域の下地を残し、一覧の選択を継続できるようにする。
  try FRenderer.DrawOverlay(C,EffectMaterialPath(Material),R); except end;
  TextRect:=System.Types.Rect(R.Right+D(12),Rect.Top+D(18),Rect.Right-D(8),Rect.Bottom-D(8));
  C.Font.Assign(FEffectList.Font); C.Font.Color:=clWhite; C.Brush.Style:=bsClear;
  DrawText(C.Handle,PChar(Material.Name),Length(Material.Name),TextRect,DT_WORDBREAK or DT_NOPREFIX or DT_END_ELLIPSIS);
  C.Brush.Style:=bsSolid;
  if odSelected in State then begin C.Brush.Style:=bsClear; C.Pen.Color:=$E5B45B; C.Rectangle(Rect); C.Brush.Style:=bsSolid; end;
end;

procedure RunWorkspaceDrawEffectItem(Form: TMainForm; Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
begin Form.ExecuteDrawEffectItem(Control,Index,Rect,State); end;
function TComicWorkspaceEffectsHelper.ExecuteSelectedEffect: TComicOverlay;
begin
  Result:=nil; if (Page=nil) or (FPanelIndex<0) or (FPanelIndex>=Page.Panels.Count) then Exit;
  if (FEffectIndex>=0) and (FEffectIndex<Page.Panels[FPanelIndex].Overlays.Count) then Result:=Page.Panels[FPanelIndex].Overlays[FEffectIndex];
end;

function RunWorkspaceSelectedEffect(Form: TMainForm): TComicOverlay;
begin Result:=Form.ExecuteSelectedEffect; end;
function TComicWorkspaceEffectsHelper.ExecuteHitEffect(Panel: TComicPanel; const P: TPointF): Integer;
var I: Integer;
begin Result:=-1; for I:=Panel.Overlays.Count-1 downto 0 do
  if OverlayContains(OverlayBounds(Panel,Panel.Overlays[I]),Panel.Overlays[I].Rotation,P) then Exit(I); end;

function RunWorkspaceHitEffect(Form: TMainForm; Panel: TComicPanel; const P: TPointF): Integer;
begin Result:=Form.ExecuteHitEffect(Panel,P); end;
procedure TComicWorkspaceEffectsHelper.ExecuteApplyEffectMaterial(PanelIndex: Integer; Material: TComicEffectMaterial);
var Overlay: TComicOverlay; Source,Dest: string; PNG: TPngImage; Bounds: TRectF;
begin
  CancelDrag;
  if (Page=nil) or (PanelIndex<0) or (PanelIndex>=Page.Panels.Count) or (Material=nil) or not HasCharacter then Exit;
  if Page.Panels[PanelIndex].Overlays.Count>=1000 then raise Exception.Create('コマの効果素材は1000件までです。');
  Source:=EffectMaterialPath(Material); PNG:=TPngImage.Create;
  try PNG.LoadFromFile(Source); if (PNG.Width<1) or (PNG.Height<1) or (Int64(PNG.Width)*PNG.Height>64000000) then raise Exception.Create('効果素材のサイズが不正です。');
    Bounds:=FitEffectBounds(Page.Panels[PanelIndex].Bounds,PNG.Width,PNG.Height);
  finally PNG.Free; end;
  Overlay:=TComicOverlay.Create; Overlay.MaterialID:=Material.ID; Overlay.FileName:='Effects\'+NewUID+'.png'; Dest:=SafeChild(FProject.Folder,Overlay.FileName);
  Overlay.Bounds:=Bounds;
  try
    ForceDirectories(ExtractFilePath(Dest)); TFile.Copy(Source,Dest,False); Checkpoint;
    Page.Panels[PanelIndex].Overlays.Add(Overlay); Overlay:=nil; FPanelIndex:=PanelIndex; FEffectIndex:=Page.Panels[PanelIndex].Overlays.Count-1;
    FBalloonIndex:=-1; Changed;
  finally Overlay.Free; end;
end;

procedure RunWorkspaceApplyEffectMaterial(Form: TMainForm; PanelIndex: Integer; Material: TComicEffectMaterial);
begin Form.ExecuteApplyEffectMaterial(PanelIndex,Material); end;
procedure TComicWorkspaceEffectsHelper.ExecuteLoadPanelEffectControls;
var Panel: TComicPanel; At: Integer;
begin
  if (FFilterKind=nil) or (Page=nil) or (FPanelIndex<0) or (FPanelIndex>=Page.Panels.Count) then Exit;
  Panel:=Page.Panels[FPanelIndex]; FFilterKind.ItemIndex:=Panel.FilterKind;
  At:=FFilterStrength.Items.IndexOf(IntToStr(Panel.FilterStrength)); if At<0 then At:=FFilterStrength.Items.Add(IntToStr(Panel.FilterStrength)); FFilterStrength.ItemIndex:=At;
  FFrameKind.ItemIndex:=Panel.FrameKind; FPanelBorderColor:=Panel.BorderColor;
  At:=FPanelBorderWidth.Items.IndexOf(FloatToStr(Panel.BorderWidth)); if At<0 then At:=FPanelBorderWidth.Items.Add(FloatToStr(Panel.BorderWidth)); FPanelBorderWidth.ItemIndex:=At;
end;

procedure RunWorkspaceLoadPanelEffectControls(Form: TMainForm);
begin Form.ExecuteLoadPanelEffectControls; end;
procedure TComicWorkspaceEffectsHelper.ExecuteApplyFilter(Sender: TObject);
var Panel: TComicPanel; Strength,Kind: Integer;
begin
  CancelDrag;
  if (Page=nil) or (FPanelIndex<0) or (FPanelIndex>=Page.Panels.Count) then Exit;
  Panel:=Page.Panels[FPanelIndex]; Strength:=StrToIntDef(FFilterStrength.Text,100); Kind:=FFilterKind.ItemIndex;
  if not (Strength in [0..100]) or not (Kind in [0..4]) then raise Exception.Create('フィルターの指定が不正です。');
  if (Panel.FilterKind=Kind) and (Panel.FilterStrength=Strength) then Exit;
  Checkpoint; Panel.FilterKind:=Kind; Panel.FilterStrength:=Strength; Changed;
end;

procedure RunWorkspaceApplyFilter(Form: TMainForm; Sender: TObject);
begin Form.ExecuteApplyFilter(Sender); end;
procedure TComicWorkspaceEffectsHelper.ExecuteApplyFrame(Sender: TObject);
var Panel: TComicPanel; Width: Double; Kind: Integer;
begin
  CancelDrag;
  if (Page=nil) or (FPanelIndex<0) or (FPanelIndex>=Page.Panels.Count) then Exit;
  Panel:=Page.Panels[FPanelIndex]; Width:=StrToFloatDef(FPanelBorderWidth.Text,4); Kind:=FFrameKind.ItemIndex;
  if IsNan(Width) or IsInfinite(Width) or (Width<0) or (Width>100) or not (Kind in [0..2]) then raise Exception.Create('枠設定が不正です。');
  if (Panel.FrameKind=Kind) and (Panel.BorderWidth=Width) and (Panel.BorderColor=FPanelBorderColor) then Exit;
  Checkpoint; Panel.FrameKind:=Kind; Panel.BorderWidth:=Width; Panel.BorderColor:=FPanelBorderColor; Changed;
end;

procedure RunWorkspaceApplyFrame(Form: TMainForm; Sender: TObject);
begin Form.ExecuteApplyFrame(Sender); end;
procedure TComicWorkspaceEffectsHelper.ExecuteChoosePanelBorderColor(Sender: TObject);
var Dialog: TColorDialog;
begin
  if (Page=nil) or (FPanelIndex<0) then Exit; Dialog:=TColorDialog.Create(Self);
  try Dialog.Color:=FPanelBorderColor; Dialog.Options:=[cdFullOpen]; if Dialog.Execute then FPanelBorderColor:=Dialog.Color; finally Dialog.Free; end;
end;

procedure RunWorkspaceChoosePanelBorderColor(Form: TMainForm; Sender: TObject);
begin Form.ExecuteChoosePanelBorderColor(Sender); end;
procedure TComicWorkspaceEffectsHelper.ExecuteDeleteEffect(Sender: TObject);
var Panel: TComicPanel;
begin
  CancelDrag;
  if (Page=nil) or (FPanelIndex<0) or (FPanelIndex>=Page.Panels.Count) then Exit; Panel:=Page.Panels[FPanelIndex];
  case FEffectCategory.ItemIndex of
    0: begin if SelectedEffect=nil then Exit; Checkpoint; Panel.Overlays.Delete(FEffectIndex); FEffectIndex:=-1; end;
    1: begin if Panel.FilterKind=0 then Exit; Checkpoint; Panel.FilterKind:=0; end;
    2: begin if (Panel.FrameKind=0) and (Panel.BorderWidth=4) and (Panel.BorderColor=0) then Exit;
      Checkpoint; Panel.FrameKind:=0; Panel.BorderWidth:=4; Panel.BorderColor:=0; end;
  end;
  LoadPanelEffectControls; Changed;
end;

procedure RunWorkspaceDeleteEffect(Form: TMainForm; Sender: TObject);
begin Form.ExecuteDeleteEffect(Sender); end;
procedure TComicWorkspaceEffectsHelper.EffectMouseDown(const P: TPointF);
var Overlay: TComicOverlay; R: TRectF; Handle: Integer;
begin
  Overlay:=SelectedEffect; R:=TRectF.Empty; Handle:=0;
  if (FEffectCategory.ItemIndex=0) and (Overlay<>nil) then begin
    R:=OverlayBounds(Page.Panels[FPanelIndex],Overlay);
    Handle:=HitOverlayHandle(R,Overlay.Rotation,P,FScale,CurrentPPI);
  end;
  if (FEffectCategory.ItemIndex<>0) or ((Handle=0) and ((Overlay=nil) or not OverlayContains(R,Overlay.Rotation,P))) then begin
    FPanelIndex:=HitPanel(P); FEffectIndex:=-1;
    if (FPanelIndex>=0) and (FEffectCategory.ItemIndex=0) then FEffectIndex:=HitEffect(Page.Panels[FPanelIndex],P);
  end;
  FBalloonIndex:=-1; LoadPanelEffectControls; UpdateIconState; FCanvas.Invalidate;
  Overlay:=SelectedEffect; if Overlay=nil then Exit;
  FDragBounds:=OverlayBounds(Page.Panels[FPanelIndex],Overlay); FDragEffectAngle:=Overlay.Rotation;
  FDragHandle:=HitOverlayHandle(FDragBounds,Overlay.Rotation,P,FScale,CurrentPPI);
  FDragSnapshot:=FProject.Snapshot; FDragMoved:=False; FDragging:=True; FStart:=P; FLast:=P;
  FDragVertex:=-1; FDragTailHandle:=0;
  if not FTesting then FCanvas.MouseCapture:=True;
  if FDragHandle=9 then FStatus.SimpleText:='ドラッグで効果を回転。Shiftで15度刻み、Escで取消。';
end;
procedure TComicWorkspaceEffectsHelper.MoveEffect(const P: TPointF; Shift: TShiftState);
var Overlay: TComicOverlay; Panel: TComicPanel; R: TRectF; Delta: TPointF;
begin
  Overlay:=SelectedEffect; if Overlay=nil then Exit; Panel:=Page.Panels[FPanelIndex];
  if FDragHandle=9 then begin
    Overlay.Rotation:=DragOverlayAngle(FDragBounds,FDragEffectAngle,FStart,P,ssShift in Shift);
    FStatus.SimpleText:=Format('効果の回転：%.1f°（Shiftで15度刻み、Escで取消）',[Overlay.Rotation]);
  end else begin
    Delta:=P-FStart; R:=FDragBounds;
    if FDragHandle<>0 then R:=ResizeRotatedOverlay(FDragBounds,FDragEffectAngle,Delta,FDragHandle)
    else R.Offset(Delta.X,Delta.Y);
    R:=TRectF.Create((R.Left-Panel.Bounds.Left)/Panel.Bounds.Width,(R.Top-Panel.Bounds.Top)/Panel.Bounds.Height,
      (R.Right-Panel.Bounds.Left)/Panel.Bounds.Width,(R.Bottom-Panel.Bounds.Top)/Panel.Bounds.Height);
    if IsNan(R.Left) or IsNan(R.Top) or IsNan(R.Width) or IsNan(R.Height) or IsInfinite(R.Left) or IsInfinite(R.Top) or
      IsInfinite(R.Width) or IsInfinite(R.Height) or (Abs(R.Left)>1000) or (Abs(R.Top)>1000) or
      (R.Width<=0) or (R.Height<=0) or (R.Width>1000) or (R.Height>1000) then Exit;
    Overlay.Bounds:=R;
  end;
  FLast:=P; FCanvas.Invalidate;
end;
procedure TComicWorkspaceEffectsHelper.UpdateEffectCursor(const P: TPointF);
const Cursors: array[0..3] of TCursor = (crSizeNWSE,crSizeNS,crSizeNESW,crSizeWE);
var Overlay: TComicOverlay; R: TRectF; Handle,Direction: Integer;
begin
  if (FTabs.ActivePageIndex<>4) or (FEffectCategory.ItemIndex<>0) then Exit;
  Overlay:=SelectedEffect; if Overlay=nil then Exit; R:=OverlayBounds(Page.Panels[FPanelIndex],Overlay);
  Handle:=HitOverlayHandle(R,Overlay.Rotation,P,FScale,CurrentPPI); if FDragging then Handle:=FDragHandle;
  if Handle=9 then FCanvas.Cursor:=crHandPoint
  else if Handle>0 then begin
    Direction:=(Handle-1+Round(Overlay.Rotation/45)+8) mod 4; FCanvas.Cursor:=Cursors[Direction];
  end else if FDragging or OverlayContains(R,Overlay.Rotation,P) then FCanvas.Cursor:=crSizeAll;
end;
procedure RunWorkspaceEffectMouseDown(Form: TMainForm; const P: TPointF);
begin Form.EffectMouseDown(P); end;
procedure RunWorkspaceMoveEffect(Form: TMainForm; const P: TPointF; Shift: TShiftState);
begin Form.MoveEffect(P,Shift); end;
procedure RunWorkspaceUpdateEffectCursor(Form: TMainForm; const P: TPointF);
begin Form.UpdateEffectCursor(P); end;
end.
