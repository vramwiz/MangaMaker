unit ComicScriptPlan;

// 責務：台本の人物指定と登録済みの人物・服装参照を照合する。
interface
uses System.SysUtils, System.Generics.Collections, ComicScript, ComicModel;
function ResolveScriptCharacter(Characters: TObjectList<TComicAsset>; Definition, Image: TScriptItem;
  out Error: string): TComicAsset;
implementation
uses System.IOUtils;

function ResolveScriptCharacter(Characters: TObjectList<TComicAsset>; Definition, Image: TScriptItem;
  out Error: string): TComicAsset;
var A: TComicAsset; Name,State,ExplicitID: string; Count: Integer;
begin
  Result:=nil; Error:='';
  if Characters=nil then begin Error:='登録人物の参照がありません。'; Exit; end;
  if Definition=nil then begin Error:='人物定義がありません。'; Exit; end;
  if Definition.Problems.Count>0 then begin Error:=Definition.ID+'：人物定義を確認してください。'; Exit; end;
  Name:=Definition.Get('登録名',Definition.ID); State:=Definition.Get('状態名'); ExplicitID:=Definition.Get('参照ID');
  if Image<>nil then State:=Image.Get(Definition.ID+'.状態名',State);
  Count:=0;
  for A in Characters do begin
    if (ExplicitID<>'') and ((Image=nil) or (Image.Get(Definition.ID+'.状態名')='')) then begin
      if A.ID<>ExplicitID then Continue;
    end else begin
      if (A.CharacterName<>Name) and not ((A.CharacterName='') and (A.Name=Name)) then Continue;
      if State<>'' then begin if A.StateName<>State then Continue; end
      else if A.ParentID<>'' then Continue;
    end;
    Inc(Count); Result:=A;
  end;
  if Count<>1 then begin Result:=nil; Error:=Definition.ID+'：登録名「'+Name+'」状態「'+State+'」に一致する参照が'+IntToStr(Count)+'件です。'; Exit; end;
  if (Result.ImageFile='') or not FileExists(SafeChild(TPath.Combine(DataRoot,'Characters'),Result.ImageFile)) then begin
    Result:=nil; Error:=Definition.ID+'：参照画像がありません。';
  end;
end;

end.
