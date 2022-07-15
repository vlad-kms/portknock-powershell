#using module "D:\tools\PSModules\avvClasses\classes\classCFG.ps1"
<#
	.SYNOPSIS
	Port knocking ��� ���������� �����

	.DESCRIPTION
	���������� port knocking ��� ���������� �����.
	������������� ������: �������� tcp (udp) ����, �������� icmp ������ ������.
	���� ������������ - ����������� �����������. ��� ���������� ����� �������� FileCFG,
	��� ������ ���� ���� � ������� �������� knock.ps1.cfg
	�������� �����:
		������ � ����� ���� �����:
	 	1) ���� ���. �������� ������ ���� ��� ���� knock. �������� (icmp, udp, tcp)
		   � ������ ��� ����� ���� (port ��� udp, tcp � ����� ������ ��� icmp)
		2) ������ �����. ������ ����� �� ������ 1-�� ����
		1) ���� ���:
			[step]
			proto=tcp, �� ��������� udp
			port=nnnn, �������� �� 1-65535, ���� ��� tcp, udp 
			length=nn, ����� ������ icmp, �������� + 28 ���� ���������
		2) ������ �����:
		[steps]
		1=step1
		2=step12
		3=step13
		4=step14
		host=host1.xxx
		��� ���������(���������) ��������� ������� �������� ������. �������� ��� ������ ���� "���� ���" � ������� ������ ��������.
		�������� host (��������������) ��������� ����� ���� ���������� �����. ���������������� ���������� ������� knock.ps1 -RemoteHost

	.PARAMETER FileCFG
	��������� ���� ������������ �� ������� ������ ��� port knocking
	�� ��������� ./knock.ps1.ini

	.PARAMETER RemoteHost
	��������� ��������� ���� ��� port knocking. ������������

	.PARAMETER SectionList
	��������� ������ ��� ���������� port knocking
	�� ��������� "steps"

    .PARAMETER DelayTime
    �������� ����� ��������� ������� udp ��� tcp
	�� ��������� 2

    .PARAMETER DelayICMP
    �������� ����� ��������� ������� icmp
    �� ��������� 10

	
	.EXAMPLE

	.\knock.ps1 -SectionList steps1 -RemoteHost h1.domain.ru -DelayICMP 10

	��������� ������ [steps1] �� ����� ������������ ��� ���������� ����� h1.domain.ru.
	�������� ����� ��������� ������� icmp 10 ������

	.EXAMPLE

	.\knock.ps1 c:\list-sections.cfg -SectionList steps2 -RemoteHost h1.domain.ru -DelayICMP 10 -DelayTime 4
	or
	.\knock.ps1 -FileCFG c:\list-sections.cfg -SectionList steps2 -RemoteHost h1.domain.ru -DelayICMP 10 -DelayTime 4

	��������� ������ [steps2] �� ����� ������������ c:\list-sections.cfg ��� ���������� ����� h1.domain.ru.
	�������� ����� ��������� ������� icmp 10 ������, � ����� �������� udp (tcp) 4 �������
#>

Param (
    [Parameter(ValueFromPipeline=$True, Position=0)]
    $FileCFG,
    [Parameter(Mandatory=$True, Position=1)]
    $RemoteHost,
    [Parameter(Mandatory=$True, Position=2)]
    $SectionList,
    $DelayTime=2,
    $DelayICMP=10,
    [switch]$isDebug=$False,
    [string]$LogFile='',
    [int]$LogLevel=1
)

$Version='3.0.1';
$MAX_LENGTH_ICMP = 4096;

function getDefaultColor(){
    switch ($host.Name) {
        'ConsoleHost' {
            $BColor = $host.ui.rawui.backgroundcolor;
            $FColor = $host.ui.rawui.Foregroundcolor;
        }
        '_Windows PowerShell ISE Host'{
            $BColor = $host.PrivateData.ConsolePaneBackgroundColor;
            $FColor = $host.PrivateData.ConsolePaneForegroundColor;
        }
        default {
            $BColor = [System.ConsoleColor]'DarkBlue';
            $FColor = [System.ConsoleColor]"White";
        }
    }
    return @{'Foreground'=$FColor; 'Background'=$BColor;}
}

function WriteConsole() {
    param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
        [System.Object]$msg,
        $FColor= (Invoke-Command {(getDefaultColor).Foreground}),
        $BColor= (Invoke-Command {(getDefaultColor).Background})
    )
    BEGIN{

    }
    PROCESS{
        $msg | Write-Host -BackgroundColor $BColor -ForegroundColor $FColor;
        return;
        # TODO ���� �� ���������� ������������� ConsoleColor <--> Colors

        if ($PSIse -eq $null)
        {
            $msg | Write-Host -BackgroundColor $BColor -ForegroundColor $FColor;
        }
        else
        {
            $oldBColor = $PSIse.Options.ConsolePaneBackgroundColor;
            $oldFColor = $PSIse.Options.ConsolePaneForegroundColor;
            try
            {
                $PSIse.Options.ConsolePaneBackgroundColor = $BColor;
                $PSIse.Options.ConsolePaneForegroundColor = $FColor;
                $msg | Write-Host;
            }
            finally
            {
                $PSIse.Options.ConsolePaneBackgroundColor = $oldBColor;
                $PSIse.Options.ConsolePaneForegroundColor = $oldFColor;
            }
        }
    }
    END{}
}

<#
    ������� � ���� ����
