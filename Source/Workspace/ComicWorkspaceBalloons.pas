unit ComicWorkspaceBalloons;

// 責務：吹き出しの文字・しっぽ設定を操作し、本体との所属と配置を保持する。
interface
uses ComicTextInput, MangaMakerMainForm, System.Types, ComicModel;
procedure RunWorkspaceApplyText(Form: TMainForm; Sender: TObject);
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
implementation
uses Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.Imm, System.SysUtils, System.Classes, System.UITypes, System.Math, System.IOUtils, System.Generics.Collections, System.JSON, System.Hash, System.DateUtils, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus, Vcl.Dialogs, Vcl.Graphics, Vcl.Imaging.pngimage, ComicRender;
type
  TComicWorkspaceBalloonsHelper = class helper for TMainForm
    procedure ExecuteApplyText(Sender: TObject);
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
  end;
procedure TComicWorkspaceBalloonsHelper.ExecuteApplyText(Sender: TObject);
var B: TComicBalloon; OldText,OldFamily: string; OldVertical: Boolean; OldStyle: TFontStyles;
begin
  if (Page=nil) or (FBalloonIndex<0) then Exit; Checkpoint; B:=Page.Balloons[FBalloonIndex];
  OldText:=B.Text; OldFamily:=B.FontFamily; OldVertical:=B.Vertical; OldStyle:=B.FontStyle;
  B.Text:=FText.Text; B.Vertical:=FVertical.Checked; B.Transparent:=FTransparent.Checked;
  B.Overflow:=FOverflow.Checked; B.FontSize:=StrToIntDef(FFont.Text,40);
  B.FontFamily:=FFontFamily.Text; if B.FontFamily='' then B.FontFamily:='Yu Gothic'; B.FontColor:=FTextColor; B.FontStyle:=[];
  if FFontBold.Checked then Include(B.FontStyle,fsBold); if FFontItalic.Checked then Include(B.FontStyle,fsItalic);
  if FFontUnderline.Checked then Include(B.FontStyle,fsUnderline); if FFontStrikeOut.Checked then Include(B.FontStyle,fsStrikeOut);
  if (B.Text<>OldText) or (B.FontFamily<>OldFamily) or (B.Vertical<>OldVertical) or (B.FontStyle<>OldStyle) then B.ResetTextLayout;
  B.FillColor:=FFillColor; B.BorderColor:=FBorderColor; B.BorderWidth:=StrToFloatDef(FBorderWidth.Text,3);
  B.Contour:=TComicBalloonContour(Max(0,FContour.ItemIndex));
  Changed;
  if FFontHistoryWritable then
    try FFontHistory.Remember(B.FontFamily,TPath.Combine(DataRoot,'Presets\FontHistory.json'));
    except on E: Exception do begin FFontHistoryWritable:=False; FStatus.SimpleText:='文字は反映しました。フォント履歴の保存に失敗しました：'+E.Message; end; end;
end;

procedure RunWorkspaceApplyText(Form: TMainForm; Sender: TObject);
begin Form.ExecuteApplyText(Sender); end;
procedure TComicWorkspaceBalloonsHelper.ExecuteLoadBalloonControls(Balloon: TComicBalloon);
var Index: Integer;
begin
  FText.Text:=Balloon.Text; FVertical.Checked:=Balloon.Vertical; FTransparent.Checked:=Balloon.Transparent; FOverflow.Checked:=Balloon.Overflow;
  FContour.ItemIndex:=Ord(Balloon.Contour);
  Index:=FFont.Items.IndexOf(IntToStr(Balloon.FontSize)); if Index<0 then Index:=FFont.Items.Add(IntToStr(Balloon.FontSize)); FFont.ItemIndex:=Index;
  Index:=FFontFamily.Items.IndexOf(Balloon.FontFamily); if Index<0 then Index:=FFontFamily.Items.Add(Balloon.FontFamily); FFontFamily.ItemIndex:=Index;
  FTextColor:=Balloon.FontColor; FFontBold.Checked:=fsBold in Balloon.FontStyle; FFontItalic.Checked:=fsItalic in Balloon.FontStyle;
  FFontUnderline.Checked:=fsUnderline in Balloon.FontStyle; FFontStrikeOut.Checked:=fsStrikeOut in Balloon.FontStyle;
  FFillColor:=Balloon.FillColor; FBorderColor:=Balloon.BorderColor;
  Index:=FBorderWidth.Items.IndexOf(FloatToStr(Balloon.BorderWidth)); if Index<0 then Index:=FBorderWidth.Items.Add(FloatToStr(Balloon.BorderWidth)); FBorderWidth.ItemIndex:=Index;
end;

procedure RunWorkspaceLoadBalloonControls(Form: TMainForm; Balloon: TComicBalloon);
begin Form.ExecuteLoadBalloonControls(Balloon); end;
procedure TComicWorkspaceBalloonsHelper.ExecuteFontDropDown(Sender: TObject);
var Current: string; Index: Integer;
begin
  Current:=FFontFamily.Text; FFontFamily.Items.BeginUpdate;
  try
    FFontFamily.Items.Clear; FFontFamily.Items.AddStrings(FFontHistory.Choices(Screen.Fonts));
    if Current<>'' then begin Index:=FFontFamily.Items.IndexOf(Current); if Index<0 then Index:=FFontFamily.Items.Add(Current); FFontFamily.ItemIndex:=Index; end;
  finally FFontFamily.Items.EndUpdate; end;
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
    Dialog.Options:=[cdFullOpen]; if Dialog.Execute then
      case Tag of 1: FFillColor:=Dialog.Color; 2: FBorderColor:=Dialog.Color; else FTextColor:=Dialog.Color; end;
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
begin
  if Dialog.ModalResult=mrOK then begin FText.Text:=Dialog.Editor.Text; ApplyText(nil); end;
end;

procedure RunWorkspaceFinishTextDialog(Form: TMainForm; Dialog: TComicTextDialog);
begin Form.ExecuteFinishTextDialog(Dialog); end;
procedure TComicWorkspaceBalloonsHelper.ExecuteTail(Sender: TObject);
begin
  if FBalloonIndex<0 then begin Notify('先に吹き出しを選択してください。'); Exit; end;
  CancelDrag; ResetGeometryInput; FTool:=TControl(Sender).Tag; FFirst:=False;
  if FTool=12 then begin FTailIndex:=Page.Balloons[FBalloonIndex].Tails.Count-1; FStatus.SimpleText:='しっぽをクリック。3点で根元・幅・先端を編集。削除は右のボタン。'; end
  else FStatus.SimpleText:='根元を本体内でクリックし、次に先端位置をクリックしてください。';
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
end.
