unit ComicEffects;

// 責務：共通PNG素材と組込素材を管理し、既存作品が参照する実体を保持する。

interface

uses System.SysUtils, System.Generics.Collections, System.JSON, System.Types, Vcl.Graphics, ComicModel;

type
  TComicEffectMaterial = class
    ID,Name,FileName: string;
    BuiltIn: Boolean;
    constructor Create;
    function Json: TJSONObject;
    procedure Read(J: TJSONObject);
  end;

procedure SeedEffectMaterials(List: TObjectList<TComicEffectMaterial>);
procedure LoadEffectMaterials(List: TObjectList<TComicEffectMaterial>; const FileName: string);
procedure SaveEffectMaterials(List: TObjectList<TComicEffectMaterial>; const FileName: string);
function FindEffectMaterial(List: TObjectList<TComicEffectMaterial>; const ID: string): TComicEffectMaterial;
function EffectMaterialPath(Material: TComicEffectMaterial): string;
procedure EnsureBuiltInMaterialFiles(List: TObjectList<TComicEffectMaterial>);
function ImportEffectMaterial(List: TObjectList<TComicEffectMaterial>; const Name,Source,LibraryPath: string): TComicEffectMaterial;
procedure RenameEffectMaterial(List: TObjectList<TComicEffectMaterial>; Material: TComicEffectMaterial; const Name,LibraryPath: string);
procedure DeleteEffectMaterial(List: TObjectList<TComicEffectMaterial>; Material: TComicEffectMaterial; const LibraryPath: string);
function OverlayBounds(Panel: TComicPanel; Overlay: TComicOverlay): TRectF;
function FitEffectBounds(const PanelBounds: TRectF; ImageWidth,ImageHeight: Integer): TRectF;
procedure PreservePanelOverlays(Panel: TComicPanel; const OriginalBounds: TRectF; NewIDs: Boolean);

implementation

uses System.IOUtils, System.Math, Vcl.Imaging.pngimage;

constructor TComicEffectMaterial.Create;
begin inherited; ID:=NewUID; end;
function TComicEffectMaterial.Json: TJSONObject;
begin Result:=TJSONObject.Create; Result.AddPair('id',ID); Result.AddPair('name',Name); Result.AddPair('file',FileName); end;
procedure TComicEffectMaterial.Read(J: TJSONObject);
begin
  ID:=JStr(J,'id',''); Name:=Trim(JStr(J,'name','')); FileName:=JStr(J,'file','');
  if (ID='') or (Length(ID)>200) or (Name='') or (Length(Name)>200) or (FileName='') or (LowerCase(ExtractFileExt(FileName))<>'.png') then
    raise Exception.Create('効果素材の登録情報が不正です。');
  if ID.StartsWith('builtin-') then raise Exception.Create('組込素材のIDは変更できません。');
  SafeChild(TPath.Combine(DataRoot,'Effects'),FileName);
end;
function FindEffectMaterial(List: TObjectList<TComicEffectMaterial>; const ID: string): TComicEffectMaterial;
var Material: TComicEffectMaterial;
begin Result:=nil; for Material in List do if Material.ID=ID then Exit(Material); end;
function EffectMaterialPath(Material: TComicEffectMaterial): string;
begin Result:=''; if Material<>nil then Result:=SafeChild(TPath.Combine(DataRoot,'Effects'),Material.FileName); end;
procedure SeedEffectMaterials(List: TObjectList<TComicEffectMaterial>);
var Material: TComicEffectMaterial; I: Integer;
begin
  for I:=0 to 2 do begin Material:=TComicEffectMaterial.Create; Material.BuiltIn:=True; List.Add(Material);
    case I of
      0: begin Material.ID:='builtin-focus'; Material.Name:='集中線'; Material.FileName:='builtin-focus.png'; end;
      1: begin Material.ID:='builtin-speed'; Material.Name:='スピード線'; Material.FileName:='builtin-speed.png'; end;
      2: begin Material.ID:='builtin-sparkle'; Material.Name:='キラキラ'; Material.FileName:='builtin-sparkle.png'; end;
    end;
  end;
end;
procedure SaveEffectMaterials(List: TObjectList<TComicEffectMaterial>; const FileName: string);
var Root: TJSONObject; Items: TJSONArray; Material: TComicEffectMaterial;
begin
  Root:=TJSONObject.Create;
  try Root.AddPair('version',TJSONNumber.Create(1)); Items:=TJSONArray.Create; Root.AddPair('materials',Items);
    for Material in List do if not Material.BuiltIn then Items.AddElement(Material.Json); AtomicWrite(FileName,Root.ToJSON);
  finally Root.Free; end;
