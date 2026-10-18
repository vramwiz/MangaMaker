unit ComicScript;

// 責務：台本の専用テキストを読み、行番号と参照を保持する。作品や生成結果は変更しない。
interface
uses System.SysUtils, System.Classes, System.Generics.Collections;
type
  TScriptKind = (skWork, skCharacter, skBackground, skAlternate, skImage, skDialogue, skEffect, skOnomatopoeia);
  TScriptItem = class
  public
    Kind: TScriptKind;
    ID, Name: string;
    Line, Page: Integer;
    Fields, Problems: TStringList;
    constructor Create(AKind: TScriptKind; const AID: string; ALine, APage: Integer);
    destructor Destroy; override;
    function Get(const Key: string; const Default: string = ''): string;
    procedure Put(const Key, Value: string);
    function Description: string;
  end;
  TComicScript = class
  public
    Work: TScriptItem;
    Items: TObjectList<TScriptItem>;
    Errors, Warnings, FatalErrors: TStringList;
    Source: string;
    constructor Create;
    destructor Destroy; override;
    function Find(const ID: string): TScriptItem;
    function FindCharacter(const Alias: string): TScriptItem;
    procedure Read(const Text: string);
    procedure Validate;
  end;
function ScriptNames(const Text: string): TArray<string>;
function ScriptHasName(const Text, Name: string): Boolean;
implementation
uses System.RegularExpressions;

function ScriptNames(const Text: string): TArray<string>;
var L: TList<string>; S: string;
begin
  L:=TList<string>.Create;
  try
    for S in Text.Replace(',', '、').Split(['、']) do
      if (Trim(S)<>'') and (Trim(S)<>'なし') then L.Add(Trim(S));
    Result:=L.ToArray;
  finally L.Free; end;
end;
function ScriptHasName(const Text, Name: string): Boolean;
var S: string;
begin Result:=False; for S in ScriptNames(Text) do if S=Name then Exit(True); end;
constructor TScriptItem.Create(AKind: TScriptKind; const AID: string; ALine, APage: Integer);
begin
  inherited Create; Kind:=AKind; ID:=AID; Line:=ALine; Page:=APage;
  Fields:=TStringList.Create; Fields.NameValueSeparator:=#9; Fields.CaseSensitive:=True;
  Problems:=TStringList.Create;
end;
destructor TScriptItem.Destroy;
begin Problems.Free; Fields.Free; inherited; end;
function TScriptItem.Get(const Key, Default: string): string;
var I: Integer;
begin I:=Fields.IndexOfName(Key); if I<0 then Result:=Default else Result:=Fields.ValueFromIndex[I]; end;
procedure TScriptItem.Put(const Key, Value: string);
begin Fields.Values[Key]:=Value; end;
function TScriptItem.Description: string;
var I: Integer;
begin
  Result:=Name;
  for I:=0 to Fields.Count-1 do Result:=Result+sLineBreak+Fields.Names[I]+'：'+Fields.ValueFromIndex[I];
end;
constructor TComicScript.Create;
begin
  inherited; Work:=TScriptItem.Create(skWork,'',1,0); Items:=TObjectList<TScriptItem>.Create;
  Errors:=TStringList.Create; Warnings:=TStringList.Create; FatalErrors:=TStringList.Create;
end;
destructor TComicScript.Destroy;
begin Work.Free; Items.Free; Errors.Free; Warnings.Free; FatalErrors.Free; inherited; end;
function TComicScript.Find(const ID: string): TScriptItem;
var Item: TScriptItem;
begin Result:=nil; for Item in Items do if Item.ID=ID then Exit(Item); end;

