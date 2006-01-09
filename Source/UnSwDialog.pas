{: Contains the UnitSwitcher main dialog.

   Last changed:    $Date$
   Revision:        $Rev$
   Author:          $Author$
}
unit UnSwDialog;

interface
uses
  ActnList,
  Classes,
  ComCtrls,
  Controls,
  ExtCtrls,
  Forms,
  Graphics,
  ImgList,
  StdCtrls,
  Windows,

  UnSwObjects,
  UnSwFilters;

type
  TUnSwStyleVisitor = class(TUnSwNoRefIntfObject, IUnSwVisitor)
  private
    FColor:             TColor;
    FImageIndex:        Integer;
  protected
    procedure VisitModule(const AUnit: TUnSwModuleUnit);
    procedure VisitProject(const AUnit: TUnSwProjectUnit);
  public
    property Color:           TColor  read FColor;
    property ImageIndex:      Integer read FImageIndex;
  end;

  TfrmUnSwDialog = class(TForm)
    btnCancel:                                  TButton;
    btnConfiguration:                           TButton;
    btnOK:                                      TButton;
    chkDataModules:                             TCheckBox;
    chkForms:                                   TCheckBox;
    chkProjectSource:                           TCheckBox;
    edtSearch:                                  TEdit;
    ilsTypes:                                   TImageList;
    lstUnits:                                   TListBox;
    pnlButtons:                                 TPanel;
    pnlIncludeTypes:                            TPanel;
    pnlMain:                                    TPanel;
    pnlSearch:                                  TPanel;
    sbStatus:                                   TStatusBar;
    alMain: TActionList;
    actSelectAll: TAction;
    procedure FormShow(Sender: TObject);
    procedure actSelectAllExecute(Sender: TObject);

    procedure FormResize(Sender: TObject);
    procedure btnConfigurationClick(Sender: TObject);
    procedure edtSearchChange(Sender: TObject);
    procedure edtSearchKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure TypeFilterChange(Sender: TObject);
    procedure lstUnitsDblClick(Sender: TObject);
    procedure lstUnitsData(Control: TWinControl; Index: Integer; var Data: string);
    procedure lstUnitsDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
  private
    FLoading:               Boolean;
    FUnitList:              TUnSwUnitList;
    FActiveUnit:            TUnSwUnit;
    FFormsOnly:             Boolean;

    FTypeFilteredList:      TUnSwUnitList;
    FInputFilteredList:     TUnSwUnitList;

    FTypeFilter:            TUnSwUnitTypeFilter;
    FInputFilter:           TUnSwUnitSimpleFilter;

    FStyleVisitor:          TUnSwStyleVisitor;

    function InternalExecute(): TUnSwUnitList;
    procedure UpdateTypeFilter();
    procedure UpdateList();

    function GetActiveUnits(): TUnSwUnitList;

    procedure LoadSettings();
    procedure SaveSettings();
  public
    class function Execute(const AUnits: TUnSwUnitList;
                           const AFormsOnly: Boolean;
                           const AActive: TUnSwUnit = nil): TUnSwUnitList;
  end;

implementation
uses
  Messages,
  SysUtils,

  UnSwConfiguration,
  UnSwSettings;


{$R *.dfm}


{ TUnSwStyleVisitor }
procedure TUnSwStyleVisitor.VisitModule(const AUnit: TUnSwModuleUnit);
begin
  case AUnit.UnitType of
    swutUnit:
      begin
        FColor      := Settings.Colors.Units;
        FImageIndex := 1;
      end;
    swutForm:
      begin
        FColor      := Settings.Colors.Forms;
        FImageIndex := 2;
      end;
    swutDataModule:
      begin
        FColor      := Settings.Colors.DataModules;
        FImageIndex := 3;
      end
  else
    FColor      := clWindowText;
    FImageIndex := 0;
  end;
end;

procedure TUnSwStyleVisitor.VisitProject(const AUnit: TUnSwProjectUnit);
begin
  FColor      := Settings.Colors.ProjectSource;
  FImageIndex := 4;
end;


{ TfrmUnSwDialog }
class function TfrmUnSwDialog.Execute(const AUnits: TUnSwUnitList;
                                      const AFormsOnly: Boolean;
                                      const AActive: TUnSwUnit): TUnSwUnitList;
