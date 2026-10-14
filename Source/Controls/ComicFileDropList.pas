unit ComicFileDropList;

// 責務：Explorerからのファイルドロップをリストへ渡し、コマへの既存D&Dと入口を分ける。
interface
uses System.Classes, Vcl.StdCtrls, Winapi.Messages;
type
  TComicFilesDropped = procedure(Sender: TObject; const Files: TArray<string>) of object;
  TComicFileDropList = class(TListBox)
  private
    FOnFilesDropped: TComicFilesDropped;
    procedure DropFiles(var Message: TMessage); message WM_DROPFILES;
  protected
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
  public
    property OnFilesDropped: TComicFilesDropped read FOnFilesDropped write FOnFilesDropped;
  end;
implementation
uses System.SysUtils, Winapi.Windows, Winapi.ShellAPI;
procedure TComicFileDropList.CreateWnd;
begin inherited; DragAcceptFiles(Handle,True); end;
procedure TComicFileDropList.DestroyWnd;
begin DragAcceptFiles(Handle,False); inherited; end;
procedure TComicFileDropList.DropFiles(var Message: TMessage);
var Drop: HDROP; Count,I: Cardinal; Files: TArray<string>;
begin
  Drop:=HDROP(Message.WParam);
  try
    Count:=DragQueryFile(Drop,$FFFFFFFF,nil,0);
    if (Count=0) or (Count>32) then Exit; SetLength(Files,Count);
    for I:=0 to Count-1 do begin
      SetLength(Files[I],DragQueryFile(Drop,I,nil,0)+1);
      DragQueryFile(Drop,I,PChar(Files[I]),Length(Files[I])); SetLength(Files[I],Length(Files[I])-1);
    end;
    if Assigned(FOnFilesDropped) then FOnFilesDropped(Self,Files);
  finally DragFinish(Drop); end;
end;
end.