function TComicScript.FindCharacter(const Alias: string): TScriptItem;
var Item: TScriptItem; Name,Canonical: string;
begin
  Result:=Find(Alias); if Result<>nil then Exit;
  Canonical:=Alias;
  if Canonical.StartsWith('他の') then Delete(Canonical,1,Length('他の'));
  if Canonical.EndsWith('たち') then Delete(Canonical,Length(Canonical)-Length('たち')+1,Length('たち'));
  // 箇条書きのモブ集約名だけを展開する。登録人物の名前を曖昧に照合しない。
  for Item in Items do if (Item.Kind=skCharacter) and (Item.Get('参照方式')='説明のみ') and
    (Item.ID.Contains('・') or Item.ID.Contains('、')) then
    for Name in ScriptNames(Item.ID.Replace('・','、')) do if (Name=Alias) or (Name=Canonical) then begin
      if (Result<>nil) and (Result<>Item) then Exit(nil);
      Result:=Item; Break;
    end;
end;

procedure TComicScript.Read(const Text: string);
var Lines: TStringList; Current, Item: TScriptItem; S,K,V,Background,Image,Multiline: string;
  I,P,N,PageNumber: Integer; Kind: TScriptKind; M: TMatch; PersonScope: string; Bracketed,InCast: Boolean;
  procedure ParseProblem(const Message: string);
  begin Errors.Add(Message); Current.Problems.Add(Message); end;
  procedure BeginItem(AKind: TScriptKind; const Header: string);
  var At: Integer; Key,Title: string;
  begin
    Key:=Trim(Header); Title:=''; At:=Pos('：',Key); if At=0 then At:=Pos(':',Key);
    if At>0 then begin Title:=Trim(Copy(Key,At+1,MaxInt)); Key:=Trim(Copy(Key,1,At-1)); end;
    Item:=TScriptItem.Create(AKind,Key,I+1,PageNumber); Item.Name:=Title; Items.Add(Item); Current:=Item; PersonScope:='';
    if AKind=skAlternate then Item.Put('参照背景',Background);
    if AKind in [skBackground,skAlternate] then Background:=Key;
    if AKind=skImage then begin Item.Put('背景',Background); Image:=Key; end;
    if AKind=skDialogue then Item.Put('画像',Image);
  end;