begin
  with Self.Create(nil) do
  try
    FUnitList   := AUnits;
    FActiveUnit := AActive;
    FFormsOnly  := AFormsOnly;
    Result      := InternalExecute();
  finally
    Free();
  end;
end;

procedure TfrmUnSwDialog.FormResize(Sender: TObject);
begin
  lstUnits.Invalidate();
end;

procedure TfrmUnSwDialog.FormShow(Sender: TObject);
begin
  // Setting ListBox.Selected[x] won't work before OnShow...
  UpdateTypeFilter();
end;

function SortByName(Item1, Item2: Pointer): Integer;
begin
  Result  := CompareText(TUnSwUnit(Item1).Name, TUnSwUnit(Item2).Name)
end;

function TfrmUnSwDialog.InternalExecute(): TUnSwUnitList;
begin
  Result              := nil;
  FTypeFilteredList   := TUnSwUnitList.Create();
  FInputFilteredList  := TUnSwUnitList.Create();
  FTypeFilter         := TUnSwUnitTypeFilter.Create(FTypeFilteredList);

  if FFormsOnly then
    FInputFilter      := TUnSwUnitSimpleFormNameFilter.Create(FInputFilteredList)
  else
    FInputFilter      := TUnSwUnitSimpleNameFilter.Create(FInputFilteredList);
  try
    LoadSettings();

    if FFormsOnly then
    begin
      pnlIncludeTypes.Visible   := False;
      Self.Caption              := 'UnitSwitcher - View Form';
    end else
      Self.Caption              := 'UnitSwitcher - View Unit';

    FStyleVisitor := TUnSwStyleVisitor.Create();
    try
      if Self.ShowModal() = mrOk then
        Result  := GetActiveUnits();

      SaveSettings();
    finally
      FreeAndNil(FStyleVisitor);
    end;
  finally
    FreeAndNil(FInputFilter);
    FreeAndNil(FTypeFilter);
    FreeAndNil(FInputFilteredList);
    FreeAndNil(FTypeFilteredList);
  end;
end;

procedure TfrmUnSwDialog.UpdateList();
var
  activeUnit:       TUnSwUnit;
  activeUnits:      TUnSwUnitList;
  itemIndex:        Integer;
  listIndex:        Integer;

begin
  activeUnits := GetActiveUnits();

  FInputFilteredList.Clone(FTypeFilteredList);
  FInputFilteredList.AcceptVisitor(FInputFilter);

  lstUnits.Count  := FInputFilteredList.Count;
  if FInputFilteredList.Count > 0 then
  begin
    lstUnits.ClearSelection();

    if Assigned(activeUnits) then
    try
      for itemIndex := 0 to Pred(activeUnits.Count) do
      begin
        activeUnit  := activeUnits[itemIndex];
        listIndex   := FInputFilteredList.IndexOf(activeUnit);
        if listIndex > -1 then
          lstUnits.Selected[listIndex]  := True;
      end;
    finally
      FreeAndNil(activeUnits);
    end else
      lstUnits.Selected[0]  := True;
  end;
end;

procedure TfrmUnSwDialog.UpdateTypeFilter();
begin
  FTypeFilter.IncludeUnits          := not FFormsOnly;
  FTypeFilter.IncludeForms          := (FFormsOnly or chkForms.Checked);
  FTypeFilter.IncludeDataModules    := (FFormsOnly or chkDataModules.Checked);
  FTypeFilter.IncludeProjectSource  := ((not FFormsOnly) and chkProjectSource.Checked);

  FTypeFilteredList.Clone(FUnitList);
  FTypeFilteredList.AcceptVisitor(FTypeFilter);
  FTypeFilteredList.Sort(SortByName);
  UpdateList();
end;

function TfrmUnSwDialog.GetActiveUnits(): TUnSwUnitList;
var
  itemIndex:      Integer;

begin
  Result  := nil;

  if Assigned(FActiveUnit) then
  begin
    Result              := TUnSwUnitList.Create();
    Result.OwnsObjects  := False;
    Result.Add(FActiveUnit);
    FActiveUnit         := nil;
  end else if lstUnits.SelCount > 0 then
  begin
    Result              := TUnSwUnitList.Create();
    Result.OwnsObjects  := False;
    for itemIndex := 0 to Pred(lstUnits.Items.Count) do
      if lstUnits.Selected[itemIndex] then
        Result.Add(FInputFilteredList[itemIndex]);
  end;
end;


