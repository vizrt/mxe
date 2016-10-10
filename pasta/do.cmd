@echo off
::
:: A bootstrap script for the Pasta tool.
::
:: This script performs a very simple task: It downloads and extracts the
:: Pasta tool if nesseccary, then hand of the command arguments to that tool
:: for actual execution.
::
:: DO NOT MODIFY THIS SCRIPT TO INTRODUCE PROJECT SPECIFIC BEHAVIOR.
::
:: If you need different behavior, either write project specific code in
:: a separate project specific script, or modify the Pasta tool codebase
:: to introduce new generally useful behavior.
::
:: This particular bootstrap should only be modified from within the Pasta
:: tool code base.  Copies of this bootstrap script, residing in project
:: specific code trees are expected to be replaced by newer versions from
:: the Pasta tool when available.  However, a goal is to keep this script
:: as minimal as possible, so that there should be little reason to update
:: it.
::
:: Since this is a bootstrap script, it has as few external dependencies as
:: possible. This means:
::  1. We don't depend on any software or API that doesn't included with
::     Windows XP or newer.
::  2. Even though this script consists of code written in several programming
::     languages, everything is embedded inside a ".cmd" script that can be
::     executed directly from the command line on Windows.
::

rem -- Unless otherwise specified, the project specific Pasta rule files are
rem -- available in the same directory as this bootstrap script.

setlocal
if "%PASTA_RULES%" == "" set "PASTA_RULES=%~dp0"
set "_self=%0"

rem -- This script may be running in all manner of environments, which means
rem -- that we can't be certain what the PATH looks like at the moment.
rem -- Since we call external commands such as the Windows command 'find'
rem -- later down, we need to make sure that the 'find' command that is
rem -- being used is the right one. If someone runs "cmd" from within a Cygwin
rem -- shell and then runs this script, we want to avoid using the Cygwin
rem -- 'find' command.  We therefore place the directory where the standard
rem -- Windows 'find' command resides in at the front of the PATH before
rem -- contiuing.

set "PATH=%SystemRoot%\System32;%PATH%"

rem -- The hidden ".pasta" directory under the Pasta rules directory contains
rem -- files considered temporary or expendable, which should not be checked
rem -- into any source code repository.
set "_pasta_workspace=%PASTA_RULES%.pasta"
if not exist "%_pasta_workspace%" (
    mkdir "%_pasta_workspace%"
    if errorlevel 1 exit /b 1
    
    attrib +h "%_pasta_workspace%"
    echo Initialized Pasta Workspace
)

set _pastatool_dir_name=pastatool
set "_pastatool_dir=%_pasta_workspace%\%_pastatool_dir_name%"
set "_pastatool_bindir=%_pastatool_dir%\bin\Release"
set "_pastatool=%_pastatool_bindir%\Pasta.exe"

rem -- New Pasta tool is only downloaded if it doesn't already exist locally
rem -- or the user passed in the "get" or "bootstrap" command.
set _bootstrap=no
if not exist "%_pastatool_bindir%" set _bootstrap=yes
if "%1" == "get" set _bootstrap=yes
if "%1" == "bootstrap" set _bootstrap=yes
if "%_bootstrap%" == "yes" (
    call :bootstrap "%_pasta_workspace%" "%_pastatool_dir%"
    if errorlevel 1 (
        echo %0: Pasta tool unavailable: Bootstrap failure
        exit /b 1
    )
)

if not exist "%_pastatool_bindir%" (
    rem -- There seems to be some confusion about where the binaries in the 
    rem -- BuildTools package reside.  The old packages that were used for
    rem -- bootstrapping had them at Release\, while all the packages that
    rem -- are built currently have them at bin\Release.
    if exist "%_pastatool_dir%\Release" (
        xcopy /s /i /y /q "%_pastatool_dir%\Release" "%_pastatool_bindir%"
    )
)

if not exist "%_pastatool%" set "_pastatool=%_pastatool_bindir%\StageTool.exe"

if not exist "%_pastatool%" (
    echo %0: can't find Pasta tool executable '%_pastatool%'
    exit /b 1
)

rem -- Run and exit inside block to allow safe runtime updating of this
rem -- bootstrap script.
(
    "%_pastatool%" %*
    if errorlevel 1 (
        echo %0: command '%_pastatool% %*' failed, exit code: %ERRORLEVEL%
        exit /b 1    
    )
    exit /b 0
)

:bootstrap
:: -- [IN] Pasta workspace
:: -- [IN] Pasta tool directory path
setlocal

