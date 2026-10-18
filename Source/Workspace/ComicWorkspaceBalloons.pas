unit ComicWorkspaceBalloons;

// 責務：吹き出しの文字・しっぽ設定を操作し、本体との所属と配置を保持する。
interface
uses ComicTextInput, MangaMakerMainForm, System.Types, System.Classes, ComicModel, Vcl.Controls;
procedure RunWorkspaceApplyText(Form: TMainForm; Sender: TObject);
procedure RunWorkspaceBalloonSettingsChanged(Form: TMainForm; Sender: TObject);
procedure RunWorkspaceLoadBalloonControls(Form: TMainForm; Balloon: TComicBalloon);
procedure RunWorkspaceFontDropDown(Form: TMainForm; Sender: TObject);
procedure RunWorkspaceChooseTextColor(Form: TMainForm; Sender: TObject);
procedure RunWorkspaceTextInputDialog(Form: TMainForm; Sender: TObject);
procedure RunWorkspaceFinishTextDialog(Form: TMainForm; Dialog: TComicTextDialog);
procedure RunWorkspaceTail(Form: TMainForm; Sender: TObject);
function RunWorkspaceInsideBalloonBody(Form: TMainForm; Balloon: TComicBalloon; const P: TPointF): Boolean;
procedure RunWorkspaceTailClick(Form: TMainForm; const P: TPointF);
procedure RunWorkspaceTailEditClick(Form: TMainForm; const P: TPointF);
procedure RunWorkspaceDeleteTail(Form: TMainForm; Sender: TObject);
procedure RunWorkspaceBalloonToolKey(Form: TMainForm; var Key: Word; Shift: TShiftState);
procedure RunWorkspaceSelectTextTool(Form: TMainForm);
procedure RunWorkspaceStartInlineText(Form: TMainForm);
procedure RunWorkspaceFinishInlineText(Form: TMainForm; Accept: Boolean);
procedure RunWorkspaceDrawDialogueSnapGuides(Form: TMainForm);
implementation
uses Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.Imm, System.SysUtils, System.UITypes, System.Math, System.IOUtils, System.Generics.Collections, System.JSON, System.Hash, System.DateUtils, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus, Vcl.Dialogs, Vcl.Graphics, Vcl.Imaging.pngimage, ComicRender, ComicInlineText, ComicIconButton;
type
  TComicWorkspaceBalloonsHelper = class helper for TMainForm
    procedure DrawDialogueSnapGuides;
    procedure ExecuteApplyText(Sender: TObject);
    procedure ExecuteBalloonSettingsChanged(Sender: TObject);
    procedure RememberSelectedFont;
    procedure RememberSelectedSize;
    procedure ExecuteLoadBalloonControls(Balloon: TComicBalloon);
    procedure ExecuteFontDropDown(Sender: TObject);
    procedure ExecuteChooseTextColor(Sender: TObject);
    procedure ExecuteTextInputDialog(Sender: TObject);
    procedure ExecuteFinishTextDialog(Dialog: TComicTextDialog);
    procedure ExecuteTail(Sender: TObject);
    function ExecuteInsideBalloonBody(Balloon: TComicBalloon; const P: TPointF): Boolean;
    procedure ExecuteTailClick(const P: TPointF);
    procedure ExecuteTailEditClick(const P: TPointF);
    procedure ExecuteDeleteTail(Sender: TObject);
    procedure ExecuteBalloonToolKey(var Key: Word; Shift: TShiftState);
    procedure ExecuteSelectTextTool;
    procedure ExecuteStartInlineText;
    procedure ExecuteFinishInlineText(Accept: Boolean);
    procedure StoreInlineText(Balloon: TComicBalloon);
  end;
procedure TComicWorkspaceBalloonsHelper.DrawDialogueSnapGuides;
var C: TCanvas; Frame,Text: TRectF; Saved: Integer; OldWidth: Integer; OldColor: TColor; OldStyle: TPenStyle;
  procedure Line(AX,AY,BX,BY: Single);
  begin
    C.MoveTo(FPageRect.Left+Round(AX*FScale),FPageRect.Top+Round(AY*FScale));
    C.LineTo(FPageRect.Left+Round(BX*FScale),FPageRect.Top+Round(BY*FScale));
  end;
