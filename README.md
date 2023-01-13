# portknock-powershell
    Performing port knocking on a remote host.
    ./knock.ps1    
        -FileCFG     - configuration file name. Default: .\knock.ps1.cfg
        -RemoteHost  - hostname to send packets to. Default: ''
        -SectionList - section name from the configuration file. Default: 'steps'
        -DelayTime   - packet response timeout in milliseconds. Default: 2
	
Для работы требуется класс IniCFG из репозитария avvClasses: using module "D:\tools\PSModules\avvClasses\classes\classCFG.ps1"

## RU-ru

    Выполнение port knocking для удаленного хоста.
    ./knock.ps1    
        -FileCFG     - имя файла конфигурации. По-умолчанию: .\knock.ps1.cfg
        -RemoteHost  - имя хоста на который отсылать пакеты. По-умолчанию: ''
        -SectionList - имя секции из файла конфигурации. По-умолчанию: 'steps'
        -DelayTime   - время ожидания ответа на пакеты в миллисекундах. По-умолчанию: 2 
---
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
			length=nn, длина пакета icmp, реальный - 28 байт заголовок
		2) Список шагов:
		[steps]
		1=step1
		2=step12
		3=step13
		4=step14
		host=host1.xxx
		Имя параметра(числового) указывает порядок отправки пакета.
		Значение имя секции типа "Один шаг" с данными пакета отправки.
		Параметр host (необязательный) указывает адрес куда отправлять пакет.
		Переопределяется параметром скрипта knock.ps1 -RemoteHost
		
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;		
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;		
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;		

	Пример файла конфигурации
	[home-icmp-1h]
	1=step4i
	2=step7i
	3=step5i
	4=step1i
	5=step8i
	host=hostname.dom
	
	[step4i]
	; в icmp length = реальный + 28 байт
	; т.е. если пакет в роутере должен быть 44, тогда length д.б. 44-28 - 16
	proto=icmp
	length=4
	
	[step7i]
	proto=icmp
	length=7
	
	[step5i]
	proto=icmp
	length=5
	
	[step1i]
	proto=icmp
	length=1
	
	[step8i]
	proto=icmp
	length=8
	
	;===================
	
	[home-mix-1h]
	1=step44i
	2=step79i
	;3=step57i
	3=step23
	4=step124i
	5=step82i
	host=hostname.dom
	
	;==============================
	
	[home-240h]
	1=step57144u
	2=step8791t
	3=step62014t
	;4=step28014u
	4=step283t
	5=step315u
	6=step60i
	7=step43857u
	host=hostname.dom
	
	[step60i]
	proto=icmp
	length=32
	
	[step283t]
	proto=tcp
	port=283
	
	[step315u]
	proto=udp
	port=315
	
	[step43857u]
	proto=udp
	port=43857
	
	[step44u]
	proto=udp
	port=44
	
	[step54987u]
	proto=udp
	port=54987
	
	[step54986u]
	proto=udp
	port=54986