end;
procedure LoadEffectMaterials(List: TObjectList<TComicEffectMaterial>; const FileName: string);
var Value,Entry: TJSONValue; Root: TJSONObject; Items: TJSONArray; Material: TComicEffectMaterial; Prepared: TObjectList<TComicEffectMaterial>; IDs: TDictionary<string,Boolean>;
begin
  if not FileExists(FileName) then Exit; Value:=nil; Prepared:=TObjectList<TComicEffectMaterial>.Create; IDs:=TDictionary<string,Boolean>.Create;
  try
    Value:=TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName,TEncoding.UTF8));
    if not (Value is TJSONObject) then raise Exception.Create('効果素材ライブラリが不正です。'); Root:=TJSONObject(Value);
    if JNum(Root,'version',0)<>1 then raise Exception.Create('未対応の効果素材形式です。'); Items:=Root.GetValue<TJSONArray>('materials');
    if Items=nil then raise Exception.Create('効果素材一覧がありません。');
    for Material in List do IDs.Add(Material.ID,True);
    for Entry in Items do begin
      if not (Entry is TJSONObject) then raise Exception.Create('効果素材の項目が不正です。');
      Material:=TComicEffectMaterial.Create; Prepared.Add(Material); Material.Read(TJSONObject(Entry));
      if IDs.ContainsKey(Material.ID) then raise Exception.Create('効果素材IDが重複しています。'); IDs.Add(Material.ID,True);
    end;
    while Prepared.Count>0 do List.Add(Prepared.Extract(Prepared[0]));
  finally IDs.Free; Prepared.Free; Value.Free; end;
end;
procedure GenerateMaterial(Material: TComicEffectMaterial);
var Bitmap: TBitmap; PNG: TPngImage; I,X,Y,CX,CY,Saved: Integer; Angle,Radius: Double; Name,Temp: string; Row: PByteArray;
  procedure Star(PX,PY,Size: Integer);
  begin Bitmap.Canvas.MoveTo(PX-Size,PY); Bitmap.Canvas.LineTo(PX+Size,PY); Bitmap.Canvas.MoveTo(PX,PY-Size); Bitmap.Canvas.LineTo(PX,PY+Size);
    Bitmap.Canvas.MoveTo(PX-Size div 2,PY-Size div 2); Bitmap.Canvas.LineTo(PX+Size div 2,PY+Size div 2);
    Bitmap.Canvas.MoveTo(PX-Size div 2,PY+Size div 2); Bitmap.Canvas.LineTo(PX+Size div 2,PY-Size div 2); end;
begin
  Name:=EffectMaterialPath(Material); if FileExists(Name) then Exit;
  Bitmap:=TBitmap.Create; PNG:=TPngImage.Create;
  try
    Bitmap.PixelFormat:=pf24bit; Bitmap.SetSize(512,512); Bitmap.Canvas.Brush.Color:=clWhite; Bitmap.Canvas.FillRect(Rect(0,0,512,512));
    Bitmap.Canvas.Pen.Color:=clBlack; Bitmap.Canvas.Pen.Width:=2;
    if Material.ID='builtin-focus' then for I:=0 to 119 do begin
      Angle:=I*2*Pi/120; Radius:=130+(I mod 7)*9;
      Bitmap.Canvas.MoveTo(256+Round(Cos(Angle)*Radius),256+Round(Sin(Angle)*Radius));
      Bitmap.Canvas.LineTo(256+Round(Cos(Angle)*400),256+Round(Sin(Angle)*400));
    end else if Material.ID='builtin-speed' then for I:=0 to 27 do begin
      Y:=I*19; Bitmap.Canvas.Pen.Width:=1+I mod 3; X:=(I*71) mod 180;
      Bitmap.Canvas.MoveTo(X,Y); Bitmap.Canvas.LineTo(512-((I*43) mod 180),Y-22);
    end else begin
      for I:=0 to 10 do begin CX:=40+(I*137) mod 440; CY:=40+(I*193) mod 440; Star(CX,CY,12+(I mod 3)*8); end;
    end;
    PNG.Assign(Bitmap); PNG.CreateAlpha;
    for Y:=0 to 511 do begin Row:=PNG.Scanline[Y]; for X:=0 to 511 do PNG.AlphaScanline[Y]^[X]:=255-Row^[X*3]; end;
    ForceDirectories(ExtractFilePath(Name)); Temp:=Name+'.'+NewUID+'.tmp'; Saved:=0;
    try PNG.SaveToFile(Temp); TFile.Move(Temp,Name); Saved:=1;
    finally if (Saved=0) and FileExists(Temp) then TFile.Delete(Temp); end;
  finally PNG.Free; Bitmap.Free; end;
