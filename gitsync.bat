@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1

:: ============================================================
::   ██████╗ ██╗████████╗███████╗██╗   ██╗███╗   ██╗ ██████╗
::  ██╔════╝ ██║╚══██╔══╝██╔════╝╚██╗ ██╔╝████╗  ██║██╔════╝
::  ██║  ███╗██║   ██║   ███████╗ ╚████╔╝ ██╔██╗ ██║██║
::  ██║   ██║██║   ██║   ╚════██║  ╚██╔╝  ██║╚██╗██║██║
::  ╚██████╔╝██║   ██║   ███████║   ██║   ██║ ╚████║╚██████╗
::   ╚═════╝ ╚═╝   ╚═╝   ╚══════╝   ╚═╝   ╚═╝  ╚═══╝ ╚═════╝
::
::        GIT AUTOMATION WIZARD  —  ULTRA EDITION v3.1
::        Full-featured, failsafe, interactive Git manager
::        Author  : ._neutron_.
::        Version : 3.1.0
::        Updated : 2026
:: ============================================================
::
:: CHANGELOG v3.1.0
::   + Self-update check on every startup (fetches latest from GitHub)
::   + Shows what changed when a new version is downloaded
::   + Auto-backup of old script before updating
::   ~ Fixed: ] file created by unescaped > in PrintStep
::   ~ Fixed: GIT_PAGER=cat prevents pager hang after commits
::   ~ Fixed: Pull logic now correctly skips pull on first push
::   ~ Fixed: Branch detected before pull check (was empty before)
:: END_CHANGELOG
:: ============================================================

:: ──────────────────────────────────────────────────────────
::  GLOBAL CONFIGURATION
:: ──────────────────────────────────────────────────────────
set "SCRIPT_VERSION=3.1.0"
set "SELF_UPDATE_URL=https://raw.githubusercontent.com/futuretonight/gitsync/main/gitsync.bat"
set "SELF_UPDATE_SKIP=0"
set "SCRIPT_NAME=GitSync Ultra"
set "CACHE_FILE=.gitsync_cache.log"
set "CONFIG_FILE=.gitsync_config.ini"
set "BACKUP_DIR=.gitsync_backups"
set "TEMPLATE_DIR=.gitsync_templates"
set "DEFAULT_BRANCH=main"
set "MAX_LOG_ENTRIES=500"
set "GIT_PAGER=cat"
set "DIVIDER==================================================================="
set "THIN_DIVIDER=-------------------------------------------------------------------"
set "STAR_LINE=***********************************************************"

:: Color codes via ANSI (requires Windows 10 1511+)
:: We use a small trick: write ESC character via a temp file
for /f %%a in ('echo prompt $E ^| cmd /q') do set "ESC=%%a"
set "C_RESET=%ESC%[0m"
set "C_RED=%ESC%[91m"
set "C_GREEN=%ESC%[92m"
set "C_YELLOW=%ESC%[93m"
set "C_BLUE=%ESC%[94m"
set "C_MAGENTA=%ESC%[95m"
set "C_CYAN=%ESC%[96m"
set "C_WHITE=%ESC%[97m"
set "C_BOLD=%ESC%[1m"
set "C_DIM=%ESC%[2m"

:: ──────────────────────────────────────────────────────────
::  TITLE BAR
:: ──────────────────────────────────────────────────────────
title %SCRIPT_NAME% v%SCRIPT_VERSION%

:: ──────────────────────────────────────────────────────────
::  PRE-FLIGHT: CHECK GIT INSTALLATION
:: ──────────────────────────────────────────────────────────
git --version >nul 2>&1
if errorlevel 1 (
    call :PrintError "Git is NOT installed or not found in PATH."
    call :PrintInfo  "Download Git from: https://git-scm.com/downloads"
    call :PrintInfo  "Install it, restart this terminal, then run gitsync again."
    pause
    exit /b 1
)

:: Capture git version for logs
for /f "tokens=3" %%v in ('git --version 2^>nul') do set "GIT_VERSION=%%v"

:: ── Load persisted config (e.g. updates_disabled) ────────
set "UPDATES_DISABLED=0"
if exist "%CONFIG_FILE%" (
    for /f "usebackq tokens=1,* delims==" %%k in ("%CONFIG_FILE%") do (
        if /i "%%k"=="updates_disabled" set "UPDATES_DISABLED=%%l"
    )
)
:: If updates are disabled, tell SelfUpdate to skip
if "%UPDATES_DISABLED%"=="1" set "SELF_UPDATE_SKIP=1"

:: ──────────────────────────────────────────────────────────
::  ARGUMENT / COMMAND ROUTER
:: ──────────────────────────────────────────────────────────
set "ARG1=%~1"
set "ARG2=%~2"
set "ARG3=%~3"

if "%ARG1%"==""         goto :MainWizard

:: ── Quick-access commands (no wizard, just do it) ──
if /i "%ARG1%"=="help"          goto :ShowHelp
if /i "%ARG1%"=="-h"            goto :ShowHelp
if /i "%ARG1%"=="--help"        goto :ShowHelp
if /i "%ARG1%"=="?"             goto :ShowHelp

if /i "%ARG1%"=="status"        goto :QuickStatus
if /i "%ARG1%"=="s"             goto :QuickStatus

if /i "%ARG1%"=="log"           goto :QuickLog
if /i "%ARG1%"=="l"             goto :QuickLog

if /i "%ARG1%"=="logfull"       goto :QuickLogFull

if /i "%ARG1%"=="undo"          goto :QuickUndo

if /i "%ARG1%"=="history"       goto :QuickHistory
if /i "%ARG1%"=="hist"          goto :QuickHistory

if /i "%ARG1%"=="diff"          goto :QuickDiff

if /i "%ARG1%"=="branch"        goto :BranchMenu
if /i "%ARG1%"=="br"            goto :BranchMenu

if /i "%ARG1%"=="stash"         goto :StashMenu
if /i "%ARG1%"=="st"            goto :StashMenu

if /i "%ARG1%"=="tag"           goto :TagMenu

if /i "%ARG1%"=="remote"        goto :RemoteMenu

if /i "%ARG1%"=="pull"          goto :QuickPull

if /i "%ARG1%"=="push"          goto :QuickPush

if /i "%ARG1%"=="fetch"         goto :QuickFetch

if /i "%ARG1%"=="clean"         goto :QuickClean

if /i "%ARG1%"=="config"        goto :ConfigMenu

if /i "%ARG1%"=="stats"         goto :QuickStats

if /i "%ARG1%"=="ignore"        goto :GitIgnoreMenu

if /i "%ARG1%"=="conflicts"     goto :ConflictHelper

if /i "%ARG1%"=="cherrypick"    goto :CherryPickMenu
if /i "%ARG1%"=="cp"            goto :CherryPickMenu

if /i "%ARG1%"=="rebase"        goto :RebaseMenu

if /i "%ARG1%"=="amend"         goto :QuickAmend

if /i "%ARG1%"=="blame"         goto :QuickBlame

if /i "%ARG1%"=="reset"         goto :ResetMenu

if /i "%ARG1%"=="backup"        goto :BackupMenu

if /i "%ARG1%"=="version"       goto :ShowVersion

if /i "%ARG1%"=="changelog"     goto :ShowChangelog

if /i "%ARG1%"=="doctor"        goto :RunDoctor

if /i "%ARG1%"=="setup"         goto :FirstTimeSetup

if /i "%ARG1%"=="clearhistory"  goto :ClearHistory

if /i "%ARG1%"=="archive"       goto :ArchiveRepo

if /i "%ARG1%"=="prune"         goto :PruneBranches

if /i "%ARG1%"=="whoami"        goto :WhoAmI

if /i "%ARG1%"=="sync"          goto :FullSync

if /i "%ARG1%"=="update"        goto :UpdateMenu
if /i "%ARG1%"=="updates"       goto :UpdateMenu

call :PrintWarning "Unknown command: '%ARG1%'"
call :PrintInfo    "Run 'gitsync help' to see all available commands."
exit /b 1

:: ============================================================
::  SECTION 1 — MAIN WIZARD
:: ============================================================
:MainWizard
cls
call :PrintBanner
call :SelfUpdate
if errorlevel 99 exit /b 0
call :EnsureCacheFile
call :EnsureGitIgnore
call :CheckGitConfig

echo.
call :PrintSection "STEP 1 — REPOSITORY CHECK"
call :CheckOrInitRepo
if errorlevel 1 exit /b 1

echo.
call :PrintSection "STEP 2 — LOCAL COMMIT"
call :LocalCommitFlow
if errorlevel 1 (
    call :PrintWarning "Local commit step skipped or encountered issues."
)

echo.
call :PrintSection "STEP 3 — REMOTE PUSH"
call :RemotePushFlow

echo.
call :PrintSection "WIZARD COMPLETE"
call :PrintSuccess "All done! Your Git workflow is up to date."
call :PrintInfo    "Run 'gitsync help' to see all shortcuts."
echo.
call :CacheWrite "Wizard completed successfully"
pause
exit /b 0

:: ============================================================
::  SECTION 2 — CORE HELPER SUBROUTINES
:: ============================================================

:: ── Print a styled banner ──────────────────────────────────
:PrintBanner
echo.
echo %C_CYAN%%C_BOLD%%DIVIDER%%C_RESET%
echo %C_CYAN%%C_BOLD%         %SCRIPT_NAME%  v%SCRIPT_VERSION%%C_RESET%
echo %C_CYAN%%C_BOLD%         Full-featured Git Automation Wizard%C_RESET%
echo %C_CYAN%         Git %GIT_VERSION%   ^|   %date%   ^|   %time:~0,8%%C_RESET%
echo %C_CYAN%%C_BOLD%%DIVIDER%%C_RESET%
exit /b 0

:: ── Section header ─────────────────────────────────────────
:PrintSection
echo.
echo %C_BOLD%%C_BLUE%[ %~1 ]%C_RESET%
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
exit /b 0

:: ── Colored message helpers ────────────────────────────────
:PrintSuccess
echo %C_GREEN%[+] %~1%C_RESET%
exit /b 0

:PrintError
echo %C_RED%[X] %~1%C_RESET%
exit /b 0

:PrintWarning
echo %C_YELLOW%[!] %~1%C_RESET%
exit /b 0

:PrintInfo
echo %C_CYAN%[i] %~1%C_RESET%
exit /b 0

:PrintStep
echo %C_MAGENTA%[^>] %~1%C_RESET%
exit /b 0

:PrintDim
echo %C_DIM%    %~1%C_RESET%
exit /b 0

:: ── Self-update check ───────────────────────────────────────
:SelfUpdate
if "%SELF_UPDATE_SKIP%"=="1" exit /b 0

curl --version >nul 2>&1
if errorlevel 1 ( call :PrintDim "Skipping update check: curl not found." & exit /b 0 )

call :PrintDim "Checking for updates..."
set "_self=%~f0"
set "_tmp_update=%TEMP%\gitsync_update_check.bat"

curl -fsSL --connect-timeout 5 --max-time 10 "%SELF_UPDATE_URL%" -o "%_tmp_update%" >nul 2>&1
if errorlevel 1 (
    call :PrintDim "Update check skipped: could not reach GitHub."
    if exist "%_tmp_update%" del /f /q "%_tmp_update%" >nul 2>&1
    exit /b 0
)

call :ExtractRemoteVersion "%_tmp_update%"
if "!_remote_ver!"=="" (
    call :PrintDim "Update check skipped: remote file has no valid version."
    del /f /q "%_tmp_update%" >nul 2>&1
    exit /b 0
)

if "!_remote_ver!"=="%SCRIPT_VERSION%" (
    call :PrintDim "Already up to date (v%SCRIPT_VERSION%)."
    del /f /q "%_tmp_update%" >nul 2>&1
    exit /b 0
)

:: Only prompt if remote is a different valid version
echo.
echo %C_BOLD%%C_CYAN%  ╔════════════════════════════════════════════╗%C_RESET%
echo %C_BOLD%%C_CYAN%  ║  UPDATE AVAILABLE:  v%SCRIPT_VERSION%  →  v!_remote_ver!%C_RESET%
echo %C_BOLD%%C_CYAN%  ╚════════════════════════════════════════════╝%C_RESET%
echo.
echo %C_BOLD%%C_YELLOW%  What's new in v!_remote_ver!:%C_RESET%
call :PrintChangelog "%_tmp_update%" "!_remote_ver!"
echo.

set /p "_doupdate=  Install update now? (y/n): "
if /i not "!_doupdate!"=="y" (
    call :PrintInfo "Update skipped. You will be asked again next run."
    del /f /q "%_tmp_update%" >nul 2>&1
    exit /b 0
)

call :DoInstallUpdate "%_tmp_update%"
exit /b !errorlevel!

:: ── Extract version from a downloaded bat file ──────────────
:: Sets _remote_ver to the version string, or empty if not found/invalid
:ExtractRemoteVersion
set "_remote_ver="
set "_evf=%~1"
for /f "usebackq delims=" %%L in ("%_evf%") do (
    :: Only process if we haven't found it yet
    if "!_remote_ver!"=="" (
        set "_evline=%%L"
        :: Check line contains both "set" and "SCRIPT_VERSION="
        set "_evcheck=!_evline!"
        if "!_evcheck:SCRIPT_VERSION=!=!" neq "!_evcheck!" (
            if "!_evcheck:set =!=!" neq "!_evcheck!" (
                :: Extract the part after SCRIPT_VERSION=
                for /f "tokens=2 delims==" %%v in ("!_evline!") do (
                    if "!_remote_ver!"=="" set "_remote_ver=%%v"
                )
            )
        )
    )
)
:: Strip quotes and spaces
set "_remote_ver=!_remote_ver:"=!"
set "_remote_ver=!_remote_ver: =!"
:: Validate: must only contain digits and dots (format x.y.z)
set "_ver_valid=0"
echo !_remote_ver! | findstr /r "^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$" >nul 2>&1
if not errorlevel 1 set "_ver_valid=1"
if "!_ver_valid!"=="0" set "_remote_ver="
exit /b 0

:: ── Print changelog lines from a bat file for a given version ─
:PrintChangelog
set "_clf=%~1"
set "_clver=%~2"
set "_in_cl=0"
for /f "usebackq delims=" %%L in ("%_clf%") do (
    set "_cll=%%L"
    :: Detect CHANGELOG header for this version
    echo !_cll! | findstr /i /c:"CHANGELOG v!_clver!" >nul 2>&1
    if not errorlevel 1 set "_in_cl=1"
    :: Detect end marker
    echo !_cll! | findstr /i /c:"END_CHANGELOG" >nul 2>&1
    if not errorlevel 1 set "_in_cl=0"
    :: Print content lines (not the header line itself)
    if "!_in_cl!"=="1" (
        echo !_cll! | findstr /i /c:"CHANGELOG v" >nul 2>&1
        if errorlevel 1 (
            set "_cll=!_cll:::   =  !"
            set "_cll=!_cll:::  =  !"
            echo %C_CYAN%!_cll!%C_RESET%
        )
    )
)
exit /b 0

