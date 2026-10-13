unit ComicExport;

interface

uses Winapi.Windows, System.SysUtils, System.Classes, System.JSON, System.Hash, System.Math,
  System.IOUtils, System.Generics.Collections, ComicModel, ComicRender;

function ExportSequence(Project: TComicProject; Renderer: TComicRenderer; All: Boolean): Integer;

implementation

function RenderSignature(Project: TComicProject; Page: TComicPage;
  Images: TDictionary<string,string>): string;
var J: TJSONObject; Pair: TJSONPair; P: TComicPanel; Path,Hash,Text: string;
begin
  J:=Page.Json;
  try
    Pair:=J.RemovePair('revision'); Pair.Free;
    Pair:=J.RemovePair('outputRevision'); Pair.Free;
    Text:='renderer-4|'+IntToStr(Project.Width)+'x'+IntToStr(Project.Height)+'|'+J.ToJSON;
    for P in Page.Panels do if P.ImageID<>'' then begin
      Path:=Project.ImagePath(P.ImageID);
      if not Images.TryGetValue(Path,Hash) then begin
        if (Path<>'') and FileExists(Path) then Hash:=THashSHA2.GetHashStringFromFile(Path) else Hash:='missing';
        Images.Add(Path,Hash);
      end;
      Text:=Text+'|'+P.ImageID+'|'+Hash;
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
  Result:=0; Output:=TPath.Combine(Project.Folder,'Output'); Cache:=TPath.Combine(Output,'.cache');
  ForceDirectories(Cache); Images:=TDictionary<string,string>.Create;
  Renderer.ClearCache;
  try
    StateFile:=TPath.Combine(Cache,'sequence-count.txt'); ManagedCount:=Project.ExportCount;
    if FileExists(StateFile) then
      if not TryStrToInt(TFile.ReadAllText(StateFile,TEncoding.UTF8),ManagedCount) then
        raise Exception.Create('Invalid PNG sequence history.');
    if (ManagedCount<0) or (ManagedCount>100000) then raise Exception.Create('Invalid PNG sequence count.');
    // Track file ownership independently of Undo snapshots, including a partial export.
    AtomicWrite(StateFile,IntToStr(Max(ManagedCount,Project.Pages.Count)));
    for I:=0 to Project.Pages.Count-1 do begin
      P:=Project.Pages[I]; FileName:=SafeChild(Cache,P.ID+'.png'); SignatureFile:=FileName+'.signature';
      Signature:=RenderSignature(Project,P,Images);
      if All or not FileExists(FileName) or not FileExists(SignatureFile) or
        (TFile.ReadAllText(SignatureFile,TEncoding.UTF8)<>Signature) then begin
        Renderer.ExportPage(Project,P,FileName+'.tmp');
        // Invalidate first: a failed signature write must never leave a new PNG
        // paired with an old signature. If invalidation fails, keep the old PNG.
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