set "_workspace=%~1"
set "_tooldirpath=%~2"
set "_tooldirname=%~n2"

set "_fridge=%PASTA_FRIDGE%"
if "%_fridge%" == "" (
    if not "%COMPONENT_STORAGE%" == "" (
        set "_fridge=%COMPONENT_STORAGE%"
    ) else (
        set _fridge=http://component.vizrt.internal/
    )
)

set "_archive=%_workspace%\BuildTools-latest.zip"
set "_pastatool_partial=%_tooldirpath%.part"

if exist "%_pastatool_partial%" (
    rmdir /s /q "%_pastatool_partial%"
    if errorlevel 1 exit /b 1
)
mkdir "%_pastatool_partial%"
if errorlevel 1 exit /b 1

set _stagetool_baseurl=%_fridge%/stagedbuilds/BuildTools-latest.zip

rem -- The Msxml2.XMLHTTP has an internal cache which cannot be disabled by
rem -- adding a "Cache-Control: no-cache" header.  Therefore we add a random
rem -- parameter to the URL to prevent getting an old file from the cache.
set _stagetool_url=%_stagetool_baseurl%?r=%RANDOM%

if not exist "%_pastatool%" goto usedownloadjs
"%_pastatool%" download "%_stagetool_baseurl%" "%_archive%" 2> "%_workspace%\err"
FOR /F "tokens=*" %%A IN ("%_workspace%\err") DO set size=%%~zA
if %size% EQU 0 goto downloaddone

echo Non-fatal error:
type "%_workspace%\err"

:usedownloadjs

call :extractFileSection "[START download.js]" "[END]" ^
    > "%_workspace%\download.js"
if errorlevel 1 exit /b 1

cscript //Nologo "%_workspace%\download.js" "%_workspace%" "%_stagetool_url%"
if errorlevel 1 (
    echo %_self%: command '//Nologo "%_workspace%\download.js" ^
"%_workspace%" "%_stagetool_url%"' failed. exitcode: %ERRORLEVEL%
    exit /b 1
)
echo Downloaded pasta tool from %_stagetool_url%

:downloaddone

if not exist "%_pastatool%" goto useunzipvbs
"%_pastatool%" extract "%_archive%" "%_tooldirpath%" --outputdir "%_pastatool_partial%" 2> "%_workspace%\err"
if %ERRORLEVEL% EQU 200 goto bootstrapdone

FOR /F "tokens=*" %%A IN ("%_workspace%\err") DO set size=%%~zA
if %size% NEQ 0 goto extractfailed

echo Pasta files extracted.
goto extractdone

:extractfailed
echo Non-fatal error:
type "%_workspace%\err"

:useunzipvbs

rem -- On XP the operation of of unzipping the stage tool leaves directories
rem -- named "Temporary Directory nn for BuildTools-latest.zip" in the %TMP%
rem -- directory. Once 99 of these directories have been created the unzip
rem -- operation start throwing up a dialog box saying "The file exists."
rem -- To avoid this, we temporarily redirect the %TMP% variable to a
rem -- directory we control, so that we can it clean up, thus avoiding this
rem -- limit.

set "_original_TMP=%TMP%"
set "TMP=%_workspace%\tmp"
if exist "%TMP%" (
    rmdir /s /q "%tmp%"
    if errorlevel 1 exit /b 1
)
mkdir "%TMP%"
call :extractFileSection "[START unzip.vbs]" "[END]" ^
    > "%_workspace%\unzip.vbs"
if errorlevel 1 exit /b 1

cscript //Nologo "%_workspace%\unzip.vbs" "%_archive%" "%_pastatool_partial%"
if errorlevel 1 (
    echo %_self%: command 'cscript //Nologo "%_workspace%\unzip.vbs" ^
"%_archive%" "%_pastatool_partial%"' failed. exitcode: %ERRORLEVEL%
    exit /b 1
)

rmdir /s /q "%TMP%"
if errorlevel 1 exit /b 1

set "TMP=%_original_TMP%"

:extractdone

if exist "%_tooldirpath%" (
    rmdir /s /q "%_tooldirpath%"
    if errorlevel 1 exit /b 1
)

if exist "%_tooldirpath%" exit /b 1

rename "%_pastatool_partial%" "%_tooldirname%"
if errorlevel 1 exit /b 1

if not exist "%_tooldirpath%" exit /b 1

:bootstrapdone
endlocal
exit /b 0