begin
  if not FDragging or (FTabs.ActivePageIndex<>3) or (FTool<>13) or
    (FDragHandle<>0) or (Page=nil) or (FBalloonIndex<0) or
    not (FDialogueSnap.HasX or FDialogueSnap.HasY) then Exit;
  Frame:=Page.Balloons[FBalloonIndex].Bounds; Text:=FDialogueSnap.Bounds;
  C:=FCanvas.Canvas; Saved:=SaveDC(C.Handle); OldWidth:=C.Pen.Width; OldColor:=C.Pen.Color; OldStyle:=C.Pen.Style;
  try
    // 吸着している軸だけを編集中のページへ描き、確定・取消・PNG出力に線を残さない。
    IntersectClipRect(C.Handle,FPageRect.Left,FPageRect.Top,FPageRect.Right,FPageRect.Bottom);
    C.Pen.Color:=$E060E0; C.Pen.Width:=1; C.Pen.Style:=psDot;
    if FDialogueSnap.HasX then Line(Frame.CenterPoint.X,Min(Frame.Top,Text.Top),Frame.CenterPoint.X,Max(Frame.Bottom,Text.Bottom));
    if FDialogueSnap.HasY then Line(Min(Frame.Left,Text.Left),Frame.CenterPoint.Y,Max(Frame.Right,Text.Right),Frame.CenterPoint.Y);
  finally C.Pen.Width:=OldWidth; C.Pen.Color:=OldColor; C.Pen.Style:=OldStyle; RestoreDC(C.Handle,Saved); end;
end;
procedure RunWorkspaceDrawDialogueSnapGuides(Form: TMainForm);
begin Form.DrawDialogueSnapGuides; end;
procedure TComicWorkspaceBalloonsHelper.ExecuteApplyText(Sender: TObject);
var B: TComicBalloon; Old: TJSONObject; Before,OldText,OldFamily: string;
  OldVertical: Boolean; OldStyle: TFontStyles; Revision: Integer;
begin
  if FApplyingBalloonSettings or FBalloonControlsLoading or FRefreshing or (Page=nil) or
    (FBalloonIndex<0) or (FBalloonIndex>=Page.Balloons.Count) then Exit;
  FApplyingBalloonSettings:=True;
  try
  CancelDrag; B:=Page.Balloons[FBalloonIndex]; Before:=FProject.Snapshot; Old:=B.Json; Revision:=Page.Revision;
  try
  OldText:=B.Text; OldFamily:=B.FontFamily; OldVertical:=B.Vertical; OldStyle:=B.FontStyle;
  B.Text:=FText.Text; B.Vertical:=FVertical.Checked; B.Transparent:=FTransparent.Checked;
  if (Sender=FText) or (Sender is TComicTextDialog) then B.AutoWrap:=False;
  B.Overflow:=FOverflow.Checked;
  var Size: Integer;
  if TryStrToInt(Trim(FFont.Text),Size) and (Size>=1) and (Size<=1000) then B.FontSize:=Size;
  B.FontFamily:=FFontFamily.Text; if B.FontFamily='' then B.FontFamily:='Yu Gothic'; B.FontColor:=FTextColor; B.FontStyle:=[];
  if FFontBold.Checked then Include(B.FontStyle,fsBold); if FFontItalic.Checked then Include(B.FontStyle,fsItalic);
  if FFontUnderline.Checked then Include(B.FontStyle,fsUnderline); if FFontStrikeOut.Checked then Include(B.FontStyle,fsStrikeOut);
  if (B.Text<>OldText) or (B.FontFamily<>OldFamily) or (B.Vertical<>OldVertical) or (B.FontStyle<>OldStyle) then B.ResetTextLayout;
  B.FillColor:=FFillColor; B.BorderColor:=FBorderColor; B.BorderWidth:=StrToFloatDef(FBorderWidth.Text,3);
  B.Contour:=TComicBalloonContour(Max(0,FContour.ItemIndex));
  var Current:=B.Json;
  try if Current.ToJSON=Old.ToJSON then begin
    if Sender=FFontFamily then RememberSelectedFont;
    if Sender=FFont then RememberSelectedSize; Exit;
  end; finally Current.Free; end;
  Inc(Page.Revision);
  try FProject.SaveDraft;
  except B.Read(Old); Page.Revision:=Revision; LoadBalloonControls(B); raise; end;
  if (Sender<>FText) or (ActiveControl<>FText) or (FTextEditUndo='') or (FUndo.Count=0) or
    (FUndo.Last<>FTextEditUndo) then begin
    FUndo.Add(Before); if (Sender=FText) and (ActiveControl=FText) then FTextEditUndo:=Before;
  end;
  if FUndo.Count>40 then FUndo.Delete(0); FRedo.Clear; FDirty:=True; RefreshUI;
  if (Sender=FFontFamily) or (B.FontFamily<>OldFamily) then RememberSelectedFont;
  if Sender=FFont then RememberSelectedSize;
  finally Old.Free; end;
  finally FApplyingBalloonSettings:=False; end;
