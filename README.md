# portknock-powershell
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
Пример файла конфигурации
[home-icmp-1h]
1=step44i
2=step79i
3=step57i
4=step124i
5=step82i
host=hostname.dom

[step44i]
; в icmp length = реальный + 28 байт
; т.е. если пакет в роутере должен быть 44, тогда length д.б. 44-28 - 16
proto=icmp
length=16

[step79i]
proto=icmp
length=51

[step57i]
proto=icmp
length=29

[step124i]
proto=icmp
length=96

[step82i]
proto=icmp
length=54

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

;==============================
[home-240h]
1=step57144u
2=step8791t
3=step62014t
;4=step28014u
4=step28315t
5=step31597u
6=step60i
7=step43857u
host=hostname.dom

[step60i]
proto=icmp
length=32

[step28315t]
proto=tcp
port=28315

[step31597u]
proto=udp
port=31597

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