:: ── Common install routine (backup + replace + restart) ──────
:DoInstallUpdate
set "_diu_src=%~1"
set "_self=%~f0"
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"
set "_bkdate=%date:~-4%%date:~3,2%%date:~0,2%_%time:~0,2%%time:~3,2%"
set "_bkdate=!_bkdate: =0!"
set "_bkfile=%BACKUP_DIR%\gitsync_v%SCRIPT_VERSION%_!_bkdate!.bat"
copy /y "!_self!" "!_bkfile!" >nul 2>&1
call :PrintSuccess "Backup saved: !_bkfile!"
copy /y "%_diu_src%" "!_self!" >nul 2>&1
if errorlevel 1 (
    call :PrintError "Update failed: cannot overwrite script. Check file permissions."
    del /f /q "%_diu_src%" >nul 2>&1
    exit /b 1
)
del /f /q "%_diu_src%" >nul 2>&1
call :PrintSuccess "Updated to v!_remote_ver! successfully!"
call :PrintInfo "Restarting GitSync..."
echo.
start "" "!_self!"
exit /b 99


:: ── Update menu (gitsync update) ───────────────────────────
:UpdateMenu
call :PrintBanner
echo.
echo %C_BOLD%%C_BLUE%[ UPDATE MANAGER ]%C_RESET%
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
echo.
echo %C_CYAN%  Current version : %C_BOLD%v%SCRIPT_VERSION%%C_RESET%
echo %C_CYAN%  Update source   : %C_DIM%%SELF_UPDATE_URL%%C_RESET%
if "%UPDATES_DISABLED%"=="1" (
    echo %C_YELLOW%  Auto-updates    : DISABLED%C_RESET%
) else (
    echo %C_GREEN%  Auto-updates    : ENABLED%C_RESET%
)
echo.
echo %C_WHITE%  [1] Check for update now (force)%C_RESET%
if "%UPDATES_DISABLED%"=="1" (
    echo %C_WHITE%  [2] Re-enable auto-updates%C_RESET%
) else (
    echo %C_WHITE%  [2] Disable auto-updates%C_RESET%
)
echo %C_WHITE%  [0] Back / Exit%C_RESET%
echo.
set /p "_umchoice=  Choice: "

if "!_umchoice!"=="1" (
    call :UpdateForce
    goto :UpdateMenu
)
if "!_umchoice!"=="2" (
    call :UpdateToggle
    goto :UpdateMenu
)
if "!_umchoice!"=="0" exit /b 0
call :PrintWarning "Invalid choice."
goto :UpdateMenu

:: ── Force update check (on-demand) ─────────────────────────
:UpdateForce
echo.
call :PrintStep "Forcing update check..."
echo.

curl --version >nul 2>&1
if errorlevel 1 ( call :PrintError "curl not found. Cannot check for updates." & exit /b 1 )

set "_self=%~f0"
set "_tmp_update=%TEMP%\gitsync_update_check.bat"

curl -fsSL --connect-timeout 5 --max-time 15 "%SELF_UPDATE_URL%" -o "%_tmp_update%" >nul 2>&1
if errorlevel 1 (
    call :PrintError "Could not reach GitHub. Check your internet connection."
    if exist "%_tmp_update%" del /f /q "%_tmp_update%" >nul 2>&1
    exit /b 1
)

call :ExtractRemoteVersion "%_tmp_update%"

call :PrintInfo "Local  version : v%SCRIPT_VERSION%"
if "!_remote_ver!"=="" (
    call :PrintError "Could not read a valid version from the remote file."
    call :PrintDim   "The remote may be an old/incompatible version."
    del /f /q "%_tmp_update%" >nul 2>&1
    exit /b 1
)
call :PrintInfo "Remote version : v!_remote_ver!"
echo.

if "!_remote_ver!"=="%SCRIPT_VERSION%" (
    call :PrintSuccess "Already on the latest version (v%SCRIPT_VERSION%). Nothing to do."
    del /f /q "%_tmp_update%" >nul 2>&1
    exit /b 0
)

echo %C_BOLD%%C_CYAN%  ╔════════════════════════════════════════════╗%C_RESET%
echo %C_BOLD%%C_CYAN%  ║  UPDATE AVAILABLE:  v%SCRIPT_VERSION%  →  v!_remote_ver!%C_RESET%
echo %C_BOLD%%C_CYAN%  ╚════════════════════════════════════════════╝%C_RESET%
echo.
echo %C_BOLD%%C_YELLOW%  What's new in v!_remote_ver!:%C_RESET%
call :PrintChangelog "%_tmp_update%" "!_remote_ver!"
echo.

set /p "_doforce=  Install this update now? (y/n): "
if /i not "!_doforce!"=="y" (
    call :PrintInfo "Update skipped."
    del /f /q "%_tmp_update%" >nul 2>&1
    exit /b 0
)

call :DoInstallUpdate "%_tmp_update%"
exit /b !errorlevel!

:: ── Toggle auto-updates on / off (persisted to config) ──────
:UpdateToggle
:: Read current state fresh
set "_cur_disabled=0"
if exist "%CONFIG_FILE%" (
    for /f "usebackq tokens=1,* delims==" %%k in ("%CONFIG_FILE%") do (
        if /i "%%k"=="updates_disabled" set "_cur_disabled=%%l"
    )
)
if "%UPDATES_DISABLED%"=="1" set "_cur_disabled=1"

if "!_cur_disabled!"=="1" (
    :: Turn updates back ON — remove the line from config
    if exist "%CONFIG_FILE%" (
        :: Rewrite config without the updates_disabled line
        set "_tmp_cfg=%TEMP%\gitsync_cfg_tmp.ini"
        (for /f "usebackq delims=" %%L in ("%CONFIG_FILE%") do (
            echo "%%L" | findstr /i "updates_disabled" >nul 2>&1
            if errorlevel 1 echo %%L
        )) > "!_tmp_cfg!"
        copy /y "!_tmp_cfg!" "%CONFIG_FILE%" >nul 2>&1
        del /f /q "!_tmp_cfg!" >nul 2>&1
    )
    set "UPDATES_DISABLED=0"
    set "SELF_UPDATE_SKIP=0"
    call :PrintSuccess "Auto-updates ENABLED. Updates will be checked on every startup."
    call :CacheWrite "UPDATES: re-enabled"
) else (
    :: Turn updates OFF — write to config
    if not exist "%CONFIG_FILE%" (
        echo # GitSync Ultra config > "%CONFIG_FILE%"
    )
    :: Remove any existing entry first, then append
    set "_tmp_cfg=%TEMP%\gitsync_cfg_tmp.ini"
    (for /f "usebackq delims=" %%L in ("%CONFIG_FILE%") do (
        echo "%%L" | findstr /i "updates_disabled" >nul 2>&1
        if errorlevel 1 echo %%L
    )) > "!_tmp_cfg!"
    echo updates_disabled=1 >> "!_tmp_cfg!"
    copy /y "!_tmp_cfg!" "%CONFIG_FILE%" >nul 2>&1
    del /f /q "!_tmp_cfg!" >nul 2>&1
    set "UPDATES_DISABLED=1"
    set "SELF_UPDATE_SKIP=1"
    call :PrintSuccess "Auto-updates DISABLED. Run 'gitsync update' and choose [2] to re-enable."
    call :CacheWrite "UPDATES: disabled"
)
exit /b 0

:: ── Write to cache file ────────────────────────────────────
:CacheWrite
set "_msg=%~1"
echo [%date% %time:~0,8%] %_msg% >> "%CACHE_FILE%"
exit /b 0

:: ── Ensure cache file exists ───────────────────────────────
:EnsureCacheFile
if not exist "%CACHE_FILE%" (
    echo GitSync Ultra — Action Log > "%CACHE_FILE%"
    echo Created: %date% %time% >> "%CACHE_FILE%"
    echo %DIVIDER% >> "%CACHE_FILE%"
    call :PrintInfo "Cache log created: %CACHE_FILE%"
)

:: Rotate log if too large (> MAX_LOG_ENTRIES lines)
set /a _count=0
for /f %%x in ('type "%CACHE_FILE%" ^| find /c /v ""') do set /a _count=%%x
if !_count! GTR %MAX_LOG_ENTRIES% (
    call :PrintWarning "Cache log is large (!_count! lines). Archiving..."
    if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"
    set "_arch_name=%BACKUP_DIR%\cache_archive_%date:~-4%%date:~3,2%%date:~0,2%_%time:~0,2%%time:~3,2%.log"
    set "_arch_name=!_arch_name: =0!"
    copy "%CACHE_FILE%" "!_arch_name!" >nul 2>&1
    echo GitSync Ultra — Action Log (rotated) > "%CACHE_FILE%"
    echo Rotated: %date% %time% >> "%CACHE_FILE%"
    echo %DIVIDER% >> "%CACHE_FILE%"
    call :PrintSuccess "Log archived to: !_arch_name!"
)
exit /b 0

:: ── Ensure .gitignore exists and contains cache/config ─────
:EnsureGitIgnore
if not exist .gitignore (
    call :PrintInfo ".gitignore not found. Creating a default one..."
    call :WriteDefaultGitIgnore
    call :CacheWrite "Created default .gitignore"
)

:: Add our internal files to .gitignore if missing
call :EnsureInGitIgnore "%CACHE_FILE%"
call :EnsureInGitIgnore "%CONFIG_FILE%"
call :EnsureInGitIgnore "%BACKUP_DIR%/"
call :EnsureInGitIgnore "%TEMPLATE_DIR%/"
exit /b 0

:: ── Add a single entry to .gitignore if not present ────────
:EnsureInGitIgnore
set "_entry=%~1"
findstr /x /c:"!_entry!" .gitignore >nul 2>&1
if errorlevel 1 (
    echo !_entry!>> .gitignore
    call :PrintInfo "Added '!_entry!' to .gitignore"
    call :CacheWrite "Gitignore updated: added !_entry!"
)
exit /b 0

:: ── Write a comprehensive default .gitignore ───────────────
:WriteDefaultGitIgnore
(
echo # GitSync Ultra — auto-generated .gitignore
echo # Generated: %date% %time%
echo.
echo # ── GitSync internal files ─────────────────────────────
echo %CACHE_FILE%
echo %CONFIG_FILE%
echo %BACKUP_DIR%/
echo %TEMPLATE_DIR%/
echo.
echo # ── OS Files ────────────────────────────────────────────
echo .DS_Store
echo .DS_Store?
echo ._*
echo .Spotlight-V100
echo .Trashes
echo ehthumbs.db
echo Thumbs.db
echo desktop.ini
echo $RECYCLE.BIN/
echo.
echo # ── Editor / IDE ────────────────────────────────────────
echo .vscode/
echo .idea/
echo *.suo
echo *.user
echo *.userosscache
echo *.sln.docstates
echo *.sublime-project
echo *.sublime-workspace
echo .vs/
echo nbproject/
echo.
echo # ── Logs and temp ───────────────────────────────────────
echo *.log
echo *.tmp
echo *.temp
echo *.swp
echo *.swo
echo *~
echo.
echo # ── Build artifacts ─────────────────────────────────────
echo /dist/
echo /build/
echo /out/
echo /target/
echo *.class
echo *.pyc
echo *.pyo
echo __pycache__/
echo *.egg-info/
echo.
echo # ── Dependencies ────────────────────────────────────────
echo /node_modules/
echo /vendor/
echo /.bundle/
echo.
echo # ── Environment / Secrets ───────────────────────────────
echo .env
echo .env.local
echo .env.*.local
echo *.pem
echo *.key
echo secrets.json
echo.
echo # ── Archives ────────────────────────────────────────────
echo *.zip
echo *.tar.gz
echo *.rar
echo *.7z
) > .gitignore
call :PrintSuccess ".gitignore written with defaults."
exit /b 0

:: ── Check git user config ──────────────────────────────────
:CheckGitConfig
set "_name="
set "_email="
for /f "delims=" %%v in ('git config --global user.name 2^>nul') do set "_name=%%v"
for /f "delims=" %%v in ('git config --global user.email 2^>nul') do set "_email=%%v"

if "!_name!"=="" (
    call :PrintWarning "Git user.name is NOT configured."
    set /p "_newname=Enter your name for Git commits: "
    if not "!_newname!"=="" (
        git config --global user.name "!_newname!"
        call :PrintSuccess "Git user.name set to: !_newname!"
        call :CacheWrite "Git config: user.name set to !_newname!"
    ) else (
        call :PrintWarning "No name entered. Commits may be anonymous."
    )
)

if "!_email!"=="" (
    call :PrintWarning "Git user.email is NOT configured."
    set /p "_newemail=Enter your email for Git commits: "
    if not "!_newemail!"=="" (
        git config --global user.email "!_newemail!"
        call :PrintSuccess "Git user.email set to: !_newemail!"
        call :CacheWrite "Git config: user.email set to !_newemail!"
    ) else (
        call :PrintWarning "No email entered. Commits may be anonymous."
    )
)
exit /b 0

:: ── Check or initialise repo ──────────────────────────────
:CheckOrInitRepo
git rev-parse --is-inside-work-tree >nul 2>&1
if not errorlevel 1 (
    for /f "delims=" %%r in ('git rev-parse --show-toplevel 2^>nul') do set "_reporoot=%%r"
    call :PrintSuccess "Git repo detected."
    call :PrintDim     "Root: !_reporoot!"
    exit /b 0
)

call :PrintWarning "This folder is NOT a Git repository."
echo.
set /p "_init=Initialize a new Git repo here? (y/n): "
if /i "!_init!"=="y" (
    git init
    if errorlevel 1 (
        call :PrintError "git init failed. Check folder permissions."
        exit /b 1
    )
    call :PrintSuccess "Git repository initialized!"
    call :CacheWrite "git init performed in %cd%"

    :: Set default branch to main
    git checkout -b %DEFAULT_BRANCH% >nul 2>&1
    if errorlevel 1 (
        git branch -M %DEFAULT_BRANCH% >nul 2>&1
    )
    call :PrintInfo "Default branch set to '%DEFAULT_BRANCH%'."
    exit /b 0
)

call :PrintInfo "Aborted. No changes made."
exit /b 1

:: ── Local stage & commit flow ─────────────────────────────
:LocalCommitFlow
:: Show current status
echo.
call :PrintStep "Current working tree status:"
echo.
git status -s
echo.

:: Count staged/unstaged files
set /a _staged=0
set /a _unstaged=0
for /f %%x in ('git status --porcelain 2^>nul ^| find /c /v ""') do set /a _total_changes=%%x

if !_total_changes! EQU 0 (
    call :PrintInfo "Nothing to commit. Working tree is clean."
    exit /b 0
)