end;

procedure TComicWorkspaceBalloonsHelper.RememberSelectedFont;
begin
  FLastFontFamily:=FFontFamily.Text; if FLastFontFamily='' then Exit;
  if FFontHistoryWritable then
    try FFontHistory.Remember(FLastFontFamily,TPath.Combine(DataRoot,'Presets\FontHistory.json'));
    except on E: Exception do begin FFontHistoryWritable:=False; FStatus.SimpleText:='フォント履歴を保存できません：'+E.Message; end; end;
end;
procedure TComicWorkspaceBalloonsHelper.RememberSelectedSize;
var Size: Integer;
begin
  if not TryStrToInt(Trim(FFont.Text),Size) or (Size<1) or (Size>1000) then Exit;
  try FFontHistory.RememberSize(Size);
  except on E: Exception do FStatus.SimpleText:='文字サイズを保存できません：'+E.Message; end;
end;
procedure TComicWorkspaceBalloonsHelper.ExecuteBalloonSettingsChanged(Sender: TObject);
var Size: Integer;
begin
  if FBalloonControlsLoading or FRefreshing or FFinishingInline or FApplyingBalloonSettings then Exit;
  if (Sender=FFont) and (not TryStrToInt(Trim(FFont.Text),Size) or (Size<1) or (Size>1000)) then Exit;
  if (Sender=FFontFamily) and ((Page=nil) or (FBalloonIndex<0)) then RememberSelectedFont
  else if (Sender=FFont) and ((Page=nil) or (FBalloonIndex<0)) then RememberSelectedSize
  else ExecuteApplyText(Sender);
end;
procedure RunWorkspaceBalloonSettingsChanged(Form: TMainForm; Sender: TObject);
begin Form.ExecuteBalloonSettingsChanged(Sender); end;

procedure RunWorkspaceApplyText(Form: TMainForm; Sender: TObject);
begin Form.ExecuteApplyText(Sender); end;
procedure TComicWorkspaceBalloonsHelper.ExecuteLoadBalloonControls(Balloon: TComicBalloon);
var Index: Integer; Loading: Boolean;
begin
  Loading:=FBalloonControlsLoading; FBalloonControlsLoading:=True;
  try
  FText.Text:=Balloon.Text; FVertical.Checked:=Balloon.Vertical; FTransparent.Checked:=Balloon.Transparent; FOverflow.Checked:=Balloon.Overflow;
  FContour.ItemIndex:=Ord(Balloon.Contour);
  Index:=FFont.Items.IndexOf(IntToStr(Balloon.FontSize)); if Index<0 then Index:=FFont.Items.Add(IntToStr(Balloon.FontSize)); FFont.ItemIndex:=Index;
  Index:=FFontFamily.Items.IndexOf(Balloon.FontFamily); if Index<0 then Index:=FFontFamily.Items.Add(Balloon.FontFamily); FFontFamily.ItemIndex:=Index;
  FTextColor:=Balloon.FontColor; FFontBold.Checked:=fsBold in Balloon.FontStyle; FFontItalic.Checked:=fsItalic in Balloon.FontStyle;
  FFontUnderline.Checked:=fsUnderline in Balloon.FontStyle; FFontStrikeOut.Checked:=fsStrikeOut in Balloon.FontStyle;
  FFillColor:=Balloon.FillColor; FBorderColor:=Balloon.BorderColor;
  Index:=FBorderWidth.Items.IndexOf(FloatToStr(Balloon.BorderWidth)); if Index<0 then Index:=FBorderWidth.Items.Add(FloatToStr(Balloon.BorderWidth)); FBorderWidth.ItemIndex:=Index;
  finally FBalloonControlsLoading:=Loading; end;
end;

