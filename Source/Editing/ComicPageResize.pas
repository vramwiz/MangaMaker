unit ComicPageResize;

// 責務：解像度変更をページ中心基準の相似変換へまとめ、全ページを検証した結果だけを返す。
interface
uses System.Types, ComicModel;
function PreparePageBasisChange(Project: TComicProject; const Basis: TComicPageBasis): string;
implementation
uses System.SysUtils, System.Math;
type
  TPageTransform = record
    Scale: Double;
    OldCenter,NewCenter: TPointF;
    function Map(const P: TPointF): TPointF;
    function MapRect(const R: TRectF): TRectF;
    procedure Panel(Value: TComicPanel);
    procedure Balloon(Value: TComicBalloon);
  end;
function TPageTransform.Map(const P: TPointF): TPointF;
begin Result:=TPointF.Create(NewCenter.X+(P.X-OldCenter.X)*Scale,NewCenter.Y+(P.Y-OldCenter.Y)*Scale); end;
function TPageTransform.MapRect(const R: TRectF): TRectF;
begin
  Result:=TRectF.Create(Map(R.TopLeft),Map(R.BottomRight));
  if (Result.Width<1) or (Result.Height<1) or
    (Abs(Result.Left)>80000) or (Abs(Result.Top)>80000) or (Abs(Result.Right)>80000) or (Abs(Result.Bottom)>80000) then
    raise Exception.Create('変更後のコマまたは吹き出しが小さすぎるか、保存できる座標範囲を超えます。');
end;
procedure TPageTransform.Panel(Value: TComicPanel);
var Points: TArray<TPointF>; I: Integer; Target: TRectF;
begin
  Target:=MapRect(Value.Bounds);
  if Value.Shape=3 then begin
    Points:=Copy(Value.Vertices); for I:=0 to High(Points) do Points[I]:=Map(Points[I]);
    Value.SetVertices(Points);
  end else Value.Bounds:=Target;
  // Zoomと効果の正規化座標は比率なので維持する。Cover倍率はコマと同率で変わる。
  Value.PanX:=Value.PanX*Scale; Value.PanY:=Value.PanY*Scale;
  Value.BorderWidth:=Value.BorderWidth*Scale; Value.FrameGap:=Value.FrameGap*Scale;
end;
procedure TPageTransform.Balloon(Value: TComicBalloon);
begin
  // 入力編集用の通常拡縮とは分け、ページ変更では文字・相対位置・全しっぽも一緒に変換する。
  if not Value.ApplyTransform(Value.CaptureTransform,MapRect(Value.Bounds),True) then
    raise Exception.Create('変更後の吹き出し・文字位置・しっぽが保存できる範囲を超えます。');
  Value.BorderWidth:=Value.BorderWidth*Scale;
end;
function PreparePageBasisChange(Project: TComicProject; const Basis: TComicPageBasis): string;
var Candidate,Validation: TComicProject; Transform: TPageTransform; Page: TComicPage;
  Panel: TComicPanel; Balloon: TComicBalloon;
begin
  if not Basis.Valid then raise Exception.Create('出力解像度またはページ外枠の余白が不正です。');
  Candidate:=TComicProject.Create; Validation:=nil;
  try
    Candidate.Folder:=Project.Folder; Candidate.Restore(Project.Snapshot);
    if (Project.Width<>Basis.Width) or (Project.Height<>Basis.Height) then begin
      Transform.Scale:=Min(Basis.Width/Project.Width,Basis.Height/Project.Height);
      Transform.OldCenter:=TPointF.Create(Project.Width/2,Project.Height/2);
      Transform.NewCenter:=TPointF.Create(Basis.Width/2,Basis.Height/2);
      for Page in Candidate.Pages do begin
        for Panel in Page.Panels do Transform.Panel(Panel);
        for Balloon in Page.Balloons do Transform.Balloon(Balloon);
        Inc(Page.Revision); Page.OutputRevision:=-1;
      end;
    end;
    Candidate.SetPageBasis(Basis); Result:=Candidate.Snapshot;
    // 線幅や文字組版も含め、保存後に再読込できることを公開前に確認する。実作品や履歴はまだ触らない。
    Validation:=TComicProject.Create; Validation.Folder:=Project.Folder; Validation.Restore(Result);
  finally Validation.Free; Candidate.Free; end;
end;
end.
