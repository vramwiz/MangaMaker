unit ComicOverlayDrawing;

// 責務：透明PNGを原本のまま保持し、回転時だけGDI+でアルファ合成する。ファイルをロックし続けない。
interface
uses Winapi.ActiveX, Winapi.GDIPOBJ, System.Types, System.Generics.Collections,
  Vcl.Graphics, Vcl.Imaging.pngimage;
type
  TComicOverlayImage = class
  private
    FPng: TPngImage;
    FNative: TGPBitmap;
    FStream: IStream;
    function Native: TGPBitmap;
  public
    constructor Create(const FileName: string);
    destructor Destroy; override;
    procedure Draw(Canvas: TCanvas; const Target: TRect; Angle: Double);
  end;
  TComicOverlayImages = TObjectDictionary<string,TComicOverlayImage>;
implementation
uses Winapi.Windows, Winapi.GDIPAPI, System.SysUtils, System.Classes, ComicOverlayTransform;
constructor TComicOverlayImage.Create(const FileName: string);
begin inherited Create; FPng:=TPngImage.Create; FPng.LoadFromFile(FileName); end;
destructor TComicOverlayImage.Destroy;
begin FNative.Free; FStream:=nil; FPng.Free; inherited; end;
function TComicOverlayImage.Native: TGPBitmap;
var Buffer: TMemoryStream;
begin
  if FNative=nil then begin
    Buffer:=TMemoryStream.Create;
    try FPng.SaveToStream(Buffer); Buffer.Position:=0; except Buffer.Free; raise; end;
    FStream:=TStreamAdapter.Create(Buffer,soOwned) as IStream;
    FNative:=TGPBitmap.Create(FStream);
    if FNative.GetLastStatus<>Ok then begin FreeAndNil(FNative); FStream:=nil; raise Exception.Create('回転用の効果画像を読み込めません。'); end;
  end;
  Result:=FNative;
end;
procedure TComicOverlayImage.Draw(Canvas: TCanvas; const Target: TRect; Angle: Double);
var Graphics: TGPGraphics; Region: HRGN; Points: array[0..2] of TGPPointF;
  P,Center: TPointF; I: Integer; Image: TGPBitmap;
begin
  if (Target.Width<=0) or (Target.Height<=0) then Exit;
  if Abs(Angle)<0.000001 then begin Canvas.StretchDraw(Target,FPng); Exit; end;
  Image:=Native; Center:=TPointF.Create((Target.Left+Target.Right)/2,(Target.Top+Target.Bottom)/2);
  for I:=0 to 2 do begin
    case I of
      0: P:=TPointF.Create(Target.Left,Target.Top);
      1: P:=TPointF.Create(Target.Right,Target.Top);
      else P:=TPointF.Create(Target.Left,Target.Bottom);
    end;
    P:=RotateOverlayPoint(P,Center,Angle); Points[I].X:=P.X; Points[I].Y:=P.Y;
  end;
  // GDI+がDC原点を引き継ぐので座標を二重に変換しない。コマのクリップはデバイス領域で渡す。
  Region:=CreateRectRgn(0,0,0,0); Graphics:=TGPGraphics.Create(Canvas.Handle);
  try
    Graphics.SetPageUnit(UnitPixel);
    if GetClipRgn(Canvas.Handle,Region)=1 then Graphics.SetClip(Region);
    Graphics.SetInterpolationMode(InterpolationModeHighQualityBicubic);
    if Graphics.DrawImage(Image,@Points[0],3,0,0,Image.GetWidth,Image.GetHeight,UnitPixel)<>Ok then
      raise Exception.Create('効果画像を回転描画できません。');
  finally Graphics.Free; DeleteObject(Region); end;
end;
end.