procedure RunWorkspaceLoadBalloonControls(Form: TMainForm; Balloon: TComicBalloon);
begin Form.ExecuteLoadBalloonControls(Balloon); end;
procedure TComicWorkspaceBalloonsHelper.ExecuteFontDropDown(Sender: TObject);
var Current: string; Index: Integer; Loading: Boolean;
begin
  Loading:=FBalloonControlsLoading; FBalloonControlsLoading:=True;
  Current:=FFontFamily.Text; FFontFamily.Items.BeginUpdate;
  try
    FFontFamily.Items.Clear; FFontFamily.Items.AddStrings(FFontHistory.Choices(Screen.Fonts));
    if Current<>'' then begin Index:=FFontFamily.Items.IndexOf(Current); if Index<0 then Index:=FFontFamily.Items.Add(Current); FFontFamily.ItemIndex:=Index; end;
  finally FFontFamily.Items.EndUpdate; FBalloonControlsLoading:=Loading; end;
end;

procedure RunWorkspaceFontDropDown(Form: TMainForm; Sender: TObject);
begin Form.ExecuteFontDropDown(Sender); end;
procedure TComicWorkspaceBalloonsHelper.ExecuteChooseTextColor(Sender: TObject);
var Dialog: TColorDialog; Tag: Integer;
begin
  if (Page=nil) or (FBalloonIndex<0) then Exit;
  Tag:=TControl(Sender).Tag; Dialog:=TColorDialog.Create(Self);
  try
    case Tag of 1: Dialog.Color:=FFillColor; 2: Dialog.Color:=FBorderColor; else Dialog.Color:=FTextColor; end;
    Dialog.Options:=[cdFullOpen]; if Dialog.Execute then begin
      case Tag of 1: FFillColor:=Dialog.Color; 2: FBorderColor:=Dialog.Color; else FTextColor:=Dialog.Color; end;
      ExecuteApplyText(Sender);
    end;
  finally Dialog.Free; end;
end;

procedure RunWorkspaceChooseTextColor(Form: TMainForm; Sender: TObject);
begin Form.ExecuteChooseTextColor(Sender); end;
procedure TComicWorkspaceBalloonsHelper.ExecuteTextInputDialog(Sender: TObject);
var Dialog: TComicTextDialog;
begin
  if (Page=nil) or (FBalloonIndex<0) or (FBalloonIndex>=Page.Balloons.Count) then Exit;
  CancelDrag; Dialog:=CreateBalloonTextDialog;
  try
    Dialog.ShowModal; FinishTextDialog(Dialog);
  finally Dialog.Free; end;
end;

procedure RunWorkspaceTextInputDialog(Form: TMainForm; Sender: TObject);
begin Form.ExecuteTextInputDialog(Sender); end;
procedure TComicWorkspaceBalloonsHelper.ExecuteFinishTextDialog(Dialog: TComicTextDialog);
var Index: Integer; Loading: Boolean;
begin
  if Dialog.ModalResult=mrOK then begin
    Loading:=FBalloonControlsLoading; FBalloonControlsLoading:=True;
    try
      FText.Text:=Dialog.Editor.Text; Index:=FFontFamily.Items.IndexOf(Dialog.Editor.Font.Name);
      if Index<0 then Index:=FFontFamily.Items.Add(Dialog.Editor.Font.Name); FFontFamily.ItemIndex:=Index;
    finally FBalloonControlsLoading:=Loading; end;
    ApplyText(Dialog);
  end;
end;

procedure RunWorkspaceFinishTextDialog(Form: TMainForm; Dialog: TComicTextDialog);
begin Form.ExecuteFinishTextDialog(Dialog); end;
procedure TComicWorkspaceBalloonsHelper.ExecuteTail(Sender: TObject);
begin
  if FBalloonIndex<0 then begin Notify('先に吹き出しを選択してください。'); Exit; end;
  CancelDrag; ResetGeometryInput; FTool:=TControl(Sender).Tag; FFirst:=False;
  if FTool=12 then begin FTailIndex:=Page.Balloons[FBalloonIndex].Tails.Count-1; FStatus.SimpleText:='しっぽをクリック。3点で根元・幅・先端を編集。削除は右のボタン。'; end
  else if FDragPlacementMenu.Checked then FStatus.SimpleText:='本体内の根元から先端へドラッグ。設定・管理で2点クリックへ切替。'
  else FStatus.SimpleText:='根元を本体内でクリックし、次に先端をクリック。設定・管理でドラッグへ切替。';
  UpdateIconState; FCanvas.Invalidate;
end;