call :PrintInfo "!_total_changes! change(s) detected."
echo.
set /p "_commit=Stage all changes and commit locally? (y/n): "
if /i not "!_commit!"=="y" (
    call :PrintInfo "Skipping local commit."
    exit /b 0
)

:: Commit message with smart default
echo.
set /p "_msg=Commit message (blank = auto): "
if "!_msg!"=="" (
    for /f "tokens=1-3 delims=/ " %%a in ("%date%") do set "_dpart=%%a-%%b-%%c"
    for /f "tokens=1-2 delims=:." %%a in ("%time%") do set "_tpart=%%a%%b"
    set "_tpart=!_tpart: =0!"
    set "_msg=Auto-update !_dpart! !_tpart!"
)

:: Stage all
call :PrintStep "Staging all changes..."
git add .
if errorlevel 1 (
    call :PrintError "git add failed."
    exit /b 1
)

:: Show staged summary
call :PrintStep "Staged files:"
git diff --cached --stat
echo.

:: Commit
call :PrintStep "Committing..."
git commit -m "!_msg!"
if errorlevel 1 (
    call :PrintError "Commit failed. Nothing new to commit, or an error occurred."
    exit /b 1
)
call :PrintSuccess "Committed: ^"!_msg!^""
call :CacheWrite "COMMIT: !_msg!"

:: Show resulting log entry
echo.
call :PrintDim "Latest commit:"
git log --oneline -1
exit /b 0

:: ── Remote push flow ──────────────────────────────────────
:RemotePushFlow
echo.
set /p "_push=Push to GitHub remote? (y/n): "
if /i not "!_push!"=="y" (
    call :PrintInfo "Skipping push."
    exit /b 0
)

:: Check for uncommitted changes first
git diff --cached --quiet >nul 2>&1
git diff --quiet >nul 2>&1

:: Detect or set remote origin
git remote -v 2>nul | findstr "origin" >nul 2>&1
if errorlevel 1 (
    call :PrintWarning "No remote 'origin' configured."
    set /p "_url=Enter GitHub repo URL (e.g. https://github.com/user/repo.git): "
    if "!_url!"=="" (
        call :PrintError "URL cannot be empty. Aborting push."
        exit /b 1
    )
    git remote add origin !_url!
    if errorlevel 1 (
        call :PrintError "Failed to add remote. Check the URL format."
        exit /b 1
    )
    git branch -M %DEFAULT_BRANCH% >nul 2>&1
    call :PrintSuccess "Remote 'origin' added: !_url!"
    call :CacheWrite "REMOTE ADDED: !_url!"
) else (
    for /f "tokens=2" %%u in ('git remote get-url origin 2^>nul') do set "_url=%%u"
    if "!_url!"=="" (
        for /f %%u in ('git remote get-url origin 2^>nul') do set "_url=%%u"
    )
    call :PrintInfo "Remote origin: !_url!"
)

:: Get current branch FIRST (needed for both pull and push)
set "_branch="
for /f %%b in ('git branch --show-current 2^>nul') do set "_branch=%%b"
if "!_branch!"=="" (
    for /f %%b in ('git rev-parse --abbrev-ref HEAD 2^>nul') do set "_branch=%%b"
)
if "!_branch!"=="" set "_branch=%DEFAULT_BRANCH%"

:: Offer to pull first to avoid conflicts
echo.
set /p "_pull_first=Pull from remote first to sync? (recommended) (y/n): "
if /i "!_pull_first!"=="y" (
    call :PrintStep "Pulling from remote..."

    :: Check if remote branch actually exists before pulling
    git ls-remote --exit-code --heads origin !_branch! >nul 2>&1
    if errorlevel 1 (
        call :PrintInfo "Remote branch does not exist yet — skipping pull (this is your first push)."
        call :CacheWrite "PULL SKIPPED: remote branch not found, first push"
    ) else (
        :: Remote branch exists, safe to pull
        git pull --rebase origin !_branch!
        set "_pull_ec=!errorlevel!"
        if !_pull_ec! EQU 0 (
            call :PrintSuccess "Pull successful."
            call :CacheWrite "PULL: from origin (before push)"
        ) else (
            :: Check specifically for merge conflicts
            git status | findstr /i "conflict" >nul 2>&1
            if not errorlevel 1 (
                call :PrintError "Merge conflicts detected! Resolve them, then run 'gitsync conflicts' for help."
                call :CacheWrite "CONFLICT DETECTED during pull"
                exit /b 1
            )
            :: Any other pull failure — warn but continue
            call :PrintWarning "Pull had an issue (exit code !_pull_ec!). Attempting push anyway..."
            call :CacheWrite "PULL WARNING: exit code !_pull_ec!, continuing to push"
        )
    )
)


call :PrintStep "Pushing to origin/!_branch!..."
git push -u origin !_branch!
set "_push_err=%errorlevel%"

if !_push_err! EQU 0 (
    call :PrintSuccess "Push successful! → origin/!_branch!"
    call :CacheWrite "PUSH: origin/!_branch! — SUCCESS"
) else (
    call :PrintError "Push failed! Exit code: !_push_err!"
    call :CacheWrite "PUSH: origin/!_branch! — FAILED (code !_push_err!)"
    echo.
    call :PrintInfo "Common reasons & fixes:"
    call :PrintDim  "  1. Authentication: check your credentials / SSH key / token"
    call :PrintDim  "  2. Remote has changes: run 'gitsync pull' first"
    call :PrintDim  "  3. Branch protection: push to a different branch"
    call :PrintDim  "  4. No internet: check your connection"
    echo.
    set /p "_force=Force push? WARNING: This can overwrite remote history! (y/n): "
    if /i "!_force!"=="y" (
        call :PrintWarning "Force-pushing to origin/!_branch!..."
        git push --force-with-lease origin !_branch!
        if errorlevel 1 (
            call :PrintError "Force push also failed. Manual intervention required."
            call :CacheWrite "FORCE PUSH: origin/!_branch! — FAILED"
            exit /b 1
        )
        call :PrintSuccess "Force push successful (--force-with-lease)."
        call :CacheWrite "FORCE PUSH: origin/!_branch! — SUCCESS"
    )
)
exit /b 0

:: ============================================================
::  SECTION 3 — QUICK COMMANDS
:: ============================================================

:: ── gitsync status ────────────────────────────────────────
:QuickStatus
call :RequireRepo
echo.
echo %C_BOLD%%C_BLUE%[ GIT STATUS ]%C_RESET%
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
git status
echo.
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
echo %C_BOLD%%C_BLUE%[ STAGED CHANGES ]%C_RESET%
git diff --cached --stat
echo.
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
echo %C_BOLD%%C_BLUE%[ UNSTAGED CHANGES ]%C_RESET%
git diff --stat
call :CacheWrite "QUICK: status viewed"
exit /b 0

:: ── gitsync log ───────────────────────────────────────────
:QuickLog
call :RequireRepo
echo.
echo %C_BOLD%%C_BLUE%[ RECENT COMMITS (last 15) ]%C_RESET%
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
git log --oneline --graph --decorate --color -15
echo.
call :CacheWrite "QUICK: log viewed"
exit /b 0

:: ── gitsync logfull ───────────────────────────────────────
:QuickLogFull
call :RequireRepo
echo.
echo %C_BOLD%%C_BLUE%[ FULL COMMIT LOG ]%C_RESET%
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
git log --graph --decorate --color --format="%C_BOLD%%C_CYAN%%%H%C_RESET% %%s %C_DIM%(%%cr by %%an)%C_RESET%"
echo.
call :CacheWrite "QUICK: full log viewed"
exit /b 0

:: ── gitsync diff ──────────────────────────────────────────
:QuickDiff
call :RequireRepo
echo.
echo %C_BOLD%%C_BLUE%[ DIFF — UNSTAGED CHANGES ]%C_RESET%
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
if not "%ARG2%"=="" (
    git diff %ARG2%
) else (
    git diff --color
)
echo.
echo %C_BOLD%%C_BLUE%[ DIFF — STAGED (CACHED) CHANGES ]%C_RESET%
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
git diff --cached --color
call :CacheWrite "QUICK: diff viewed"
exit /b 0

:: ── gitsync undo ──────────────────────────────────────────
:QuickUndo
call :RequireRepo
echo.
call :PrintWarning "This will undo the LAST commit (files stay staged)."
set /p "_confirm=Are you sure? (y/n): "
if /i not "!_confirm!"=="y" (
    call :PrintInfo "Undo cancelled."
    exit /b 0
)
git reset HEAD~1 --soft
if errorlevel 1 (
    call :PrintError "Undo failed. You may be on the first commit (no parent)."
    exit /b 1
)
call :PrintSuccess "Last commit undone. Files are still staged."
git status -s
call :CacheWrite "UNDO: last commit reversed (soft reset)"
exit /b 0

:: ── gitsync history ───────────────────────────────────────
:QuickHistory
echo.
echo %C_BOLD%%C_BLUE%[ GITSYNC ACTION HISTORY ]%C_RESET%
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
if exist "%CACHE_FILE%" (
    type "%CACHE_FILE%"
) else (
    call :PrintWarning "No history found. Cache file does not exist yet."
)
echo.
exit /b 0

:: ── gitsync pull ──────────────────────────────────────────
:QuickPull
call :RequireRepo
echo.
call :PrintStep "Pulling latest changes from remote..."

set "_strat=--rebase"
if /i "%ARG2%"=="merge" set "_strat="

git pull !_strat! origin 2>nul
if errorlevel 1 (
    call :PrintError "Pull failed."
    git status | findstr "conflict\|CONFLICT" >nul 2>&1
    if not errorlevel 1 (
        call :PrintWarning "Conflicts detected! Run 'gitsync conflicts' for help."
        call :CacheWrite "PULL FAILED: conflicts detected"
        exit /b 1
    )
    call :PrintInfo "Try: gitsync pull merge"
    call :CacheWrite "PULL FAILED"
    exit /b 1
)
call :PrintSuccess "Pull successful."
git log --oneline -3
call :CacheWrite "PULL: successful from origin"
exit /b 0

:: ── gitsync push ──────────────────────────────────────────
:QuickPush
call :RequireRepo
set "_branch="
for /f %%b in ('git branch --show-current 2^>nul') do set "_branch=%%b"
if "!_branch!"=="" set "_branch=%DEFAULT_BRANCH%"
echo.
call :PrintStep "Pushing !_branch! to origin..."
git push -u origin !_branch!
if errorlevel 1 (
    call :PrintError "Push failed. Try 'gitsync pull' first."
    call :CacheWrite "QUICK PUSH FAILED: origin/!_branch!"
    exit /b 1
)
call :PrintSuccess "Pushed origin/!_branch!"
call :CacheWrite "QUICK PUSH: origin/!_branch! — SUCCESS"
exit /b 0

:: ── gitsync fetch ─────────────────────────────────────────
:QuickFetch
call :RequireRepo
echo.
call :PrintStep "Fetching all remotes..."
git fetch --all --prune
if errorlevel 1 (
    call :PrintError "Fetch failed."
    call :CacheWrite "FETCH FAILED"
    exit /b 1
)
call :PrintSuccess "Fetch complete. Use 'gitsync log' to review incoming changes."
call :CacheWrite "FETCH: all remotes"
exit /b 0

:: ── gitsync clean ─────────────────────────────────────────
:QuickClean
call :RequireRepo
echo.
call :PrintWarning "This will remove all untracked files and folders."
echo.
call :PrintStep "Preview (dry-run):"
git clean -nfd
echo.
set /p "_clean=Proceed with clean? (y/n): "
if /i not "!_clean!"=="y" (
    call :PrintInfo "Clean cancelled."
    exit /b 0
)
git clean -fd
if errorlevel 1 (
    call :PrintError "Clean failed."
    exit /b 1
)
call :PrintSuccess "Working directory cleaned."
call :CacheWrite "CLEAN: untracked files removed"
exit /b 0

:: ── gitsync amend ─────────────────────────────────────────
:QuickAmend
call :RequireRepo
echo.
for /f "delims=" %%m in ('git log --format^=%%s -1 2^>nul') do set "_lastmsg=%%m"
call :PrintInfo "Last commit message: !_lastmsg!"
echo.
set /p "_newmsg=New message (blank = keep): "
if "!_newmsg!"=="" (
    git commit --amend --no-edit
) else (
    git commit --amend -m "!_newmsg!"
)
if errorlevel 1 (
    call :PrintError "Amend failed. Nothing to amend?"
    exit /b 1
)
call :PrintSuccess "Commit amended."
call :CacheWrite "AMEND: commit message updated"
exit /b 0

:: ── gitsync blame ─────────────────────────────────────────
:QuickBlame
call :RequireRepo
if "%ARG2%"=="" (
    call :PrintError "Usage: gitsync blame <filename>"
    exit /b 1
)
if not exist "%ARG2%" (
    call :PrintError "File not found: %ARG2%"
    exit /b 1
)
echo.
echo %C_BOLD%%C_BLUE%[ GIT BLAME — %ARG2% ]%C_RESET%
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
git blame --color-lines "%ARG2%"
call :CacheWrite "BLAME: viewed %ARG2%"
exit /b 0

:: ── gitsync stats ─────────────────────────────────────────
:QuickStats
call :RequireRepo
echo.
echo %C_BOLD%%C_BLUE%[ REPOSITORY STATISTICS ]%C_RESET%
echo %C_DIM%%THIN_DIVIDER%%C_RESET%

:: Total commits
for /f %%c in ('git rev-list --count HEAD 2^>nul') do set "_commits=%%c"
if "!_commits!"=="" set "_commits=0"

:: Contributors
for /f %%n in ('git shortlog -s HEAD 2^>nul ^| find /c /v ""') do set "_contribs=%%n"
if "!_contribs!"=="" set "_contribs=0"

:: Branches
for /f %%n in ('git branch -a 2^>nul ^| find /c /v ""') do set "_branches=%%n"
if "!_branches!"=="" set "_branches=0"

:: Tags
for /f %%n in ('git tag 2^>nul ^| find /c /v ""') do set "_tags=%%n"
if "!_tags!"=="" set "_tags=0"

:: Current branch
for /f %%b in ('git branch --show-current 2^>nul') do set "_branch=%%b"

:: First commit date
for /f "delims=" %%d in ('git log --reverse --format^=%%ar 2^>nul ^| head -1 2^>nul') do set "_first=%%d"
for /f "delims=" %%d in ('git log --reverse --pretty^=format:%%ad --date^=short 2^>nul') do (
    if "!_first_date!"=="" set "_first_date=%%d"
)

:: Last commit date
for /f "delims=" %%d in ('git log -1 --pretty^=format:%%ad --date^=short 2^>nul') do set "_last_date=%%d"

