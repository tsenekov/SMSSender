unit broadcast;

interface

uses
  System.Classes,
{$IFDEF ANDROID}
  Androidapi.JNI.Embarcadero, Androidapi.JNI.GraphicsContentViewText, Androidapi.Helpers, Androidapi.JNIBridge,
  Androidapi.JNI.JavaTypes, Androidapi.JNI.App,
{$ENDIF}
  System.SysUtils;

type

{$IFNDEF ANDROID}
  JIntent = class
  end;

  JContext = class
  end;
{$ENDIF}

  TCSBroadcastReceiver = class;
  TOnReceive = procedure(csContext: JContext; csIntent: JIntent) of object;

{$IFDEF ANDROID}

  TCSListener = class(TJavaLocal, JFMXBroadcastReceiverListener)
  private
    FOwner: TCSBroadcastReceiver;
  public
    constructor Create(AOwner: TCSBroadcastReceiver);
    procedure OnReceive(csContext: JContext; csIntent: JIntent); cdecl;
  end;
{$ENDIF}

  TCSBroadcastReceiver = class(TComponent)
  private
{$IFDEF ANDROID}
    FReceiver: JBroadcastReceiver;
    FListener: TCSListener;
{$ENDIF}
    FOnReceive: TOnReceive;
    FItems: TStringList;
    function GetItem(const csIndex: Integer): String;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SendBroadcast(csValue: String);
    procedure Add(csValue: String);
    procedure Delete(csIndex: Integer);
    procedure Clear;
{$IFDEF ANDROID}
    procedure setResultData(data: JString);
{$ENDIF}
    function Remove(const csValue: String): Integer;
    function First: String;
    function Last: String;
    function HasPermission(const csPermission: string): Boolean;
    procedure RegisterReceive;
    property Item[const csIndex: Integer]: string read GetItem; default;
    property Items: TStringList read FItems write FItems;
  published
    property OnReceive: TOnReceive read FOnReceive write FOnReceive;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('Classicsoft', [TCSBroadcastReceiver]);
end;

{ TCSBroadcastReceiver }

{$IFDEF ANDROID}
procedure TCSBroadcastReceiver.setResultData(data: JString);
begin
  FReceiver.setResultData(data);
end;
{$ENDIF}

procedure TCSBroadcastReceiver.Add(csValue: String);
{$IFDEF ANDROID}
var
  Filter: JIntentFilter;
{$ENDIF}
begin
{$IFDEF ANDROID}
  if (FListener = nil) or (FReceiver = nil) then
  begin
    Raise Exception.Create('First use RegisterReceive!');
    Exit;
  end;
{$ENDIF}
  if FItems <> nil then
    if FItems.IndexOf(csValue) = -1 then
    begin
{$IFDEF ANDROID}
      Filter := TJIntentFilter.Create;
      Filter.addAction(StringToJString(csValue));
      TAndroidHelper.Context.registerReceiver(FReceiver, Filter);
{$ENDIF}
      FItems.Add(csValue);
    end;
end;

procedure TCSBroadcastReceiver.Clear;
begin
  FItems.Clear;
end;

constructor TCSBroadcastReceiver.Create(AOwner: TComponent);
begin
  inherited;
  FItems := TStringList.Create;
end;

procedure TCSBroadcastReceiver.Delete(csIndex: Integer);
begin
  if FItems <> nil then
  begin
    FItems.Delete(csIndex);
{$IFDEF ANDROID}
    TAndroidHelper.Activity.UnregisterReceiver(FReceiver);
    RegisterReceive;
{$ENDIF}
  end;
end;

destructor TCSBroadcastReceiver.Destroy;
begin
  FItems.Free;
{$IFDEF ANDROID}
  if FReceiver <> nil then
    TAndroidHelper.Activity.UnregisterReceiver(FReceiver);
{$ENDIF}
  inherited;
end;

function TCSBroadcastReceiver.First: String;
begin
  Result := FItems[0];
end;

function TCSBroadcastReceiver.GetItem(const csIndex: Integer): String;
begin
  Result := FItems[csIndex];
end;

function TCSBroadcastReceiver.HasPermission(const csPermission: string): Boolean;
{$IFDEF ANDROID}
begin
  Result := TAndroidHelper.Activity.checkCallingOrSelfPermission(StringToJString(csPermission))
    = TJPackageManager.JavaClass.PERMISSION_GRANTED;
{$ELSE}
begin
  Result := False;
{$ENDIF}
end;

function TCSBroadcastReceiver.Last: String;
begin
  Result := FItems[FItems.Count];
end;

procedure TCSBroadcastReceiver.RegisterReceive;
{$IFDEF ANDROID}
var
  I: Integer;
begin
  if FListener = nil then
    FListener := TCSListener.Create(Self);
  if FReceiver = nil then
    FReceiver := TJFMXBroadcastReceiver.JavaClass.init(FListener);
  if FItems <> nil then
    if FItems.Count > 0 then
      for I := 0 to FItems.Count - 1 do
        Add(FItems[I]);
{$ELSE}
begin
{$ENDIF}
end;

function TCSBroadcastReceiver.Remove(const csValue: String): Integer;
begin
  Result := FItems.IndexOf(csValue);
  if Result > -1 then
    FItems.Delete(Result);
end;

procedure TCSBroadcastReceiver.SendBroadcast(csValue: String);
{$IFDEF ANDROID}
var
  Inx: JIntent;
begin
  Inx := TJIntent.Create;
  Inx.setAction(StringToJString(csValue));
  TAndroidHelper.Context.SendBroadcast(Inx);
{$ELSE}
begin
{$ENDIF}
end;

{$IFDEF ANDROID}

constructor TCSListener.Create(AOwner: TCSBroadcastReceiver);
begin
  inherited Create;
  FOwner := AOwner;
end;

procedure TCSListener.OnReceive(csContext: JContext; csIntent: JIntent);
begin
  if Assigned(FOwner.OnReceive) then
    FOwner.OnReceive(csContext, csIntent);
end;

{$ENDIF}

end.