procedure RunWorkspaceTail(Form: TMainForm; Sender: TObject);
begin Form.ExecuteTail(Sender); end;
function TComicWorkspaceBalloonsHelper.ExecuteInsideBalloonBody(Balloon: TComicBalloon; const P: TPointF): Boolean;
var Region: HRGN;
begin
  Region:=BalloonBodyRegion(Balloon,Point(0,0),1);
  try Result:=PtInRegion(Region,Round(P.X),Round(P.Y)); finally Winapi.Windows.DeleteObject(Region); end;
end;

function RunWorkspaceInsideBalloonBody(Form: TMainForm; Balloon: TComicBalloon; const P: TPointF): Boolean;
begin Result:=Form.ExecuteInsideBalloonBody(Balloon,P); end;
procedure TComicWorkspaceBalloonsHelper.ExecuteTailClick(const P: TPointF);
var Balloon: TComicBalloon; Tail: TComicTail;
begin
  CancelDrag;
  if (FBalloonIndex<0) or (FBalloonIndex>=Page.Balloons.Count) then Exit; Balloon:=Page.Balloons[FBalloonIndex];
  if not FFirst then begin
    if not InsideBalloonBody(Balloon,P) then begin FStatus.SimpleText:='しっぽの根元は選択中の吹き出し本体内に指定してください。'; Exit; end;
    FStart:=P; FLast:=P; FFirst:=True; FCanvas.Invalidate; Exit;
  end;
  if Balloon.Tails.Count>=64 then begin FStatus.SimpleText:='1つの吹き出しのしっぽは最大64個です。'; Exit; end;
  Tail:=TComicTail.Create; Tail.Root:=FStart; Tail.Tip:=P; Tail.Width:=Min(2000,Max(8,Balloon.Bounds.Width/6));
  if FTool=7 then Tail.Width:=Min(2000,2*Tail.Width);
  if FTool=11 then Tail.Kind:=ctThought;
  if not Tail.Valid then begin Tail.Free; FStatus.SimpleText:='根元と先端を離して指定してください。'; Exit; end;
  Checkpoint; Balloon.Tails.Add(Tail); FTailIndex:=Balloon.Tails.Count-1; FFirst:=False; FTool:=12; Changed;
end;

procedure RunWorkspaceTailClick(Form: TMainForm; const P: TPointF);
begin Form.ExecuteTailClick(P); end;
procedure TComicWorkspaceBalloonsHelper.ExecuteTailEditClick(const P: TPointF);
var Balloon: TComicBalloon; Tail: TComicTail; Handles: TArray<TPointF>; I,K: Integer; Best,Distance: Double; Region: HRGN;
begin
  if (FBalloonIndex<0) or (FBalloonIndex>=Page.Balloons.Count) then Exit; Balloon:=Page.Balloons[FBalloonIndex];
  FDragTailHandle:=0; Best:=MulDiv(9,CurrentPPI,96)/Max(0.001,FScale);
  for I:=0 to Balloon.Tails.Count-1 do begin
    Handles:=Balloon.Tails[I].Handles;
    for K:=0 to High(Handles) do begin Distance:=Hypot(Handles[K].X-P.X,Handles[K].Y-P.Y);
      if Distance<=Best then begin Best:=Distance; FTailIndex:=I; FDragTailHandle:=K+1; end;
    end;
  end;
  if FDragTailHandle=0 then begin
    for I:=Balloon.Tails.Count-1 downto 0 do begin Region:=TailRegion(Balloon.Tails[I],Point(0,0),1);
      try if PtInRegion(Region,Round(P.X),Round(P.Y)) then begin FTailIndex:=I; Break; end; finally Winapi.Windows.DeleteObject(Region); end;
    end;
    UpdateIconState; FCanvas.Invalidate; Exit;
  end;
  Tail:=Balloon.Tails[FTailIndex]; FDragTailState.Root:=Tail.Root; FDragTailState.Tip:=Tail.Tip; FDragTailState.Width:=Tail.Width;
  FStart:=P; FLast:=P; FDragSnapshot:=FProject.Snapshot; FDragMoved:=False; FDragging:=True; FDragHandle:=0;
  FDragMouse:=Point(FPageRect.Left+Round(P.X*FScale),FPageRect.Top+Round(P.Y*FScale));
  if not FTesting then FCanvas.MouseCapture:=True;
  UpdateIconState; FCanvas.Invalidate;
end;

