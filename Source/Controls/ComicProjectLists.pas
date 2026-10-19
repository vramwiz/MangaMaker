unit ComicProjectLists;

// 責務：一覧の構造と内容更新を分け、通常編集では行・選択・スクロールを保持する。
interface
uses System.Classes, System.Types, Vcl.StdCtrls, Vcl.Graphics, ComicModel, ComicRender, ComicPageThumbnails;
type
  TComicPageList = class(TListBox)
  private
    FThumbnails: TComicPageThumbnails;
    FProjectKey: string;
    {$IFDEF MANGAMAKER_SELFTEST}FInvalidatedRects: TArray<TRect>;{$ENDIF}
    function SameOrder(Project: TComicProject): Boolean;
    procedure Rebuild(Project: TComicProject; Index: Integer; NewProject: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Synchronize(Project: TComicProject; Renderer: TComicRenderer; Index: Integer);
    function Thumbnail(Project: TComicProject; Renderer: TComicRenderer; Index,W,H: Integer): TBitmap;
    property Thumbnails: TComicPageThumbnails read FThumbnails;
    {$IFDEF MANGAMAKER_SELFTEST}property InvalidatedRects: TArray<TRect> read FInvalidatedRects;{$ENDIF}
  end;
  TComicImageList = class(TListBox)
  private
    FIDs: TStringList;
    FProjectKey: string;
    function SameItems(Project: TComicProject): Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Synchronize(Project: TComicProject);
  end;
implementation
uses Winapi.Windows, System.SysUtils, System.Math;
constructor TComicPageList.Create(AOwner: TComponent);
begin inherited; FThumbnails:=TComicPageThumbnails.Create; ParentDoubleBuffered:=False; DoubleBuffered:=True; end;
destructor TComicPageList.Destroy;
begin FThumbnails.Free; inherited; end;
function TComicPageList.SameOrder(Project: TComicProject): Boolean;
var I: Integer;
begin
  Result:=Count=Project.Pages.Count; if not Result then Exit;
  for I:=0 to Count-1 do if Items[I]<>Project.Pages[I].ID then Exit(False);
end;
procedure TComicPageList.Rebuild(Project: TComicProject; Index: Integer; NewProject: Boolean);
var SelectedIDs: TStringList; I,Top: Integer;
begin
  SelectedIDs:=TStringList.Create; Top:=TopIndex;
  try
    if not NewProject then for I:=0 to Count-1 do if Selected[I] then SelectedIDs.Add(Items[I]);
    Items.BeginUpdate;
    try
      Clear; for I:=0 to Project.Pages.Count-1 do Items.Add(Project.Pages[I].ID);
      ItemIndex:=Index;
      for I:=0 to Count-1 do Selected[I]:=SelectedIDs.IndexOf(Items[I])>=0;
      if (SelCount=0) and (Index>=0) then Selected[Index]:=True;
      if NewProject then TopIndex:=0 else TopIndex:=Max(0,Min(Top,Count-1));
    finally Items.EndUpdate; end;
  finally SelectedIDs.Free; end;
end;
procedure TComicPageList.Synchronize(Project: TComicProject; Renderer: TComicRenderer; Index: Integer);
var Dirty: TArray<Integer>; I: Integer; R,Visible: TRect; Key: string;
begin
  {$IFDEF MANGAMAKER_SELFTEST}FInvalidatedRects:=nil;{$ENDIF}
  Dirty:=FThumbnails.Synchronize(Project,Renderer);
  if Project=nil then begin if Count>0 then Clear; FProjectKey:=''; Exit; end;
  Key:=Project.ID+'|'+Project.Folder;
  if (Key<>FProjectKey) or not SameOrder(Project) then Rebuild(Project,Index,Key<>FProjectKey)
  else begin
    // BeginUpdate/EndUpdate自体も全行を無効化するため、構造が同じなら呼ばない。
    if ItemIndex<>Index then ItemIndex:=Index;
    if (SelCount=0) and (Index>=0) then Selected[Index]:=True;
    if HandleAllocated then for I in Dirty do begin
      R:=ItemRect(I); if IntersectRect(Visible,R,ClientRect) then begin
        // 非表示の検証窓ではWindowsが更新領域を保持しないため、実際に渡す矩形も記録する。
        {$IFDEF MANGAMAKER_SELFTEST}
        SetLength(FInvalidatedRects,Length(FInvalidatedRects)+1); FInvalidatedRects[High(FInvalidatedRects)]:=Visible;
        {$ENDIF}
        InvalidateRect(Handle,@Visible,False);
      end;
    end;
  end;
  FProjectKey:=Key;
end;
function TComicPageList.Thumbnail(Project: TComicProject; Renderer: TComicRenderer; Index,W,H: Integer): Vcl.Graphics.TBitmap;
begin Result:=FThumbnails.GetBitmap(Project,Renderer,Index,W,H); end;
constructor TComicImageList.Create(AOwner: TComponent);
begin inherited; FIDs:=TStringList.Create; ParentDoubleBuffered:=False; DoubleBuffered:=True; end;
destructor TComicImageList.Destroy;
begin FIDs.Free; inherited; end;
function TComicImageList.SameItems(Project: TComicProject): Boolean;
var I,At: Integer; Asset: TComicAsset;
begin
  At:=0; Result:=False;
  for Asset in Project.Assets do if Asset.ImageFile<>'' then begin
    I:=At; Inc(At);
    if (I>=Count) or (I>=FIDs.Count) then Exit;
    if (FIDs[I]<>Asset.ID) or (Items[I]<>Asset.Name) then Exit;
  end;
  Result:=(At=Count) and (At=FIDs.Count);
end;
procedure TComicImageList.Synchronize(Project: TComicProject);
var SelectedID,Key: string; I,Top: Integer; Asset: TComicAsset;
begin
  if Project=nil then begin if Count>0 then Clear; FIDs.Clear; FProjectKey:=''; Exit; end;
  Key:=Project.ID+'|'+Project.Folder;
  if (Key=FProjectKey) and SameItems(Project) then begin
    // Undoでは同じIDのオブジェクトが作り直される。表示を保ち、参照だけを差し替える。
    I:=0;
    for Asset in Project.Assets do if Asset.ImageFile<>'' then begin
      if Items.Objects[I]<>Asset then Items.Objects[I]:=Asset; Inc(I);
    end;
    Exit;
  end;
  SelectedID:=''; Top:=TopIndex;
  if (Key=FProjectKey) and (ItemIndex>=0) and (ItemIndex<FIDs.Count) then SelectedID:=FIDs[ItemIndex];
  Items.BeginUpdate;
  try
    Clear; FIDs.Clear;
    for Asset in Project.Assets do if Asset.ImageFile<>'' then begin
      Items.AddObject(Asset.Name,Asset); FIDs.Add(Asset.ID);
    end;
    ItemIndex:=FIDs.IndexOf(SelectedID); TopIndex:=Max(0,Min(Top,Count-1)); FProjectKey:=Key;
  finally Items.EndUpdate; end;
end;
end.
