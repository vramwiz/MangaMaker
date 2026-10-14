unit ComicEffectRegistration;

// 責務：受信したPNGを検証して共通素材へ登録し、保存失敗で元画像を消さない。
interface
uses System.Generics.Collections, ComicEffects;
function AdoptPreparedEffect(List: TObjectList<TComicEffectMaterial>; const Name,Relative,LibraryPath: string;
  RequireTransparency: Boolean): TComicEffectMaterial;
function ImportDroppedEffect(List: TObjectList<TComicEffectMaterial>; const Source,LibraryPath: string): TComicEffectMaterial;
function ComicEffectPrompt(const Instruction: string): string;
implementation
uses System.SysUtils, System.IOUtils, Vcl.Imaging.pngimage, ComicModel, ComicImageAdoption;
function ComicEffectPrompt(const Instruction: string): string;
begin
  if Trim(Instruction)='' then raise Exception.Create('作りたい効果をメモへ入力してください。');
  Result:='漫画のコマに重ねて使う効果素材を1枚生成してください。横4:縦3。PNG、透明背景（transparent_background=true）。'+sLineBreak+
    '黒い線や形を主体に、漫画の絵やセリフを隠しすぎない素材にしてください。写真・背景風景・人物・説明文字・外枠・透かしは不要です。'+sLineBreak+
    '集中線は中央に余白を残す、スピード線は方向を揃えるなど、次の短い指示に合わせて使いやすい漫画効果に仕上げてください。'+sLineBreak+
    '透明部分は実際のアルファで保存し、市松模様や白背景を画像に描き込まないでください。'+sLineBreak+'作りたい効果：'+Trim(Instruction);
end;
function AdoptPreparedEffect(List: TObjectList<TComicEffectMaterial>; const Name,Relative,LibraryPath: string;
  RequireTransparency: Boolean): TComicEffectMaterial;
var Path: string; PNG: TPngImage; X,Y: Integer; Transparent: Boolean;
begin
  if (Trim(Name)='') or (Length(Trim(Name))>200) then raise Exception.Create('素材名が不正です。');
  if not SameText(ExtractFileExt(Relative),'.png') then raise Exception.Create('生成結果は透明PNGで登録してください。');
  Path:=SafeChild(TPath.Combine(DataRoot,'Effects'),Relative); ValidateComicImage(Path);
  if RequireTransparency then begin
    PNG:=TPngImage.Create;
    try
      PNG.LoadFromFile(Path); Transparent:=False;
      for Y:=0 to PNG.Height-1 do begin
        if PNG.AlphaScanline[Y]=nil then Break;
        for X:=0 to PNG.Width-1 do if PNG.AlphaScanline[Y]^[X]<255 then begin Transparent:=True; Break; end;
        if Transparent then Break;
      end;
      if not Transparent then raise Exception.Create('生成画像に透明部分がありません。透明背景の効果を指定して再送してください。');
    finally PNG.Free; end;
  end;
  Result:=TComicEffectMaterial.Create; Result.Name:=Trim(Name); Result.FileName:=Relative;
  List.Add(Result);
  try SaveEffectMaterials(List,LibraryPath);
  except List.Remove(Result); raise; end;
end;
function ImportDroppedEffect(List: TObjectList<TComicEffectMaterial>; const Source,LibraryPath: string): TComicEffectMaterial;
var Relative,Root: string;
begin
  if not SameText(ExtractFileExt(Source),'.png') then raise Exception.Create('PNG素材をドロップしてください。');
  Root:=TPath.Combine(DataRoot,'Effects'); Relative:=CopyValidatedComicImage(Source,Root,'imported-');
  try Result:=AdoptPreparedEffect(List,TPath.GetFileNameWithoutExtension(Source),Relative,LibraryPath,False);
  // 消すのは今回作成したコピーだけ。元ファイルや既存の素材には触れない。
  except TFile.Delete(SafeChild(Root,Relative)); raise; end;
end;
end.
