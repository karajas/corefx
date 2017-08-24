@if not defined _echo @echo off
setlocal

set INIT_TOOLS_LOG=%~dp0init-tools.log
if [%PACKAGES_DIR%]==[] set PACKAGES_DIR=%~dp0packages\
if [%TOOLRUNTIME_DIR%]==[] set TOOLRUNTIME_DIR=%~dp0Tools
set DOTNET_PATH=%TOOLRUNTIME_DIR%\dotnetcli\
if NOT exist "%DOTNET_PATH%" mkdir "%DOTNET_PATH%"
if [%DOTNET_CMD%]==[] set DOTNET_CMD=%DOTNET_PATH%dotnet.exe
if [%BUILDTOOLS_SOURCE%]==[] set BUILDTOOLS_SOURCE=https://dotnet.myget.org/F/dotnet-buildtools/api/v3/index.json
set /P BUILDTOOLS_VERSION=< "%~dp0BuildToolsVersion.txt"
set BUILD_TOOLS_PATH=%PACKAGES_DIR%Microsoft.DotNet.BuildTools\%BUILDTOOLS_VERSION%\lib\
set INIT_TOOLS_RESTORE_PROJECT=%~dp0init-tools.msbuild
set BUILD_TOOLS_SEMAPHORE=%TOOLRUNTIME_DIR%\%BUILDTOOLS_VERSION%\init-tools.completed
if [%COMPONENT_SOURCE%]==[] set COMPONENT_SOURCE=https://dotnet.myget.org/F/dotnet-buildtools/api/v3/index.json
if [%COMPONENT_DIR%]==[] set COMPONENT_DIR=%~dp0component\
set COMPONENT_ONLY=0

:: if force option is specified then clean the tool runtime and build tools package directory to force it to get recreated
if NOT [%1]==[] (
  if [%1]==[force] (
    if exist "%TOOLRUNTIME_DIR%" rmdir /S /Q "%TOOLRUNTIME_DIR%"
    if exist "%PACKAGES_DIR%Microsoft.DotNet.BuildTools" rmdir /S /Q "%PACKAGES_DIR%Microsoft.DotNet.BuildTools"
    goto :beforedotnetrestore
  )
  set COMPONENT=%1
  set COMPONENT_ONLY=1
  ::if exist "%PACKAGES_DIR%%COMPONENT%" rmdir /S /Q "%PACKAGES_DIR%%COMPONENT%"
  if NOT exist "%COMPONENT_DIR%" mkdir "%COMPONENT_DIR%"
  goto :afterdotnetrestore
)

:beforedotnetrestore

:: If semaphore exists do nothing
if exist "%BUILD_TOOLS_SEMAPHORE%" (
  echo Tools are already initialized.
  goto :EOF
)

if exist "%TOOLRUNTIME_DIR%" rmdir /S /Q "%TOOLRUNTIME_DIR%"

echo Running %0 > "%INIT_TOOLS_LOG%"

set /p DOTNET_VERSION=< "%~dp0DotnetCLIVersion.txt"
if exist "%DOTNET_CMD%" goto :afterdotnetrestore

echo Installing dotnet cli...
if NOT exist "%DOTNET_PATH%" mkdir "%DOTNET_PATH%"
set DOTNET_ZIP_NAME=dotnet-dev-win-x64.%DOTNET_VERSION%.zip
set DOTNET_REMOTE_PATH=https://dotnetcli.azureedge.net/dotnet/Sdk/%DOTNET_VERSION%/%DOTNET_ZIP_NAME%
set DOTNET_LOCAL_PATH=%DOTNET_PATH%%DOTNET_ZIP_NAME%
echo Installing '%DOTNET_REMOTE_PATH%' to '%DOTNET_LOCAL_PATH%' >> "%INIT_TOOLS_LOG%"
powershell -NoProfile -ExecutionPolicy unrestricted -Command "$retryCount = 0; $success = $false; do { try { (New-Object Net.WebClient).DownloadFile('%DOTNET_REMOTE_PATH%', '%DOTNET_LOCAL_PATH%'); $success = $true; } catch { if ($retryCount -ge 6) { throw; } else { $retryCount++; Start-Sleep -Seconds (5 * $retryCount); } } } while ($success -eq $false); Add-Type -Assembly 'System.IO.Compression.FileSystem' -ErrorVariable AddTypeErrors; if ($AddTypeErrors.Count -eq 0) { [System.IO.Compression.ZipFile]::ExtractToDirectory('%DOTNET_LOCAL_PATH%', '%DOTNET_PATH%') } else { (New-Object -com shell.application).namespace('%DOTNET_PATH%').CopyHere((new-object -com shell.application).namespace('%DOTNET_LOCAL_PATH%').Items(),16) }" >> "%INIT_TOOLS_LOG%"
if NOT exist "%DOTNET_LOCAL_PATH%" (
  echo ERROR: Could not install dotnet cli correctly. 1>&2
  goto :error
)

