{: Implements unit handling.

   Last changed:    $Date$
   Revision:        $Rev$
   Author:          $Author$
}
unit UnSwObjects;

{$I UnSwDefines.inc}

interface
uses
  Classes,
  Contnrs,
  ToolsAPI;

type
  // Forward declarations
  TUnSwUnit             = class;
  TUnSwModuleUnit       = class;
  TUnSwProjectUnit      = class;
  

  IUnSwVisitor          = interface
    ['{A822C25B-5D0F-462F-94DD-47CD6235D79F}']
    procedure VisitModule(const AUnit: TUnSwModuleUnit);
    procedure VisitProject(const AUnit: TUnSwProjectUnit);
  end;

  IUnSwVisited          = interface
    ['{9540671E-184B-4DB6-A015-27B457C74C6C}']
    procedure AcceptVisitor(const AVisitor: IUnSwVisitor);
  end;


  TUnSwNoRefIntfObject  = class(TPersistent, IInterface)
  protected
    // IInterface
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef(): Integer; stdcall;
    function _Release(): Integer; stdcall;
  end;


  TUnSwUnit             = class(TUnSwNoRefIntfObject, IUnSwVisited)
  protected
    function GetName(): String; virtual;
    function GetFileName(): String; virtual;

    procedure OpenModule(const AModule: IOTAModule; const ASource: Boolean); virtual;
  public
    // IUnSwVisited
    procedure AcceptVisitor(const AVisitor: IUnSwVisitor); virtual; abstract;

    procedure Activate(const ASource: Boolean); virtual; abstract;

    property Name:          String        read GetName;
    property FileName:      String        read GetFileName;
  end;


  TUnSwUnitType         = (
                          swutForm          = 0,
                          swutDataModule    = 1,
                          swutProjUnit      = 2,
                          swutUnit          = 3,
                          swutRc            = 4,
                          swutAsm           = 5,
                          swutDef           = 6,
                          swutObj           = 7,
                          swutRes           = 8,
                          swutLib           = 9,
                          swutTypeLib       = 10,
                          swutPackageImport = 11,
                          swutFormResource  = 12,
                          swutCustom        = 13,
                          swutIDL           = 14
                          );
  TUnSwUnitTypes        = set of TUnSwUnitType;


  TUnSwModuleUnit       = class(TUnSwUnit)
  private
    FModule:        IOTAModuleInfo;
  protected
    function GetFileName(): String; override;
    function GetFormName(): String;
    function GetName(): String; override;
    function GetUnitType(): TUnSwUnitType;
  public
    constructor Create(const AModule: IOTAModuleInfo);
    procedure AcceptVisitor(const AVisitor: IUnSwVisitor); override;

    procedure Activate(const ASource: Boolean); override;

    property FormName:      String        read GetFormName;
    property UnitType:      TUnSwUnitType read GetUnitType;
  end;

  TUnSwProjectUnit      = class(TUnSwUnit)
  private
    FProject:       IOTAProject;
  protected
    function GetName(): String; override;
    function GetFileName(): String; override;
  public
    constructor Create(const AProject: IOTAProject);
    procedure AcceptVisitor(const AVisitor: IUnSwVisitor); override;

    procedure Activate(const ASource: Boolean); override;
  end;


  TUnSwUnitList         = class(TUnSwNoRefIntfObject, IUnSwVisited)
  private
    FItems:       TObjectList;

    function GetOwnsObjects(): Boolean;
    procedure SetOwnsObjects(const Value: Boolean);

    function GetCount(): Integer;
    function GetItem(Index: Integer): TUnSwUnit;
    procedure SetItem(Index: Integer; Value: TUnSwUnit);
  public
    constructor Create();
    destructor Destroy(); override;

    function Add(const AUnit: TUnSwUnit): Integer; virtual;
    function IndexOf(const AUnit: TUnSwUnit): Integer;
    function IndexOfFileName(const AFileName: String): Integer;
    procedure Delete(const AIndex: Integer);
    function Remove(const AUnit: TUnSwUnit): Integer;

    procedure Sort(Compare: TListSortCompare);
    procedure Clone(const ASource: TUnSwUnitList); virtual;

    procedure AcceptVisitor(const AVisitor: IUnSwVisitor);

    property Count:                 Integer   read GetCount;
    property Items[Index: Integer]: TUnSwUnit read GetItem
                                              write SetItem; default;
    property OwnsObjects:           Boolean   read GetOwnsObjects
                                              write SetOwnsObjects;
  end;

implementation
uses
  {$IFDEF DELPHI7}
  ActnList,
  {$ENDIF}
  SysUtils;


{ TUnSwNoRefIntfObject }
function TUnSwNoRefIntfObject.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
  if GetInterface(IID, Obj) then
    Result  := S_OK
  else
    Result  := E_NOINTERFACE;
end;

function TUnSwNoRefIntfObject._AddRef(): Integer;
begin
  Result  := -1;
end;

function TUnSwNoRefIntfObject._Release(): Integer;
begin
  Result  := -1;
end;


{ TUnSwUnit }
function TUnSwUnit.GetName(): String;
begin
  Result  := '';
end;

function TUnSwUnit.GetFileName(): String;
begin
  Result  := '';
end;


procedure TUnSwUnit.OpenModule(const AModule: IOTAModule; const ASource: Boolean);
var
  editor:         IOTAEditor;
  formEditor:     IOTAFormEditor;
  isForm:         Boolean;
  moduleIndex:    Integer;

