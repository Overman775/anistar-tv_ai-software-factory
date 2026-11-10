@echo off
setlocal
set "FACTORY_PYTHON=%~dp0..\.venv\Scripts\python.exe"
if not exist "%FACTORY_PYTHON%" (
  echo Factory Python is not ready. Follow Python setup in .factory/tools/README.md. 1>&2
  exit /b 1
)
"%FACTORY_PYTHON%" -E -s -B "%~dp0python_runtime.py" run %*
exit /b %errorlevel%