procedure RunWorkspaceTailEditClick(Form: TMainForm; const P: TPointF);
begin Form.ExecuteTailEditClick(P); end;
procedure TComicWorkspaceBalloonsHelper.ExecuteDeleteTail(Sender: TObject);
begin
  if (Page=nil) or (FBalloonIndex<0) or (FTailIndex<0) or (FTailIndex>=Page.Balloons[FBalloonIndex].Tails.Count) then Exit;
  Checkpoint; Page.Balloons[FBalloonIndex].Tails.Delete(FTailIndex); FTailIndex:=Min(FTailIndex,Page.Balloons[FBalloonIndex].Tails.Count-1);
  if FTailIndex<0 then FTool:=0; Changed;
end;

procedure RunWorkspaceDeleteTail(Form: TMainForm; Sender: TObject);
begin Form.ExecuteDeleteTail(Sender); end;

procedure TComicWorkspaceBalloonsHelper.ExecuteSelectTextTool;
begin
  CancelDrag; ResetGeometryInput; FFirst:=False;
  if FTool=13 then FTextToolVertical:=not FTextToolVertical else FTextToolVertical:=True;
  FTool:=13; FBalloonControlsLoading:=True;
  try FVertical.Checked:=FTextToolVertical; finally FBalloonControlsLoading:=False; end;
  ActiveControl:=FView;
  ExecuteApplyText(FVertical);
  FStatus.SimpleText:='セリフ選択：クリックで入力、ドラッグで移動。四隅で文字サイズ、辺で文字間隔・行間隔。Tで縦横切替。';
  UpdateIconState; FCanvas.Invalidate;
end;

procedure TComicWorkspaceBalloonsHelper.ExecuteBalloonToolKey(var Key: Word; Shift: TShiftState);
var Tag: Integer; Role: TComicButtonRole; Button: TComicIconButton;
begin
  if (FTabs.ActivePageIndex<>3) or (Page=nil) or not (Shift<= [ssShift]) then Exit;
  if (Key=Ord('T')) and (Shift=[]) then begin SelectTextTool(nil); Key:=0; Exit; end;
  if (Key=VK_RETURN) and (Shift=[]) and (FTool=13) then begin BeginTextInput(nil); Key:=0; Exit; end;
  Role:=brTool; Tag:=-1;
  case Key of
    Ord('S'): if Shift=[] then Tag:=0;
    Ord('V'): if Shift=[] then begin Tag:=13; Role:=brTextPlacement; end;
    Ord('A'): if Shift=[] then begin Tag:=12; Role:=brTail; end;
    Ord('U'): begin
      if Shift=[] then case FTool of 10: Tag:=5; 5: Tag:=6; else Tag:=10; end
      else case FTool of 10: Tag:=6; 6: Tag:=5; else Tag:=10; end;
    end;
    Ord('P'): begin Role:=brTail; if FTool=7 then Tag:=11 else Tag:=7; end;
    VK_DELETE: if (Shift=[]) and (ActiveControl=FView) then begin
      if FTool=12 then begin Role:=brDeleteTail; Tag:=0; end
      else begin Role:=brDeleteBalloon; Tag:=1; end;
    end;
  end;
  if Tag<0 then Exit; UpdateIconState;
  for Button in FIconButtons do
    if (Button.Role=Role) and (Button.Tag=Tag) and
      ((Button.Context=3) or (Role in [brDeleteTail,brDeleteBalloon])) then begin
      if Button.Enabled then begin Button.Click; ActiveControl:=FView; end;
      Key:=0; Exit;
    end;
end;

procedure TComicWorkspaceBalloonsHelper.ExecuteStartInlineText;
begin
  if (Page=nil) or (FBalloonIndex<0) or (FBalloonIndex>=Page.Balloons.Count) then Exit;
  CancelDrag; LoadBalloonControls(Page.Balloons[FBalloonIndex]);
  if FInlineText=nil then begin
    FInlineText:=TComicInlineText.Create(Self); FInlineText.Parent:=FView;
    FInlineText.OnAccept:=InlineTextAccept; FInlineText.OnCancel:=InlineTextCancel;
    FInlineText.OnChange:=InlineTextChanged; FInlineText.OnLeave:=InlineTextLeave;
  end;
  FInlineProjectID:=FProject.ID; FInlinePageID:=Page.ID;
  FInlineText.Start(Page.Balloons[FBalloonIndex],FTextToolVertical,FTesting,FLastFontFamily,FFontHistory.LastSize);
  LoadBalloonControls(FInlineText.Preview);
  UpdateViewport; FInlineText.DrawOverlay(FCanvas.Canvas,FPageRect.TopLeft,FScale,FPageRect,Page);
  FInlineText.FocusInput;
  FStatus.SimpleText:='ページ上で文字編集：Enterは改行、Ctrl+Enterで確定、Escで取消。ドラッグ／Shift+矢印で範囲選択。';
  UpdateIconState; FCanvas.Invalidate;
