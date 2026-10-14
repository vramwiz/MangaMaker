program MangaMaker;

uses
  System.SysUtils,
  System.IOUtils,
  Vcl.Forms,
  Vcl.Themes,
  Vcl.Styles,
{$IFDEF MANGAMAKER_SELFTEST}
  ComicTestSupport in 'Source\Tests\Support\ComicTestSupport.pas',
  ComicSelfTests in 'Source\Tests\Support\ComicSelfTests.pas',
{$ENDIF}
  MangaMakerMainForm in 'Source\Shell\MangaMakerMainForm.pas' {MainForm};

{$R *.res}

var
  IsSelfTest: Boolean;
  TestFolder,TestData: string;

begin
  IsSelfTest:=(ParamCount>0) and (ParamStr(1)='--self-test');
{$IFNDEF MANGAMAKER_SELFTEST}
  if IsSelfTest then Halt(2);
{$ENDIF}
  if IsSelfTest then
  begin
    // 共有ライブラリに触れるフォームを作る前に、自己検証データの隔離条件を確認する。
    if ParamCount<>2 then Halt(2);
    TestFolder:=TPath.GetFullPath(ParamStr(2));
    TestData:=GetEnvironmentVariable('MANGAMAKER_DATA_ROOT');
    if (TestData='') or not TPath.GetFullPath(TestData).StartsWith(
      IncludeTrailingPathDelimiter(TestFolder),True) then Halt(2);
    ForceDirectories(TestFolder);
  end;
  Application.Initialize;
  TStyleManager.TrySetStyle('Windows Modern Dark');
  Application.MainFormOnTaskbar := True;
  Application.Title := 'MangaMaker';
{$IFDEF MANGAMAKER_SELFTEST}
  if IsSelfTest then Application.CreateForm(TComicTestForm, MainForm)
  else
{$ENDIF}
    Application.CreateForm(TMainForm, MainForm);
{$IFDEF MANGAMAKER_SELFTEST}
  if IsSelfTest then
  begin
    try
      RunSelfTests(TComicTestForm(MainForm),ParamStr(2));
      MainForm.Free;
      Halt(0);
    except on E: Exception do
      begin
        TFile.WriteAllText(TPath.Combine(ParamStr(2),'result.txt'),'FAIL: '+E.ClassName+': '+E.Message,TEncoding.UTF8);
        Halt(1);
      end;
    end;
  end;
{$ENDIF}
  Application.Run;
end.
