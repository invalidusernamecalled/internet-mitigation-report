@echo off & setlocal enabledelayedexpansion

SET FLAG_STAY_OPEN=1

    set counters=0
    for /f "skip=2 tokens=1,2,3,* delims= " %%a in ('netsh interface show interface') do if "x%%dx" NEQ "xx" set /a counters+=1 & set "ifacename[!counters!]=%%d"
    if !counters! LEQ 1 for /f %%i in ("%counters%") do set interfacename=!ifacename[%%i]!
    if !counters! GTR 1 (
    set choices=
    echo Select an interface
    for /l %%i in (1,1,!counters!) do echo %%i^) !ifacename[%%i]! & set choices=!choices!%%i
    choice /c !choices!
    for /f "delims=" %%i in ("!errorlevel!") do set interfacename=!ifacename[%%i]!
    )
    for /f "tokens=* delims= " %%a in ("!interfacename!") do set "interfacename=%%a"

    
    if "!interfacename!" NEQ "" (for /f "delims=" %%i in ("!interfacename!") do echo ^<%%i^>) else (echo: & echo:***No Wireless interface found^!*** & echo: &  PAUSE & GOTO :eof)


echo /-----------------"%~nx0"-----------------\
set /a points=0
set is_connected=0
set is_dhcp=
set FLAG_INTERNET_CONNECTION_GATEWAY=1.1.1.1
for /f "skip=2 tokens=1,2,3,* delims= " %%a in ('netsh interface show interface') do if "%%d"=="!interfacename!" if /i "%%b"=="connected" set is_connected=1&set /a points+=1
if %is_connected%==1 (echo:[V] Interface is connected) else (goto not_connected)
for /f "tokens=*" %%i in ('netsh  interface ipv4 show addresses name^="!interfacename!"  ^| find "DHCP enabled:"') do for /f "tokens=3 delims=: " %%a in ("%%i") do set is_dhcp=%%a&echo     checking dhcp... %%a
set dns_is_reachable=0
set internet_gateway_is_reachable=0
call :check_ip_settings
call :check_gateway
call :check_internet_connection
goto print_reports
:check_gateway
set gateway_is_reachable=0
if "%gateway%" NEQ "" (ping -n 1 %GATEWAY% | find /i "ttl=" >NUL&&(set gateway_is_reachable=1))
exit /b
:check_internet_connection
ping -n 1 %FLAG_INTERNET_CONNECTION_GATEWAY% | find /i "ttl=" >NUL&&(set internet_gateway_is_reachable=1)
ping -n 1 %dns_server% | find /i "ttl=" >NUL&&(set dns_is_reachable=1)
exit /b
:check_ip_settings
set ip_address=
set gateway=
set dns_server=
set ip_1=
set /a count_ip=0
set /a count_gateway=0
for /f "tokens=1,* delims=:" %%i in ('netsh interface ipv4 show config name^="!interfacename!" ^| findstr /ir "ip address[:] gateway[:]"') do for /f "tokens=1,2 delims= " %%b in ("%%i") do (if /i "%%b %%c"=="ip address" set ip_address=%%j&set /a count_ip+=1)&(if /i "%%b %%c"=="default gateway" set gateway=%%j&set /a count_gateway+=1)
if %count_ip% GTR 1 (echo:WARNING: Multiple IP addresses are configured^^^!)
if %count_gateway% GTR 1 (echo:WARNING: Multiple gateways are configured^^^!)
for /f "tokens=2  delims=:" %%i in ('netsh interface ipv4 show config name^="!interfacename!" ^| findstr /ir "DNS"') do set dns_server=%%i
if "%dns_server%" NEQ "" for /f  "tokens=1 delims= " %%i in ("%dns_server%") do set dns_server=%%i
if "%gateway%" NEQ "" for /f  "tokens=1 delims= " %%i in ("%gateway%") do set gateway=%%i
if "%ip_address%" NEQ "" for /f  "tokens=1 delims= " %%i in ("%ip_address%") do set ip_address=%%i
if "%ip_address%" NEQ "" for /f  "tokens=1 delims=." %%i in ("%ip_address%") do set ip_1=%%i
exit /b
:print_reports
if "%is_dhcp%"=="Yes" echo     IP Configuration: DHCP
if "%is_dhcp%"=="No" echo     IP Configuration: Static
if "%ip_1%" == "" (call :ip_is_not_set)
if "%ip_1%" NEQ "" if "%ip_1%"=="169" (call :ip_config_failed) else (echo:[V] IP Address is set as %ip_address%&set /a points+=1)
if "%gateway%"=="" (call :gateway_is_missing) else (echo:[V] Gateway: %gateway%&set /a points+=1)
if "%dns_server%"=="" (call: dns_is_missing) else (if /i "%dns_server%"=="none" ( call :dns_is_missing ) else (echo:[V] Dns server: %dns_server% & set /a points+=1 & call :print_dns))
if %gateway_is_reachable%==1 (set /a points+=1&echo:[V] Gateway . . . . . . . . : reachable) else (if "%gateway%" NEQ "" call :gateway_not_reachable)
REM if "%dns_server%"=="" (if %internet_gateway_is_reachable%==1 (echo:[V] %FLAG_INTERNET_CONNECTION_GATEWAY% is reachable.) else (echo:    DNS Server is missing.&echo:^<^^^!^> ERROR: %FLAG_INTERNET_CONNECTION_GATEWAY% is not reachable.)) else (if %dns_is_reachable%==1 (echo:[V] Dns . . . . . . . . . . : reachable) else (echo:^<^^^!^> ERROR: Dns is not reachable.))
echo:POINTS           ^ =        [%points%/6]
if %FLAG_STAY_OPEN%==1 (for /l %%i in (1,1,5) do echo:) & pause >NUL
goto :eof

