unit main;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, FMX.Types, FMX.Layouts, FMX.Dialogs,
  FMX.Memo, FMX.Controls.Presentation, FMX.Edit, FMX.StdCtrls, FMX.TabControl, FMX.ScrollBox, FMX.Controls, FMX.Graphics, FMX.Forms,
  FMX.DialogService, System.Permissions,
{$IFDEF ANDROID}
  Androidapi.Helpers, Androidapi.JNI.JavaTypes, Androidapi.JNI, Androidapi.JNI.GraphicsContentViewText, Androidapi.JNI.Os,
  Androidapi.JNIBridge,
  Androidapi.JNI.App, Androidapi.JNI.Embarcadero,
  Androidapi.JNI.Net, Androidapi.JNI.Util, Androidapi.JNI.Provider,
  Androidapi.JNI.Telephony,
{$ENDIF}
{$IFDEF IOS}
  iOSapi.UIKit,
{$ENDIF}
  broadcast, FMX.ListBox, FMX.EditBox, FMX.SpinBox;

type
  TfrmMain = class(TForm)
    ToolBarLabel: TLabel;
    StyleBook1: TStyleBook;
    Panel1: TPanel;
    MemoSMS: TMemo;
    Panel3: TPanel;
    Panel4: TPanel;
    Button1: TButton;
    Logs: TListBox;
    LimitSMS: TSpinBox;
    Label3: TLabel;
    EditPhone: TEdit;
    btnSend: TButton;
    procedure btnSendClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    FPermission_SEND, FPermission_READ, FPermission_RECEIVE: string;
    procedure FetchSMS;
    procedure CreateBroadcastReceiver;
    procedure BroadcastReceiverOnReceive(csContext: JContext; csIntent: JIntent);
    procedure CheckSmsInState(Context: JContext; Intent: JIntent);
    procedure RequestPerms;
    procedure RequestResult(Sender: TObject; const APermissions: TArray<string>; const AGrantResults: TArray<TPermissionStatus>);
    procedure DisplayRationale(Sender: TObject; const APermissions: TArray<string>; const APostRationaleProc: TProc);
    procedure AddToLog(line: string);
    function myUnixToDateTime(USec: Longint): TDateTime;
    procedure TestIOS;
    { Private declarations }
  public
    BroadcastReceiver: TCSBroadcastReceiver;
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.fmx}

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  Logs.Items.Clear;
end;

procedure TfrmMain.AddToLog(line: string);
begin
  Logs.Items.add(line);
  Logs.ItemIndex := Logs.Items.Count - 1;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  if Assigned(BroadcastReceiver) then
    BroadcastReceiver.Free;
end;

procedure TfrmMain.FormShow(Sender: TObject);
begin
  RequestPerms;
  CreateBroadcastReceiver;
end;

function TfrmMain.myUnixToDateTime(USec: Longint): TDateTime;
begin
  Result := (USec / 86400) + UnixDateDelta;
end;

procedure TfrmMain.btnSendClick(Sender: TObject);
var
  s: string;
{$IFDEF ANDROID}
  smsTo: JString;
  smsManager: JSmsManager;
{$ENDIF}
begin
  if length(EditPhone.Text) < 1 then
  begin
    AddToLog('No phone number');
    exit;
  end;

  // send sms
{$IFDEF ANDROID}
  AddToLog('Send sms to ' + EditPhone.Text);
  try
    smsManager := TJSmsManager.JavaClass.getDefault;
    smsTo := StringToJstring(EditPhone.Text);
    smsManager.sendTextMessage(smsTo, nil, StringToJstring(MemoSMS.Lines.Text), nil, nil);
  except
    AddToLog('Except on SMS send');
  end;
{$ENDIF}
end;

procedure TfrmMain.Button1Click(Sender: TObject);
begin
  FetchSMS;
end;

procedure TfrmMain.FetchSMS;
var
{$IFDEF ANDROID}
  cursor: JCursor;
  uri: Jnet_Uri;
{$ENDIF}
  id_smsid, id_smssender: integer;
  id_smsbody: integer;
  id_smsdate: integer;

  smsid: string;
  smssender: string;
  smsbody: string;
  limit, i: integer;
  msgunixtimestampms: int64;
  dt: TDateTime;
begin
  limit := trunc(LimitSMS.Value);

{$IFDEF ANDROID}
  try
    uri := StrToJURI('content://sms/inbox');
    cursor := TAndroidHelper.Activity.getContentResolver.query(uri, nil, nil, nil, nil);
    id_smsid := cursor.getColumnIndex(StringToJstring('_id'));
    id_smssender := cursor.getColumnIndex(StringToJstring('address'));
    id_smsbody := cursor.getColumnIndex(StringToJstring('body'));
    id_smsdate := cursor.getColumnIndex(StringToJstring('date'));
    cursor.moveToFirst;
    i := cursor.getCount;
    if i > limit then
      i := limit;
    AddToLog('Read SMS ' + i.ToString + '/' + cursor.getCount.ToString);

    while i > 1 do
    begin
      smsid := JStringToString(cursor.getString(id_smsid));
      smssender := JStringToString(cursor.getString(id_smssender));
      smsbody := JStringToString(cursor.getString(id_smsbody));
      msgunixtimestampms := cursor.getLong(id_smsdate);
      dt := myUnixToDateTime(msgunixtimestampms div 1000);
      AddToLog('SMS #' + smsid + ' date:' + DateToStr(dt) + ' from:' + smssender);
      AddToLog(smsbody);

      dec(i);
      cursor.moveToNext;
    end;
  except
    AddToLog('SMS reading not allowed');
  end;
{$ENDIF}
end;

