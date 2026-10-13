program MangaMaker;

uses
  System.SysUtils,
  System.IOUtils,
  Vcl.Forms,
  Vcl.Themes,
  Vcl.Styles,
  MangaMakerMainForm in 'Source\Shell\MangaMakerMainForm.pas' {MainForm};

{$R *.res}

var
  IsSelfTest: Boolean;
  TestFolder,TestData: string;

begin
  IsSelfTest:=(ParamCount>0) and (ParamStr(1)='--self-test');
  if IsSelfTest then
  begin
    // Validate before form construction can read the shared user library.
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
  Application.CreateForm(TMainForm, MainForm);
  if IsSelfTest then
  begin
    try
      MainForm.SmokeTest(ParamStr(2));
      MainForm.Free;
      Halt(0);
    except on E: Exception do
      begin
        TFile.WriteAllText(TPath.Combine(ParamStr(2),'result.txt'),'FAIL: '+E.ClassName+': '+E.Message,TEncoding.UTF8);
        Halt(1);
      end;
    end;
  end;
  Application.Run;
end.