:dns_is_missing
if %internet_gateway_is_reachable%==1 echo: Internet is working, but dns is not set, so websites not opening
if %dns_is_reachable%==1  echo: '%FLAG_INTERNET_CONNECTION_GATEWAY%' is reachable, but dns is not set, so websites not opening
exit /b
:ip_is_not_set
if "%is_dhcp%"=="No" echo: Check Static ip configuration, because No ip address is set
exit /b
:print_dns
if %dns_is_reachable%==1 set /a points+=1
if %dns_is_reachable%==0 echo:           == DNS Not Reachable: ==
if %dns_is_reachable%==0 echo:  1. Check if DNS address entered is correct
if %dns_is_reachable%==0 if %internet_gateway_is_reachable%==1 echo:  2. Since '%FLAG_INTERNET_CONNECTION_GATEWAY%' is in fact, reachable
exit /b
:gateway_is_missing
if "%is_dhcp%"=="No" echo: Gateway is missing^^^!
if "%is_dhcp%"=="No" echo: Check Make sure gateway has been configured in Static ip configuration
if "%is_dhcp%"=="Yes" echo: Check router configuration to make sure it is providing a Gateway
exit /b
:ip_config_failed
if "%is_dhcp%"=="No" echo Router may have failed to provide IP, due to incompatible Static Ip configuration
if "%is_dhcp%"=="Yes" echo Router has failed in IP configuration
exit /b
:gateway_not_reachable
echo:           == Gateway Not Reachable: ==
echo:  1. Router is Busy or not responding (equally likely)
echo:  2. Wrong Gateway Address (equally likely)
echo:  3. Invalid IP Configuration (equally likely)
exit /b
:not_connected
echo:           == Interface is not connected ==
echo:  1. Try connecting to wifi or ethernet [likely]
echo:  2. Try resetting wifi/ethernet adapter in order to reconnect properly
echo:  3. Install correct drivers for the wifi/ethernet interface [unlikely]
goto :eof
