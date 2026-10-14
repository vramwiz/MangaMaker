unit ComicExportDialog;

interface

uses Winapi.Windows, System.Classes, System.UITypes, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TComicExportDialog = class(TForm)
  private
    FRadio: TRadioGroup;
    FLabel,FWarning: TLabel;
    FOutput: TEdit;
    FApply,FCancel,FOpen: TButton;
    procedure ResizeControls(Sender: TObject);
    function GetWarningText: string;
    function GetOutputPath: string;
  protected
    procedure ChangeScale(M,D: Integer; isDpiChange: Boolean); override;
  public
    constructor CreateOptions(AOwner: TComponent; const Output: string; OpenFolder: TNotifyEvent; const Warnings: string='');
    property WarningText: string read GetWarningText;
    property OutputPath: string read GetOutputPath;
    function Accepted(out All: Boolean): Boolean;
  end;

implementation

constructor TComicExportDialog.CreateOptions(AOwner: TComponent; const Output: string; OpenFolder: TNotifyEvent; const Warnings: string);
begin
  inherited CreateNew(AOwner); Caption:='連番PNG出力'; Position:=poOwnerFormCenter; ClientWidth:=600; ClientHeight:=246;
  BorderStyle:=bsDialog; Font.Name:='Yu Gothic UI'; Font.Size:=10;
  FLabel:=TLabel.Create(Self); FLabel.Parent:=Self; FLabel.AutoSize:=False; FLabel.Caption:='出力先：';
  FOutput:=TEdit.Create(Self); FOutput.Parent:=Self; FOutput.ReadOnly:=True; FOutput.Text:=Output;
  FOutput.Hint:=Output; FOutput.ShowHint:=True;
  FWarning:=TLabel.Create(Self); FWarning.Parent:=Self; FWarning.AutoSize:=False; FWarning.WordWrap:=True;
  FWarning.Caption:=Warnings; FWarning.Visible:=Warnings<>'';
  if FWarning.Visible then ClientHeight:=340;
  FRadio:=TRadioGroup.Create(Self); FRadio.Parent:=Self; FRadio.SetBounds(16,82,568,92); FRadio.Caption:='出力対象';
  FRadio.Items.Add('変更されたページのみ'); FRadio.Items.Add('すべてのページ'); FRadio.ItemIndex:=0;
  FApply:=TButton.Create(Self); FApply.Parent:=Self; FApply.Caption:='出力'; FApply.Default:=True; FApply.ModalResult:=mrOK;
  FCancel:=TButton.Create(Self); FCancel.Parent:=Self; FCancel.Caption:='取消'; FCancel.Cancel:=True; FCancel.ModalResult:=mrCancel;
  FOpen:=TButton.Create(Self); FOpen.Parent:=Self; FOpen.Caption:='出力フォルダーを開く'; FOpen.OnClick:=OpenFolder;
  OnResize:=ResizeControls; ResizeControls(nil);
end;
procedure TComicExportDialog.ResizeControls(Sender: TObject);
var Gap,Width,Height,Y,RadioTop: Integer;
begin
  if FOpen=nil then Exit;
  Gap:=MulDiv(16,ClientWidth,600); Width:=MulDiv(100,ClientWidth,600); Height:=MulDiv(32,ClientWidth,600); Y:=ClientHeight-Gap-Height;
  FCancel.SetBounds(ClientWidth-Gap-Width,Y,Width,Height); FApply.SetBounds(FCancel.Left-Gap-Width,Y,Width,Height);
  FOpen.SetBounds(Gap,Y,MulDiv(220,ClientWidth,600),Height);
  FLabel.SetBounds(Gap,Gap,ClientWidth-Gap*2,MulDiv(20,ClientWidth,600));
  FOutput.SetBounds(Gap,FLabel.Top+FLabel.Height+Gap div 2,ClientWidth-Gap*2,MulDiv(28,ClientWidth,600));
  RadioTop:=FOutput.Top+FOutput.Height+Gap div 2;
  FWarning.SetBounds(Gap,RadioTop,ClientWidth-Gap*2,MulDiv(64,ClientWidth,600));
  if FWarning.Visible then RadioTop:=FWarning.Top+FWarning.Height+Gap div 2;
  FRadio.SetBounds(Gap,RadioTop,ClientWidth-Gap*2,Y-RadioTop-Gap);
end;
procedure TComicExportDialog.ChangeScale(M,D: Integer; isDpiChange: Boolean);
begin inherited; ResizeControls(nil); end;
function TComicExportDialog.GetOutputPath: string;
begin Result:=FOutput.Text; end;
function TComicExportDialog.GetWarningText: string;
begin Result:=FWarning.Caption; end;
function TComicExportDialog.Accepted(out All: Boolean): Boolean;
begin Result:=ModalResult=mrOK; All:=Result and (FRadio.ItemIndex=1); end;

end.
