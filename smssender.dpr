program smssender;

uses
  System.StartUpCopy,
  FMX.Forms,
  main in 'main.pas' {frmMain} ,
  // iOSapi.UIKit in 'iOSapi.UIKit.pas',
  broadcast in 'broadcast.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;

end.
