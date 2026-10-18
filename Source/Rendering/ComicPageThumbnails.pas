unit ComicPageThumbnails;

// 責務：ページ内容ごとの縮小画像を保持し、描画に関係する変更だけで失効させる。
// RevisionはUndoで再利用されるためキーにせず、画像ファイルも全文ハッシュせず属性で比較する。
interface
uses System.SysUtils, System.Types, System.Generics.Collections, Vcl.Graphics, ComicModel, ComicRender;
type
  TComicPageThumbnail = class
    Signature: string;
    Bitmap: TBitmap;
    Used: UInt64;
    destructor Destroy; override;
  end;
  TComicPageThumbnails = class
  private
    FEntries: TObjectDictionary<string,TComicPageThumbnail>;
    FFiles: TDictionary<string,string>;
    FProjectKey: string;
    FClock,FBytes: UInt64;
    FBitmapCount: Integer;
    FFilesChanged: Boolean;
    {$IFDEF MANGAMAKER_SELFTEST}FBuildCount: Integer;{$ENDIF}
    function FileVersion(const Path: string; Versions: TDictionary<string,string>): string;
    function Signature(Project: TComicProject; Page: TComicPage; Versions: TDictionary<string,string>): string;
    function Observe(const ID,Value: string; out Changed: Boolean): TComicPageThumbnail;
    procedure DropBitmap(Entry: TComicPageThumbnail);
    procedure MakeRoom(Bytes: UInt64);
    procedure CheckFiles(Renderer: TComicRenderer);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function Synchronize(Project: TComicProject; Renderer: TComicRenderer): TArray<Integer>;
    function GetBitmap(Project: TComicProject; Renderer: TComicRenderer; Index,W,H: Integer): TBitmap;
    property BitmapCount: Integer read FBitmapCount;
    property CachedBytes: UInt64 read FBytes;
    {$IFDEF MANGAMAKER_SELFTEST}property BuildCount: Integer read FBuildCount;{$ENDIF}
  end;
implementation
uses Winapi.Windows, System.JSON, System.Hash, System.IOUtils;
const MaxThumbnailBytes=32*1024*1024; MaxThumbnailCount=64;
destructor TComicPageThumbnail.Destroy;
begin Bitmap.Free; inherited; end;
constructor TComicPageThumbnails.Create;
begin
  inherited; FEntries:=TObjectDictionary<string,TComicPageThumbnail>.Create([doOwnsValues]);
  FFiles:=TDictionary<string,string>.Create;
end;
destructor TComicPageThumbnails.Destroy;
begin FFiles.Free; FEntries.Free; inherited; end;
procedure TComicPageThumbnails.Clear;
begin FEntries.Clear; FFiles.Clear; FBytes:=0; FBitmapCount:=0; FProjectKey:=''; FFilesChanged:=False; end;
procedure TComicPageThumbnails.DropBitmap(Entry: TComicPageThumbnail);
begin
  if Entry.Bitmap=nil then Exit;
  Dec(FBytes,UInt64(Entry.Bitmap.Width)*UInt64(Entry.Bitmap.Height)*4); Dec(FBitmapCount);
  FreeAndNil(Entry.Bitmap);
end;
function TComicPageThumbnails.FileVersion(const Path: string; Versions: TDictionary<string,string>): string;
var Data: TWin32FileAttributeData; Previous,Version: string;
begin
  if Versions.TryGetValue(Path,Result) then Exit;
  Version:='missing';
  if (Path<>'') and GetFileAttributesEx(PChar(Path),GetFileExInfoStandard,@Data) then
    Version:=IntToHex(Data.ftLastWriteTime.dwHighDateTime,8)+IntToHex(Data.ftLastWriteTime.dwLowDateTime,8)+
      ':'+IntToHex(Data.nFileSizeHigh,8)+IntToHex(Data.nFileSizeLow,8);
  if FFiles.TryGetValue(Path,Previous) and (Previous<>Version) then FFilesChanged:=True;
  FFiles.AddOrSetValue(Path,Version); Result:=Path+'|'+Version; Versions.Add(Path,Result);
end;
function TComicPageThumbnails.Signature(Project: TComicProject; Page: TComicPage; Versions: TDictionary<string,string>): string;
var J: TJSONObject; Pair: TJSONPair; Panel: TComicPanel; Overlay: TComicOverlay; Text,Path: string;
begin
  J:=Page.Json;
  try
    Pair:=J.RemovePair('revision'); Pair.Free; Pair:=J.RemovePair('outputRevision'); Pair.Free;
    Text:=IntToStr(Project.Width)+'x'+IntToStr(Project.Height)+'|'+J.ToJSON;
    for Panel in Page.Panels do begin
      if Panel.ImageID<>'' then Text:=Text+'|'+FileVersion(Project.ImagePath(Panel.ImageID),Versions);
      for Overlay in Panel.Overlays do begin
        if Overlay.FileName='' then Path:=SafeChild(TPath.Combine(DataRoot,'Effects'),Overlay.MaterialID+'.png')
        else Path:=SafeChild(Project.Folder,Overlay.FileName);
        Text:=Text+'|'+FileVersion(Path,Versions);
      end;
    end;
    Result:=THashSHA2.GetHashString(Text);
  finally J.Free; end;