begin
  formEditor  := nil;
  for moduleIndex := 0 to Pred(AModule.ModuleFileCount) do
  begin
    editor  := AModule.ModuleFileEditors[moduleIndex];
    isForm  := Supports(editor, IOTAFormEditor);

    if (not ASource) and (isForm) and (not Assigned(formEditor)) then
      formEditor  := (editor as IOTAFormEditor);

    if not isForm then
      editor.Show();
  end;

  if Assigned(formEditor) then
    formEditor.Show();
end;


{ TUnSwModuleUnit }
constructor TUnSwModuleUnit.Create(const AModule: IOTAModuleInfo);
begin
  inherited Create();

  FModule := AModule;
end;

procedure TUnSwModuleUnit.Activate(const ASource: Boolean);
var
  ifModule:     IOTAModule;

begin
  ifModule  := FModule.OpenModule();
  if Assigned(ifModule) then
    OpenModule(ifModule, ASource);
end;

procedure TUnSwModuleUnit.AcceptVisitor(const AVisitor: IUnSwVisitor);
begin
  AVisitor.VisitModule(Self);
end;

function TUnSwModuleUnit.GetName(): String;
begin
  Result  := FModule.Name;
end;

function TUnSwModuleUnit.GetFormName(): String;
begin
  Result  := FModule.FormName;
end;

function TUnSwModuleUnit.GetFileName(): String;
begin
  Result  := FModule.FileName;
end;

function TUnSwModuleUnit.GetUnitType(): TUnSwUnitType;
begin
  Result  := TUnSwUnitType(FModule.ModuleType);

  if Result = swutForm then
    if SameText(FModule.DesignClass, 'TDataModule') then
      Result  := swutDataModule
    else if Length(FModule.FormName) = 0 then
      if Length(FModule.FileName) = 0 then
        Result  := swutProjUnit
      else
        Result  := swutUnit;
end;


{ TUnSwProjectUnit }
constructor TUnSwProjectUnit.Create(const AProject: IOTAProject);
begin
  inherited Create();

  FProject  := AProject;
end;

procedure TUnSwProjectUnit.Activate(const ASource: Boolean);
{$IFDEF DELPHI7}
var
  actionIndex:    Integer;
  ntaServices:    INTAServices;
  action:         TContainedAction;
{$ENDIF}

begin
  {$IFDEF DELPHI7}
  // Bit of a hack, but opening the file itself will result in Delphi 7
  // reloading the project...
  ntaServices := (BorlandIDEServices as INTAServices);
  for actionIndex := 0 to Pred(ntaServices.ActionList.ActionCount) do
  begin
    action  := ntaServices.ActionList.Actions[actionIndex];
    if action.Name = 'ProjectViewSourceCommand' then
    begin
      action.Execute();
      break;
    end;
  end;
  {$ELSE}
  OpenModule(FProject, True);
  {$ENDIF}
end;

procedure TUnSwProjectUnit.AcceptVisitor(const AVisitor: IUnSwVisitor);
begin
  AVisitor.VisitProject(Self);
end;

function TUnSwProjectUnit.GetName(): String;
begin
  Result  := ChangeFileExt(ExtractFileName(FProject.FileName), '');
end;

function TUnSwProjectUnit.GetFileName(): String;
begin
  Result  := FProject.FileName;
end;


{ TUnSwUnitList}
constructor TUnSwUnitList.Create();
begin
  inherited Create();

  FItems  := TObjectList.Create(True);
end;


destructor TUnSwUnitList.Destroy();
begin
  FreeAndNil(FItems);

  inherited;
end;


procedure TUnSwUnitList.AcceptVisitor(const AVisitor: IUnSwVisitor);
var
  itemIndex:    Integer;

begin
  for itemIndex := Pred(Count) downto 0 do
    Items[itemIndex].AcceptVisitor(AVisitor);
end;

function TUnSwUnitList.Add(const AUnit: TUnSwUnit): Integer;
begin
  Result  := FItems.Add(AUnit);
end;

function TUnSwUnitList.IndexOf(const AUnit: TUnSwUnit): Integer;
begin
  Result  := FItems.IndexOf(AUnit);
end;

function TUnSwUnitList.IndexOfFileName(const AFileName: String): Integer;
var
  itemIndex:    Integer;

begin
  Result  := -1;
  if Length(AFileName) = 0 then
    exit;

  for itemIndex := Pred(Count) downto 0 do
    if SameText(Items[itemIndex].FileName, AFileName) then
    begin
      Result  := itemIndex;
      break;
    end;
end;

procedure TUnSwUnitList.Delete(const AIndex: Integer);
begin
  FItems.Delete(AIndex);
end;

function TUnSwUnitList.Remove(const AUnit: TUnSwUnit): Integer;
begin
  Result  := FItems.Remove(AUnit);
end;

procedure TUnSwUnitList.Sort(Compare: TListSortCompare);
begin
  FItems.Sort(Compare);
end;

procedure TUnSwUnitList.Clone(const ASource: TUnSwUnitList);
var
  itemIndex:      Integer;

begin
  FItems.Clear();
  FItems.OwnsObjects  := False;

  for itemIndex := 0 to Pred(ASource.Count) do
    FItems.Add(ASource[itemIndex]);
end;


function TUnSwUnitList.GetCount(): Integer;
begin
  Result  := FItems.Count;
end;

function TUnSwUnitList.GetItem(Index: Integer): TUnSwUnit;
begin
  Result  := TUnSwUnit(FItems[Index]);
end;

procedure TUnSwUnitList.SetItem(Index: Integer; Value: TUnSwUnit);
begin
  FItems[Index] := Value;
end;

function TUnSwUnitList.GetOwnsObjects(): Boolean;
begin
  Result  := FItems.OwnsObjects;
end;

procedure TUnSwUnitList.SetOwnsObjects(const Value: Boolean);
begin
  FItems.OwnsObjects  := Value;
end;

end.