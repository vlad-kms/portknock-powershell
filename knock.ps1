<#
	.SYNOPSIS
	Port knocking для удаленного хоста

	.DESCRIPTION
	Выполнение port knocking для удаленного хоста.
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
		Имя параметра(числового) указывает порядок отправки пакета. Значение имя секции типа "Один шаг" с данными пакета отправки
		Параметр host (необязательный) указывает адрес куда отправлять пакет. Переопределяется параметром скрипта knock.ps1 -RemoteHost

	.PARAMETER FileCFG
	Указывает файл конфигурации со списком секций для port knocking
	По умолчанию ./knock.ps1.cfg

	.PARAMETER RemoteHost
	Указывает удаленный хост для port knocking.
	По умолчанию пусто. Будет использоваться хост из секции [steps], указанной
	в параметре SectionList

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
    [Parameter(Position=1)]
    $RemoteHost='',
    $SectionList='steps',
    $DelayTime=2,
    $DelayICMP=10
)

<#---------------------------------
 Работа с SectionVariable
-----------------------------------#>

<# Создать секция [VAR] и инциализировать ее значениями по умолчанию #>
function New-SectionVariables () {
    $variables = [ordered]@{
        proto=[Net.Sockets.ProtocolType]'udp'
        port=0
        length=0
        host=''
    }
    return $variables
}

<# Создать копию секции [VAR] из переданной #>
function Copy-SectionVariables ([hashtable]$SectionVariables) {
    $result = New-SectionVariables
    $SectionVariables.Keys.ForEach({
        $result[$_]=$SectionVariables[$_]
    }) ### $SectionVariables.Keys.ForEach({
    return $result
}

<#---------------------------------
 Работа с файлом конфигурации
-----------------------------------#>

<# Импорт (чтение) параметров из файла конфигурации в hashtable. Пример в начале #>
function avvImport-Ini {
#[CmdletBinding()]
param (
    # Name of the iniFile to be parsed.
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ValidateScript({ Test-Path -PathType:Leaf -Path:$_ })]
    [string] $IniFile
)

    begin
    {
        Write-Verbose "$($MyInvocation.Line)"
        $iniObj = [ordered]@{}
    }

    process
    {
        switch -regex -File $IniFile {
            "^\[(.+)\]$" {
                $section = $matches[1]
                $iniObj[$section] = [ordered]@{}
                #Continue
            }
            "(?<key>^[^\#\;\=]*)[=?](?<value>.+)" {
                $key  = $matches.key.Trim()
                $value  = $matches.value.Trim()

                if ( ($value -like '$(*)') -or ($value -like '"*"') ) {
                    # в INI могут использоваться переменные (команды) из скрипта 
                    # key1=$($var1)
                    # key2="$var1"
                    $value = Invoke-Expression $value
                }
                if ( $section ) {
                    $iniObj[$section][$key] = $value
                } else {
                    $iniObj[$key] = $value
                }
                continue
            }
            "(?<key>^[^\#\;\=]*)[=?]" {
                $key  = $matches.key.Trim()
                if ( $section ) {
                    $iniObj[$section][$key] = ""
                } else {
                    $iniObj[$key] = ""
                }
            }
        } ### switch -regex -File $IniFile {
    }
    end
    {
        return $iniObj
    }
}

<# Считать параметры из файла конфигурации. Пример файла в начале #>
function Init-VariableCFG {
Param (
  [Parameter(ValueFromPipeline=$true,Position=0)]
  [string]$FileIni
)
    $result = $null
    try {
        # считать настройки из .CFG файла
        $hashCFG=avvImport-Ini -IniFile $FileINI
        # отсортировать секцию [steps]
        #$hashCFG[$section_steps] = ($hashCFG[$section_steps].GetEnumerator()) | sort -Property Name
            # ПРОЧИТАТЬ секцию [steps] INI файла, проверить существование секций, соответсвующим шагам.
            # Если нет, то создать ее и использовать значения по-умолчанию
        $hc=$hashCFG[$section_steps]
        if ($hc.contains('host')) {
            $currentHost = $hc.Host
        }
        if ( $global:paramHost -ne '') {
            $currentHost = $global:paramHost
        }
        # сортировать индексы списка шагов
        $SortKeys=$hashCFG[$section_steps].Keys.GetEnumerator() |sort
        $hashCFG.add('StepSortKeys', $SortKeys)

        # инициализировать значениями по-умолчанию для секций stepN (где N - число)
        $DefaultVariables = [ordered]@{Global=(New-SectionVariables)}
        $vg=$DefaultVariables.Global
        #$hc.Keys.Foreach({ write-host "$($_) ;;; $($hc[$_]) ;;; $($hashCFG.contains($hc[$_]))"})
        $hc.Keys.Foreach({
            $currStep = $hc[$_]
            # секции для шага не существует
            #if ( -not ($hashCFG.contains($currStep)) -and ($_.ToUpper() -ne 'HOST') ) {
            if ( -not ($hashCFG.contains($currStep)) ) {
                $hashCFG.add($currStep, [ordered]@{})
            }
            #$hashCFG[$currStep].Keys.Foreach({
            $currStepSection = $hashCFG[$currStep];

            #$hashCFG[$currStep].Keys.foreach({
            # проинициализировать ключи в секции step: host, port, length, proto
            foreach ($currKey in  $vg.Keys) {
                if ($currStepSection.contains($currKey)) {
                    if ($vg[$currKey] -is [Net.Sockets.ProtocolType]) {
                        try {
                            $currStepSection[$currKey] = [Net.Sockets.ProtocolType]$currStepSection[$currKey]
                        }
                        catch {
                            $currStepSection[$currKey] = [Net.Sockets.ProtocolType]'udp'
                        }
                    } else {
                        $currStepSection[$currKey] = [Convert]::ChangeType($currStepSection[$currKey], ($vg[$currKey]).GetType())
                    }
                } else {
                    #$currStepSection[$_] = [Convert]::ChangeType($vg[$currKey], ($vg[$currKey]).GetType())
                    $currStepSection[$currKey] = $vg[$currKey]
                }
                if ($currKey.ToUpper() -eq 'HOST') {
                    if ($currStepSection[$currKey] -eq '') {
                        $currStepSection[$currKey]=$currentHost
                    }
                }
            }

            <#
            if ( $vg.Contains($_) ) {
                $vg[$_] = [Convert]::ChangeType($hc[$_], ($vg[$_]).GetType())
                #$vg[$_] = $hc[$_]
            }
            #>
        }) ### $hc.Keys.Foreach({
        $Result = $hashCFG
    }
    catch {
       $result = $null
    }
    return $result
}