end;

procedure TComicWorkspaceBalloonsHelper.StoreInlineText(Balloon: TComicBalloon);
var Before: string; Old: TJSONObject; Revision: Int64;
begin
  if (Balloon.Text=FInlineText.Text) and (Balloon.Vertical=FInlineText.Vertical) and
    (Balloon.FontFamily=FInlineText.Preview.FontFamily) and (Balloon.AutoWrap=FInlineText.Preview.AutoWrap) and
    (Balloon.FontSize=FInlineText.Preview.FontSize) and
    (Balloon.TextOffset=FInlineText.Preview.TextOffset) then Exit;
  // 手動改行では長い一行が作れるため、再読込できる座標範囲を保存前に確認する。
  if IsNan(FInlineText.Preview.TextOffset.X) or IsInfinite(FInlineText.Preview.TextOffset.X) or
    IsNan(FInlineText.Preview.TextOffset.Y) or IsInfinite(FInlineText.Preview.TextOffset.Y) or
    (Abs(FInlineText.Preview.TextOffset.X)>80000) or (Abs(FInlineText.Preview.TextOffset.Y)>80000) then
    raise Exception.Create('文字位置が保存範囲を超えています。文字サイズ・改行・位置を調整してください。');
  Before:=FProject.Snapshot; Old:=Balloon.Json; Revision:=Page.Revision;
  try
    Balloon.Text:=FInlineText.Text; Balloon.Vertical:=FInlineText.Vertical;
    Balloon.FontFamily:=FInlineText.Preview.FontFamily; Balloon.AutoWrap:=False;
    Balloon.FontSize:=FInlineText.Preview.FontSize;
    Balloon.TextOffset:=FInlineText.Preview.TextOffset;
    Balloon.TextLayoutSize:=FInlineText.Preview.TextLayoutSize;
    Balloon.TextLayoutFontSize:=FInlineText.Preview.TextLayoutFontSize;
    Inc(Page.Revision);
    try FProject.SaveDraft;
    except
      // 保存失敗で作品やUndoだけを先へ進めず、入力バッファを残して再試行可能にする。
      Balloon.Read(Old); Page.Revision:=Revision; raise;
    end;
    FUndo.Add(Before); if FUndo.Count>40 then FUndo.Delete(0);
    FRedo.Clear; FDirty:=True;
  finally Old.Free; end;
end;

procedure TComicWorkspaceBalloonsHelper.ExecuteFinishInlineText(Accept: Boolean);
var Balloon,Target: TComicBalloon;
begin
  if not InlineTextActive or FFinishingInline then Exit;
  FFinishingInline:=True;
  try
    Target:=nil;
    if (FProject<>nil) and (FProject.ID=FInlineProjectID) and (Page<>nil) and (Page.ID=FInlinePageID) then
      for Balloon in Page.Balloons do if Balloon.ID=FInlineText.Preview.ID then begin Target:=Balloon; Break; end;
    if Accept and (Target<>nil) then begin FInlineText.CompleteComposition; StoreInlineText(Target); end;
    FInlineSelecting:=False; FCanvas.MouseCapture:=False;
    FInlineText.EndSession; FInlineText.Visible:=False;
    if Target<>nil then begin
      if not FApplyingBalloonSettings then LoadBalloonControls(Target);
      if FTool=14 then FTool:=13;
    end;
    RefreshUI;
  finally FFinishingInline:=False; end;
end;

procedure RunWorkspaceBalloonToolKey(Form: TMainForm; var Key: Word; Shift: TShiftState);
begin Form.ExecuteBalloonToolKey(Key,Shift); end;
procedure RunWorkspaceSelectTextTool(Form: TMainForm);
begin Form.ExecuteSelectTextTool; end;
procedure RunWorkspaceStartInlineText(Form: TMainForm);
begin Form.ExecuteStartInlineText; end;
procedure RunWorkspaceFinishInlineText(Form: TMainForm; Accept: Boolean);
begin Form.ExecuteFinishInlineText(Accept); end;
end.