echo.
echo   %C_BOLD%Total Commits    :%C_RESET% !_commits!
echo   %C_BOLD%Contributors     :%C_RESET% !_contribs!
echo   %C_BOLD%Branches         :%C_RESET% !_branches!
echo   %C_BOLD%Tags             :%C_RESET% !_tags!
echo   %C_BOLD%Current Branch   :%C_RESET% !_branch!
echo   %C_BOLD%First Commit     :%C_RESET% !_first_date!
echo   %C_BOLD%Last Commit      :%C_RESET% !_last_date!
echo.

echo %C_BOLD%%C_CYAN%Top Contributors:%C_RESET%
git shortlog -sn --no-merges HEAD 2>nul | head -10 2>nul
git shortlog -sn --no-merges HEAD 2>nul

echo.
echo %C_BOLD%%C_CYAN%File Type Breakdown:%C_RESET%
git ls-files 2>nul | for /f "tokens=* delims=." %%e in ('git ls-files 2^>nul') do echo %%~xe | sort | uniq -c 2>nul
:: Windows-friendly fallback:
git ls-files 2>nul

call :CacheWrite "STATS: repository stats viewed"
exit /b 0

:: ── gitsync whoami ────────────────────────────────────────
:WhoAmI
echo.
echo %C_BOLD%%C_BLUE%[ GIT IDENTITY ]%C_RESET%
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
for /f "delims=" %%n in ('git config --global user.name 2^>nul') do set "_gname=%%n"
for /f "delims=" %%e in ('git config --global user.email 2^>nul') do set "_gemail=%%e"
for /f "delims=" %%e in ('git config --global core.editor 2^>nul') do set "_geditor=%%e"

echo   %C_BOLD%Name    :%C_RESET% !_gname!
echo   %C_BOLD%Email   :%C_RESET% !_gemail!
echo   %C_BOLD%Editor  :%C_RESET% !_geditor!
echo   %C_BOLD%Git Ver :%C_RESET% %GIT_VERSION%
echo.
exit /b 0

:: ── gitsync version ───────────────────────────────────────
:ShowVersion
echo.
echo   %C_BOLD%%C_CYAN%%SCRIPT_NAME%  v%SCRIPT_VERSION%%C_RESET%
echo   Git installed: %GIT_VERSION%
echo   Running on: %COMPUTERNAME% / %USERNAME%
echo.
exit /b 0

:: ── gitsync clearhistory ──────────────────────────────────
:ClearHistory
echo.
call :PrintWarning "This will delete all local GitSync action history."
set /p "_ch=Confirm? (y/n): "
if /i not "!_ch!"=="y" (
    call :PrintInfo "Cancelled."
    exit /b 0
)
del /q "%CACHE_FILE%" >nul 2>&1
call :EnsureCacheFile
call :PrintSuccess "History cleared."
exit /b 0

:: ── gitsync archive ───────────────────────────────────────
:ArchiveRepo
call :RequireRepo
echo.
set "_arcname=%cd%"
for %%f in ("!_arcname!") do set "_arcname=%%~nxf"
set "_arcfile=!_arcname!_%date:~-4%%date:~3,2%%date:~0,2%.zip"
set "_arcfile=!_arcfile:/=-!"
set "_arcfile=!_arcfile: =-!"

call :PrintStep "Creating archive: !_arcfile!"

:: Use PowerShell for zipping (available Windows 8+)
powershell -NoProfile -Command "Compress-Archive -Path '.' -DestinationPath '!_arcfile!' -Force" >nul 2>&1
if errorlevel 1 (
    call :PrintError "Archive failed. Ensure PowerShell is available."
    exit /b 1
)
call :PrintSuccess "Archive created: !_arcfile!"
call :CacheWrite "ARCHIVE: !_arcfile! created"
exit /b 0

:: ── gitsync sync (full pull + commit + push) ──────────────
:FullSync
call :RequireRepo
call :PrintBanner
echo.
call :PrintSection "FULL SYNC — Pull, Commit, Push"
echo.
call :PrintStep "Pulling latest..."
git pull --rebase origin >nul 2>&1
if errorlevel 1 (
    call :PrintWarning "Pull had issues. Continuing with local commit..."
)
call :LocalCommitFlow
call :RemotePushFlow
call :PrintSuccess "Full sync complete."
call :CacheWrite "FULL SYNC: completed"
exit /b 0

:: ============================================================
::  SECTION 4 — BRANCH MANAGEMENT
:: ============================================================
:BranchMenu
call :RequireRepo
cls
echo.
echo %C_BOLD%%C_MAGENTA%%DIVIDER%%C_RESET%
echo %C_BOLD%%C_MAGENTA%                  BRANCH MANAGER%C_RESET%
echo %C_BOLD%%C_MAGENTA%%DIVIDER%%C_RESET%
echo.
echo   %C_BOLD%Current branch:%C_RESET%
for /f %%b in ('git branch --show-current 2^>nul') do echo     %C_GREEN%%%b%C_RESET%
echo.
echo   %C_BOLD%Local branches:%C_RESET%
git branch --color
echo.
echo   %C_BOLD%Remote branches:%C_RESET%
git branch -r --color
echo.
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
echo  [1] Create new branch
echo  [2] Switch to branch
echo  [3] Rename branch
echo  [4] Delete branch (local)
echo  [5] Delete branch (remote)
echo  [6] Merge branch into current
echo  [7] Push branch to remote
echo  [8] Track remote branch
echo  [9] Compare two branches
echo  [0] Back / Exit
echo %C_DIM%%THIN_DIVIDER%%C_RESET%

if not "%ARG2%"=="" (
    :: If argument passed, do quick operation
    set "_subcmd=%ARG2%"
    if /i "!_subcmd!"=="create"   goto :BranchCreate
    if /i "!_subcmd!"=="switch"   goto :BranchSwitch
    if /i "!_subcmd!"=="delete"   goto :BranchDelete
    if /i "!_subcmd!"=="merge"    goto :BranchMerge
    if /i "!_subcmd!"=="push"     goto :BranchPush
)

set /p "_bchoice=Choose option: "
if "!_bchoice!"=="1" goto :BranchCreate
if "!_bchoice!"=="2" goto :BranchSwitch
if "!_bchoice!"=="3" goto :BranchRename
if "!_bchoice!"=="4" goto :BranchDelete
if "!_bchoice!"=="5" goto :BranchDeleteRemote
if "!_bchoice!"=="6" goto :BranchMerge
if "!_bchoice!"=="7" goto :BranchPush
if "!_bchoice!"=="8" goto :BranchTrack
if "!_bchoice!"=="9" goto :BranchCompare
if "!_bchoice!"=="0" exit /b 0
call :PrintWarning "Invalid option."
exit /b 0

:BranchCreate
echo.
set /p "_newbr=New branch name: "
if "!_newbr!"=="" (
    call :PrintError "Branch name cannot be empty."
    exit /b 1
)
:: Validate name (no spaces, special chars)
echo !_newbr! | findstr /r "[^a-zA-Z0-9_/.-]" >nul 2>&1
if not errorlevel 1 (
    call :PrintWarning "Branch name contains special characters. Proceed with caution."
)
set /p "_from=Base branch (blank = current): "
if "!_from!"=="" (
    git checkout -b "!_newbr!"
) else (
    git checkout -b "!_newbr!" "!_from!"
)
if errorlevel 1 (
    call :PrintError "Failed to create branch '!_newbr!'."
    exit /b 1
)
call :PrintSuccess "Branch '!_newbr!' created and checked out."
call :CacheWrite "BRANCH CREATE: !_newbr!"
set /p "_pushbr=Push this branch to remote now? (y/n): "
if /i "!_pushbr!"=="y" (
    git push -u origin "!_newbr!"
    call :CacheWrite "BRANCH PUSH: !_newbr! pushed to origin"
)
exit /b 0

:BranchSwitch
echo.
call :PrintStep "Available branches:"
git branch -a --color
echo.
set /p "_swbr=Branch to switch to: "
if "!_swbr!"=="" (
    call :PrintError "No branch name given."
    exit /b 1
)
git checkout "!_swbr!"
if errorlevel 1 (
    call :PrintWarning "Branch '!_swbr!' not found locally. Trying remote..."
    git checkout -b "!_swbr!" "origin/!_swbr!" 2>nul
    if errorlevel 1 (
        call :PrintError "Cannot switch to '!_swbr!'. Does it exist?"
        exit /b 1
    )
)
call :PrintSuccess "Switched to '!_swbr!'."
call :CacheWrite "BRANCH SWITCH: !_swbr!"
exit /b 0

:BranchRename
echo.
for /f %%b in ('git branch --show-current 2^>nul') do set "_currbr=%%b"
call :PrintInfo "Current branch: !_currbr!"
set /p "_oldbr=Branch to rename (blank = current '!_currbr!'): "
if "!_oldbr!"=="" set "_oldbr=!_currbr!"
set /p "_rnewbr=New name: "
if "!_rnewbr!"=="" (
    call :PrintError "New name cannot be empty."
    exit /b 1
)
git branch -m "!_oldbr!" "!_rnewbr!"
if errorlevel 1 (
    call :PrintError "Rename failed."
    exit /b 1
)
call :PrintSuccess "Branch renamed: !_oldbr! → !_rnewbr!"
call :CacheWrite "BRANCH RENAME: !_oldbr! to !_rnewbr!"
exit /b 0

:BranchDelete
echo.
call :PrintStep "Local branches (except current):"
git branch --color
echo.
set /p "_delbr=Branch to delete (local): "
if "!_delbr!"=="" (
    call :PrintError "No branch name given."
    exit /b 1
)
for /f %%b in ('git branch --show-current 2^>nul') do set "_currbr=%%b"
if /i "!_delbr!"=="!_currbr!" (
    call :PrintError "Cannot delete the currently checked-out branch."
    exit /b 1
)
call :PrintWarning "Deleting local branch '!_delbr!'..."
git branch -d "!_delbr!"
if errorlevel 1 (
    call :PrintWarning "Branch not fully merged. Force delete?"
    set /p "_fdb=Force delete? (y/n): "
    if /i "!_fdb!"=="y" (
        git branch -D "!_delbr!"
        if errorlevel 1 (
            call :PrintError "Force delete failed."
            exit /b 1
        )
    ) else (
        call :PrintInfo "Delete cancelled."
        exit /b 0
    )
)
call :PrintSuccess "Branch '!_delbr!' deleted locally."
call :CacheWrite "BRANCH DELETE LOCAL: !_delbr!"
exit /b 0

:BranchDeleteRemote
echo.
call :PrintStep "Remote branches:"
git branch -r --color
echo.
set /p "_rdelbr=Remote branch to delete (e.g. feature/x): "
if "!_rdelbr!"=="" (
    call :PrintError "No branch name given."
    exit /b 1
)
call :PrintWarning "This will DELETE 'origin/!_rdelbr!' on the remote server!"
set /p "_confirmrd=Confirm? (y/n): "
if /i not "!_confirmrd!"=="y" (
    call :PrintInfo "Cancelled."
    exit /b 0
)
git push origin --delete "!_rdelbr!"
if errorlevel 1 (
    call :PrintError "Remote branch delete failed."
    exit /b 1
)
call :PrintSuccess "Remote branch 'origin/!_rdelbr!' deleted."
call :CacheWrite "BRANCH DELETE REMOTE: !_rdelbr!"
exit /b 0

:BranchMerge
echo.
for /f %%b in ('git branch --show-current 2^>nul') do set "_currbr=%%b"
call :PrintInfo "Merging INTO current branch: !_currbr!"
echo.
git branch --color
echo.
set /p "_mergesrc=Branch to merge FROM: "
if "!_mergesrc!"=="" (
    call :PrintError "No source branch given."
    exit /b 1
)
echo.
echo   [1] Regular merge (--no-ff)
echo   [2] Squash merge
echo   [3] Fast-forward only
set /p "_mtype=Merge type (1/2/3): "

if "!_mtype!"=="1" (
    git merge --no-ff "!_mergesrc!"
) else if "!_mtype!"=="2" (
    git merge --squash "!_mergesrc!"
    call :PrintInfo "Squash merge staged. Run 'gitsync' to commit."
) else if "!_mtype!"=="3" (
    git merge --ff-only "!_mergesrc!"
) else (
    git merge "!_mergesrc!"
)

if errorlevel 1 (
    call :PrintError "Merge failed! Check for conflicts with 'gitsync conflicts'."
    call :CacheWrite "MERGE FAILED: !_mergesrc! into !_currbr!"
    exit /b 1
)
call :PrintSuccess "Merged '!_mergesrc!' into '!_currbr!'."
call :CacheWrite "MERGE: !_mergesrc! into !_currbr!"
exit /b 0

:BranchPush
echo.
for /f %%b in ('git branch --show-current 2^>nul') do set "_pushbranch=%%b"
call :PrintInfo "Current branch: !_pushbranch!"
set /p "_overridebr=Branch to push (blank = current '!_pushbranch!'): "
if not "!_overridebr!"=="" set "_pushbranch=!_overridebr!"
git push -u origin "!_pushbranch!"
if errorlevel 1 (
    call :PrintError "Push failed."
    call :CacheWrite "BRANCH PUSH FAILED: !_pushbranch!"
    exit /b 1
)
call :PrintSuccess "Pushed '!_pushbranch!' to origin."
call :CacheWrite "BRANCH PUSH: !_pushbranch!"
exit /b 0

:BranchTrack
echo.
call :PrintStep "Remote branches:"
git branch -r --color
echo.
set /p "_trackbr=Remote branch to track locally (e.g. feature/x): "
if "!_trackbr!"=="" (
    call :PrintError "No branch given."
    exit /b 1
)
git checkout -b "!_trackbr!" "origin/!_trackbr!"
if errorlevel 1 (
    call :PrintError "Failed to track remote branch."
    exit /b 1
)
call :PrintSuccess "Now tracking 'origin/!_trackbr!' locally."
call :CacheWrite "BRANCH TRACK: !_trackbr!"
exit /b 0

:BranchCompare
echo.
git branch --color
echo.
set /p "_cmp1=First branch: "
set /p "_cmp2=Second branch: "
if "!_cmp1!"=="" (
    call :PrintError "First branch required."
    exit /b 1
)
if "!_cmp2!"=="" (
    call :PrintError "Second branch required."
    exit /b 1
)
echo.
echo %C_BOLD%%C_BLUE%[ COMMITS IN !_cmp1! NOT IN !_cmp2! ]%C_RESET%
git log "!_cmp2!..!_cmp1!" --oneline --graph --color
echo.
echo %C_BOLD%%C_BLUE%[ COMMITS IN !_cmp2! NOT IN !_cmp1! ]%C_RESET%
git log "!_cmp1!..!_cmp2!" --oneline --graph --color
echo.
echo %C_BOLD%%C_BLUE%[ FILE DIFF SUMMARY ]%C_RESET%
git diff --stat "!_cmp1!" "!_cmp2!"
call :CacheWrite "BRANCH COMPARE: !_cmp1! vs !_cmp2!"
exit /b 0