end;
procedure EnsureBuiltInMaterialFiles(List: TObjectList<TComicEffectMaterial>);
var Material: TComicEffectMaterial;
begin for Material in List do if Material.BuiltIn then GenerateMaterial(Material); end;
function ImportEffectMaterial(List: TObjectList<TComicEffectMaterial>; const Name,Source,LibraryPath: string): TComicEffectMaterial;
var PNG: TPngImage; Path: string; Copied: Boolean;
begin
  if (Trim(Name)='') or (Length(Trim(Name))>200) then raise Exception.Create('効果素材名を指定してください。');
  if LowerCase(ExtractFileExt(Source))<>'.png' then raise Exception.Create('PNG素材を指定してください。'); PNG:=TPngImage.Create;
  try PNG.LoadFromFile(Source); if (PNG.Width<1) or (PNG.Height<1) or (Int64(PNG.Width)*PNG.Height>64000000) then raise Exception.Create('素材画像のサイズが不正です。');
  finally PNG.Free; end;
  Result:=TComicEffectMaterial.Create; Result.Name:=Trim(Name); Result.FileName:=Result.ID+'.png'; Path:=EffectMaterialPath(Result); Copied:=False;
  try
    ForceDirectories(ExtractFilePath(Path)); TFile.Copy(Source,Path,False); Copied:=True; List.Add(Result);
    try SaveEffectMaterials(List,LibraryPath); except List.Extract(Result); raise; end;
  except Result.Free; if Copied and FileExists(Path) then TFile.Delete(Path); raise; end;
end;
procedure RenameEffectMaterial(List: TObjectList<TComicEffectMaterial>; Material: TComicEffectMaterial; const Name,LibraryPath: string);
var Before: string;
begin
  if (Material=nil) or (List.IndexOf(Material)<0) or Material.BuiltIn then raise Exception.Create('組込素材は変更できません。');
  if (Trim(Name)='') or (Length(Trim(Name))>200) then raise Exception.Create('素材名を指定してください。'); Before:=Material.Name; Material.Name:=Trim(Name);
  try SaveEffectMaterials(List,LibraryPath); except Material.Name:=Before; raise; end;
end;
procedure DeleteEffectMaterial(List: TObjectList<TComicEffectMaterial>; Material: TComicEffectMaterial; const LibraryPath: string);
var At: Integer;
begin
  if (Material=nil) or Material.BuiltIn then raise Exception.Create('組込素材は削除できません。'); At:=List.IndexOf(Material); if At<0 then Exit;
  List.Extract(Material); try SaveEffectMaterials(List,LibraryPath); except List.Insert(At,Material); raise; end;
  // 登録項目を外してもPNGは残し、既存作品が保存済みの素材IDで描画できるようにする。
  Material.Free;
end;
function OverlayBounds(Panel: TComicPanel; Overlay: TComicOverlay): TRectF;
begin Result:=TRectF.Create(Panel.Bounds.Left+Overlay.Bounds.Left*Panel.Bounds.Width,Panel.Bounds.Top+Overlay.Bounds.Top*Panel.Bounds.Height,
  Panel.Bounds.Left+Overlay.Bounds.Right*Panel.Bounds.Width,Panel.Bounds.Top+Overlay.Bounds.Bottom*Panel.Bounds.Height); end;
function FitEffectBounds(const PanelBounds: TRectF; ImageWidth,ImageHeight: Integer): TRectF;
var Scale,W,H: Double;
begin
  if (PanelBounds.Width<=0) or (PanelBounds.Height<=0) or (ImageWidth<=0) or (ImageHeight<=0) then
    raise Exception.Create('素材または配置先のコマの寸法が不正です。');
  Scale:=Min(1,Min(PanelBounds.Width/ImageWidth,PanelBounds.Height/ImageHeight));
  W:=ImageWidth*Scale/PanelBounds.Width; H:=ImageHeight*Scale/PanelBounds.Height;
  Result:=TRectF.Create((1-W)/2,(1-H)/2,(1+W)/2,(1+H)/2);
end;
procedure PreservePanelOverlays(Panel: TComicPanel; const OriginalBounds: TRectF; NewIDs: Boolean);
var Overlay: TComicOverlay; R: TRectF;
begin
  for Overlay in Panel.Overlays do begin
    R:=TRectF.Create(OriginalBounds.Left+Overlay.Bounds.Left*OriginalBounds.Width,OriginalBounds.Top+Overlay.Bounds.Top*OriginalBounds.Height,
      OriginalBounds.Left+Overlay.Bounds.Right*OriginalBounds.Width,OriginalBounds.Top+Overlay.Bounds.Bottom*OriginalBounds.Height);
    Overlay.Bounds:=TRectF.Create((R.Left-Panel.Bounds.Left)/Panel.Bounds.Width,(R.Top-Panel.Bounds.Top)/Panel.Bounds.Height,
      (R.Right-Panel.Bounds.Left)/Panel.Bounds.Width,(R.Bottom-Panel.Bounds.Top)/Panel.Bounds.Height);
    if NewIDs then Overlay.ID:=NewUID;
  end;
end;

end.
