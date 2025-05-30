﻿param(
[String]$ScriptArgs = @("")
)
$ErrorActionPreference = "SilentlyContinue"


$Argsarray = $ScriptArgs -Split ";"
if($Argsarray.Count -lt 3){
    Write-Host "Needs 3 arguments"
    break
}
$Dispatcher = $Argsarray[0]; 
$allowedNetworks = $Argsarray[1];
$allowedNetworks = $allowedNetworks -split ','
write-Host $allowedNetworks
$Notnats = $Argsarray[2];




netsh advfirewal export "C:\Firewall.wfw"




if(-not(Get-Command -Name New-NetFirewallRule -ErrorAction SilentlyContinue) -or -not(Get-Command Get-ScheduledTask)){
   if(schtasks /Query /TN  FWRevert){

        schtasks /delete /tn FWRevert /f
        $startTime = (Get-Date).AddMinutes(5).ToString("HH:mm")
        schtasks /create /tn "FWRevert" /tr "netsh advfirewall import 'C:\Firewall.wfw'" /ru "NT AUTHORITY\SYSTEM" /sc once /st $startTime /f 
    }

    else{

        $startTime = (Get-Date).AddMinutes(5).ToString("HH:mm")
        schtasks /create /tn "FWRevert" /tr "netsh advfirewall import 'C:\Firewall.wfw'" /ru "NT AUTHORITY\SYSTEM" /sc once /st $startTime /f 
    }
        
    netsh advfirewall set allprofiles state off

    cmd.exe /c "netsh advfirewall set allprofiles firewallpolicy blockinbound,blockoutbound"


    netsh advfirewall firewall delete rule name=all


    netsh advfirewall firewall add rule name="WINRM 80" dir=in protocol=TCP localport=80 remoteip=$Dispatcher action=allow
    netsh advfirewall firewall add rule name="WINRM 5985" dir=in protocol=TCP localport=5985 remoteip=$Dispatcher action=allow
    netsh advfirewall firewall add rule name="WINRM 5986" dir=in protocol=TCP localport=5986 remoteip=$Dispatcher action=allow




    foreach($network in $allowedNetworks){
        netsh advfirewall firewall add rule name="Local Network" dir=in protocol=TCP  remoteip=$network action=allow
        netsh advfirewall firewall add rule name="Local Network" dir=out protocol=TCP  remoteip=$network action=allow
    }

    

    if($Notnats -ne "NOTNATS"){
        netsh advfirewall firewall add rule name="NotNats" dir=in protocol=any remoteip=$Notnats action=allow
        netsh advfirewall firewall add rule name="NotNats" dir=out protocol=any remoteip=$Notnats action=allow
    }

    netsh advfirewall set allprofiles state on
}

else{
   if(Get-ScheduledTask -TaskName "FWRevert" -ErrorAction SilentlyContinue){

        Unregister-ScheduledTask -TaskName "FWRevert" -Confirm:$false
        $taskaction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "netsh advfirewal import 'C:\Firewall.wfw'"
        $starttime = (Get-Date).AddMinutes(5)
        $trigger = New-ScheduledTaskTrigger -At $starttime -Once
        Register-ScheduledTask -Action $taskaction -Trigger $trigger -TaskName FWRevert -User "NT AUTHORITY\SYSTEM" -Force
    }

    else{
    
       $taskaction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "netsh advfirewal import 'C:\Firewall.wfw'"
       $starttime = (Get-Date).AddMinutes(5)
       $trigger = New-ScheduledTaskTrigger -At $starttime -Once
       Register-ScheduledTask -Action $taskaction -Trigger $trigger -TaskName FWRevert -Description "Reverts Firewall" -User "NT AUTHORITY\SYSTEM" -Force
    }


    Set-NetFirewallProfile -All -Enabled False
    
    Set-NetFirewallProfile -DefaultInboundAction Block -DefaultOutboundAction Block -Name Domain -Enabled False
    Set-NetFirewallProfile -DefaultInboundAction Block -DefaultOutboundAction Block -Name Private -Enabled False
    Set-NetFirewallProfile -DefaultInboundAction Block -DefaultOutboundAction Block -Name Public -Enabled False

    Remove-NetFirewallRule -All 



    New-NetFirewallRule -DisplayName "WinRM" -Direction Inbound -Protocol TCP -LocalPort 80,5985,5986 -RemoteAddress $Dispatcher



    foreach($network in $allowedNetworks){
        New-NetFirewallRule  -DisplayName "Local Network" -Direction Inbound -Protocol TCP  -RemoteAddress $network
        New-NetFirewallRule  -DisplayName "Local Network" -Direction Outbound -Protocol TCP  -RemoteAddress $network
    }

    if($Notnats -ne "NOTNATS"){
        New-NetFirewallRule  -DisplayName "NotNats" -Direction Inbound -Protocol any  -RemoteAddress $Notnats
        New-NetFirewallRule  -DisplayName "NotNats" -Direction Outbound -Protocol any  -RemoteAddress $Notnats
    }

    Set-NetFirewallProfile -All -Enabled true



}