<#
    Послать в один порт
#>
function SendOneKnock() {
param(
  [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
  [System.Object]$KnockData
)
    BEGIN {}
    PROCESS {
        if ($is_debug) {
            $KnockData.Keys.foreach({
                Write-Host "$($_) = $($KnockData[$_])"
            });
        }
        # Проверить переданный параметр на валидность
        #$is_valid_proto = ($KnockData.proto -is [Net.Sockets.ProtocolType]) -and                () -and
        if (! $KnockData.proto -is [Net.Sockets.ProtocolType] -or ($KnockData.host -eq '')) { return }
        $is_icmp = $KnockData.proto -eq [Net.Sockets.ProtocolType]'Icmp'
        $is_tcpORudp = ($KnockData.proto -eq [Net.Sockets.ProtocolType]'Tcp') -or ($KnockData.proto -eq [Net.Sockets.ProtocolType]'Udp')

        if (
                ( $is_tcpORudp -and
                ( ($KnockData.port -gt 0) -and ($KnockData.port -le 65535) ) ) -or
                ( $is_icmp -and
                    (($KnockData.length -gt 0) -and ($KnockData.length -le 150)) )
           )
        {

            if ($KnockData.proto -eq [Net.Sockets.ProtocolType]'tcp') {
                $socket = new-object net.sockets.socket([Net.Sockets.AddressFamily]'InterNetwork',
                         [Net.Sockets.SocketType]'Stream',
                         [Net.Sockets.ProtocolType]'tcp');
                try {
                    # [System.IAsyncResult]
                    $result = $socket.BeginConnect( $KnockData.host, $KnockData.Port, $null, $null);
                    $success = $result.AsyncWaitHandle.WaitOne( $DelayTime, $true );
                    if ($succes) {
                        $socket.EndConnect($result)
                    }
                } finally {
                    $socket.Close()
                }
            } elseif ($KnockData.proto -eq [Net.Sockets.ProtocolType]'icmp') {
                #Test-Connection -BufferSize $KnockData.Length -Count 1 -ComputerName $KnockData.Host
                $pingSender = new-object System.Net.NetworkInformation.Ping
                try {
                    $buf = [text.encoding]::ascii.getbytes(''.PadRight($KnockData.length, '1'));
                    $PingOptions = New-Object System.Net.NetworkInformation.PingOptions
                    $PingOptions.DontFragment = $false
                    $global:reply = $pingSender.Send($KnockData.host, 100, $buf, $PingOptions);
                } finally {
                    $pingSender.Dispose()
                }
            } else {
                $udpclient.Connect($KnockData.host, $KnockData.port);
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
    $FileCFG = $PSCommandPath + '.cfg'
}
if ( ! (Test-Path -Path $FileCFG) ) {
    Write-Host "Файл настроек $($FileCFG) не существует. Запуск невозможен." -BackgroundColor Red
    Exit
}

#echo $FileCFG;
#echo $PSCommandPath

$global:section_steps='steps'
if ($SectionList -ne '') {
    $section_steps=$SectionList
}
# ОТЛАДКА, ПОТОМ УБРАТЬ
#$section_steps='home1'
#$section_steps='home_icmp'

$global:paramHost = $RemoteHost

$global:hashCFG = Init-VariableCFG -FileIni $FileCFG

$global:buf=[text.encoding]::ascii.getbytes("hi");

if ( $hashCFG ) {
    $global:udpclient = new-object net.sockets.udpclient(0);
    #$global:tcpclient = new-object net.sockets.tcpclient([Net.Sockets.AddressFamily]'InterNetwork');
    #$global:socket = new-object net.sockets.socket([Net.Sockets.AddressFamily]'InterNetwork',
    #                     [Net.Sockets.SocketType]'Stream',
    #                     [Net.Sockets.ProtocolType]'tcp');
    $is_debug = $true
    if ($is_debug) {
        Write-Host "Begin KNOCK"
    }
    try {
        $hashCFG.StepSortKeys.Foreach({
            $currentStep = $hashCFG[$hashCFG[$section_steps]["$_"]]
            if ($is_debug) {
                #$currentStep
                Write-Host '==============='
            }
            $currentStep | SendOneKnock

        })
    }
    finally {
        #$tcpclient.close()
        $udpclient.close()
        #$socket.close()
    }
} else {
    Write-Host "Ошибка в разборе файла конфигурации, или неверно передано имя секции для выполнения"
} ### if ( $hashCFG ) {
