unit ComicCharacterRefs;

// 責務：人物の共通情報と服装別参照を整理し、生成対象に必要な参照だけを選ぶ。

interface

uses Winapi.Windows, System.SysUtils, System.Classes, System.Generics.Collections, Vcl.Forms, Vcl.Controls, Vcl.StdCtrls,
  Vcl.CheckLst, Vcl.ExtCtrls, ComicModel;

type
  TComicCharacterRefDialog = class(TForm)
  private
    FList: TCheckListBox;
    FIDs: TList<string>;
    FSelected: TArray<string>;
    FBar: TPanel;
    FAccept,FCancel: TButton;
    procedure Commit(Sender: TObject);
    procedure ResizeActions(Sender: TObject);
  public
    constructor CreateSelector(AOwner: TComponent; Characters: TObjectList<TComicAsset>; const Selected: TArray<string>);
    destructor Destroy; override;
    procedure SetChecked(const ID: string; Checked: Boolean);
    procedure AcceptSelection;
    property SelectedIDs: TArray<string> read FSelected;
  end;

implementation

constructor TComicCharacterRefDialog.CreateSelector(AOwner: TComponent; Characters: TObjectList<TComicAsset>; const Selected: TArray<string>);
var Item: TComicAsset; Ref,LabelText: string; LabelControl: TLabel;
begin
  inherited CreateNew(AOwner); FIDs:=TList<string>.Create; FSelected:=Copy(Selected); Caption:='この画像で参照する人物・服装';
  Width:=600; Height:=500; Position:=poOwnerFormCenter; Font.Name:='Yu Gothic UI'; Font.Size:=10;
  Constraints.MinWidth:=500; Constraints.MinHeight:=350;
  LabelControl:=TLabel.Create(Self); LabelControl.Parent:=Self; LabelControl.AutoSize:=False; LabelControl.Align:=alTop; LabelControl.Height:=48; LabelControl.WordWrap:=True;
  LabelControl.Caption:='生成に必要な人物・服装だけを選びます。0件も選択できます。人物の基本服装と別服装は個別の参照です。';
  FBar:=TPanel.Create(Self); FBar.Parent:=Self; FBar.Align:=alBottom; FBar.Height:=52; FBar.BevelOuter:=bvNone;
  FAccept:=TButton.Create(Self); FAccept.Parent:=FBar; FAccept.Caption:='適用'; FAccept.Default:=True; FAccept.OnClick:=Commit;
  FCancel:=TButton.Create(Self); FCancel.Parent:=FBar; FCancel.Caption:='取消'; FCancel.Cancel:=True; FCancel.ModalResult:=mrCancel;
  FBar.OnResize:=ResizeActions; OnResize:=ResizeActions; ResizeActions(nil);
  FList:=TCheckListBox.Create(Self); FList.Parent:=Self; FList.Align:=alClient;
  for Item in Characters do begin
    LabelText:=Item.CharacterName; if LabelText='' then LabelText:=Item.Name;
    if Item.StateName<>'' then LabelText:=LabelText+' / '+Item.StateName;
    FList.Items.Add(LabelText); FIDs.Add(Item.ID);
  end;
  for Ref in Selected do begin
    if not FIDs.Contains(Ref) then begin FIDs.Add(Ref); FList.Items.Add('見つからない参照: '+Ref); end;
    SetChecked(Ref,True);
  end;
end;
procedure TComicCharacterRefDialog.ResizeActions(Sender: TObject);
var Width,Height,Gap: Integer;
begin
  if (FBar=nil) or (FAccept=nil) or (FCancel=nil) then Exit;
  Width:=MulDiv(100,CurrentPPI,96); Height:=MulDiv(32,CurrentPPI,96); Gap:=MulDiv(12,CurrentPPI,96);
  FCancel.SetBounds(FBar.ClientWidth-Gap-Width,(FBar.ClientHeight-Height) div 2,Width,Height);
  FAccept.SetBounds(FCancel.Left-Gap-Width,FCancel.Top,Width,Height);
end;
destructor TComicCharacterRefDialog.Destroy;
begin FIDs.Free; inherited; end;
procedure TComicCharacterRefDialog.SetChecked(const ID: string; Checked: Boolean);
var At: Integer;
begin At:=FIDs.IndexOf(ID); if At>=0 then FList.Checked[At]:=Checked; end;
procedure TComicCharacterRefDialog.AcceptSelection;
var I: Integer; Selected: TList<string>;
begin
  Selected:=TList<string>.Create;
  try for I:=0 to FIDs.Count-1 do if FList.Checked[I] then Selected.Add(FIDs[I]); FSelected:=Selected.ToArray; finally Selected.Free; end;
  ModalResult:=mrOK;
end;
procedure TComicCharacterRefDialog.Commit(Sender: TObject);
begin AcceptSelection; end;

end.
