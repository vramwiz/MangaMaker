unit ComicExportDialog;

interface

uses Winapi.Windows, System.Classes, System.UITypes, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TComicExportDialog = class(TForm)
  private
    FRadio: TRadioGroup;
    FLabel: TLabel;
    FApply,FCancel,FOpen: TButton;
    procedure ResizeControls(Sender: TObject);
  protected
    procedure ChangeScale(M,D: Integer; isDpiChange: Boolean); override;
  public
    constructor CreateOptions(AOwner: TComponent; const Output: string; OpenFolder: TNotifyEvent);
    function Accepted(out All: Boolean): Boolean;
  end;

implementation

constructor TComicExportDialog.CreateOptions(AOwner: TComponent; const Output: string; OpenFolder: TNotifyEvent);
begin
  inherited CreateNew(AOwner); Caption:='連番PNG出力'; Position:=poOwnerFormCenter; ClientWidth:=600; ClientHeight:=246;
  BorderStyle:=bsDialog; Font.Name:='Yu Gothic UI'; Font.Size:=10;
  FLabel:=TLabel.Create(Self); FLabel.Parent:=Self; FLabel.AutoSize:=False; FLabel.WordWrap:=True; FLabel.Caption:='出力先：'+Output;
  FRadio:=TRadioGroup.Create(Self); FRadio.Parent:=Self; FRadio.SetBounds(16,82,568,92); FRadio.Caption:='出力対象';
  FRadio.Items.Add('変更されたページのみ'); FRadio.Items.Add('すべてのページ'); FRadio.ItemIndex:=0;
  FApply:=TButton.Create(Self); FApply.Parent:=Self; FApply.Caption:='出力'; FApply.Default:=True; FApply.ModalResult:=mrOK;
  FCancel:=TButton.Create(Self); FCancel.Parent:=Self; FCancel.Caption:='取消'; FCancel.Cancel:=True; FCancel.ModalResult:=mrCancel;
  FOpen:=TButton.Create(Self); FOpen.Parent:=Self; FOpen.Caption:='出力フォルダーを開く'; FOpen.OnClick:=OpenFolder;
  OnResize:=ResizeControls; ResizeControls(nil);
end;
procedure TComicExportDialog.ResizeControls(Sender: TObject);
var Gap,Width,Height,Y: Integer;
begin
  if FOpen=nil then Exit;
  Gap:=MulDiv(16,ClientWidth,600); Width:=MulDiv(100,ClientWidth,600); Height:=MulDiv(32,ClientWidth,600); Y:=ClientHeight-Gap-Height;
  FCancel.SetBounds(ClientWidth-Gap-Width,Y,Width,Height); FApply.SetBounds(FCancel.Left-Gap-Width,Y,Width,Height);
  FOpen.SetBounds(Gap,Y,MulDiv(220,ClientWidth,600),Height);
  FLabel.SetBounds(Gap,Gap,ClientWidth-Gap*2,MulDiv(58,ClientWidth,600));
  FRadio.SetBounds(Gap,FLabel.Top+FLabel.Height+Gap div 2,ClientWidth-Gap*2,Y-FLabel.Top-FLabel.Height-Gap*2);
end;
procedure TComicExportDialog.ChangeScale(M,D: Integer; isDpiChange: Boolean);
begin inherited; ResizeControls(nil); end;
function TComicExportDialog.Accepted(out All: Boolean): Boolean;
begin Result:=ModalResult=mrOK; All:=Result and (FRadio.ItemIndex=1); end;

end.
