#using module "D:\tools\PSModules\avvClasses\classes\classCFG.ps1"
<#
	.SYNOPSIS
	Port knocking для удаленного хоста

	.DESCRIPTION
	Выполнение port knocking для удаленного хоста.
	Идентификация пакета: протокол tcp (udp) порт, протокол icmp размер пакета.
	Файл конфигурации - присутствие обязательно. Или передается через параметр FileCFG,
	или должен быть файл в текущем каталоге knock.ps1.cfg
	Описание файла:
		Секции в файле двух видов:
	 	1) Один шаг. Описание одного шага для порт knock. Протокол (icmp, udp, tcp)
		   и данные для этого шага (port для udp, tcp и длина пакета для icmp)
		2) Список шагов. Список шагов из секций 1-го типа
		1) Один шаг:
			[step]
			proto=tcp, по умолчанию udp
			port=nnnn, значение от 1-65535, порт для tcp, udp 
			length=nn, длина пакета icmp, реальный + 28 байт заголовок
		2) Список шагов:
		[steps]
		1=step1
		2=step12
		3=step13
		4=step14
		host=host1.xxx
		Имя параметра(числового) указывает порядок отправки пакета. Значение имя секции типа "Один шаг" с данными пакета отправки.
		Параметр host (необязательный) указывает адрес куда отправлять пакет. Переопределяется параметром скрипта knock.ps1 -RemoteHost

	.PARAMETER FileCFG
	Указывает файл конфигурации со списком секций для port knocking
	По умолчанию ./knock.ps1.ini

	.PARAMETER RemoteHost
	Указывает удаленный хост для port knocking. Обязательный

	.PARAMETER SectionList
	Указывает секцию для выполнения port knocking
	По умолчанию "steps"

    .PARAMETER DelayTime
    Задержка между отправкой пакетов udp или tcp
	По умолчанию 2

    .PARAMETER DelayICMP
    Задержка между отправкой пакетов icmp
    По умолчанию 10

	
	.EXAMPLE

	.\knock.ps1 -SectionList steps1 -RemoteHost h1.domain.ru -DelayICMP 10

	Выполняет секцию [steps1] из файла конфигурации для удаленного хоста h1.domain.ru.
	Задержка между отправкой пакетов icmp 10 секунд

	.EXAMPLE

	.\knock.ps1 c:\list-sections.cfg -SectionList steps2 -RemoteHost h1.domain.ru -DelayICMP 10 -DelayTime 4
	or
	.\knock.ps1 -FileCFG c:\list-sections.cfg -SectionList steps2 -RemoteHost h1.domain.ru -DelayICMP 10 -DelayTime 4

	Выполняет секцию [steps2] из файла конфигурации c:\list-sections.cfg для удаленного хоста h1.domain.ru.
	Задержка между отправкой пакетов icmp 10 секунд, а между пакетами udp (tcp) 4 секунды
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
    [switch]$isDebug=$False
)

$Version='2.0.0';
$MAX_LENGTH_ICMP = 150;

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
        [System.ConsoleColor]$FColor= (Invoke-Command {(getDefaultColor).Foreground}),
        [System.ConsoleColor]$BColor= (Invoke-Command {(getDefaultColor).Background})
    )
    BEGIN{

    }
    PROCESS{
        
        $msg | Write-Host -BackgroundColor $BColor -ForegroundColor $FColor;
    }
    END{}
}

<#
    Послать в один порт
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
        # получить секцию с переданным именем
        $currentSection = $hashCFG.getSection($sectionName);
        if ($currentSection -eq $null)
        {
            return;
        }
        $hashCFG.toJson($sectionName) | WriteConsole  -FColor Cyan;
        # Проверить переданные параметры на валидность
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
    WriteConsole -msg "Файл настроек $($FileCFG) не существует. Запуск невозможен." -FColor Red
    Exit
}

$section_steps='steps'
if ($SectionList) {
    $section_steps=$SectionList
}

$global:buf=[text.encoding]::ascii.getbytes("hi");
#$global:paramHost = $RemoteHost
$paramHost = $RemoteHost

$par=@{
    '_obj_'=@{
        'filename' = $FileCFG;
        'isReadOnly' = $False;
        'isOverwrite' = $True;
    }
}
$hashCFG = (Get-AvvClass -ClassName 'IniCFG' -Params $par);
$hashCFG.setKeyValue('_always_', 'host', $paramHost);


if ($isDebug)
{
    "hashCFG  ".PadRight(80, '=') | WriteConsole
    $hashCFG.toJson();
    "".PadRight(80, '=') | WriteConsole
}

if ( $hashCFG ) {
    # объект для работы с udp протоколом
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
    "Ошибка в разборе файла конфигурации, или неверно передано имя секции для выполнения" | WriteConsole;
} ### if ( $hashCFG ) {