:: ============================================================
::  SECTION 5 — STASH MANAGEMENT
:: ============================================================
:StashMenu
call :RequireRepo
cls
echo.
echo %C_BOLD%%C_YELLOW%%DIVIDER%%C_RESET%
echo %C_BOLD%%C_YELLOW%                    STASH MANAGER%C_RESET%
echo %C_BOLD%%C_YELLOW%%DIVIDER%%C_RESET%
echo.
echo   %C_BOLD%Current stashes:%C_RESET%
git stash list
echo.
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
echo  [1] Stash current changes (save)
echo  [2] Pop latest stash (apply + drop)
echo  [3] Apply stash (keep it)
echo  [4] Drop a stash
echo  [5] Show stash contents
echo  [6] Clear ALL stashes
echo  [7] Create named stash
echo  [8] Apply stash to different branch
echo  [0] Back / Exit
echo %C_DIM%%THIN_DIVIDER%%C_RESET%

set /p "_schoice=Choose option: "
if "!_schoice!"=="1" goto :StashSave
if "!_schoice!"=="2" goto :StashPop
if "!_schoice!"=="3" goto :StashApply
if "!_schoice!"=="4" goto :StashDrop
if "!_schoice!"=="5" goto :StashShow
if "!_schoice!"=="6" goto :StashClearAll
if "!_schoice!"=="7" goto :StashNamed
if "!_schoice!"=="8" goto :StashToBranch
if "!_schoice!"=="0" exit /b 0
call :PrintWarning "Invalid option."
exit /b 0

:StashSave
echo.
git status --porcelain | find /c /v "" > nul
for /f %%x in ('git status --porcelain 2^>nul ^| find /c /v ""') do set /a _cnt=%%x
if !_cnt! EQU 0 (
    call :PrintInfo "Nothing to stash. Working tree is clean."
    exit /b 0
)
git stash push -u
if errorlevel 1 (
    call :PrintError "Stash failed."
    exit /b 1
)
call :PrintSuccess "Changes stashed."
call :CacheWrite "STASH SAVE: changes stashed"
exit /b 0

:StashPop
echo.
git stash list | find /c /v "" > nul 2>&1
for /f %%x in ('git stash list 2^>nul ^| find /c /v ""') do set /a _stcnt=%%x
if !_stcnt! EQU 0 (
    call :PrintInfo "No stashes to pop."
    exit /b 0
)
git stash pop
if errorlevel 1 (
    call :PrintError "Stash pop failed. Possible conflict."
    exit /b 1
)
call :PrintSuccess "Latest stash applied and removed."
call :CacheWrite "STASH POP: latest stash applied"
exit /b 0

:StashApply
echo.
git stash list
echo.
set /p "_stidx=Stash index (e.g. 0): "
if "!_stidx!"=="" set "_stidx=0"
git stash apply "stash@{!_stidx!}"
if errorlevel 1 (
    call :PrintError "Stash apply failed."
    exit /b 1
)
call :PrintSuccess "Stash stash@{!_stidx!} applied (still in list)."
call :CacheWrite "STASH APPLY: stash@{!_stidx!}"
exit /b 0

:StashDrop
echo.
git stash list
echo.
set /p "_stdi=Stash index to drop (e.g. 0): "
if "!_stdi!"=="" set "_stdi=0"
git stash drop "stash@{!_stdi!}"
if errorlevel 1 (
    call :PrintError "Stash drop failed."
    exit /b 1
)
call :PrintSuccess "Stash stash@{!_stdi!} dropped."
call :CacheWrite "STASH DROP: stash@{!_stdi!}"
exit /b 0

:StashShow
echo.
git stash list
echo.
set /p "_stsi=Stash index to show (e.g. 0): "
if "!_stsi!"=="" set "_stsi=0"
git stash show -p "stash@{!_stsi!}"
call :CacheWrite "STASH SHOW: stash@{!_stsi!}"
exit /b 0

:StashClearAll
echo.
call :PrintWarning "This will permanently delete ALL stashes!"
set /p "_cstall=Confirm clear all stashes? (y/n): "
if /i not "!_cstall!"=="y" (
    call :PrintInfo "Cancelled."
    exit /b 0
)
git stash clear
call :PrintSuccess "All stashes cleared."
call :CacheWrite "STASH CLEAR ALL"
exit /b 0

:StashNamed
echo.
set /p "_stname=Stash name/message: "
if "!_stname!"=="" set "_stname=Manual stash %date% %time:~0,8%"
git stash push -u -m "!_stname!"
if errorlevel 1 (
    call :PrintError "Stash failed."
    exit /b 1
)
call :PrintSuccess "Named stash created: !_stname!"
call :CacheWrite "STASH NAMED: !_stname!"
exit /b 0

:StashToBranch
echo.
git stash list
echo.
set /p "_stbi=Stash index: "
if "!_stbi!"=="" set "_stbi=0"
set /p "_stbb=New branch name to apply it on: "
if "!_stbb!"=="" (
    call :PrintError "Branch name required."
    exit /b 1
)
git stash branch "!_stbb!" "stash@{!_stbi!}"
if errorlevel 1 (
    call :PrintError "Failed to create branch from stash."
    exit /b 1
)
call :PrintSuccess "Stash applied to new branch '!_stbb!'."
call :CacheWrite "STASH TO BRANCH: !_stbb! from stash@{!_stbi!}"
exit /b 0

:: ============================================================
::  SECTION 6 — TAG MANAGEMENT
:: ============================================================
:TagMenu
call :RequireRepo
cls
echo.
echo %C_BOLD%%C_GREEN%%DIVIDER%%C_RESET%
echo %C_BOLD%%C_GREEN%                     TAG MANAGER%C_RESET%
echo %C_BOLD%%C_GREEN%%DIVIDER%%C_RESET%
echo.
echo   %C_BOLD%Existing tags:%C_RESET%
git tag --sort=-version:refname | head -20 2>nul
git tag --sort=-version:refname
echo.
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
echo  [1] Create lightweight tag
echo  [2] Create annotated tag (with message)
echo  [3] Create tag on a specific commit
echo  [4] Delete local tag
echo  [5] Delete remote tag
echo  [6] Push tags to remote
echo  [7] Push single tag
echo  [8] Show tag details
echo  [9] List all tags with dates
echo  [0] Back / Exit
echo %C_DIM%%THIN_DIVIDER%%C_RESET%

set /p "_tchoice=Choose option: "
if "!_tchoice!"=="1" goto :TagLightweight
if "!_tchoice!"=="2" goto :TagAnnotated
if "!_tchoice!"=="3" goto :TagOnCommit
if "!_tchoice!"=="4" goto :TagDeleteLocal
if "!_tchoice!"=="5" goto :TagDeleteRemote
if "!_tchoice!"=="6" goto :TagPushAll
if "!_tchoice!"=="7" goto :TagPushSingle
if "!_tchoice!"=="8" goto :TagShow
if "!_tchoice!"=="9" goto :TagList
if "!_tchoice!"=="0" exit /b 0
call :PrintWarning "Invalid option."
exit /b 0

:TagLightweight
echo.
set /p "_tagname=Tag name (e.g. v1.0.0): "
if "!_tagname!"=="" (
    call :PrintError "Tag name required."
    exit /b 1
)
git tag "!_tagname!"
if errorlevel 1 (
    call :PrintError "Tag creation failed. Tag may already exist."
    exit /b 1
)
call :PrintSuccess "Lightweight tag '!_tagname!' created."
call :CacheWrite "TAG CREATE LIGHTWEIGHT: !_tagname!"
exit /b 0

:TagAnnotated
echo.
set /p "_atagname=Tag name (e.g. v1.0.0): "
if "!_atagname!"=="" (
    call :PrintError "Tag name required."
    exit /b 1
)
set /p "_atagmsg=Tag message: "
if "!_atagmsg!"=="" set "_atagmsg=Release !_atagname!"
git tag -a "!_atagname!" -m "!_atagmsg!"
if errorlevel 1 (
    call :PrintError "Annotated tag creation failed."
    exit /b 1
)
call :PrintSuccess "Annotated tag '!_atagname!' created."
call :CacheWrite "TAG CREATE ANNOTATED: !_atagname! — !_atagmsg!"
exit /b 0

:TagOnCommit
echo.
call :PrintStep "Recent commits:"
git log --oneline -10
echo.
set /p "_tcsha=Commit hash to tag: "
if "!_tcsha!"=="" (
    call :PrintError "Commit hash required."
    exit /b 1
)
set /p "_tcname=Tag name: "
if "!_tcname!"=="" (
    call :PrintError "Tag name required."
    exit /b 1
)
set /p "_tcmsg=Tag message (blank = lightweight): "
if "!_tcmsg!"=="" (
    git tag "!_tcname!" "!_tcsha!"
) else (
    git tag -a "!_tcname!" "!_tcsha!" -m "!_tcmsg!"
)
if errorlevel 1 (
    call :PrintError "Tag on commit failed."
    exit /b 1
)
call :PrintSuccess "Tag '!_tcname!' created on commit !_tcsha!."
call :CacheWrite "TAG ON COMMIT: !_tcname! @ !_tcsha!"
exit /b 0

:TagDeleteLocal
echo.
git tag
echo.
set /p "_dtag=Tag to delete locally: "
if "!_dtag!"=="" (
    call :PrintError "Tag name required."
    exit /b 1
)
git tag -d "!_dtag!"
if errorlevel 1 (
    call :PrintError "Delete failed. Tag may not exist."
    exit /b 1
)
call :PrintSuccess "Tag '!_dtag!' deleted locally."
call :CacheWrite "TAG DELETE LOCAL: !_dtag!"
exit /b 0

:TagDeleteRemote
echo.
set /p "_rdtag=Remote tag to delete: "
if "!_rdtag!"=="" (
    call :PrintError "Tag name required."
    exit /b 1
)
call :PrintWarning "Deleting remote tag 'origin/!_rdtag!'..."
git push origin --delete "!_rdtag!"
if errorlevel 1 (
    call :PrintError "Remote tag delete failed."
    exit /b 1
)
call :PrintSuccess "Remote tag '!_rdtag!' deleted."
call :CacheWrite "TAG DELETE REMOTE: !_rdtag!"
exit /b 0

:TagPushAll
echo.
call :PrintStep "Pushing all local tags to origin..."
git push origin --tags
if errorlevel 1 (
    call :PrintError "Tag push failed."
    exit /b 1
)
call :PrintSuccess "All tags pushed to origin."
call :CacheWrite "TAG PUSH ALL"
exit /b 0

:TagPushSingle
echo.
git tag
echo.
set /p "_sptag=Tag to push: "
if "!_sptag!"=="" (
    call :PrintError "Tag name required."
    exit /b 1
)
git push origin "!_sptag!"
if errorlevel 1 (
    call :PrintError "Tag push failed."
    exit /b 1
)
call :PrintSuccess "Tag '!_sptag!' pushed."
call :CacheWrite "TAG PUSH SINGLE: !_sptag!"
exit /b 0

:TagShow
echo.
git tag
echo.
set /p "_showtag=Tag to inspect: "
if "!_showtag!"=="" (
    call :PrintError "Tag name required."
    exit /b 1
)
git show "!_showtag!"
call :CacheWrite "TAG SHOW: !_showtag!"
exit /b 0

:TagList
echo.
echo %C_BOLD%%C_GREEN%[ ALL TAGS WITH CREATION DATE ]%C_RESET%
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
git log --tags --simplify-by-decoration --pretty="format:%%d  %%ai" 2>nul
echo.
call :CacheWrite "TAG LIST: all tags viewed"
exit /b 0

:: ============================================================
::  SECTION 7 — REMOTE MANAGEMENT
:: ============================================================
:RemoteMenu
call :RequireRepo
cls
echo.
echo %C_BOLD%%C_BLUE%%DIVIDER%%C_RESET%
echo %C_BOLD%%C_BLUE%                   REMOTE MANAGER%C_RESET%
echo %C_BOLD%%C_BLUE%%DIVIDER%%C_RESET%
echo.
echo   %C_BOLD%Configured remotes:%C_RESET%
git remote -v
echo.
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
echo  [1] Add remote
echo  [2] Remove remote
echo  [3] Rename remote
echo  [4] Change remote URL
echo  [5] Show remote details
echo  [6] Fetch from remote
echo  [7] Prune stale remote branches
echo  [0] Back / Exit
echo %C_DIM%%THIN_DIVIDER%%C_RESET%

set /p "_rmchoice=Choose option: "
if "!_rmchoice!"=="1" goto :RemoteAdd
if "!_rmchoice!"=="2" goto :RemoteRemove
if "!_rmchoice!"=="3" goto :RemoteRename
if "!_rmchoice!"=="4" goto :RemoteChangeUrl
if "!_rmchoice!"=="5" goto :RemoteShow
if "!_rmchoice!"=="6" goto :QuickFetch
if "!_rmchoice!"=="7" goto :PruneBranches
if "!_rmchoice!"=="0" exit /b 0
call :PrintWarning "Invalid option."
exit /b 0

:RemoteAdd
echo.
set /p "_rname=Remote name (e.g. origin, upstream): "
if "!_rname!"=="" (
    call :PrintError "Remote name required."
    exit /b 1
)
set /p "_rurl=Remote URL: "
if "!_rurl!"=="" (
    call :PrintError "URL required."
    exit /b 1
)
git remote add "!_rname!" "!_rurl!"
if errorlevel 1 (
    call :PrintError "Failed to add remote '!_rname!'."
    exit /b 1
)
call :PrintSuccess "Remote '!_rname!' added: !_rurl!"
call :CacheWrite "REMOTE ADD: !_rname! → !_rurl!"
exit /b 0

:RemoteRemove
echo.
git remote -v
echo.
set /p "_rmdel=Remote to remove: "
if "!_rmdel!"=="" (
    call :PrintError "Remote name required."
    exit /b 1
)
git remote remove "!_rmdel!"
if errorlevel 1 (
    call :PrintError "Remove failed."
    exit /b 1
)
call :PrintSuccess "Remote '!_rmdel!' removed."
call :CacheWrite "REMOTE REMOVE: !_rmdel!"
exit /b 0

:RemoteRename
echo.
git remote -v
echo.
set /p "_rold=Old remote name: "
set /p "_rnew=New remote name: "
if "!_rold!"=="" (
    call :PrintError "Old name required."
    exit /b 1
)
if "!_rnew!"=="" (
    call :PrintError "New name required."
    exit /b 1
)
git remote rename "!_rold!" "!_rnew!"
if errorlevel 1 (
    call :PrintError "Rename failed."
    exit /b 1
)
call :PrintSuccess "Remote renamed: !_rold! → !_rnew!"
call :CacheWrite "REMOTE RENAME: !_rold! to !_rnew!"
exit /b 0

