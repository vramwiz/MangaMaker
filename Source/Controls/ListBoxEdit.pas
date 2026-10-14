unit ListBoxEdit;

{
  TListBoxEdit
  -------------------------------------------
  編集可能な TListBox コンポーネント。

  本クラスは TListBox を拡張し、ユーザーがリスト項目を
  直接編集できる機能を提供します。
  編集は TEdit コントロールを使用して項目上に重ねて表示され
  ダブルクリックや外部からの指示で編集モードに入ることができます。

  主な特徴：
    - 任意の項目をダブルクリックで編集可能
    - 編集完了（Enter）およびキャンセル（Esc）操作に対応
    - 編集可否は OnCanEdit で判定可能
    - 編集完了時に OnItemEdited イベントを発火

}

// 責務：Garetonの編集可能リストを再利用し、グループ名を確定・取消できる入力範囲を提供する。
interface

uses
  System.Classes, System.SysUtils, Vcl.Controls, Vcl.StdCtrls,
  Winapi.Windows, Winapi.Messages, Vcl.Graphics, Vcl.Forms,ExtCtrls;

type
  TEditListBoxEditedEvent = procedure(Sender: TObject; const EditStr: string; const Index : Integer) of object;
  TListBoxCanEditEvent = procedure(Sender: TObject; Index: Integer; var CanEdit: Boolean) of object;

type
  TListBoxEdit = class(TListBox)
  private
    FEdit: TEdit;
    FEditIndex: Integer;
    FClickTimer: TTimer;
    FOnItemEdited: TEditListBoxEditedEvent;
    FDelayTime: Integer;
    FOnCanEdit: TListBoxCanEditEvent;
    procedure DoDelayedClick(Sender: TObject);
    procedure BeginEdit(Index: Integer);
    procedure EndEdit(Accept: Boolean);
    procedure EditExit(Sender: TObject);
    procedure EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure SetDelayTime(const Value: Integer);
  protected
    procedure WndProc(var Message: TMessage); override;
    procedure Click; override;
    procedure DblClick; override;
    procedure DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState); override;
    procedure DoItemEdited(const EditStr: string; const Index : Integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property DelayTime: Integer read FDelayTime write SetDelayTime default 300;
    property OnItemEdited: TEditListBoxEditedEvent read FOnItemEdited write FOnItemEdited;
    property OnCanEdit: TListBoxCanEditEvent read FOnCanEdit write FOnCanEdit;
  end;

implementation

{ TListBoxEdit }

procedure TListBoxEdit.Click;
begin
  // 即時クリック抑制 → 遅延トリガに変更
  FClickTimer.Enabled := False;
  FClickTimer.Enabled := True;
end;

constructor TListBoxEdit.Create(AOwner: TComponent);
begin
  inherited;

  FClickTimer := TTimer.Create(Self);
  FClickTimer.Enabled := False;
  FDelayTime := 300;
  FClickTimer.Interval := FDelayTime;
  FClickTimer.OnTimer := DoDelayedClick;

  Style := lbOwnerDrawFixed;
  FEdit := TEdit.Create(Self);
  FEdit.Visible := False;
  FEdit.Parent := Self;
  FEdit.OnExit := EditExit;
  FEdit.OnKeyDown := EditKeyDown;
  FEditIndex := -1;
end;

destructor TListBoxEdit.Destroy;
begin
  FEdit.Free;
  FClickTimer.Enabled := False;
  FClickTimer.Free;
  inherited;
end;

procedure TListBoxEdit.DoDelayedClick(Sender: TObject);
begin
  FClickTimer.Enabled := False;
  inherited Click;  // 本来の Click を発火させる（OnClick イベント呼び出し）
end;

procedure TListBoxEdit.DoItemEdited(const EditStr: string;  const Index: Integer);
begin
  if Assigned(FOnItemEdited) then  FOnItemEdited(Self,EditStr,Index);
end;

procedure TListBoxEdit.BeginEdit(Index: Integer);
var
  R: TRect;
  CanEdit: Boolean;
begin
  if (Index < 0) or (Index >= Items.Count) then Exit;
  CanEdit := True;
  if Assigned(FOnCanEdit) then FOnCanEdit(Self,Index,CanEdit);
  if not CanEdit then Exit;
  R := ItemRect(Index);

  FEdit.SetBounds(R.Left, R.Top, R.Width, ItemHeight);
  FEdit.Text := Items[Index];
  FEdit.Tag := Index;
  FEdit.BorderStyle := bsNone;
  FEdit.Ctl3D := False;
  FEdit.Visible := True;
  FEdit.BringToFront;
  FEdit.SelectAll;
  FEdit.SetFocus;

  FEditIndex := Index;
end;

procedure TListBoxEdit.EndEdit(Accept: Boolean);
var Index: Integer; Value: string;
begin
  Index := FEditIndex; Value := FEdit.Text;
  // 通知先がリストを再構築しても再入・二重確定しないよう、入力状態を先に閉じる。
  FEditIndex := -1;
  FEdit.Visible := False;
  if (Index >= 0) and (Index < Items.Count) then
  begin
    if Accept then
    begin
      Items[Index] := Value;
      DoItemEdited(Value,Index);
    end;
  end;
end;

procedure TListBoxEdit.SetDelayTime(const Value: Integer);
var
  v : Integer;
begin
  v := Value;
  if v < 10 then v := 10;  // 最小値を設定
  if v <> FDelayTime then
  begin
    FDelayTime := v;
    if Assigned(FClickTimer) then
      FClickTimer.Interval := v;
  end;
end;

procedure TListBoxEdit.EditExit(Sender: TObject);
begin
  EndEdit(True);
end;

procedure TListBoxEdit.EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_RETURN: begin EndEdit(True); Key := 0; end;
    VK_ESCAPE: begin EndEdit(False); Key := 0; end;
  end;
end;

procedure TListBoxEdit.DblClick;
begin
  FClickTimer.Enabled := False;
  inherited;
  if ItemIndex >= 0 then
    BeginEdit(ItemIndex);
end;

procedure TListBoxEdit.WndProc(var Message: TMessage);
begin
  inherited;
  if Message.Msg = WM_KEYDOWN then
  begin
    if (Message.WParam = VK_F2) and (ItemIndex >= 0) then
    begin
      BeginEdit(ItemIndex);
      Message.Result := 1;
    end;
  end;
end;

procedure TListBoxEdit.DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState);
begin
  if Index = FEditIndex then
    Canvas.Brush.Color := Color
  else if odSelected in State then
    Canvas.Brush.Color := clHighlight
  else
    Canvas.Brush.Color := Color;

  Canvas.FillRect(Rect);

  Canvas.Font.Assign(Font);
  if odSelected in State then Canvas.Font.Color := clHighlightText;
  Canvas.TextRect(Rect,Rect.Left,Rect.Top,Items[Index]);
end;

end.