end;
function TComicPageThumbnails.Observe(const ID,Value: string; out Changed: Boolean): TComicPageThumbnail;
begin
  if not FEntries.TryGetValue(ID,Result) then begin
    Result:=TComicPageThumbnail.Create; FEntries.Add(ID,Result);
  end;
  Changed:=Result.Signature<>Value;
  if Changed then begin DropBitmap(Result); Result.Signature:=Value; end;
end;
procedure TComicPageThumbnails.CheckFiles(Renderer: TComicRenderer);
begin
  // 共有画像が同じパスで更新された場合は、元画像のキャッシュも失効させる。
  if FFilesChanged then begin Renderer.ClearCache; FFilesChanged:=False; end;
end;
function TComicPageThumbnails.Synchronize(Project: TComicProject; Renderer: TComicRenderer): TArray<Integer>;
var Versions: TDictionary<string,string>; Live: TDictionary<string,Boolean>; Changed: TList<Integer>;
  I: Integer; ID,Key: string; Different: Boolean;
begin
  Result:=nil; if Project=nil then begin Clear; Exit; end;
  Key:=Project.ID+'|'+Project.Folder;
  if Key<>FProjectKey then begin Clear; FProjectKey:=Key; end;
  Versions:=TDictionary<string,string>.Create; Live:=TDictionary<string,Boolean>.Create; Changed:=TList<Integer>.Create;
  try
    for I:=0 to Project.Pages.Count-1 do begin
      ID:=Project.Pages[I].ID; Live.AddOrSetValue(ID,True);
      Observe(ID,Signature(Project,Project.Pages[I],Versions),Different); if Different then Changed.Add(I);
    end;
    for ID in FEntries.Keys.ToArray do if not Live.ContainsKey(ID) then begin DropBitmap(FEntries[ID]); FEntries.Remove(ID); end;
    for Key in FFiles.Keys.ToArray do if not Versions.ContainsKey(Key) then FFiles.Remove(Key);
    CheckFiles(Renderer); Result:=Changed.ToArray;
  finally Changed.Free; Live.Free; Versions.Free; end;
end;
procedure TComicPageThumbnails.MakeRoom(Bytes: UInt64);
var Item,Oldest: TComicPageThumbnail;
begin
  while (FBytes+Bytes>MaxThumbnailBytes) or (FBitmapCount>=MaxThumbnailCount) do begin
    Oldest:=nil;
    for Item in FEntries.Values do if (Item.Bitmap<>nil) and ((Oldest=nil) or (Item.Used<Oldest.Used)) then Oldest:=Item;
    if Oldest=nil then Exit; DropBitmap(Oldest);
  end;
end;
function TComicPageThumbnails.GetBitmap(Project: TComicProject; Renderer: TComicRenderer; Index,W,H: Integer): Vcl.Graphics.TBitmap;
var Entry: TComicPageThumbnail; Versions: TDictionary<string,string>; Different: Boolean; Bitmap: Vcl.Graphics.TBitmap;
begin
  if (W<1) or (H<1) or (W>2048) or (H>2048) then raise EArgumentOutOfRangeException.Create('縮小画像の寸法が不正です。');
  if FProjectKey<>Project.ID+'|'+Project.Folder then Synchronize(Project,Renderer);
  Versions:=TDictionary<string,string>.Create;
  try Entry:=Observe(Project.Pages[Index].ID,Signature(Project,Project.Pages[Index],Versions),Different); CheckFiles(Renderer);
  finally Versions.Free; end;
  Inc(FClock); Entry.Used:=FClock;
  if (Entry.Bitmap<>nil) and ((Entry.Bitmap.Width<>W) or (Entry.Bitmap.Height<>H)) then DropBitmap(Entry);
  if Entry.Bitmap=nil then begin
    MakeRoom(UInt64(W)*UInt64(H)*4); Bitmap:=Vcl.Graphics.TBitmap.Create;
    try
      Bitmap.PixelFormat:=pf32bit; Bitmap.SetSize(W,H);
      Renderer.Draw(Bitmap.Canvas,Project,Project.Pages[Index],Rect(0,0,W,H),False);
      Entry.Bitmap:=Bitmap; Bitmap:=nil; Inc(FBytes,UInt64(W)*UInt64(H)*4); Inc(FBitmapCount);
      {$IFDEF MANGAMAKER_SELFTEST}Inc(FBuildCount);{$ENDIF}
    finally Bitmap.Free; end;
  end;
  Result:=Entry.Bitmap;
end;
end.