:RemoteChangeUrl
echo.
git remote -v
echo.
set /p "_rcu_name=Remote to update: "
if "!_rcu_name!"=="" (
    call :PrintError "Remote name required."
    exit /b 1
)
set /p "_rcu_url=New URL: "
if "!_rcu_url!"=="" (
    call :PrintError "URL required."
    exit /b 1
)
git remote set-url "!_rcu_name!" "!_rcu_url!"
if errorlevel 1 (
    call :PrintError "URL update failed."
    exit /b 1
)
call :PrintSuccess "Remote '!_rcu_name!' URL updated: !_rcu_url!"
call :CacheWrite "REMOTE URL CHANGE: !_rcu_name! → !_rcu_url!"
exit /b 0

:RemoteShow
echo.
git remote -v
echo.
set /p "_rsname=Remote to inspect (blank = origin): "
if "!_rsname!"=="" set "_rsname=origin"
git remote show "!_rsname!"
call :CacheWrite "REMOTE SHOW: !_rsname!"
exit /b 0

:: ============================================================
::  SECTION 8 — RESET MANAGEMENT
:: ============================================================
:ResetMenu
call :RequireRepo
cls
echo.
echo %C_BOLD%%C_RED%%DIVIDER%%C_RESET%
echo %C_BOLD%%C_RED%                    RESET MANAGER%C_RESET%
echo %C_BOLD%%C_RED%  WARNING: Some resets are IRREVERSIBLE!%C_RESET%
echo %C_BOLD%%C_RED%%DIVIDER%%C_RESET%
echo.
echo   %C_BOLD%Recent commits:%C_RESET%
git log --oneline -8
echo.
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
echo  [1] Soft reset   — undo commits, keep changes STAGED
echo  [2] Mixed reset  — undo commits, keep changes UNSTAGED (default)
echo  [3] Hard reset   — undo commits + DISCARD all changes (DANGER)
echo  [4] Reset single file to HEAD
echo  [5] Reset to a specific commit hash
echo  [6] Revert a commit (safe, creates new commit)
echo  [0] Back / Exit
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
echo.
call :PrintWarning "Hard reset (option 3) will permanently lose uncommitted work!"
echo.

set /p "_rschoice=Choose option: "
if "!_rschoice!"=="1" goto :ResetSoft
if "!_rschoice!"=="2" goto :ResetMixed
if "!_rschoice!"=="3" goto :ResetHard
if "!_rschoice!"=="4" goto :ResetFile
if "!_rschoice!"=="5" goto :ResetToHash
if "!_rschoice!"=="6" goto :RevertCommit
if "!_rschoice!"=="0" exit /b 0
call :PrintWarning "Invalid option."
exit /b 0

:ResetSoft
echo.
set /p "_srn=How many commits back? (e.g. 1): "
if "!_srn!"=="" set "_srn=1"
git reset HEAD~!_srn! --soft
if errorlevel 1 (
    call :PrintError "Soft reset failed."
    exit /b 1
)
call :PrintSuccess "Soft reset !_srn! commit(s). Files still staged."
call :CacheWrite "RESET SOFT: ~!_srn!"
exit /b 0

:ResetMixed
echo.
set /p "_mrn=How many commits back? (e.g. 1): "
if "!_mrn!"=="" set "_mrn=1"
git reset HEAD~!_mrn!
if errorlevel 1 (
    call :PrintError "Mixed reset failed."
    exit /b 1
)
call :PrintSuccess "Mixed reset !_mrn! commit(s). Files unstaged."
call :CacheWrite "RESET MIXED: ~!_mrn!"
exit /b 0

:ResetHard
echo.
call :PrintWarning "HARD RESET will PERMANENTLY delete uncommitted changes!"
set /p "_hrn=Commits back (e.g. 1): "
if "!_hrn!"=="" set "_hrn=1"
set /p "_hrc=Type 'CONFIRM' to proceed: "
if not "!_hrc!"=="CONFIRM" (
    call :PrintInfo "Hard reset cancelled."
    exit /b 0
)
git reset HEAD~!_hrn! --hard
if errorlevel 1 (
    call :PrintError "Hard reset failed."
    exit /b 1
)
call :PrintSuccess "Hard reset !_hrn! commit(s). Changes discarded."
call :CacheWrite "RESET HARD: ~!_hrn!"
exit /b 0

:ResetFile
echo.
git status -s
echo.
set /p "_rfile=File to reset to HEAD: "
if "!_rfile!"=="" (
    call :PrintError "Filename required."
    exit /b 1
)
git checkout HEAD -- "!_rfile!"
if errorlevel 1 (
    call :PrintError "File reset failed."
    exit /b 1
)
call :PrintSuccess "File '!_rfile!' reset to HEAD."
call :CacheWrite "RESET FILE: !_rfile!"
exit /b 0

:ResetToHash
echo.
git log --oneline -10
echo.
set /p "_rhash=Target commit hash: "
if "!_rhash!"=="" (
    call :PrintError "Hash required."
    exit /b 1
)
echo  [1] Soft  [2] Mixed  [3] Hard
set /p "_rhtype=Reset type (1/2/3): "
if "!_rhtype!"=="1" (
    git reset --soft "!_rhash!"
) else if "!_rhtype!"=="3" (
    set /p "_rhhard_confirm=Type 'CONFIRM' for hard reset to !_rhash!: "
    if not "!_rhhard_confirm!"=="CONFIRM" (
        call :PrintInfo "Cancelled."
        exit /b 0
    )
    git reset --hard "!_rhash!"
) else (
    git reset "!_rhash!"
)
if errorlevel 1 (
    call :PrintError "Reset to hash failed."
    exit /b 1
)
call :PrintSuccess "Reset to !_rhash! complete."
call :CacheWrite "RESET TO HASH: !_rhash!"
exit /b 0

:RevertCommit
echo.
git log --oneline -10
echo.
set /p "_revcmt=Commit hash to revert: "
if "!_revcmt!"=="" (
    call :PrintError "Hash required."
    exit /b 1
)
git revert --no-edit "!_revcmt!"
if errorlevel 1 (
    call :PrintError "Revert failed. Possible conflicts."
    exit /b 1
)
call :PrintSuccess "Commit '!_revcmt!' reverted safely (new commit created)."
call :CacheWrite "REVERT COMMIT: !_revcmt!"
exit /b 0

:: ============================================================
::  SECTION 9 — CHERRY-PICK
:: ============================================================
:CherryPickMenu
call :RequireRepo
echo.
echo %C_BOLD%%C_CYAN%[ CHERRY-PICK ]%C_RESET%
echo.
git log --oneline --all -15
echo.
set /p "_cpcommit=Commit hash to cherry-pick: "
if "!_cpcommit!"=="" (
    call :PrintError "Commit hash required."
    exit /b 1
)
echo.
echo  [1] Cherry-pick (commit immediately)
echo  [2] Cherry-pick --no-commit (stage only)
set /p "_cptype=Option (1/2): "

if "!_cptype!"=="2" (
    git cherry-pick --no-commit "!_cpcommit!"
) else (
    git cherry-pick "!_cpcommit!"
)
if errorlevel 1 (
    call :PrintError "Cherry-pick failed. Conflicts may exist."
    call :PrintInfo  "Resolve conflicts, then run: git cherry-pick --continue"
    call :CacheWrite "CHERRY-PICK FAILED: !_cpcommit!"
    exit /b 1
)
call :PrintSuccess "Cherry-pick of '!_cpcommit!' successful."
call :CacheWrite "CHERRY-PICK: !_cpcommit!"
exit /b 0

:: ============================================================
::  SECTION 10 — REBASE
:: ============================================================
:RebaseMenu
call :RequireRepo
cls
echo.
echo %C_BOLD%%C_YELLOW%%DIVIDER%%C_RESET%
echo %C_BOLD%%C_YELLOW%                    REBASE MANAGER%C_RESET%
echo %C_BOLD%%C_YELLOW%%DIVIDER%%C_RESET%
echo.
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
echo  [1] Rebase current branch onto another
echo  [2] Interactive rebase (last N commits)
echo  [3] Continue rebase (after resolving conflicts)
echo  [4] Abort rebase
echo  [5] Skip current commit during rebase
echo  [0] Back / Exit
echo %C_DIM%%THIN_DIVIDER%%C_RESET%

set /p "_rbchoice=Choose option: "
if "!_rbchoice!"=="1" goto :RebaseOnto
if "!_rbchoice!"=="2" goto :RebaseInteractive
if "!_rbchoice!"=="3" (git rebase --continue & call :CacheWrite "REBASE CONTINUE" & exit /b 0)
if "!_rbchoice!"=="4" (git rebase --abort & call :PrintInfo "Rebase aborted." & call :CacheWrite "REBASE ABORT" & exit /b 0)
if "!_rbchoice!"=="5" (git rebase --skip & call :CacheWrite "REBASE SKIP" & exit /b 0)
if "!_rbchoice!"=="0" exit /b 0
call :PrintWarning "Invalid option."
exit /b 0

:RebaseOnto
echo.
for /f %%b in ('git branch --show-current 2^>nul') do set "_rbbranch=%%b"
call :PrintInfo "Current branch: !_rbbranch!"
git branch --color
echo.
set /p "_rbbase=Rebase onto branch: "
if "!_rbbase!"=="" (
    call :PrintError "Target branch required."
    exit /b 1
)
call :PrintWarning "This rewrites commit history. Only do this on private branches!"
set /p "_rbconfirm=Proceed? (y/n): "
if /i not "!_rbconfirm!"=="y" (
    call :PrintInfo "Rebase cancelled."
    exit /b 0
)
git rebase "!_rbbase!"
if errorlevel 1 (
    call :PrintError "Rebase failed. Conflicts detected."
    call :PrintInfo  "Resolve conflicts, then run: gitsync rebase → [3] Continue"
    call :CacheWrite "REBASE FAILED: !_rbbranch! onto !_rbbase!"
    exit /b 1
)
call :PrintSuccess "Rebase complete: !_rbbranch! onto !_rbbase!"
call :CacheWrite "REBASE: !_rbbranch! onto !_rbbase!"
exit /b 0

:RebaseInteractive
echo.
set /p "_rbn=How many commits to interactively edit? (e.g. 3): "
if "!_rbn!"=="" set "_rbn=3"
call :PrintInfo "Opening interactive rebase for last !_rbn! commits..."
call :PrintInfo "In the editor: pick/squash/reword/drop/edit each commit."
git rebase -i "HEAD~!_rbn!"
if errorlevel 1 (
    call :PrintWarning "Interactive rebase closed with error or was aborted."
) else (
    call :PrintSuccess "Interactive rebase complete."
)
call :CacheWrite "INTERACTIVE REBASE: HEAD~!_rbn!"
exit /b 0

:: ============================================================
::  SECTION 11 — CONFLICT HELPER
:: ============================================================
:ConflictHelper
call :RequireRepo
echo.
echo %C_BOLD%%C_RED%%DIVIDER%%C_RESET%
echo %C_BOLD%%C_RED%                 CONFLICT HELPER%C_RESET%
echo %C_BOLD%%C_RED%%DIVIDER%%C_RESET%
echo.

:: Check if we're actually in a conflict state
git status | findstr "conflict\|Unmerged" >nul 2>&1
if errorlevel 1 (
    call :PrintSuccess "No merge conflicts detected!"
    git status
    exit /b 0
)

echo %C_BOLD%%C_RED%Conflicted files:%C_RESET%
git diff --name-only --diff-filter=U
echo.
echo %C_BOLD%What to do:%C_RESET%
echo.
echo  1. Open each conflicted file and look for:
echo       %C_RED%^<^<^<^<^<^<^< HEAD      (your changes)%C_RESET%
echo       %C_YELLOW%======= (separator)%C_RESET%
echo       %C_GREEN%^>^>^>^>^>^>^> branch   (incoming changes)%C_RESET%
echo.
echo  2. Decide which changes to keep (or combine them).
echo  3. Remove the conflict markers.
echo  4. Stage the resolved files and commit.
echo.
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
echo  [1] Mark all conflicts as resolved (add .) then continue
echo  [2] Abort the merge
echo  [3] Show conflicted file list again
echo  [4] Open a specific file in default editor
echo  [0] Exit
echo %C_DIM%%THIN_DIVIDER%%C_RESET%

set /p "_cchoice=Choose option: "
if "!_cchoice!"=="1" (
    git add .
    git commit --no-edit
    if errorlevel 1 (
        call :PrintWarning "Commit failed. Conflicts may still exist."
    ) else (
        call :PrintSuccess "Merge commit created. Conflicts resolved."
        call :CacheWrite "CONFLICT RESOLVED: merge committed"
    )
)
if "!_cchoice!"=="2" (
    git merge --abort
    call :PrintSuccess "Merge aborted. Repository restored to pre-merge state."
    call :CacheWrite "MERGE ABORT"
)
if "!_cchoice!"=="3" (
    git diff --name-only --diff-filter=U
)
if "!_cchoice!"=="4" (
    set /p "_cfile=File to open: "
    start "" "!_cfile!"
)
exit /b 0

:: ============================================================
::  SECTION 12 — .GITIGNORE MANAGER
:: ============================================================
:GitIgnoreMenu
cls
echo.
echo %C_BOLD%%C_CYAN%%DIVIDER%%C_RESET%
echo %C_BOLD%%C_CYAN%                .GITIGNORE MANAGER%C_RESET%
echo %C_BOLD%%C_CYAN%%DIVIDER%%C_RESET%
echo.
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
echo  [1] View current .gitignore
echo  [2] Add a pattern to .gitignore
echo  [3] Check if file/pattern is ignored
echo  [4] Generate language-specific template
echo  [5] Open .gitignore in default editor
echo  [6] Add standard security entries (secrets, keys)
echo  [7] Remove a file from tracking (and add to .gitignore)
echo  [0] Back / Exit
echo %C_DIM%%THIN_DIVIDER%%C_RESET%

set /p "_gichoice=Choose option: "
if "!_gichoice!"=="1" goto :GitIgnoreView
if "!_gichoice!"=="2" goto :GitIgnoreAdd
if "!_gichoice!"=="3" goto :GitIgnoreCheck
if "!_gichoice!"=="4" goto :GitIgnoreTemplate
if "!_gichoice!"=="5" (start "" .gitignore & exit /b 0)
if "!_gichoice!"=="6" goto :GitIgnoreSecurity
if "!_gichoice!"=="7" goto :GitIgnoreUntrack
if "!_gichoice!"=="0" exit /b 0
call :PrintWarning "Invalid option."
exit /b 0

:GitIgnoreView
echo.
if not exist .gitignore (
    call :PrintWarning ".gitignore not found."
    exit /b 0
)
echo %C_BOLD%%C_CYAN%[ CURRENT .GITIGNORE ]%C_RESET%
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
type .gitignore
echo.
call :CacheWrite "GITIGNORE VIEW"
exit /b 0