:afterdotnetrestore

if [%COMPONENT_ONLY%]==[1] (
  echo Restoring component %COMPONENT%...
  echo Running: "%DOTNET_CMD%" restore "%INIT_TOOLS_RESTORE_PROJECT%" --no-cache --packages %PACKAGES_DIR% --source "%COMPONENT_SOURCE%" /p:ComponentPackage=%COMPONENT% /p:TargetFramework= /p:AllowWildCard=true >> "%INIT_TOOLS_LOG%"
  "%DOTNET_CMD%" restore "%INIT_TOOLS_RESTORE_PROJECT%" --no-cache --packages %PACKAGES_DIR% --source "%COMPONENT_SOURCE%" /p:ComponentPackage=%COMPONENT% /p:TargetFramework= /p:AllowWildCard=true
  powershell -NoProfile -ExecutionPolicy unrestricted -Command "$dirToCopy = Get-ChildItem %PACKAGES_DIR%%COMPONENT% | ? { $_.PSIsContainer } | sort CreationTime -desc | select -f 1; Copy-Item %PACKAGES_DIR%%COMPONENT%\$($dirToCopy.ToString())\lib %COMPONENT_DIR%\%COMPONENT% -recurse"
  echo Done initializing component.
  goto :done
)

if exist "%BUILD_TOOLS_PATH%" goto :afterbuildtoolsrestore
echo Restoring BuildTools version %BUILDTOOLS_VERSION%...
echo Running: "%DOTNET_CMD%" restore "%INIT_TOOLS_RESTORE_PROJECT%" --no-cache --packages %PACKAGES_DIR% --source "%BUILDTOOLS_SOURCE%" /p:BuildToolsPackageVersion=%BUILDTOOLS_VERSION% >> "%INIT_TOOLS_LOG%"
call "%DOTNET_CMD%" restore "%INIT_TOOLS_RESTORE_PROJECT%" --no-cache --packages %PACKAGES_DIR% --source "%BUILDTOOLS_SOURCE%" /p:ComponentPackage="Microsoft.DotNet.BuildTools" /p:BuildToolsPackageVersion=%BUILDTOOLS_VERSION% >> "%INIT_TOOLS_LOG%"

if NOT exist "%BUILD_TOOLS_PATH%init-tools.cmd" (
  echo ERROR: Could not restore build tools correctly. 1>&2
  goto :error
)

:afterbuildtoolsrestore

echo Initializing BuildTools...
echo Running: "%BUILD_TOOLS_PATH%init-tools.cmd" "%~dp0" "%DOTNET_CMD%" "%TOOLRUNTIME_DIR%" >> "%INIT_TOOLS_LOG%"
call "%BUILD_TOOLS_PATH%init-tools.cmd" "%~dp0" "%DOTNET_CMD%" "%TOOLRUNTIME_DIR%" >> "%INIT_TOOLS_LOG%"
set INIT_TOOLS_ERRORLEVEL=%ERRORLEVEL%
if not [%INIT_TOOLS_ERRORLEVEL%]==[0] (
  echo ERROR: An error occured when trying to initialize the tools. 1>&2
  goto :error
)

:: Create semaphore file
echo Done initializing tools.
echo Init-Tools.cmd completed for BuildTools Version: %BUILDTOOLS_VERSION% > "%BUILD_TOOLS_SEMAPHORE%"

:done
exit /b 0

:error
echo Please check the detailed log that follows. 1>&2
type "%INIT_TOOLS_LOG%" 1>&2
exit /b 1
