unit ComicImageAdoption;

// 責務：受信画像の寸法・形式を検証し、新規コピーの検証成功後だけ管理画像へ採用する。
interface
uses System.SysUtils;
procedure RequireLocalImagePath(const Path: string);
procedure ValidateComicImage(const Path: string);
function CopyValidatedComicImage(const Source,Root,Prefix: string): string;
implementation
uses Winapi.Windows, System.Classes, System.IOUtils, System.Math, Vcl.Graphics,
  Vcl.Imaging.pngimage, Vcl.Imaging.jpeg, ComicModel;

procedure RequireLocalImagePath(const Path: string);
begin
  // WindowsのIsPathRootedはドライブ相対パスも許すため、完全な絶対パスを別途確認する。
  if (Length(Path)<3) or not CharInSet(Path[1],['A'..'Z','a'..'z']) or
    (Path[2]<>':') or not CharInSet(Path[3],['\','/']) or (Pos(#0,Path)>0) or
    (Pos('"',Path)>0) or (Pos(':',Copy(Path,3,MaxInt))>0) then
    raise Exception.Create('画像はドライブ名付きのローカル完全パスで指定してください。');
end;
procedure ValidateComicImage(const Path: string);
var Stream: TFileStream; Header: array[0..31] of Byte; W,H: Int64;
  Marker,B,Hi,Lo: Byte; Segment: Word; Found: Boolean; Picture: TPicture; Ext: string;
  function BE32(At: Integer): UInt32;
  begin Result:=(UInt32(Header[At]) shl 24) or (UInt32(Header[At+1]) shl 16) or (UInt32(Header[At+2]) shl 8) or Header[At+3]; end;
  function LE32(At: Integer): Integer;
  begin Result:=Integer(UInt32(Header[At]) or (UInt32(Header[At+1]) shl 8) or (UInt32(Header[At+2]) shl 16) or (UInt32(Header[At+3]) shl 24)); end;
begin
  RequireLocalImagePath(Path); Ext:=LowerCase(ExtractFileExt(Path));
  if not (Ext='.png') and not (Ext='.jpg') and not (Ext='.jpeg') and not (Ext='.bmp') then raise Exception.Create('PNG/JPEG/BMP画像を指定してください。');
  Stream:=TFileStream.Create(Path,fmOpenRead or fmShareDenyWrite);
  try
    if (Stream.Size<26) or (Stream.Size>64*1024*1024) then raise Exception.Create('画像ファイルは26バイト以上64MB以下で指定してください。');
    FillChar(Header,SizeOf(Header),0); Stream.ReadBuffer(Header,Min(Stream.Size,SizeOf(Header))); W:=0; H:=0;
    if Ext='.png' then begin
      if (BE32(0)<>$89504E47) or (BE32(4)<>$0D0A1A0A) or (BE32(12)<>$49484452) then raise Exception.Create('PNGヘッダーが不正です。');
      W:=BE32(16); H:=BE32(20);
    end else if Ext='.bmp' then begin
      if (Header[0]<>Ord('B')) or (Header[1]<>Ord('M')) then raise Exception.Create('BMPヘッダーが不正です。');
      if LE32(14)=12 then begin W:=Header[18] or (Word(Header[19]) shl 8); H:=Header[20] or (Word(Header[21]) shl 8); end
      else begin
        if LE32(14)<40 then raise Exception.Create('BMPヘッダーが不正です。');
        W:=LE32(18); H:=Abs(Int64(LE32(22)));
      end;
    end else begin
      if (Header[0]<>$FF) or (Header[1]<>$D8) then raise Exception.Create('JPEGヘッダーが不正です。');
      Stream.Position:=2; Found:=False;
      while (Stream.Position<Stream.Size-8) and (Stream.Position<1024*1024) do begin
        Stream.ReadBuffer(B,1); if B<>$FF then raise Exception.Create('JPEGマーカーが不正です。');
        repeat Stream.ReadBuffer(Marker,1); until Marker<>$FF;
        if Marker in [$D8,$01,$D0..$D7] then Continue;
        if Marker in [$D9,$DA] then Break;
        Stream.ReadBuffer(Hi,1); Stream.ReadBuffer(Lo,1); Segment:=(Word(Hi) shl 8) or Lo;
        if (Segment<2) or (Stream.Position+Segment-2>Stream.Size) then raise Exception.Create('JPEGデータ長が不正です。');
        if (Marker in [$C0..$CF]) and not (Marker in [$C4,$C8,$CC]) then begin
          if Segment<8 then raise Exception.Create('JPEG寸法が不正です。');
          Stream.ReadBuffer(B,1); Stream.ReadBuffer(Hi,1); Stream.ReadBuffer(Lo,1); H:=(Word(Hi) shl 8) or Lo;
          Stream.ReadBuffer(Hi,1); Stream.ReadBuffer(Lo,1); W:=(Word(Hi) shl 8) or Lo; Found:=True; Break;
        end;
        Stream.Seek(Segment-2,soCurrent);
      end;
      if not Found then raise Exception.Create('JPEG寸法を読み取れません。');
    end;
    if (W<1) or (H<1) or (W>32000) or (H>32000) or (W*H>64000000) then raise Exception.Create('画像の寸法は各32000以下、6400万画素以下で指定してください。');
    // 寸法上限を確認し、書換えを防いだ同じファイルを復号して、検証と採用の間の不整合を避ける。
    Picture:=TPicture.Create;
    try Picture.LoadFromFile(Path); if (Picture.Width<>W) or (Picture.Height<>H) then raise Exception.Create('画像の復号寸法が一致しません。'); finally Picture.Free; end;
  finally Stream.Free; end;
end;
function CopyValidatedComicImage(const Source,Root,Prefix: string): string;
var Input: TFileStream; Output: THandleStream; Handle: THandle; Target,Ext: string;
begin
  RequireLocalImagePath(Source); RequireLocalImagePath(Root); Ext:=LowerCase(ExtractFileExt(Source));
  if not (Ext='.png') and not (Ext='.jpg') and not (Ext='.jpeg') and not (Ext='.bmp') then raise Exception.Create('PNG/JPEG/BMP画像を指定してください。');
  Input:=TFileStream.Create(Source,fmOpenRead or fmShareDenyWrite);
  try
    if (Input.Size<26) or (Input.Size>64*1024*1024) then raise Exception.Create('画像ファイルのサイズが不正です。');
    Result:=Prefix+NewUID+Ext; Target:=SafeChild(Root,Result); ForceDirectories(ExtractFileDir(Target));
    Handle:=CreateFile(PChar(Target),GENERIC_WRITE,0,nil,CREATE_NEW,FILE_ATTRIBUTE_NORMAL,0);
    if Handle=INVALID_HANDLE_VALUE then RaiseLastOSError;
    try
      Output:=THandleStream.Create(Handle);
      try Output.CopyFrom(Input,Input.Size); finally Output.Free; end;
    // 失敗時に消すのはこの要求がCREATE_NEWで作成したコピーだけで、元画像や旧採用画像を消さない。
    except CloseHandle(Handle); DeleteFile(PChar(Target)); raise; end;
    CloseHandle(Handle);
    try ValidateComicImage(Target); except DeleteFile(PChar(Target)); raise; end;
  finally Input.Free; end;
end;
end.