:GitIgnoreAdd
echo.
set /p "_gipat=Pattern to add (e.g. *.log or /dist/): "
if "!_gipat!"=="" (
    call :PrintError "Pattern required."
    exit /b 1
)
if not exist .gitignore type nul > .gitignore
echo !_gipat!>> .gitignore
call :PrintSuccess "Added '!_gipat!' to .gitignore"
call :CacheWrite "GITIGNORE ADD: !_gipat!"
exit /b 0

:GitIgnoreCheck
echo.
set /p "_gicheck=File or pattern to check: "
if "!_gicheck!"=="" (
    call :PrintError "Input required."
    exit /b 1
)
git check-ignore -v "!_gicheck!"
if errorlevel 1 (
    call :PrintWarning "'!_gicheck!' is NOT ignored."
) else (
    call :PrintSuccess "'!_gicheck!' IS ignored."
)
call :CacheWrite "GITIGNORE CHECK: !_gicheck!"
exit /b 0

:GitIgnoreTemplate
echo.
echo  Available templates:
echo  [1] Node.js / JavaScript
echo  [2] Python
echo  [3] Java / Maven
echo  [4] C / C++
echo  [5] .NET / C#
echo  [6] PHP
echo  [7] Go
echo  [8] Rust
echo  [9] Ruby / Rails
echo  [A] Android
echo  [B] Unity
echo  [0] Cancel
echo.
set /p "_tplchoice=Template: "
if "!_tplchoice!"=="0" exit /b 0

if not exist .gitignore (
    echo # .gitignore> .gitignore
)

