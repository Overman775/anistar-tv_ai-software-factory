@echo off
setlocal DisableDelayedExpansion
set "FACTORY_JSON_MODE="
:leading_flags
if not "%~1"=="--json" goto select_mode
set "FACTORY_JSON_MODE=1"
shift
goto leading_flags

:select_mode
if "%~1"=="setup" goto setup
set "FACTORY_PYTHON=%~dp0..\..\.venv\Scripts\python.exe"
if not exist "%FACTORY_PYTHON%" goto missing_env
"%FACTORY_PYTHON%" -E -s -B "%~dp0..\bootstrap.py" cli %*
exit /b %errorlevel%

:setup
if defined FACTORY_SETUP_PYTHON goto setup_explicit
py -3.14 -c "import sys" >nul 2>&1
if errorlevel 1 goto missing_python
py -3.14 -E -s -B "%~dp0..\bootstrap.py" %*
exit /b %errorlevel%

:setup_explicit
if not exist "%FACTORY_SETUP_PYTHON%" goto invalid_python
"%FACTORY_SETUP_PYTHON%" -E -s -B "%~dp0..\bootstrap.py" %*
exit /b %errorlevel%

:missing_env
set "FACTORY_ERROR=environment_not_ready"
set "FACTORY_REASON=Factory Python is not ready. Run .factory/tooling/bin/cli.cmd setup."
goto report
:missing_python
set "FACTORY_ERROR=setup_failed"
set "FACTORY_REASON=Factory setup needs py -3.14 or FACTORY_SETUP_PYTHON."
goto report
:invalid_python
set "FACTORY_ERROR=setup_failed"
set "FACTORY_REASON=FACTORY_SETUP_PYTHON must point to an executable Python 3.14."
:report
if defined FACTORY_JSON_MODE goto json_error
if "%~1"=="--json" goto json_error
if "%~1"=="--" goto text_error
if "%~1"=="" goto text_error
shift
goto report
:json_error
echo {"ok":false,"error":{"code":"%FACTORY_ERROR%","message":"%FACTORY_REASON%"}}
exit /b 1
:text_error
echo %FACTORY_REASON% 1>&2
exit /b 1
