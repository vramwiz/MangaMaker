unit ComicExport;

// 責務：内容署名で差分PNGを出力し、正常なキャッシュと連番ファイルの対応を管理する。

interface

uses Winapi.Windows, System.SysUtils, System.Classes, System.JSON, System.Hash, System.Math,
  System.IOUtils, System.Generics.Collections, ComicModel, ComicRender;

function ExportSequence(Project: TComicProject; Renderer: TComicRenderer; All: Boolean): Integer;

implementation

function RenderSignature(Project: TComicProject; Page: TComicPage;
  Images: TDictionary<string,string>): string;
var J: TJSONObject; Pair: TJSONPair; P: TComicPanel; Overlay: TComicOverlay; Path,Hash,Text: string;
  procedure AddImage(const ID,FileName: string);
  begin
    if not Images.TryGetValue(FileName,Hash) then begin
      if (FileName<>'') and FileExists(FileName) then Hash:=THashSHA2.GetHashStringFromFile(FileName) else Hash:='missing';
      Images.Add(FileName,Hash);
    end;
    Text:=Text+'|'+ID+'|'+Hash;
  end;
begin
  J:=Page.Json;
  try
    Pair:=J.RemovePair('revision'); Pair.Free;
    Pair:=J.RemovePair('outputRevision'); Pair.Free;
    Text:='renderer-16|'+IntToStr(Project.Width)+'x'+IntToStr(Project.Height)+'|'+J.ToJSON;
    for P in Page.Panels do begin
      if P.ImageID<>'' then AddImage(P.ImageID,Project.ImagePath(P.ImageID));
      for Overlay in P.Overlays do begin
        if Overlay.FileName='' then Path:=SafeChild(TPath.Combine(DataRoot,'Effects'),Overlay.MaterialID+'.png') else Path:=SafeChild(Project.Folder,Overlay.FileName);
        AddImage(Overlay.MaterialID,Path);
      end;
    end;
    Result:=THashSHA2.GetHashString(Text);
  finally J.Free; end;
end;

procedure ReplaceFile(const Temp,Dest: string);
begin
  if not MoveFileEx(PChar(Temp),PChar(Dest),MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then RaiseLastOSError;
end;

function ExportSequence(Project: TComicProject; Renderer: TComicRenderer; All: Boolean): Integer;
var Output,Cache,FileName,Dest,Signature,SignatureFile,StateFile: string; I,ManagedCount: Integer;
  P: TComicPage; Images: TDictionary<string,string>;
begin
  Result:=0; Output:=Project.Folder; Cache:=Output;
  ForceDirectories(Cache); Images:=TDictionary<string,string>.Create;
  Renderer.ClearCache;
  try
    StateFile:=TPath.Combine(Cache,'Export-sequence-count.txt'); ManagedCount:=Project.ExportCount;
    if FileExists(StateFile) then
      if not TryStrToInt(TFile.ReadAllText(StateFile,TEncoding.UTF8),ManagedCount) then
        raise Exception.Create('Invalid PNG sequence history.');
    if (ManagedCount<0) or (ManagedCount>100000) then raise Exception.Create('Invalid PNG sequence count.');
    // 部分出力も含めたファイル所有関係をUndoとは別に持ち、履歴復元で他の連番を消さない。
    AtomicWrite(StateFile,IntToStr(Max(ManagedCount,Project.Pages.Count)));
    for I:=0 to Project.Pages.Count-1 do begin
      P:=Project.Pages[I]; FileName:=SafeChild(Cache,'Export-cache-'+P.ID+'.png'); SignatureFile:=FileName+'.signature';
      Signature:=RenderSignature(Project,P,Images);
      if All or not FileExists(FileName) or not FileExists(SignatureFile) or
        (TFile.ReadAllText(SignatureFile,TEncoding.UTF8)<>Signature) then begin
        Renderer.ExportPage(Project,P,FileName+'.tmp');
        // 署名を先に無効化し、新しいPNGと古い署名の組合せを残さない。失敗時は旧PNGを保持する。
        if FileExists(SignatureFile) then TFile.Delete(SignatureFile);
        ReplaceFile(FileName+'.tmp',FileName); AtomicWrite(SignatureFile,Signature); Inc(Result);
      end;
      Dest:=TPath.Combine(Output,Format('%.4d.png',[I+1]));
      TFile.Copy(FileName,Dest+'.tmp',True); ReplaceFile(Dest+'.tmp',Dest);
      P.OutputRevision:=P.Revision;
    end;
    for I:=Project.Pages.Count+1 to ManagedCount do begin
      Dest:=TPath.Combine(Output,Format('%.4d.png',[I])); if FileExists(Dest) then TFile.Delete(Dest);
    end;
    AtomicWrite(StateFile,IntToStr(Project.Pages.Count));
    Project.ExportCount:=Project.Pages.Count; Project.SaveDraft;
  finally Images.Free; end;
end;

end.