if "!_tplchoice!"=="1" (
    >> .gitignore (
        echo.
        echo # --- Node.js ---
        echo node_modules/
        echo npm-debug.log*
        echo yarn-debug.log*
        echo yarn-error.log*
        echo .npm
        echo .env
        echo .env.local
        echo dist/
        echo build/
        echo .cache/
        echo *.tsbuildinfo
    )
    call :PrintSuccess "Node.js entries added."
)
if "!_tplchoice!"=="2" (
    >> .gitignore (
        echo.
        echo # --- Python ---
        echo __pycache__/
        echo *.py[cod]
        echo *.pyo
        echo *.pyd
        echo .Python
        echo env/
        echo venv/
        echo .venv/
        echo *.egg-info/
        echo dist/
        echo build/
        echo .pytest_cache/
        echo .mypy_cache/
        echo .hypothesis/
        echo *.so
        echo .tox/
    )
    call :PrintSuccess "Python entries added."
)
if "!_tplchoice!"=="3" (
    >> .gitignore (
        echo.
        echo # --- Java / Maven ---
        echo *.class
        echo *.jar
        echo *.war
        echo *.ear
        echo target/
        echo .mvn/
        echo pom.xml.tag
        echo pom.xml.releaseBackup
        echo *.iml
        echo .idea/
        echo .classpath
        echo .project
        echo .settings/
    )
    call :PrintSuccess "Java/Maven entries added."
)
if "!_tplchoice!"=="4" (
    >> .gitignore (
        echo.
        echo # --- C / C++ ---
        echo *.o
        echo *.a
        echo *.so
        echo *.out
        echo *.exe
        echo *.obj
        echo *.lib
        echo *.dll
        echo CMakeFiles/
        echo CMakeCache.txt
        echo cmake_install.cmake
        echo Makefile
        echo build/
    )
    call :PrintSuccess "C/C++ entries added."
)
if "!_tplchoice!"=="5" (
    >> .gitignore (
        echo.
        echo # --- .NET / C# ---
        echo bin/
        echo obj/
        echo .vs/
        echo *.user
        echo *.suo
        echo *.log
        echo [Pp]ackages/
        echo *.nupkg
        echo .nuget/
        echo project.lock.json
        echo *.userprefs
    )
    call :PrintSuccess ".NET/C# entries added."
)
if "!_tplchoice!"=="6" (
    >> .gitignore (
        echo.
        echo # --- PHP ---
        echo /vendor/
        echo composer.phar
        echo .env
        echo .phpunit.result.cache
        echo *.log
        echo /storage/*.key
        echo /public/storage
        echo /public/hot
    )
    call :PrintSuccess "PHP entries added."
)
if "!_tplchoice!"=="7" (
    >> .gitignore (
        echo.
        echo # --- Go ---
        echo *.exe
        echo *.test
        echo *.out
        echo /vendor/
        echo /bin/
        echo go.sum
    )
    call :PrintSuccess "Go entries added."
)
if "!_tplchoice!"=="8" (
    >> .gitignore (
        echo.
        echo # --- Rust ---
        echo /target/
        echo Cargo.lock
        echo **/*.rs.bk
        echo *.pdb
    )
    call :PrintSuccess "Rust entries added."
)
if "!_tplchoice!"=="9" (
    >> .gitignore (
        echo.
        echo # --- Ruby / Rails ---
        echo *.gem
        echo *.rbc
        echo /.bundle
        echo /vendor/bundle
        echo /log/
        echo /tmp/
        echo /db/*.sqlite3
        echo /public/system
        echo .secret
        echo config/secrets.yml
    )
    call :PrintSuccess "Ruby/Rails entries added."
)
if /i "!_tplchoice!"=="A" (
    >> .gitignore (
        echo.
        echo # --- Android ---
        echo *.apk
        echo *.ap_
        echo /build
        echo local.properties
        echo .gradle/
        echo *.class
        echo bin/
        echo gen/
        echo proguard/
        echo *.keystore
    )
    call :PrintSuccess "Android entries added."
)
if /i "!_tplchoice!"=="B" (
    >> .gitignore (
        echo.
        echo # --- Unity ---
        echo /[Ll]ibrary/
        echo /[Tt]emp/
        echo /[Oo]bj/
        echo /[Bb]uild/
        echo /[Bb]uilds/
        echo /[Ll]ogs/
        echo /[Uu]ser[Ss]ettings/
        echo *.pidb.meta
        echo *.pdb.meta
        echo /Assets/AssetStoreTools*
    )
    call :PrintSuccess "Unity entries added."
)
call :CacheWrite "GITIGNORE TEMPLATE ADDED: !_tplchoice!"
exit /b 0

:GitIgnoreSecurity
>> .gitignore (
    echo.
    echo # --- Security / Secrets (added by GitSync) ---
    echo .env
    echo .env.*
    echo !.env.example
    echo *.pem
    echo *.key
    echo *.p12
    echo *.pfx
    echo id_rsa
    echo id_ed25519
    echo *.secret
    echo secrets.json
    echo secrets.yml
    echo credentials.json
    echo serviceAccountKey.json
    echo firebase-adminsdk*.json
    echo google-services.json
    echo GoogleService-Info.plist
)
call :PrintSuccess "Security/secrets entries added to .gitignore."
call :CacheWrite "GITIGNORE SECURITY ENTRIES ADDED"
exit /b 0

:GitIgnoreUntrack
echo.
git status -s
echo.
set /p "_utfile=File to untrack (will be added to .gitignore): "
if "!_utfile!"=="" (
    call :PrintError "Filename required."
    exit /b 1
)
git rm --cached "!_utfile!"
if errorlevel 1 (
    call :PrintWarning "File may not be tracked."
) else (
    call :PrintSuccess "Removed '!_utfile!' from tracking."
)
echo !_utfile!>> .gitignore
call :PrintSuccess "Added '!_utfile!' to .gitignore"
call :CacheWrite "GITIGNORE UNTRACK: !_utfile!"
exit /b 0

:: ============================================================
::  SECTION 13 — CONFIG MENU
:: ============================================================
:ConfigMenu
cls
echo.
echo %C_BOLD%%C_WHITE%%DIVIDER%%C_RESET%
echo %C_BOLD%%C_WHITE%                 GIT CONFIG MANAGER%C_RESET%
echo %C_BOLD%%C_WHITE%%DIVIDER%%C_RESET%
echo.
echo %C_BOLD%Current global config:%C_RESET%
git config --global --list
echo.
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
echo  [1] Set user.name
echo  [2] Set user.email
echo  [3] Set default editor
echo  [4] Set default branch name
echo  [5] Enable/disable colored output
echo  [6] Set credential helper
echo  [7] Configure line endings (CRLF/LF)
echo  [8] View all local repo config
echo  [9] Edit global config in editor
echo  [A] Set commit signing (GPG)
echo  [B] Set HTTP proxy
echo  [C] Reset a specific config key
echo  [0] Back / Exit
echo %C_DIM%%THIN_DIVIDER%%C_RESET%

set /p "_cfchoice=Choose option: "
if "!_cfchoice!"=="1" (
    set /p "_cfn=New user.name: "
    git config --global user.name "!_cfn!"
    call :PrintSuccess "user.name set to: !_cfn!"
    call :CacheWrite "CONFIG: user.name = !_cfn!"
)
if "!_cfchoice!"=="2" (
    set /p "_cfe=New user.email: "
    git config --global user.email "!_cfe!"
    call :PrintSuccess "user.email set to: !_cfe!"
    call :CacheWrite "CONFIG: user.email = !_cfe!"
)
if "!_cfchoice!"=="3" (
    echo  Common editors: notepad, code, vim, nano, notepad++
    set /p "_cfedit=Editor command: "
    git config --global core.editor "!_cfedit!"
    call :PrintSuccess "Editor set to: !_cfedit!"
    call :CacheWrite "CONFIG: core.editor = !_cfedit!"
)
if "!_cfchoice!"=="4" (
    set /p "_cfdb=Default branch name (e.g. main): "
    git config --global init.defaultBranch "!_cfdb!"
    call :PrintSuccess "Default branch set to: !_cfdb!"
    call :CacheWrite "CONFIG: init.defaultBranch = !_cfdb!"
)
if "!_cfchoice!"=="5" (
    git config --global color.ui auto
    call :PrintSuccess "Color output set to auto."
    call :CacheWrite "CONFIG: color.ui = auto"
)
if "!_cfchoice!"=="6" (
    echo  Options: manager (Windows), osxkeychain (Mac), store (Linux)
    set /p "_cfcred=Credential helper: "
    git config --global credential.helper "!_cfcred!"
    call :PrintSuccess "Credential helper set to: !_cfcred!"
    call :CacheWrite "CONFIG: credential.helper = !_cfcred!"
)
if "!_cfchoice!"=="7" (
    echo  [1] Windows (CRLF)  [2] Unix/Mac (LF)  [3] Auto-detect
    set /p "_cfle=Choice: "
    if "!_cfle!"=="1" (git config --global core.autocrlf true)
    if "!_cfle!"=="2" (git config --global core.autocrlf input)
    if "!_cfle!"=="3" (git config --global core.autocrlf auto)
    call :PrintSuccess "Line ending setting updated."
    call :CacheWrite "CONFIG: autocrlf updated"
)
if "!_cfchoice!"=="8" (
    echo.
    echo %C_BOLD%Local repo config:%C_RESET%
    git config --local --list
)
if "!_cfchoice!"=="9" (
    git config --global --edit
)
if /i "!_cfchoice!"=="A" (
    set /p "_gpgkey=GPG Key ID: "
    git config --global user.signingkey "!_gpgkey!"
    git config --global commit.gpgsign true
    call :PrintSuccess "GPG signing configured."
    call :CacheWrite "CONFIG: GPG signing = !_gpgkey!"
)
if /i "!_cfchoice!"=="B" (
    set /p "_httpproxy=HTTP proxy URL (e.g. http://proxy:8080): "
    git config --global http.proxy "!_httpproxy!"
    call :PrintSuccess "HTTP proxy set."
    call :CacheWrite "CONFIG: http.proxy = !_httpproxy!"
)
if /i "!_cfchoice!"=="C" (
    set /p "_cfkey=Config key to reset (e.g. http.proxy): "
    git config --global --unset "!_cfkey!"
    call :PrintSuccess "Config key '!_cfkey!' removed."
    call :CacheWrite "CONFIG UNSET: !_cfkey!"
)
exit /b 0

:: ============================================================
::  SECTION 14 — BACKUP MANAGER
:: ============================================================
:BackupMenu
cls
echo.
echo %C_BOLD%%C_YELLOW%%DIVIDER%%C_RESET%
echo %C_BOLD%%C_YELLOW%                  BACKUP MANAGER%C_RESET%
echo %C_BOLD%%C_YELLOW%%DIVIDER%%C_RESET%
echo.
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
echo  [1] Create a local zip snapshot of this repo
echo  [2] Create git bundle (full repo portable backup)
echo  [3] View existing backups
echo  [4] Delete old backups
echo  [0] Back / Exit
echo %C_DIM%%THIN_DIVIDER%%C_RESET%

set /p "_bakchoice=Choose option: "
if "!_bakchoice!"=="1" goto :ArchiveRepo
if "!_bakchoice!"=="2" goto :GitBundle
if "!_bakchoice!"=="3" goto :BackupList
if "!_bakchoice!"=="4" goto :BackupDelete
if "!_bakchoice!"=="0" exit /b 0
call :PrintWarning "Invalid option."
exit /b 0

:GitBundle
call :RequireRepo
echo.
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"
set "_bunfile=%BACKUP_DIR%\repo_bundle_%date:~-4%%date:~3,2%%date:~0,2%.bundle"
set "_bunfile=!_bunfile: =0!"
call :PrintStep "Creating Git bundle: !_bunfile!"
git bundle create "!_bunfile!" --all
if errorlevel 1 (
    call :PrintError "Bundle creation failed."
    exit /b 1
)
call :PrintSuccess "Bundle created: !_bunfile!"
call :PrintInfo   "Restore with: git clone !_bunfile! <target_dir>"
call :CacheWrite "BACKUP BUNDLE: !_bunfile!"
exit /b 0

:BackupList
echo.
if not exist "%BACKUP_DIR%" (
    call :PrintWarning "No backups found (directory does not exist)."
    exit /b 0
)
echo %C_BOLD%%C_YELLOW%[ EXISTING BACKUPS ]%C_RESET%
dir /b "%BACKUP_DIR%"
echo.
call :CacheWrite "BACKUP LIST: viewed"
exit /b 0

:BackupDelete
echo.
if not exist "%BACKUP_DIR%" (
    call :PrintWarning "No backups directory found."
    exit /b 0
)
dir /b "%BACKUP_DIR%"
echo.
set /p "_delback=File to delete (blank = cancel): "
if "!_delback!"=="" (
    call :PrintInfo "Cancelled."
    exit /b 0
)
if not exist "%BACKUP_DIR%\!_delback!" (
    call :PrintError "File not found in backups."
    exit /b 1
)
del /q "%BACKUP_DIR%\!_delback!"
call :PrintSuccess "Backup '!_delback!' deleted."
call :CacheWrite "BACKUP DELETE: !_delback!"
exit /b 0

:: ============================================================
::  SECTION 15 — PRUNE BRANCHES
:: ============================================================
:PruneBranches
call :RequireRepo
echo.
call :PrintStep "Fetching remote info (prune)..."
git fetch --prune
echo.
call :PrintStep "Local branches that no longer have a remote tracking branch:"
git branch -vv | findstr ": gone]"
echo.
set /p "_prunelocal=Delete these orphaned local branches? (y/n): "
if /i not "!_prunelocal!"=="y" (
    call :PrintInfo "Skipping prune."
    exit /b 0
)
for /f "tokens=1" %%b in ('git branch -vv ^| findstr ": gone]"') do (
    echo Deleting: %%b
    git branch -D "%%b"
)
call :PrintSuccess "Orphaned branches pruned."
call :CacheWrite "PRUNE: orphaned local branches deleted"
exit /b 0

:: ============================================================
::  SECTION 16 — GIT DOCTOR (HEALTH CHECK)
:: ============================================================
:RunDoctor
cls
echo.
echo %C_BOLD%%C_GREEN%%DIVIDER%%C_RESET%
echo %C_BOLD%%C_GREEN%               GIT DOCTOR — HEALTH CHECK%C_RESET%
echo %C_BOLD%%C_GREEN%%DIVIDER%%C_RESET%
echo.

set /a _issues=0

:: Check 1: Git installed
echo %C_BOLD%[CHECK] Git installed...%C_RESET%
git --version >nul 2>&1
if errorlevel 1 (
    call :PrintError "Git is NOT installed!"
    set /a _issues+=1
) else (
    call :PrintSuccess "Git installed: %GIT_VERSION%"
)

:: Check 2: Inside a git repo
echo.
echo %C_BOLD%[CHECK] Inside a Git repo...%C_RESET%
git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    call :PrintWarning "Not inside a Git repository."
    set /a _issues+=1
) else (
    call :PrintSuccess "Valid Git repository detected."
)

:: Check 3: user.name
echo.
echo %C_BOLD%[CHECK] user.name configured...%C_RESET%
for /f "delims=" %%n in ('git config --global user.name 2^>nul') do set "_dn=%%n"
if "!_dn!"=="" (
    call :PrintWarning "user.name is NOT set. Run 'gitsync config' to fix."
    set /a _issues+=1
) else (
    call :PrintSuccess "user.name = !_dn!"
)

:: Check 4: user.email
echo.
echo %C_BOLD%[CHECK] user.email configured...%C_RESET%
for /f "delims=" %%e in ('git config --global user.email 2^>nul') do set "_de=%%e"
if "!_de!"=="" (
    call :PrintWarning "user.email is NOT set. Run 'gitsync config' to fix."
    set /a _issues+=1
) else (
    call :PrintSuccess "user.email = !_de!"
)

:: Check 5: .gitignore present
echo.
echo %C_BOLD%[CHECK] .gitignore present...%C_RESET%
if exist .gitignore (
    call :PrintSuccess ".gitignore found."
) else (
    call :PrintWarning ".gitignore missing. Run 'gitsync ignore' to create."
    set /a _issues+=1
)

:: Check 6: Remote origin set
echo.
echo %C_BOLD%[CHECK] Remote 'origin' configured...%C_RESET%
git remote -v 2>nul | findstr "origin" >nul 2>&1
if errorlevel 1 (
    call :PrintWarning "No remote 'origin' found."
    set /a _issues+=1
) else (
    for /f %%u in ('git remote get-url origin 2^>nul') do set "_ru=%%u"
    call :PrintSuccess "Remote origin: !_ru!"
)

:: Check 7: Pending local changes
echo.
echo %C_BOLD%[CHECK] Checking for uncommitted changes...%C_RESET%
for /f %%x in ('git status --porcelain 2^>nul ^| find /c /v ""') do set /a _uc=%%x
if !_uc! GTR 0 (
    call :PrintWarning "!_uc! uncommitted change(s). Consider committing."
) else (
    call :PrintSuccess "Working tree is clean."
)

:: Check 8: Unpushed commits
echo.
echo %C_BOLD%[CHECK] Checking for unpushed commits...%C_RESET%
for /f %%x in ('git log origin..HEAD --oneline 2^>nul ^| find /c /v ""') do set /a _up=%%x
if !_up! GTR 0 (
    call :PrintWarning "!_up! unpushed commit(s). Run 'gitsync push'."
) else (
    call :PrintSuccess "All commits pushed."
)

:: Check 9: Merge conflicts
echo.
echo %C_BOLD%[CHECK] Merge conflicts in progress...%C_RESET%
if exist ".git\MERGE_HEAD" (
    call :PrintError "Merge in progress! Run 'gitsync conflicts' to resolve."
    set /a _issues+=1
) else (
    call :PrintSuccess "No merge in progress."
)

:: Check 10: Rebase in progress
echo.
echo %C_BOLD%[CHECK] Rebase in progress...%C_RESET%
if exist ".git\rebase-merge" (
    call :PrintError "Rebase in progress! Complete or abort it."
    set /a _issues+=1
) else if exist ".git\rebase-apply" (
    call :PrintError "Rebase in progress! Complete or abort it."
    set /a _issues+=1
) else (
    call :PrintSuccess "No rebase in progress."
)

:: Check 11: Detached HEAD
echo.
echo %C_BOLD%[CHECK] Detached HEAD state...%C_RESET%
for /f %%b in ('git branch --show-current 2^>nul') do set "_hb=%%b"
if "!_hb!"=="" (
    call :PrintWarning "Detached HEAD! You are not on any branch."
    call :PrintInfo   "Run: git checkout <branchname>"
    set /a _issues+=1
) else (
    call :PrintSuccess "On branch: !_hb!"
)

:: Summary
echo.
echo %C_DIM%%DIVIDER%%C_RESET%
if !_issues! EQU 0 (
    echo %C_GREEN%%C_BOLD%[RESULT] All checks passed! Repository is healthy.%C_RESET%
) else (
    echo %C_YELLOW%%C_BOLD%[RESULT] !_issues! issue(s) found. Review the warnings above.%C_RESET%
)
echo %C_DIM%%DIVIDER%%C_RESET%
echo.
call :CacheWrite "DOCTOR: !_issues! issue(s) found"
exit /b 0

:: ============================================================
::  SECTION 17 — FIRST-TIME SETUP WIZARD
:: ============================================================
:FirstTimeSetup
cls
call :PrintBanner
echo.
echo %C_BOLD%%C_CYAN%FIRST-TIME SETUP WIZARD%C_RESET%
echo This will walk you through configuring Git globally.
echo.

:: Name
set /p "_sname=Your full name (for commits): "
if not "!_sname!"=="" (
    git config --global user.name "!_sname!"
    call :PrintSuccess "Name set: !_sname!"
)

:: Email
set /p "_semail=Your email: "
if not "!_semail!"=="" (
    git config --global user.email "!_semail!"
    call :PrintSuccess "Email set: !_semail!"
)

:: Default branch
echo.
echo What should the default branch be called?
echo  [1] main (recommended)
echo  [2] master
echo  [3] Custom
set /p "_sbropt=Choice: "
if "!_sbropt!"=="1" git config --global init.defaultBranch main
if "!_sbropt!"=="2" git config --global init.defaultBranch master
if "!_sbropt!"=="3" (
    set /p "_sbrcustom=Custom branch name: "
    git config --global init.defaultBranch "!_sbrcustom!"
)

:: Editor
echo.
echo Preferred text editor:
echo  [1] Notepad (built-in)
echo  [2] VS Code (code)
echo  [3] Notepad++ 
echo  [4] Skip
set /p "_sedit=Choice: "
if "!_sedit!"=="1" git config --global core.editor notepad
if "!_sedit!"=="2" git config --global core.editor "code --wait"
if "!_sedit!"=="3" git config --global core.editor "'C:/Program Files/Notepad++/notepad++.exe' -multiInst -notabbar -nosession -noPlugin"

:: Credential helper
echo.
echo Credential helper (saves GitHub password/token):
echo  [1] Windows Credential Manager (recommended for Windows)
echo  [2] Store in plaintext file (not recommended)
echo  [3] Skip
set /p "_scred=Choice: "
if "!_scred!"=="1" git config --global credential.helper manager
if "!_scred!"=="2" git config --global credential.helper store

:: Colors
git config --global color.ui auto
git config --global color.branch auto
git config --global color.diff auto
git config --global color.status auto

:: Aliases
echo.
set /p "_saliases=Add helpful git aliases? (y/n): "
if /i "!_saliases!"=="y" (
    git config --global alias.st "status -s"
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.lg "log --oneline --graph --decorate -15"
    git config --global alias.last "log -1 HEAD"
    git config --global alias.unstage "reset HEAD --"
    git config --global alias.visual "!gitk"
    call :PrintSuccess "Aliases added: st, co, br, lg, last, unstage, visual"
)

echo.
call :PrintSuccess "Setup complete!"
echo.
echo %C_BOLD%Summary:%C_RESET%
git config --global --list | findstr "user\|core\|alias\|init"
echo.
call :CacheWrite "FIRST-TIME SETUP: completed"
pause
exit /b 0

:: ============================================================
::  SECTION 18 — HELP MENU
:: ============================================================
:ShowHelp
cls
echo.
echo %C_CYAN%%C_BOLD%%DIVIDER%%C_RESET%
echo %C_CYAN%%C_BOLD%          %SCRIPT_NAME%  v%SCRIPT_VERSION%  —  COMMAND REFERENCE%C_RESET%
echo %C_CYAN%%C_BOLD%%DIVIDER%%C_RESET%
echo.
echo %C_BOLD%USAGE:%C_RESET%  gitsync [command] [arg]
echo.
echo %C_BOLD%%C_WHITE%WIZARD%C_RESET%
echo   gitsync                  Run the full interactive wizard
echo   gitsync setup            First-time Git configuration wizard
echo   gitsync sync             Pull + commit + push (one step)
echo   gitsync doctor           Health check: diagnose common issues
echo.
echo %C_BOLD%%C_WHITE%BASIC OPERATIONS%C_RESET%
echo   gitsync status           Show modified/staged/untracked files
echo   gitsync log              Last 15 commits (graph view)
echo   gitsync logfull          Full commit history with dates
echo   gitsync diff [file]      Show unstaged and staged diffs
echo   gitsync pull             Pull from remote (rebase mode)
echo   gitsync push             Push current branch to origin
echo   gitsync fetch            Fetch all remotes (with prune)
echo   gitsync undo             Undo last commit (keep files staged)
echo   gitsync amend            Edit last commit message
echo   gitsync clean            Remove untracked files (interactive)
echo.
echo %C_BOLD%%C_WHITE%HISTORY %AMP; INFO%C_RESET%
echo   gitsync history          View GitSync action log
echo   gitsync clearhistory     Clear the action log
echo   gitsync blame ^<file^>     Show who last changed each line
echo   gitsync stats            Repo stats (commits, contributors)
echo   gitsync whoami           Show your configured Git identity
echo   gitsync version          Show version info
echo.
echo %C_BOLD%%C_WHITE%BRANCH MANAGEMENT%C_RESET%
echo   gitsync branch           Interactive branch manager
echo   gitsync branch create    Create a new branch
echo   gitsync branch switch    Switch to a branch
echo   gitsync branch delete    Delete a local branch
echo   gitsync branch merge     Merge a branch into current
echo   gitsync branch push      Push a branch to remote
echo   gitsync prune            Remove orphaned local branches
echo.
echo %C_BOLD%%C_WHITE%STASH%C_RESET%
echo   gitsync stash            Interactive stash manager
echo.
echo %C_BOLD%%C_WHITE%TAGS%C_RESET%
echo   gitsync tag              Interactive tag manager
echo.
echo %C_BOLD%%C_WHITE%REMOTES%C_RESET%
echo   gitsync remote           Interactive remote manager
echo.
echo %C_BOLD%%C_WHITE%RESETS %AMP; REVERTS%C_RESET%
echo   gitsync reset            Interactive reset menu (soft/mixed/hard)
echo   gitsync cherrypick       Apply a specific commit to current branch
echo   gitsync rebase           Rebase current branch
echo.
echo %C_BOLD%%C_WHITE%CONFLICT RESOLUTION%C_RESET%
echo   gitsync conflicts        Guided merge conflict helper
echo.
echo %C_BOLD%%C_WHITE%.GITIGNORE%C_RESET%
echo   gitsync ignore           Manage .gitignore (templates, entries)
echo.
echo %C_BOLD%%C_WHITE%CONFIGURATION%C_RESET%
echo   gitsync config           Interactive Git config manager
echo   gitsync whoami           View current identity
echo.
echo %C_BOLD%%C_WHITE%BACKUPS %AMP; ARCHIVES%C_RESET%
echo   gitsync backup           Create snapshots/bundles
echo   gitsync archive          Zip the current repo
echo.
echo %C_BOLD%%C_WHITE%SHORTCUTS (aliases)%C_RESET%
echo   gitsync s                = status
echo   gitsync l                = log
echo   gitsync st               = stash
echo   gitsync br               = branch
echo   gitsync cp               = cherrypick
echo.
echo %C_DIM%%DIVIDER%%C_RESET%
echo %C_DIM%  Cache log: %CACHE_FILE%   Config: %CONFIG_FILE%%C_RESET%
echo %C_DIM%%DIVIDER%%C_RESET%
echo.
exit /b 0

:: ============================================================
::  SECTION 19 — CHANGELOG
:: ============================================================
:ShowChangelog
echo.
echo %C_BOLD%%C_CYAN%%DIVIDER%%C_RESET%
echo %C_BOLD%%C_CYAN%                    CHANGELOG%C_RESET%
echo %C_BOLD%%C_CYAN%%DIVIDER%%C_RESET%
echo.
echo %C_BOLD%v3.0.0 (2025)%C_RESET%
echo   + Full rewrite with colored ANSI output
echo   + Interactive menus: Branch, Stash, Tag, Remote, Reset
echo   + Cherry-pick and Rebase workflows
echo   + Conflict helper with guided resolution
echo   + .gitignore template generator (10+ languages)
echo   + Git Doctor health check (11 checks)
echo   + First-time setup wizard
echo   + Smart log rotation for cache file
echo   + Backup: zip snapshots + git bundles
echo   + Branch compare, track remote, orphan pruning
echo   + Tag management with dates and remote ops
echo   + Config manager (GPG, proxy, credentials, line endings)
echo   + Full Sync (pull + commit + push in one command)
echo   + Archive repo as ZIP
echo   + Version and changelog commands
echo.
echo %C_BOLD%v2.0.0%C_RESET%
echo   + Added stash, tag, remote management
echo   + Added .gitignore auto-management
echo   + Added help shortcuts
echo.
echo %C_BOLD%v1.0.0%C_RESET%
echo   + Initial release: basic commit + push wizard
echo.
exit /b 0

:: ============================================================
::  SECTION 20 — UTILITY: REQUIRE REPO
:: ============================================================
:RequireRepo
git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    call :PrintError "This command requires a Git repository."
    call :PrintInfo  "Run 'gitsync' to initialize one, or cd into a repo."
    exit /b 1
)
exit /b 0

:: ============================================================
::  END OF SCRIPT
:: ============================================================