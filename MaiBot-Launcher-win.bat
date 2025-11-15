@echo off
chcp 65001
title MaiBot 管理脚本（Windows）

set "SCRIPT_DIR=%~dp0"
set "VENV_PYTHON=%SCRIPT_DIR%venv\Scripts\python.exe"

:MAIN_MENU
cls
echo ========================================
echo           MaiBot 管理脚本
echo       CopyRight@清蒸云鸭,2025
echo ========================================
echo.
echo 请选择操作:
echo 1. 启动/重启 MaiBot
echo 2. 停止 MaiBot
echo 3. 启动/重启 MaiBot-Napcat-Adapter
echo 4. 停止 MaiBot-Napcat-Adapter
echo 5. 启动/重启 Napcat
echo 6. 停止 Napcat
echo 7. 查看文件分布
echo 0. 退出
echo ========================================
set /p choice=请输入选择 (0-7): 

if "%choice%"=="1" goto START_MAIBOT
if "%choice%"=="2" goto STOP_MAIBOT
if "%choice%"=="3" goto START_ADAPTER
if "%choice%"=="4" goto STOP_ADAPTER
if "%choice%"=="5" goto START_NAPCAT
if "%choice%"=="6" goto STOP_NAPCAT
if "%choice%"=="7" goto SHOW_STRUCTURE
if "%choice%"=="0" goto EXIT

echo 无效选择，请按任意键重新输入...
pause >nul
goto MAIN_MENU

:START_MAIBOT
echo 正在启动 MaiBot...
taskkill /fi "WindowTitle eq MaiBot" /f >nul 2>&1
timeout /t 2 /nobreak >nul
cd /d "%SCRIPT_DIR%MaiBot"
start "MaiBot" cmd /k "%VENV_PYTHON%" bot.py
echo MaiBot 启动完成！
pause >nul
goto MAIN_MENU

:STOP_MAIBOT
echo 正在停止 MaiBot...
taskkill /fi "WindowTitle eq MaiBot" /f >nul 2>&1
echo MaiBot 已停止！
pause >nul
goto MAIN_MENU

:START_ADAPTER
echo 正在启动 MaiBot-Napcat-Adapter...
taskkill /fi "WindowTitle eq MaiBot-Napcat-Adapter" /f >nul 2>&1
timeout /t 2 /nobreak >nul
cd /d "%SCRIPT_DIR%MaiBot-Napcat-Adapter"
start "MaiBot-Napcat-Adapter" cmd /k "%VENV_PYTHON%" main.py
echo MaiBot-Napcat-Adapter 启动完成！
pause >nul
goto MAIN_MENU

:STOP_ADAPTER
echo 正在停止 MaiBot-Napcat-Adapter...
taskkill /fi "WindowTitle eq MaiBot-Napcat-Adapter" /f >nul 2>&1
echo MaiBot-Napcat-Adapter 已停止！
pause >nul
goto MAIN_MENU

:START_NAPCAT
echo 正在启动 Napcat..
taskkill /fi "WindowTitle eq Napcat" /f >nul 2>&1
timeout /t 2 /nobreak >nul
cd /d "%SCRIPT_DIR%NapCat.Shell"
start "Napcat" cmd /k launcher.bat
echo Napcat 启动完成！
echo 请前往http://127.0.0.1:6100/webui 扫码登录
echo token: 详见Napcat窗口
pause >nul
goto MAIN_MENU

:STOP_NAPCAT
echo 正在停止 Napcat...
taskkill /fi "WindowTitle eq Napcat" /f >nul 2>&1
echo Napcat 已停止！
pause >nul
goto MAIN_MENU

:SHOW_STRUCTURE
cls
echo ========================================
echo           项目文件分布结构
echo ========================================
echo.
echo %SCRIPT_DIR%
echo ^|
echo +-- MaiBot\
echo ^|   ^|-- bot.py
echo ^|
echo +-- MaiBot-Napcat-Adapter\
echo ^|   ^|-- main.py
echo ^|
echo +-- NapCat.Shell\
echo ^|   ^|-- launcher.bat
echo ^|
echo +-- venv\
echo     ^|-- Scripts\
echo         ^|-- activate
echo         ^|-- python.exe
echo.
echo ========================================
echo 按任意键返回主菜单...
pause >nul
goto MAIN_MENU

:EXIT
echo 再见！
exit /b 0