begin
  Source:=Text; Items.Clear; Work.Fields.Clear; Work.Problems.Clear; Errors.Clear; Warnings.Clear; FatalErrors.Clear;
  if Length(Text)>1024*1024 then begin FatalErrors.Add('台本は100万文字以下にしてください。'); Errors.AddStrings(FatalErrors); Exit; end;
  Lines:=TStringList.Create;
  try
    Lines.Text:=Text; Current:=Work; Background:=''; Image:=''; Multiline:=''; PersonScope:=''; PageNumber:=1; InCast:=False;
    for I:=0 to Lines.Count-1 do begin
      S:=Trim(Lines[I]);
      if Multiline<>'' then begin
        if S='[/'+Multiline+']' then Multiline:=''
        else begin V:=Current.Get(Multiline); if V<>'' then V:=V+sLineBreak; Current.Put(Multiline,V+Lines[I]); end;
        Continue;
      end;
      if S='' then Continue;
      M:=TRegEx.Match(S,'^#\s*(\d+)\s*ページ目\s*$');
      if M.Success then begin
        if not TryStrToInt(M.Groups[1].Value,PageNumber) or (PageNumber<1) then begin ParseProblem(Format('%d行：ページ番号が不正です。',[I+1])); PageNumber:=1; end;
        Current:=Work; InCast:=False; Continue;
      end;
      if S.StartsWith('#') or S.StartsWith('//') then Continue;
      if S.StartsWith('※') then begin InCast:=False; Continue; end;
      if S.StartsWith('*') then begin
        N:=0; while (N<Length(S)) and (S[N+1]='*') do Inc(N);
        case N of 1: Kind:=skBackground; 2: Kind:=skAlternate; 3: Kind:=skImage;
        else ParseProblem(Format('%d行：* は1～3個です。',[I+1])); Continue; end;
        BeginItem(Kind,Trim(Copy(S,N+1,MaxInt))); Continue;
      end;
      if S='[作品]' then begin Current:=Work; Continue; end;
      if (S='[本文]') then begin Current.Put('本文',''); Multiline:='本文'; Continue; end;
      // 半角空白2つの旧形式の改行は本文に限り解釈し、項目行の字下げと混同しない。
      if Lines[I].StartsWith('  ') and (Current.Kind=skDialogue) and (Current.Get('本文')<>'') and
        not S.StartsWith('[') and (Pos('：',S)=0) and (Pos(':',S)=0) then begin
        Current.Put('本文',Current.Get('本文')+sLineBreak+S); Continue;
      end;
      Bracketed:=S.StartsWith('[');
      if Bracketed then begin
        if not S.EndsWith(']') then begin ParseProblem(Format('%d行：閉じる ] がありません。この項目だけ保留します。',[I+1])); Continue; end;
        S:=Copy(S,2,Length(S)-2);
      end;
      P:=Pos('：',S); if P=0 then P:=Pos(':',S);
      if P=0 then begin ParseProblem(Format('%d行：項目名：内容 の形で記入してください。',[I+1])); Continue; end;
      K:=Trim(Copy(S,1,P-1)); V:=Trim(Copy(S,P+1,MaxInt));
      if (K='登場人物') and not Bracketed then begin InCast:=True; Continue; end;
      if InCast and not Bracketed then begin
        BeginItem(skCharacter,K); Current.Put('外見',V); Current.Put('参照方式','説明のみ'); Current:=Work; Continue;
      end;
      if (K='人物定義') or ((K='人物') and (Current.Kind in [skWork,skCharacter])) then begin BeginItem(skCharacter,V); Continue; end;
      if K='セリフ' then begin BeginItem(skDialogue,V); Continue; end;
      if (K='効果') and (Bracketed or (Current.Kind<>skImage)) then begin BeginItem(skEffect,V); Continue; end;
      if (K='オノマトペ') and (Bracketed or (Current.Kind<>skImage)) then begin BeginItem(skOnomatopoeia,V); Continue; end;
      // 試験台本の「人物→表情」を人物別の項目に正規化し、人物一覧を上書きしない。
      if (Current.Kind=skImage) and (K='人物') and (Current.Get('人物')<>'') then begin
        if Length(ScriptNames(V))<>1 then ParseProblem(Format('%d行：人物別指定は1名ずつ記入してください。',[I+1]))
        else begin PersonScope:=V; if not ScriptHasName(Current.Get('人物'),V) then ParseProblem(Format('%d行：人物一覧にない指定です。',[I+1])); end;
        Continue;
      end;
      if (Current.Kind=skImage) and (PersonScope<>'') and
        ((K='表情') or (K='位置') or (K='動作') or (K='服装') or (K='履物') or (K='靴下') or (K='持ち物')) then K:=PersonScope+'.'+K;
      if (Current.Kind=skDialogue) and (K='話者') and V.EndsWith('（心の声）') then begin
        V:=Copy(V,1,Length(V)-Length('（心の声）')); Current.Put('種別','心の声');
      end;
      if K='背景参照' then K:='背景'; if K='参照元' then K:='参照背景';
      if (Current.Kind=skImage) and (K='効果') then K:='使用効果';
      if (Current.Kind=skImage) and (K='オノマトペ') then K:='使用オノマトペ';
      // 暗黙の背景・画像は明示指定で置換できる。その他の重複は入力ミスとして見せる。
      if (Current.Fields.IndexOfName(K)>=0) and not ((K='背景') or (K='参照背景') or (K='画像')) then
        ParseProblem(Format('%d行：%s が重複しています。人物別指定は 主人公.表情 のように書いてください。',[I+1,K]));
      Current.Put(K,V);
    end;
    if Multiline<>'' then ParseProblem('[/本文] がありません。このセリフだけ保留します。');
    if Items.Count>2000 then begin FatalErrors.Add('項目は2000件以下にしてください。'); Errors.AddStrings(FatalErrors); end;
    Validate;
  finally Lines.Free; end;