:extractFileSection StartMark EndMark FileName -- extracts a section of file that is defined by a start and end mark
::                  -- [IN]     StartMark - start mark, use '...:S' mark to allow variable substitution
::                  -- [IN,OPT] EndMark   - optional end mark, default is first empty line
::                  -- [IN,OPT] FileName  - optional source file, default is THIS file
:$created 20080219 :$changed 20100205 :$categories FileOperation
:$source http://www.dostips.com

SETLOCAL Disabledelayedexpansion
set "bmk=%~1"
set "emk=%~2"
set "src=%~3"
set "bExtr="
set "bSubs="
if "%src%"=="" set src=%~f0&        rem if no source file then assume THIS file

for /f "tokens=1,* delims=]" %%A in ('find /n /v "" "%src%"') do (
    if /i "%%B"=="%emk%" set "bExtr="&set "bSubs="
    if defined bExtr if defined bSubs (call echo.%%B) ELSE (echo.%%B)
    if /i "%%B"=="%bmk%"   set "bExtr=Y"
    if /i "%%B"=="%bmk%:S" set "bExtr=Y"&set "bSubs=Y"
)
EXIT /b 0

[START download.js]
var download = function(pastaWorkspace, url) {
    var targetFilename = pastaWorkspace + '\\BuildTools-latest.zip';
    var xmlhttp = new ActiveXObject("Msxml2.XMLHTTP");

    try {    
        xmlhttp.open('GET', url, false);
    } catch (err) {
        throw new Error('Download URL not valid "' + url + '"');
    }
    
    xmlhttp.send()
    if (xmlhttp.Status !== 200) {
        throw new Error('Resource "' + url + '" unavailable. Status: '
            + xmlhttp.Status);
    }    
    var objADOStream = new ActiveXObject("ADODB.Stream");
    objADOStream.Open();
       
    objADOStream.Type = 1; /* binary */
    objADOStream.Write(xmlhttp.ResponseBody);
    objADOStream.Position = 0; /* rewind to start of stream */

    var objFSO = new ActiveXObject("Scripting.FileSystemObject");
    if (objFSO.Fileexists(targetFilename)) {
        objFSO.DeleteFile(targetFilename);
    }
    
    objADOStream.SaveToFile(targetFilename);    
    objADOStream.Close();
}

try {
    var args = WScript.Arguments;
    download(args(0), args(1));
} catch (e) {
    WScript.StdErr.WriteLine(e.name + ": " + e.message);
    if (e.number) {
        var num = e.number;
        if (num < 0) {
            num = num + 1<<16;
        }
        WScript.StdErr.WriteLine("  number: 0x" + num.toString(16));
        if (num == 0x7f0000) {
            WScript.StdErr.WriteLine("This may be due to running this command over SSH against a Cygwin host.\n" +
                    "The CommonProgramFiles(x86) environment variable needs to be set.\n" +
                    "See also: http://moinwiki.vizrt.internal/PaSta/FrequentlyAskedQuestions");
        }
    }
    WScript.Quit(1)
}
[END]

[START unzip.vbs]
Function fUnzip(sZipFile,sTargetFolder)
    Dim oShellApp, oTargetNs, count, tries, dots, remaining, newRemaining
    Set oShellApp = CreateObject("Shell.Application")
    Set oTargetNs = oShellApp.NameSpace(sTargetFolder)
    oTargetNs.CopyHere oShellApp.NameSpace(sZipFile).Items, 4 + 16 + 512 + 1024
    count = oShellApp.NameSpace(sZipFile).Items.Count
    tries = 0
    dots = False
    remaining = -1
    Do While oTargetNs.Items.Count < count
        tries = tries + 1
        newRemaining = count - oTargetNs.Items.Count
        If (tries Mod 10 = 0) Then
            If Not Dots Then
                If remaining <> newRemaining Then
                    remaining = newRemaining
                    WScript.StdOut.Write("Unzipping (" & remaining & " files remaining)")
                End If
                Dots = True
            End If
            WScript.StdOut.Write(".")
        End If
        If tries > 100 Then
           WScript.StdOut.WriteLine("")
           WScript.StdOut.WriteLine("Unzipping stalled.")
           WScript.StdOut.WriteLine("Expected " & count & " files in " & sTargetFolder)
           WScript.StdOut.WriteLine("Found only " & oTargetNs.Items.Count & " files.")
           WScript.Quit(1)
        End If 
        WScript.Sleep 100
    Loop
    If Dots Then
        WScript.StdOut.WriteLine()
    End If
    WScript.StdOut.WriteLine(count & " files extracted")
End Function

fUnzip WScript.Arguments(0), WScript.Arguments(1)
[END]
