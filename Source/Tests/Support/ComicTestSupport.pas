unit ComicTestSupport;

// 責務：隔離した検証フォームと共通記録を提供し、製品フォームへテスト専用状態を持ち込まない。
interface
uses Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.Imm,
  System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Math, System.IOUtils, System.Generics.Collections, System.JSON,
  System.Hash, System.DateUtils, Vcl.Controls, Vcl.Forms,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus,
  Vcl.Dialogs, Vcl.Graphics, Vcl.Imaging.pngimage, ComicModel,
  ComicAssetDialog, ComicLayouts, MangaMakerMainForm;
type
  TComicTestForm = class(TMainForm)
  public
    B: TBitmap;
    A,A2: TComicAsset;
    P: TComicPanel;
    Balloon: TComicBalloon;
    Loaded: TComicProject;
    Snapshot,AssetID,FirstID,SecondID,ThirdID,FourthID,CacheFile,TestFolder: string;
    Dialog: TAssetDialog;
    Layout: TComicLayout;
    LibraryCopy: TObjectList<TComicLayout>;
    J: TJSONObject;
    R: TRect;
    Accept,Failed: Boolean;
    N,BeforeOutput,FIconTestClicks: Integer;
    Lines: TStringList;
    SignatureLock: THandle;
    ImageKey: Word;
    procedure Check(Condition: Boolean; const Message: string);
    procedure Capture(const Name: string);
    procedure SelectOnly(Index: Integer);
    procedure IconTestClick(Sender: TObject);
  end;
function CreateFixtureProject: TComicProject;
implementation
function CreateFixtureProject: TComicProject;
begin
  // 既存の座標・描画回帰は従来の1200×1700を明示し、新規作品の初期値変更から切り離す。
  Result:=TComicProject.Create; Result.Width:=1200; Result.Height:=1700;
end;
procedure TComicTestForm.Check(Condition: Boolean; const Message: string);
  begin
    if not Condition then raise Exception.Create(Message);
    Lines.Add('PASS: '+Message);
    Lines.SaveToFile(TPath.Combine(TestFolder,'progress.txt'),TEncoding.UTF8);
  end;

procedure TComicTestForm.Capture(const Name: string);
  begin
    UpdateIconState; HandleNeeded; B.SetSize(ClientWidth,ClientHeight); PaintTo(B.Canvas,0,0);
    B.SaveToFile(TPath.Combine(TestFolder,Name+'.bmp'));
  end;

procedure TComicTestForm.SelectOnly(Index: Integer);
  var K: Integer;
  begin
    FPages.ItemIndex:=Index; for K:=0 to FPages.Count-1 do FPages.Selected[K]:=K=Index;
    PageSelect(nil);
  end;

procedure TComicTestForm.IconTestClick(Sender: TObject);
begin Inc(FIconTestClicks); end;
end.