procedure TfrmUnSwDialog.LoadSettings();
var
  dialogSettings:       TUnSwDialogSettings;

begin
  if FFormsOnly then
    dialogSettings  := Settings.FormsDialog
  else
    dialogSettings  := Settings.UnitsDialog;

  FLoading  := True;
  try
    chkDataModules.Checked    := dialogSettings.IncludeDataModules;
    chkForms.Checked          := dialogSettings.IncludeForms;
    chkProjectSource.Checked  := dialogSettings.IncludeProjectSource;

    Self.ClientWidth          := dialogSettings.Width;
    Self.ClientHeight         := dialogSettings.Height;
  finally
    FLoading  := False;
  end;
end;

procedure TfrmUnSwDialog.SaveSettings();
var
  dialogSettings:       TUnSwDialogSettings;

begin
  if FFormsOnly then
    dialogSettings  := Settings.FormsDialog
  else
    dialogSettings  := Settings.UnitsDialog;

  dialogSettings.IncludeDataModules   := chkForms.Checked;
  dialogSettings.IncludeForms         := chkDataModules.Checked;
  dialogSettings.IncludeProjectSource := chkProjectSource.Checked;

  dialogSettings.Width                := Self.ClientWidth;
  dialogSettings.Height               := Self.ClientHeight;

  Settings.Save();
end;


procedure TfrmUnSwDialog.actSelectAllExecute(Sender: TObject);
begin
  lstUnits.SelectAll();
end;

procedure TfrmUnSwDialog.btnConfigurationClick(Sender: TObject);
begin
  if TfrmUnSwConfiguration.Execute() then
    lstUnits.Invalidate();
end;

procedure TfrmUnSwDialog.edtSearchChange(Sender: TObject);
begin
  FInputFilter.Filter := edtSearch.Text;
  UpdateList();
end;

procedure TfrmUnSwDialog.edtSearchKeyDown(Sender: TObject; var Key: Word;
                                          Shift: TShiftState);
begin
  if ((Shift = []) and (Key in [VK_UP, VK_DOWN, VK_PRIOR, VK_NEXT])) or
     ((Shift = [ssCtrl]) and (Key in [VK_UP, VK_DOWN, VK_HOME, VK_END])) or
     ((Shift = [ssShift]) and (Key in [VK_UP, VK_DOWN, VK_PRIOR, VK_NEXT])) then
    lstUnits.Perform(WM_KEYDOWN, Key, 0);
end;

procedure TfrmUnSwDialog.TypeFilterChange(Sender: TObject);
begin
  if not FLoading then
    UpdateTypeFilter();
end;

procedure TfrmUnSwDialog.lstUnitsDblClick(Sender: TObject);
begin
  btnOK.Click();
end;

procedure TfrmUnSwDialog.lstUnitsData(Control: TWinControl; Index: Integer;
                                      var Data: string);
begin
  Data  := FInputFilteredList[Index].Name;
end;

procedure TfrmUnSwDialog.lstUnitsDrawItem(Control: TWinControl; Index: Integer;
                                          Rect: TRect; State: TOwnerDrawState);
var
  currentUnit:  TUnSwUnit;
  textRect:     TRect;
  text:         String;

begin
  with TListBox(Control) do
  begin
    currentUnit := FInputFilteredList[Index];
    currentUnit.AcceptVisitor(FStyleVisitor);
    
    if FFormsOnly and (currentUnit is TUnSwModuleUnit) then
      text  := TUnSwModuleUnit(currentUnit).FormName
    else
      text  := currentUnit.Name;

    if odSelected in State then
    begin
      Canvas.Brush.Color  := clHighlight;
      Canvas.Font.Color   := clHighlightText;
    end else
    begin
      Canvas.Brush.Color  := clWindow;
      if Settings.Colors.Enabled then
        Canvas.Font.Color := FStyleVisitor.Color
      else
        Canvas.Font.Color := clWindowText;
    end;
    Canvas.FillRect(Rect);

    textRect  := Rect;
    InflateRect(textRect, -2, -2);
    ilsTypes.Draw(Canvas, textRect.Left, textRect.Top, FStyleVisitor.ImageIndex);

    Inc(textRect.Left, ilsTypes.Width + 4);
    DrawText(Canvas.Handle, PChar(text), Length(text), textRect, DT_SINGLELINE or
             DT_LEFT or DT_VCENTER or DT_END_ELLIPSIS);
  end;
end;

end.