#>
function SendOneKnock() {
param(
  [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
  [String]$sectionName
)
    BEGIN {}
    PROCESS {
        if ($isDebug) {
            WriteConsole "sectionName = $($sectionName)" -FColor Cyan;
        }
        # �������� ������ � ���������� ������
        $currentSection = $hashCFG.getSection($sectionName);
        if ($currentSection -eq $null)
        {
            return;
        }
        $hashCFG.toJson($sectionName) | WriteConsole  -FColor Cyan;
        # ��������� ���������� ��������� �� ����������
        try
        {
            $proto = [Net.Sockets.ProtocolType]($hashCFG.getString($sectionName, 'proto'));
        }
        catch
        {
            $proto = $null;
        }
        if ($proto -eq $null) { return }
        $is_icmp = $proto -eq [Net.Sockets.ProtocolType]'Icmp'
        $is_tcpORudp = ($proto -eq [Net.Sockets.ProtocolType]'Tcp') -or ($proto -eq [Net.Sockets.ProtocolType]'Udp')
        $port = $hashCFG.getInt($sectionName, 'port');
        $length = $hashCFG.getInt($sectionName, 'length');
        $__Host = $hashCFG.getString($sectionName, 'host');
        #return;
        if (
                ( $is_tcpORudp `
                -and ( ($port -gt 0) -and ($port -le 65535) ) ) `
                -or ( $is_icmp -and (($length -gt 0) -and ($length -le $MAX_LENGTH_ICMP)) )
           )
        {
            if ($proto -eq [Net.Sockets.ProtocolType]'tcp') {
                $socket = new-object net.sockets.socket([Net.Sockets.AddressFamily]'InterNetwork',
                         [Net.Sockets.SocketType]'Stream',
                         $proto);
                try {
                    # [System.IAsyncResult]
                    $result = $socket.BeginConnect( $__Host, $port, $null, $null);
                    $success = $result.AsyncWaitHandle.WaitOne( $DelayTime, $true );
                    if ($succes) {
                        $socket.EndConnect($result)
                    }
                } finally {
                    $socket.Close()
                }
            } elseif ($proto -eq [Net.Sockets.ProtocolType]'icmp') {
                #Test-Connection -BufferSize $KnockData.Length -Count 1 -ComputerName $KnockData.Host
                $pingSender = new-object System.Net.NetworkInformation.Ping
                try {
                    $buf = [text.encoding]::ascii.getbytes(''.PadRight($length, '1'));
                    $PingOptions = New-Object System.Net.NetworkInformation.PingOptions
                    $PingOptions.DontFragment = $false
                    $global:reply = $pingSender.Send($__Host, 100, $buf, $PingOptions);
                } finally {
                    $pingSender.Dispose()
                }
            } else {
                $udpclient.Connect($__Host, $port);
                $res=$udpClient.Send($buf, $buf.length);
            } ###
            if ($is_icmp) {
                sleep($DelayICMP);
            } else {
                sleep($DelayTime);
            }
        } ### if ($KnockData.proto -is [Net.Sockets.ProtocolType]) {
    }
    END {}
}

<#
--------------------------
--------------------------
--------------------------
--------------------------
#>

if ( !$FileCFG ) {
    $FileCFG = $PSCommandPath + '.ini'
}
if ( ! (Test-Path -Path $FileCFG -Type Leaf) ) {
    WriteConsole -msg "���� �������� $($FileCFG) �� ����������. ������ ����������." -FColor Red
    Exit
}

if ($SectionList) {
    $section_steps=$SectionList
}

$global:buf=[text.encoding]::ascii.getbytes("hi");

$par=@{
    '_obj_'=@{
        'filename' = $FileCFG;
        'isReadOnly' = $False;
        'isOverwrite' = $True;
        'HostVar' = $Host;
    }
}

if ($isDebug) {
    $HV=$Host;
    $ll = 1;
}
else {
    $HV=$null;
    $ll = -1;
}
$parLog = @{
    '_obj_'=@{
        'logFile' = '.\knock.log';
        'logLevel'= $ll
        'HostVar' = $HV;
    }
}
$hashCFG = (Get-AvvClass -ClassName 'IniCFG' -Params $par);
$hashCFG.setKeyValue('_always_', 'host', $RemoteHost);
$log = (Get-AvvClass -ClassName 'Logger' -Params $parLog);
$log.log("$(''.PadRight(80, '='))", 0, 5, 1, $False, '', $null, 'cyan');
$log.log("$($hashCFG.ToJson())", 0, 100, 1, $False, '', $null, 'cyan');
$log.log($hashCFG, 0, 100, 1, $False, '', 'black', 'yellow');
$log.log($log.ToJson(), 0, 100, 1, $False, '', $null, 'cyan');

if ( $hashCFG ) {
    # ������ ��� ������ � udp ����������
    $global:udpclient = new-object net.sockets.udpclient(0);
    $sectionData = $hashCFG.getSection('', $section_steps);
    if ($sectionData -ne $null) {
        $sectionData = ($sectionData.GetEnumerator()|Sort-Object name);
    }
    if ($isDebug)
    {
        "hashCFG  ".PadRight(80, '=') | WriteConsole
        $hashCFG.toJson();
        "sectionData  ".PadRight(80, '=') | WriteConsole
        $sectionData;
    }

    "Begin KNOCK" | WriteConsole -FColor Cyan;
    try {
        if ($sectionData -ne $null){
            $sectionData.Foreach({
                #$currentStep = $hashCFG[$hashCFG[$section_steps]["$_"]]
                #$currentStepName = $_.value;
                #$currentStepSection = $hashCFG.getSection($currentStepName)
                #$currentStep | SendOneKnock
                $_.value | SendOneKnock;
            })
        }
    }
    finally {
        #$tcpclient.close()
        $udpclient.close()
        #$socket.close()
    }
    "End KNOCK" | WriteConsole -FColor Cyan;
} else {
    "������ � ������� ����� ������������, ��� ������� �������� ��� ������ ��� ����������" | WriteConsole;
} ### if ( $hashCFG ) {
