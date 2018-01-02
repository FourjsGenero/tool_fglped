@echo off
setlocal EnableExtensions
set CURDIR=%CD%
set CURDRIVE=%CURDIR:~0,2%
set FGLPEDPATH=%~dp0
set FGLDEBDRIVE=%FGLPEDPATH:~0,2%
%FGLDEBDRIVE%
cd %FGLPEDPATH%
rem we recompile everything: hence never version clashes
fglcomp -M fglped.4gl
if %errorlevel% neq 0 exit /b %errorlevel%
fglcomp -M fglmkper.4gl
if %errorlevel% neq 0 exit /b %errorlevel%
for %%F in (*.per) do fglform -M %%F
set FGLRESOURCEPATH=%FGLPEDPATH%;%FGLRESOURCEPATH%
set DBPATH=%FGLPEDPATH%:%DBPATH%
%CURDRIVE%
cd %CURDIR%
fglrun %FGLPEDPATH%\fglped.42m %*