procedure TfrmMain.CreateBroadcastReceiver;
begin
  if not Assigned(BroadcastReceiver) then
  begin
    BroadcastReceiver := TCSBroadcastReceiver.Create(nil);
    BroadcastReceiver.OnReceive := BroadcastReceiverOnReceive;
    BroadcastReceiver.RegisterReceive;
    BroadcastReceiver.add('android.provider.Telephony.SMS_RECEIVED');
  end;
end;

procedure TfrmMain.BroadcastReceiverOnReceive(csContext: JContext; csIntent: JIntent);
begin
  CheckSmsInState(csContext, csIntent);
end;

procedure TfrmMain.CheckSmsInState(Context: JContext; Intent: JIntent);
var
{$IFDEF ANDROID}
  aSmss: TJavaObjectArray<JSmsMessage>;
  aSms: JSmsMessage;
{$ENDIF}
  aFrom: string;
  aBody: string;
  i: integer;
begin
  AddToLog('Intent Received');
{$IFDEF ANDROID}
  try
    if (Intent <> nil) and (Intent.getAction <> nil) and
      (Intent.getAction.compareToIgnoreCase(StringToJstring('android.provider.Telephony.SMS_RECEIVED')) = 0) then
    begin
      AddToLog('SMS Received');
      aSmss := TJavaObjectArray<JSmsMessage>.Create;
      aSmss := TJSms_Intents.JavaClass.getMessagesFromIntent(Intent);
      aFrom := JStringToString(aSmss[0].getDisplayOriginatingAddress);
      aBody := '';
      for i := 0 to aSmss.length - 1 do
      begin
        aSms := aSmss[i];
        aBody := aBody + JStringToString(aSms.getDisplayMessageBody);
      end;
      AddToLog('SMS from: ' + aFrom);
      AddToLog('SMS body: ' + aBody);
    end;
  except

  end;
{$ENDIF}
end;

procedure TfrmMain.RequestPerms;
begin
{$IFDEF ANDROID}
  FPermission_SEND := JStringToString(TJManifest_permission.JavaClass.SEND_SMS);
  FPermission_READ := JStringToString(TJManifest_permission.JavaClass.READ_SMS);
  FPermission_RECEIVE := JStringToString(TJManifest_permission.JavaClass.RECEIVE_SMS);
  // FPermission_BROADCAST := JStringToString(TJManifest_permission.JavaClass.BROADCAST_SMS);
  PermissionsService.RequestPermissions([FPermission_SEND, FPermission_READ, FPermission_RECEIVE], RequestResult, DisplayRationale)
{$ENDIF}
end;

procedure TfrmMain.RequestResult(Sender: TObject; const APermissions: TArray<string>; const AGrantResults: TArray<TPermissionStatus>);
begin
{$IFDEF ANDROID}
  if (AGrantResults[0] = TPermissionStatus.Granted) and (AGrantResults[1] = TPermissionStatus.Granted) and
    (AGrantResults[2] = TPermissionStatus.Granted) then
  begin
  end
  else
    TDialogService.ShowMessage('required permissions are not all granted')
{$ENDIF}
end;

procedure TfrmMain.DisplayRationale(Sender: TObject; const APermissions: TArray<string>; const APostRationaleProc: TProc);
var
  i: integer;
  RationaleMsg: string;
begin
  for i := 0 to High(APermissions) do
  begin
    if APermissions[i] = FPermission_SEND then
      RationaleMsg := RationaleMsg + 'The app needs to SEND SMS' + SLineBreak + SLineBreak;
    if APermissions[i] = FPermission_READ then
      RationaleMsg := RationaleMsg + 'The app needs to READ SMS' + SLineBreak + SLineBreak;
    if APermissions[i] = FPermission_RECEIVE then
      RationaleMsg := RationaleMsg + 'The app needs to RECEIVE SMS' + SLineBreak + SLineBreak;
  end;
  // Show an explanation to the user *asynchronously*
  {
    TDialogService.ShowMessage(RationaleMsg,
    procedure(const AResult: TModalResult)
    begin
    APostRationaleProc;
    end)
  }

end;

procedure TfrmMain.TestIOS;
{$IFDEF IOS}
var
  intf: UITextField;
{$ENDIF}
begin
  // Message should contain passcode or code keyword for work autofill
  // UITextField declared in iOSapi.UIKit.pas and its corresponding control is TiOSNativeEdit in FMX.Edit.iOS.pas.
  // In TEdit its used in PresentationProxy property, but only if ControlType = Platform. For example:

{$IFDEF IOS}
  if EditPhone.PresentationProxy.HasNativeObject and (EditPhone.PresentationProxy.NativeObject.QueryInterface(UITextField, intf) = S_OK)
  then
  begin
    // UITextView
    intf.becomeFirstResponder;
    // https://docs.microsoft.com/ru-ru/dotnet/api/uikit.uitextcontenttype
   // intf.TextContentType:='Name';   // Name,oneTimeCode,
  end;
{$ENDIF}
end;

end.