end;

procedure TComicScript.Validate;
var IDs: TDictionary<string,TScriptItem>; Item,Other,Previous: TScriptItem; Key,Ref: string; Index: Integer;
  procedure Problem(const Text: string);
  begin
    var Message:=Format('%d行 %s：%s',[Item.Line,Item.ID,Text]); Errors.Add(Message); Item.Problems.Add(Message);
  end;
  procedure Earlier(const Key: string; Kinds: TArray<TScriptKind>);
  var Found: Boolean; K: TScriptKind;
  begin
    Ref:=Item.Get(Key); Other:=Find(Ref); Found:=False;
    if Other<>nil then for K in Kinds do if (Other.Kind=K) and (Other.Line<Item.Line) then Found:=True;
    if not Found then Problem(Key+' '+Ref+' を先に定義してください。');
  end;
begin
  IDs:=TDictionary<string,TScriptItem>.Create;
  try
    for Item in Items do begin
      if Item.ID='' then Problem('IDが空です。')
      else if IDs.TryGetValue(LowerCase(Item.ID),Previous) then begin
        Problem('IDが重複しています。同じIDの項目と参照先を保留します。');
        Previous.Problems.Add(Item.Problems[Item.Problems.Count-1]);
      end else IDs.Add(LowerCase(Item.ID),Item);
      if Item.Kind<>skCharacter then begin
        case Item.Kind of skBackground,skAlternate: Key:='B'; skImage: Key:='I'; skDialogue: Key:='D';
          skEffect: Key:='E'; skOnomatopoeia: Key:='O'; else Key:=''; end;
        if not TRegEx.IsMatch(Item.ID,'^'+Key+'[0-9]{3,}$') then Problem('IDは '+Key+'001 のように指定してください。');
      end;
      if Item.Fields.IndexOfName('生成')>=0 then begin
        Key:=Item.Get('生成');
        if (Key<>'対象') and (Key<>'保留') then Problem('生成は「対象」または「保留」で指定してください。');
      end;
      case Item.Kind of
        skAlternate: Earlier('参照背景',[skBackground,skAlternate]);
        skImage: begin
          Earlier('背景',[skBackground,skAlternate]);
          for Key in ScriptNames(Item.Get('人物')) do begin
            Other:=FindCharacter(Key); if (Other=nil) or (Other.Kind<>skCharacter) then Problem('人物 '+Key+' の人物定義がありません。');
          end;
          if Item.Get('人物')='' then Warnings.Add(Item.ID+'：人物未指定。背景だけなら [人物：なし] と記入してください。');
          for Index:=0 to 1 do begin
            if Index=0 then Key:='使用効果' else Key:='使用オノマトペ';
            for Ref in ScriptNames(Item.Get(Key)) do begin
              Other:=Find(Ref);
              if (Other=nil) or not (Other.Kind in [skEffect,skOnomatopoeia]) then Problem('素材 '+Ref+' が未定義です。');
            end;
          end;
        end;
        skDialogue: begin
          Earlier('画像',[skImage]);
          if Item.Get('本文')='' then Problem('本文が空です。');
          if Item.Get('話者')='' then Problem('話者が空です。')
          else if Item.Get('話者')<>'ナレーション' then begin
            Other:=Find(Item.Get('画像')); if Other<>nil then begin
              var Present:=False;
              for Key in ScriptNames(Other.Get('人物')) do if Key=Item.Get('話者') then Present:=True;
              if not Present then Problem('話者が対象画像の人物に含まれません。');
            end;
          end;
          Key:=Item.Get('種別','発言');
          if (Key<>'発言') and (Key<>'心の声') and (Key<>'ナレーション') then Problem('種別は発言・心の声・ナレーションです。');
        end;
      end;
    end;
    if Items.Count=0 then begin FatalErrors.Add('背景や画像の定義がありません。'); Errors.AddStrings(FatalErrors); end;
  finally IDs.Free; end;
end;
end.
