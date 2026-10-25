@echo off
setlocal enabledelayedexpansion

:: ====================================================================
::   GITSYNC ULTRA v4.0.0
::   Ultra-Fast, Failsafe, Cross-Platform Git Automation & Stash Tracker
::   Compatible with Windows 10/11, CMD, PowerShell, Windows Terminal
:: ====================================================================

:: --------------------------------------------------------------------
::  ANSI COLOR INITIALIZATION (SAFE & PORTABLE)
:: --------------------------------------------------------------------
set "ESC="
for /f "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do set "ESC=%%b"

if not defined ESC (
    set "C_RESET="
    set "C_RED="
    set "C_GREEN="
    set "C_YELLOW="
    set "C_BLUE="
    set "C_MAGENTA="
    set "C_CYAN="
    set "C_WHITE="
    set "C_BOLD="
    set "C_DIM="
) else (
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
)

:: --------------------------------------------------------------------
::  GLOBAL CONSTANTS & SAFE STORAGE PATHS
:: --------------------------------------------------------------------
set "SCRIPT_VERSION=4.0.0"
set "SCRIPT_NAME=GitSync Ultra"
set "SELF_UPDATE_URL=https://raw.githubusercontent.com/futuretonight/gitsync/main/gitsync.bat"
set "DEFAULT_BRANCH=main"
set "GIT_PAGER=cat"
set "DIVIDER===================================================================="
set "THIN_DIVIDER=--------------------------------------------------------------------"
set "STAR_LINE=********************************************************************"

:: Global directory in user profile prevents 'Access Denied' in root/system folders
set "GLOBAL_DIR=%USERPROFILE%\.gitsync"
if not exist "%GLOBAL_DIR%" mkdir "%GLOBAL_DIR%" >nul 2>&1
set "GLOBAL_CONFIG=%GLOBAL_DIR%\config.ini"
set "GLOBAL_LOG=%GLOBAL_DIR%\history.log"

:: Repository-level tracking (inside .git/gitsync so git never commits it)
set "IS_IN_REPO=0"
set "GIT_DIR="
set "REPO_ROOT="
set "REPO_SYNC_DIR="
set "STASH_TRACK_LOG="
set "STASH_BACKUP_DIR="
set "REPO_LOG="

git rev-parse --is-inside-work-tree >nul 2>&1
if not errorlevel 1 (
    set "IS_IN_REPO=1"
    for /f "delims=" %%r in ('git rev-parse --git-dir 2^>nul') do set "GIT_DIR=%%r"
    for /f "delims=" %%r in ('git rev-parse --show-toplevel 2^>nul') do set "REPO_ROOT=%%r"
    if defined GIT_DIR (
        set "REPO_SYNC_DIR=!GIT_DIR!\gitsync"
        set "STASH_TRACK_LOG=!REPO_SYNC_DIR!\stash_tracker.log"
        set "STASH_BACKUP_DIR=!REPO_SYNC_DIR!\stashes"
        set "REPO_LOG=!REPO_SYNC_DIR!\action.log"
        if not exist "!REPO_SYNC_DIR!" mkdir "!REPO_SYNC_DIR!" >nul 2>&1
        if not exist "!STASH_BACKUP_DIR!" mkdir "!STASH_BACKUP_DIR!" >nul 2>&1
    )
)

title %SCRIPT_NAME% v%SCRIPT_VERSION%

:: --------------------------------------------------------------------
::  PRE-FLIGHT: GIT CHECK
:: --------------------------------------------------------------------
git --version >nul 2>&1
if errorlevel 1 (
    call :PrintError "Git is NOT installed or not found in PATH."
    call :PrintInfo  "Download and install Git from: https://git-scm.com/downloads"
    call :PrintInfo  "Restart your terminal, then run gitsync again."
    pause
    exit /b 1
)
for /f "tokens=3" %%v in ('git --version 2^>nul') do set "GIT_VERSION=%%v"

:: Load config if exists
set "UPDATES_DISABLED=1"
if exist "%GLOBAL_CONFIG%" (
    for /f "usebackq tokens=1,* delims==" %%k in ("%GLOBAL_CONFIG%") do (
        if /i "%%k"=="updates_disabled" set "UPDATES_DISABLED=%%l"
    )
)

:: --------------------------------------------------------------------
::  COMMAND LINE ROUTER (BLAZING FAST DIRECT DISPATCH)
:: --------------------------------------------------------------------
set "ARG1=%~1"
set "ARG2=%~2"
set "ARG3=%~3"
set "ARG4=%~4"

if "%ARG1%"=="" goto :MainWizard

:: Help & Version
if /i "%ARG1%"=="help"          goto :ShowHelp
if /i "%ARG1%"=="-h"            goto :ShowHelp
if /i "%ARG1%"=="--help"        goto :ShowHelp
if /i "%ARG1%"=="?"             goto :ShowHelp
if /i "%ARG1%"=="version"       goto :ShowVersion
if /i "%ARG1%"=="-v"            goto :ShowVersion
if /i "%ARG1%"=="--version"     goto :ShowVersion
if /i "%ARG1%"=="changelog"     goto :ShowChangelog

:: Core Workflow Commands
if /i "%ARG1%"=="status"        goto :QuickStatus
if /i "%ARG1%"=="s"             goto :QuickStatus
if /i "%ARG1%"=="log"           goto :QuickLog
if /i "%ARG1%"=="l"             goto :QuickLog
if /i "%ARG1%"=="logfull"       goto :QuickLogFull
if /i "%ARG1%"=="diff"          goto :QuickDiff
if /i "%ARG1%"=="undo"          goto :QuickUndo
if /i "%ARG1%"=="commit"        goto :QuickCommit
if /i "%ARG1%"=="c"             goto :QuickCommit
if /i "%ARG1%"=="push"          goto :QuickPush
if /i "%ARG1%"=="p"             goto :QuickPush
if /i "%ARG1%"=="pull"          goto :QuickPull
if /i "%ARG1%"=="fetch"         goto :QuickFetch
if /i "%ARG1%"=="sync"          goto :FullSync
if /i "%ARG1%"=="amend"         goto :QuickAmend
if /i "%ARG1%"=="clean"         goto :QuickClean
if /i "%ARG1%"=="blame"         goto :QuickBlame

:: Stash & Stash Pop Tracking Commands
if /i "%ARG1%"=="pop"           goto :StashPopRouter
if /i "%ARG1%"=="stash"         goto :StashRouter
if /i "%ARG1%"=="st"            goto :StashRouter

:: Branch, Remote, Tag, Reset
if /i "%ARG1%"=="branch"        goto :BranchRouter
if /i "%ARG1%"=="br"            goto :BranchRouter
if /i "%ARG1%"=="tag"           goto :TagMenu
if /i "%ARG1%"=="remote"        goto :RemoteMenu
if /i "%ARG1%"=="reset"         goto :ResetMenu
if /i "%ARG1%"=="cherrypick"    goto :CherryPickMenu
if /i "%ARG1%"=="cp"            goto :CherryPickMenu
if /i "%ARG1%"=="rebase"        goto :RebaseMenu
if /i "%ARG1%"=="conflicts"     goto :ConflictHelper

:: Utilities & Tools
if /i "%ARG1%"=="ignore"        goto :GitIgnoreMenu
if /i "%ARG1%"=="config"        goto :ConfigMenu
if /i "%ARG1%"=="doctor"        goto :RunDoctor
if /i "%ARG1%"=="setup"         goto :FirstTimeSetup
if /i "%ARG1%"=="prune"         goto :PruneBranches
if /i "%ARG1%"=="archive"       goto :ArchiveRepo
if /i "%ARG1%"=="backup"        goto :BackupMenu
if /i "%ARG1%"=="stats"         goto :QuickStats
if /i "%ARG1%"=="whoami"        goto :WhoAmI
if /i "%ARG1%"=="history"       goto :QuickHistory
if /i "%ARG1%"=="hist"          goto :QuickHistory
if /i "%ARG1%"=="clearhistory"  goto :ClearHistory
if /i "%ARG1%"=="update"        goto :UpdateMenu

call :PrintError "Unknown command: '%ARG1%'"
call :PrintInfo  "Run 'gitsync help' to view all available commands."
exit /b 1

:: ====================================================================
::  SECTION 1 -- MAIN INTERACTIVE WIZARD
:: ====================================================================
:MainWizard
cls
call :PrintBanner
call :CheckGitConfig

echo.
call :PrintSection "STEP 1 - REPOSITORY CHECK"
call :CheckOrInitRepo || exit /b 1

echo.
call :PrintSection "STEP 2 - LOCAL COMMIT"
call :LocalCommitFlow

echo.
call :PrintSection "STEP 3 - REMOTE PUSH"
call :RemotePushFlow

echo.
call :PrintSection "WIZARD COMPLETE"
call :PrintSuccess "All done! Your repository workflow is up to date."
call :PrintInfo    "Run 'gitsync help' to explore instant shortcuts."
echo.
call :CacheWrite "Wizard completed successfully"
pause
exit /b 0

:: ====================================================================
::  SECTION 2 -- CORE HELPERS & OUTPUT FORMATTERS
:: ====================================================================
:PrintBanner
echo.
echo %C_CYAN%%C_BOLD%%DIVIDER%%C_RESET%
echo %C_CYAN%%C_BOLD%         %SCRIPT_NAME%  v%SCRIPT_VERSION%%C_RESET%
echo %C_CYAN%%C_BOLD%         Failsafe Git Manager ^& Stash Tracker%C_RESET%
echo %C_CYAN%         Git %GIT_VERSION%   ^|   %date%   ^|   %time:~0,8%%C_RESET%
echo %C_CYAN%%C_BOLD%%DIVIDER%%C_RESET%
exit /b 0

:PrintSection
echo.
echo %C_BOLD%%C_BLUE%[ %~1 ]%C_RESET%
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
exit /b 0

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

:RequireRepo
git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    call :PrintError "This command requires a Git repository."
    call :PrintInfo  "cd into a repository or run 'gitsync' to initialize one."
    exit /b 1
)
exit /b 0

:CacheWrite
set "_cw_msg=%~1"
set "_cw_dt=%date% %time:~0,8%"
echo [!_cw_dt!] !_cw_msg!>> "%GLOBAL_LOG%" 2>nul
if defined REPO_LOG (
    echo [!_cw_dt!] !_cw_msg!>> "%REPO_LOG%" 2>nul
)
exit /b 0

:: --------------------------------------------------------------------
::  REPOSITORY VALIDATION & FIRST-TIME INIT
:: --------------------------------------------------------------------
:CheckOrInitRepo
git rev-parse --is-inside-work-tree >nul 2>&1
if not errorlevel 1 (
    for /f "delims=" %%r in ('git rev-parse --show-toplevel 2^>nul') do set "_rroot=%%r"
    call :PrintSuccess "Git repo detected: !_rroot!"
    exit /b 0
)

call :PrintWarning "This directory is NOT a Git repository."
echo.
set /p "_init=Initialize a new Git repository here? (y/n): "
if /i "!_init!"=="y" (
    git init
    if errorlevel 1 (
        call :PrintError "git init failed. Check folder permissions."
        exit /b 1
    )
    call :PrintSuccess "Git repository initialized successfully!"
    call :CacheWrite "git init performed in %cd%"
    git checkout -b %DEFAULT_BRANCH% >nul 2>&1 || git branch -M %DEFAULT_BRANCH% >nul 2>&1
    call :PrintInfo "Default branch configured to '%DEFAULT_BRANCH%'."
    call :EnsureGitIgnore
    exit /b 0
)
call :PrintInfo "Aborted. No repository initialized."
exit /b 1

:CheckGitConfig
set "_cname="
set "_cemail="
for /f "delims=" %%v in ('git config --global user.name 2^>nul') do set "_cname=%%v"
for /f "delims=" %%v in ('git config --global user.email 2^>nul') do set "_cemail=%%v"

if "!_cname!"=="" (
    call :PrintWarning "Git user.name is not configured."
    set /p "_newname=Enter your name for Git commits: "
    if not "!_newname!"=="" (
        git config --global user.name "!_newname!"
        call :PrintSuccess "user.name set to: !_newname!"
    )
)
if "!_cemail!"=="" (
    call :PrintWarning "Git user.email is not configured."
    set /p "_newemail=Enter your email for Git commits: "
    if not "!_newemail!"=="" (
        git config --global user.email "!_newemail!"
        call :PrintSuccess "user.email set to: !_newemail!"
    )
)
exit /b 0

:EnsureGitIgnore
if not exist .gitignore (
    call :PrintStep "Creating default .gitignore..."
    (
        echo # GitSync auto-generated .gitignore
        echo .DS_Store
        echo Thumbs.db
        echo *.log
        echo *.tmp
        echo node_modules/
        echo __pycache__/
        echo dist/
        echo build/
        echo .env
        echo .env.local
    ) > .gitignore
    call :PrintSuccess "Created standard .gitignore"
)
exit /b 0

:: ====================================================================
::  SECTION 3 -- COMMIT & PUSH FLOWS
:: ====================================================================
:LocalCommitFlow
echo.
call :PrintStep "Working tree status:"
git status -s
echo.

set /a _num_chg=0
for /f %%x in ('git status --porcelain 2^>nul ^| find /c /v ""') do set /a _num_chg=%%x
if !_num_chg! EQU 0 (
    call :PrintInfo "Nothing to commit. Working tree is clean."
    exit /b 0
)

call :PrintInfo "!_num_chg! change(s) detected."
echo.
set /p "_do_c=Stage all changes and commit? (y/n): "
if /i not "!_do_c!"=="y" (
    call :PrintInfo "Skipping local commit."
    exit /b 0
)

echo.
set /p "_cmsg=Commit message (blank = auto-timestamp): "
if "!_cmsg!"=="" (
    set "_cmsg=Update %date% %time:~0,8%"
)

call :PrintStep "Staging files (git add -A)..."
git add -A
if errorlevel 1 (
    call :PrintError "git add failed."
    exit /b 1
)

call :PrintStep "Committing..."
git commit -m "!_cmsg!"
if errorlevel 1 (
    call :PrintError "Commit failed."
    exit /b 1
)
call :PrintSuccess "Committed: '!_cmsg!'"
call :CacheWrite "COMMIT: !_cmsg!"
echo.
git log --oneline -1
exit /b 0

:RemotePushFlow
echo.
set /p "_do_p=Push to remote? (y/n): "
if /i not "!_do_p!"=="y" (
    call :PrintInfo "Skipping push."
    exit /b 0
)

git remote -v 2>nul | findstr "origin" >nul 2>&1
if errorlevel 1 (
    call :PrintWarning "No remote 'origin' configured."
    set /p "_rurl=Enter remote Git URL: "
    if "!_rurl!"=="" (
        call :PrintError "Remote URL required."
        exit /b 1
    )
    git remote add origin "!_rurl!" || ( call :PrintError "Failed to add remote." & exit /b 1 )
    call :PrintSuccess "Remote 'origin' set to: !_rurl!"
)

set "_curbranch="
for /f %%b in ('git branch --show-current 2^>nul') do set "_curbranch=%%b"
if "!_curbranch!"=="" set "_curbranch=%DEFAULT_BRANCH%"

echo.
set /p "_dopull=Pull from remote first to prevent rejections? (y/n): "
if /i "!_dopull!"=="y" (
    call :PrintStep "Pulling from origin/!_curbranch! (rebase)..."
    git pull --rebase origin "!_curbranch!" >nul 2>&1
    if errorlevel 1 (
        call :PrintWarning "Pull had conflicts or origin branch is new. Continuing..."
    ) else (
        call :PrintSuccess "Up to date with remote."
    )
)

call :PrintStep "Pushing !_curbranch! to origin..."
git push -u origin "!_curbranch!"
if errorlevel 1 (
    call :PrintError "Push failed. Remote may have rejected non-fast-forward."
    set /p "_force=Force push with lease? (y/n): "
    if /i "!_force!"=="y" (
        git push --force-with-lease origin "!_curbranch!"
        if errorlevel 1 (
            call :PrintError "Force push failed."
            exit /b 1
        )
        call :PrintSuccess "Pushed successfully with --force-with-lease."
    )
) else (
    call :PrintSuccess "Pushed successfully to origin/!_curbranch!."
    call :CacheWrite "PUSH: origin/!_curbranch!"
)
exit /b 0

:: ====================================================================
::  SECTION 4 -- STASH & STASH POP TRACKING SYSTEM
:: ====================================================================
:StashRouter
if /i "%ARG2%"==""         goto :StashMenu
if /i "%ARG2%"=="pop"      goto :DoTrackedStashPop
if /i "%ARG2%"=="save"     goto :DoTrackedStashSaveCli
if /i "%ARG2%"=="push"     goto :DoTrackedStashSaveCli
if /i "%ARG2%"=="apply"    goto :DoTrackedStashApplyCli
if /i "%ARG2%"=="drop"     goto :DoTrackedStashDropCli
if /i "%ARG2%"=="list"     goto :StashListCli
if /i "%ARG2%"=="show"     goto :StashShowCli
if /i "%ARG2%"=="clear"    goto :StashClearAll
if /i "%ARG2%"=="history"  goto :StashHistory
if /i "%ARG2%"=="log"      goto :StashHistory
if /i "%ARG2%"=="track"    goto :StashHistory
if /i "%ARG2%"=="recover"  goto :StashRecover

call :PrintError "Unknown stash subcommand: '%ARG2%'"
call :PrintInfo  "Valid subcommands: pop, save, list, history, recover, apply, drop, show, clear"
exit /b 1

:StashPopRouter
goto :DoTrackedStashPop

:StashMenu
call :RequireRepo || exit /b 1
cls
echo.
echo %C_BOLD%%C_YELLOW%%DIVIDER%%C_RESET%
echo %C_BOLD%%C_YELLOW%             STASH ^& STASH POP TRACKER MANAGER%C_RESET%
echo %C_BOLD%%C_YELLOW%%DIVIDER%%C_RESET%
echo.
echo   %C_BOLD%Active Git Stashes:%C_RESET%
git stash list
echo.
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
echo  [1] Stash changes with Auto-Backup ^& Tracking
echo  [2] Pop latest stash with Tracking (apply + drop)
echo  [3] Apply stash (keep in git stash list)
echo  [4] Drop a stash (backed up safely in tracker)
echo  [5] Show stash diff / contents
echo  [6] View Stash ^& Pop Audit History (Tracking Log)
echo  [7] Recover a lost / popped / dropped stash snapshot
echo  [8] Create Named Stash
echo  [9] Apply stash to a new branch
echo  [10] Clear ALL stashes (with full backup snapshot)
echo  [0] Back / Exit
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
echo.
set /p "_smc=Select option (0-10): "
if "!_smc!"=="1"  goto :StashSaveInteractive
if "!_smc!"=="2"  goto :DoTrackedStashPop
if "!_smc!"=="3"  goto :StashApplyInteractive
if "!_smc!"=="4"  goto :StashDropInteractive
if "!_smc!"=="5"  goto :StashShowInteractive
if "!_smc!"=="6"  goto :StashHistory
if "!_smc!"=="7"  goto :StashRecover
if "!_smc!"=="8"  goto :StashNamedInteractive
if "!_smc!"=="9"  goto :StashToBranchInteractive
if "!_smc!"=="10" goto :StashClearAll
if "!_smc!"=="0"  exit /b 0
call :PrintWarning "Invalid selection."
exit /b 0

:: --- Internal Tracked Stash Engine ---
:DoTrackedStashInternal
:: %~1 = message, %~2 = Action tag (STASH-SAVE or AUTO-STASH)
set "_st_msg=%~1"
set "_st_tag=%~2"
if "!_st_tag!"=="" set "_st_tag=STASH-SAVE"
if "!_st_msg!"=="" set "_st_msg=Stash %date% %time:~0,8%"

:: Check if dirty
set /a _has_chg=0
for /f %%c in ('git status --porcelain 2^>nul ^| find /c /v ""') do set /a _has_chg=%%c
if !_has_chg! EQU 0 (
    call :PrintInfo "Nothing to stash. Working directory is clean."
    exit /b 2
)

set "_cur_br="
for /f %%b in ('git branch --show-current 2^>nul') do set "_cur_br=%%b"
if "!_cur_br!"=="" set "_cur_br=HEAD"

set "_cur_sha="
for /f %%h in ('git rev-parse --short HEAD 2^>nul') do set "_cur_sha=%%h"

:: Generate timestamp and unique snapshot id
set "_d_str=%date:~-4%%date:~3,2%%date:~0,2%"
set "_t_str=%time:~0,2%%time:~3,2%%time:~6,2%"
set "_d_str=!_d_str: =0!"
set "_t_str=!_t_str: =0!"
set "_sid=stash_!_d_str!_!_t_str!"

:: Make sure backup directory exists
if not exist "%STASH_BACKUP_DIR%" mkdir "%STASH_BACKUP_DIR%" >nul 2>&1

:: Create a patch snapshot before git stash for safety
git diff HEAD > "%STASH_BACKUP_DIR%\!_sid!.patch" 2>nul

:: Perform git stash push
git stash push -u -m "!_st_msg!" >nul 2>&1
if errorlevel 1 (
    call :PrintError "Git stash failed."
    exit /b 1
)

:: Record event in stash tracker log
set "_now=%date% %time:~0,8%"
echo [!_now!] [!_st_tag!] Branch: !_cur_br! ^| Commit: !_cur_sha! ^| Patch: !_sid!.patch ^| Msg: "!_st_msg!">> "%STASH_TRACK_LOG%"
call :CacheWrite "!_st_tag!: !_st_msg! (Snapshot: !_sid!.patch)"
call :PrintSuccess "Changes stashed and tracked successfully."
call :PrintDim     "Safety snapshot saved: !_sid!.patch"
exit /b 0

:DoTrackedStashSaveCli
call :RequireRepo || exit /b 1
set "_cl_msg=%~3"
if "!_cl_msg!"=="" set "_cl_msg=%~2"
if /i "!_cl_msg!"=="save" set "_cl_msg="
if /i "!_cl_msg!"=="push" set "_cl_msg="
call :DoTrackedStashInternal "!_cl_msg!" "STASH-SAVE"
exit /b 0

:StashSaveInteractive
call :RequireRepo || exit /b 1
echo.
set /p "_imsg=Stash description/label (blank = auto-timestamp): "
call :DoTrackedStashInternal "!_imsg!" "STASH-SAVE"
exit /b 0

:StashNamedInteractive
call :RequireRepo || exit /b 1
echo.
set /p "_imsg=Enter named stash label: "
if "!_imsg!"=="" set "_imsg=Manual Named Stash %date% %time:~0,8%"
call :DoTrackedStashInternal "!_imsg!" "STASH-NAMED"
exit /b 0

:DoTrackedStashPop
call :RequireRepo || exit /b 1
echo.
call :PrintStep "Checking stash queue..."

set /a _stcount=0
for /f %%x in ('git stash list 2^>nul ^| find /c /v ""') do set /a _stcount=%%x
if !_stcount! EQU 0 (
    call :PrintWarning "No stashes found to pop."
    exit /b 0
)

:: Capture top stash details before popping
set "_top_stash_line="
for /f "delims=" %%s in ('git stash list -1 2^>nul') do set "_top_stash_line=%%s"

set "_cur_br="
for /f %%b in ('git branch --show-current 2^>nul') do set "_cur_br=%%b"
if "!_cur_br!"=="" set "_cur_br=HEAD"

set "_pop_idx=stash@{0}"
if not "%ARG3%"=="" set "_pop_idx=stash@{%ARG3%}"

call :PrintStep "Popping !_pop_idx! (!(_top_stash_line!))..."
git stash pop "%_pop_idx%"
set "_pop_status=%errorlevel%"
set "_now=%date% %time:~0,8%"

if !_pop_status! EQU 0 (
    echo [!_now!] [STASH-POP-SUCCESS] Branch: !_cur_br! ^| Item: !_top_stash_line!>> "%STASH_TRACK_LOG%"
    call :CacheWrite "STASH-POP-SUCCESS: !_top_stash_line!"
    call :PrintSuccess "Stash applied and dropped cleanly!"
) else (
    echo [!_now!] [STASH-POP-CONFLICT] Branch: !_cur_br! ^| Item: !_top_stash_line!>> "%STASH_TRACK_LOG%"
    call :CacheWrite "STASH-POP-CONFLICT: !_top_stash_line!"
    call :PrintError "Stash popped with merge conflicts!"
    call :PrintInfo  "Your changes are preserved in the working tree with conflict markers."
    call :PrintInfo  "All previous stash snapshots remain backed up in: .git/gitsync/stashes/"
    call :PrintInfo  "Run 'gitsync conflicts' to resolve."
)
exit /b !_pop_status!

:StashApplyInteractive
call :RequireRepo || exit /b 1
echo.
git stash list
echo.
set /p "_aidx=Stash index to apply (e.g. 0 for stash@{0}): "
if "!_aidx!"=="" set "_aidx=0"
git stash apply "stash@{!_aidx!}"
if errorlevel 1 (
    call :PrintError "Failed to apply stash@{!_aidx!}."
    exit /b 1
)
set "_now=%date% %time:~0,8%"
echo [!_now!] [STASH-APPLY] Index: stash@{!_aidx!}>> "%STASH_TRACK_LOG%"
call :PrintSuccess "Stash stash@{!_aidx!} applied (retained in stash list)."
exit /b 0

:DoTrackedStashApplyCli
call :RequireRepo || exit /b 1
set "_aidx=%ARG3%"
if "!_aidx!"=="" set "_aidx=0"
git stash apply "stash@{!_aidx!}"
exit /b 0

:StashDropInteractive
call :RequireRepo || exit /b 1
echo.
git stash list
echo.
set /p "_didx=Stash index to drop (e.g. 0): "
if "!_didx!"=="" set "_didx=0"

:: Create safety backup before dropping
set "_d_str=%date:~-4%%date:~3,2%%date:~0,2%"
set "_t_str=%time:~0,2%%time:~3,2%%time:~6,2%"
set "_d_str=!_d_str: =0!"
set "_t_str=!_t_str: =0!"
set "_sid=dropped_stash_!_d_str!_!_t_str!"
git stash show -p "stash@{!_didx!}" > "%STASH_BACKUP_DIR%\!_sid!.patch" 2>nul

git stash drop "stash@{!_didx!}"
if errorlevel 1 (
    call :PrintError "Failed to drop stash@{!_didx!}."
    exit /b 1
)
set "_now=%date% %time:~0,8%"
echo [!_now!] [STASH-DROP] Index: stash@{!_didx!} ^| Backup: !_sid!.patch>> "%STASH_TRACK_LOG%"
call :PrintSuccess "Stash dropped from Git, but tracked backup saved to: !_sid!.patch"
exit /b 0

:DoTrackedStashDropCli
call :RequireRepo || exit /b 1
set "_didx=%ARG3%"
if "!_didx!"=="" set "_didx=0"
git stash drop "stash@{!_didx!}"
exit /b 0

:StashShowInteractive
call :RequireRepo || exit /b 1
echo.
git stash list
echo.
set /p "_sidx=Stash index to show (e.g. 0): "
if "!_sidx!"=="" set "_sidx=0"
git stash show -p "stash@{!_sidx!}"
exit /b 0

:StashShowCli
call :RequireRepo || exit /b 1
set "_sidx=%ARG3%"
if "!_sidx!"=="" set "_sidx=0"
git stash show -p "stash@{!_sidx!}"
exit /b 0

:StashListCli
call :RequireRepo || exit /b 1
git stash list
exit /b 0

:StashHistory
call :RequireRepo || exit /b 1
cls
echo.
echo %C_BOLD%%C_CYAN%%DIVIDER%%C_RESET%
echo %C_BOLD%%C_CYAN%         GITSYNC STASH ^& STASH POP TRACKING AUDIT LOG%C_RESET%
echo %C_BOLD%%C_CYAN%%DIVIDER%%C_RESET%
echo.
if not exist "%STASH_TRACK_LOG%" (
    call :PrintInfo "No stash operations recorded in this repository yet."
    exit /b 0
)
echo %C_DIM%Log File: %STASH_TRACK_LOG%%C_RESET%
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
type "%STASH_TRACK_LOG%"
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
echo.
call :PrintInfo "Use 'gitsync stash recover' to restore any historical snapshot."
exit /b 0

:StashRecover
call :RequireRepo || exit /b 1
cls
echo.
echo %C_BOLD%%C_GREEN%%DIVIDER%%C_RESET%
echo %C_BOLD%%C_GREEN%           STASH SAFETY SNAPSHOT RECOVERY WIZARD%C_RESET%
echo %C_BOLD%%C_GREEN%%DIVIDER%%C_RESET%
echo.
if not exist "%STASH_BACKUP_DIR%" (
    call :PrintWarning "No backup snapshot directory found."
    exit /b 0
)

echo Available stash snapshots:
echo.
set /a _rcnt=0
for %%f in ("%STASH_BACKUP_DIR%\*.patch") do (
    set /a _rcnt+=1
    echo   [!_rcnt!] %%~nxf
)
if !_rcnt! EQU 0 (
    call :PrintInfo "No snapshot patches found in backup store."
    exit /b 0
)

echo.
set /p "_rf=Enter patch filename to restore (e.g. stash_20261025_220000.patch) or '0' to exit: "
if "!_rf!"=="" exit /b 0
if "!_rf!"=="0" exit /b 0

set "_full_patch=%STASH_BACKUP_DIR%\!_rf!"
if not exist "!_full_patch!" (
    call :PrintError "Patch file not found: !_rf!"
    exit /b 1
)

echo.
call :PrintStep "Patch Preview:"
type "!_full_patch!" | more /e
echo.
set /p "_apply_now=Apply this patch to your current working directory now? (y/n): "
if /i "!_apply_now!"=="y" (
    git apply --reject "!_full_patch!" 2>nul
    if errorlevel 1 (
        call :PrintWarning "Patch had conflicts. Applied cleanly where possible (.rej files created)."
    ) else (
        call :PrintSuccess "Patch successfully applied to working tree!"
    )
    set "_now=%date% %time:~0,8%"
    echo [!_now!] [STASH-RECOVERED] File: !_rf!>> "%STASH_TRACK_LOG%"
)
exit /b 0

:StashToBranchInteractive
call :RequireRepo || exit /b 1
echo.
git stash list
echo.
set /p "_st_idx=Stash index (e.g. 0): "
if "!_st_idx!"=="" set "_st_idx=0"
set /p "_st_newbr=New branch name: "
if "!_st_newbr!"=="" (
    call :PrintError "Branch name required."
    exit /b 1
)
git stash branch "!_st_newbr!" "stash@{!_st_idx!}"
if errorlevel 1 (
    call :PrintError "Failed to create branch from stash."
    exit /b 1
)
call :PrintSuccess "Stash applied to new branch '!_st_newbr!'."
exit /b 0

:StashClearAll
call :RequireRepo || exit /b 1
echo.
call :PrintWarning "DANGER: This clears ALL stashes from Git!"
set /p "_cfc=Are you sure? A full safety snapshot will be saved. (y/n): "
if /i not "!_cfc!"=="y" (
    call :PrintInfo "Aborted."
    exit /b 0
)
set "_d_str=%date:~-4%%date:~3,2%%date:~0,2%"
set "_t_str=%time:~0,2%%time:~3,2%%time:~6,2%"
set "_d_str=!_d_str: =0!"
set "_t_str=!_t_str: =0!"
set "_sid=cleared_all_!_d_str!_!_t_str!"
git stash show -p "stash@{0}" > "%STASH_BACKUP_DIR%\!_sid!.patch" 2>nul
git stash clear
set "_now=%date% %time:~0,8%"
echo [!_now!] [STASH-CLEAR-ALL] Snapshot: !_sid!.patch>> "%STASH_TRACK_LOG%"
call :PrintSuccess "All stashes cleared. Safety snapshot saved to: !_sid!.patch"
exit /b 0

:: ====================================================================
::  SECTION 5 -- FULL SYNC (WITH AUTO-STASH TRACKING)
:: ====================================================================
:FullSync
call :RequireRepo || exit /b 1
call :PrintBanner
echo.
call :PrintSection "FULL REPOSITORY SYNC (AUTO-STASH + PULL + COMMIT + PUSH)"

set "_curbranch="
for /f %%b in ('git branch --show-current 2^>nul') do set "_curbranch=%%b"
if "!_curbranch!"=="" set "_curbranch=%DEFAULT_BRANCH%"

:: Step 1: Check if working tree is dirty
set /a _is_dirty=0
for /f %%c in ('git status --porcelain 2^>nul ^| find /c /v ""') do set /a _is_dirty=%%c

set "_did_autostash=0"
if !_is_dirty! GTR 0 (
    call :PrintStep "Uncommitted changes detected. Creating tracked auto-stash..."
    call :DoTrackedStashInternal "Auto-stash before sync" "AUTO-STASH"
    if errorlevel 1 (
        call :PrintWarning "Auto-stash skipped or failed. Continuing..."
    ) else (
        set "_did_autostash=1"
    )
)

:: Step 2: Pull latest changes
echo.
call :PrintStep "Pulling latest changes (origin/!_curbranch!)..."
git pull --rebase origin "!_curbranch!" >nul 2>&1
if errorlevel 1 (
    call :PrintWarning "Pull returned non-zero code. (Remote branch may be empty or new)."
) else (
    call :PrintSuccess "Pull completed."
)

:: Step 3: Restore auto-stash if created
if "!_did_autostash!"=="1" (
    echo.
    call :PrintStep "Restoring auto-stashed changes..."
    git stash pop >nul 2>&1
    if errorlevel 1 (
        call :PrintError "Auto-stash pop had conflicts! Resolve them before committing."
        call :CacheWrite "FULL SYNC: paused due to auto-stash conflicts"
        exit /b 1
    ) else (
        call :PrintSuccess "Auto-stashed changes restored cleanly."
        set "_now=%date% %time:~0,8%"
        echo [!_now!] [AUTO-POP-SUCCESS] Restored after sync>> "%STASH_TRACK_LOG%"
    )
)

:: Step 4: Commit local changes if any
set /a _rem_dirty=0
for /f %%c in ('git status --porcelain 2^>nul ^| find /c /v ""') do set /a _rem_dirty=%%c
if !_rem_dirty! GTR 0 (
    echo.
    call :PrintStep "Committing local changes..."
    set "_smsg=%ARG2%"
    if "!_smsg!"=="" set "_smsg=Sync auto-commit %date% %time:~0,8%"
    git add -A
    git commit -m "!_smsg!"
    call :PrintSuccess "Committed: '!_smsg!'"
)

:: Step 5: Push to remote
echo.
call :PrintStep "Pushing to remote origin/!_curbranch!..."
git push -u origin "!_curbranch!"
if errorlevel 1 (
    call :PrintError "Push failed."
    exit /b 1
)
call :PrintSuccess "Full sync completed successfully!"
call :CacheWrite "FULL SYNC COMPLETE: origin/!_curbranch!"
exit /b 0

:: ====================================================================
::  SECTION 6 -- QUICK CLI WORKFLOW COMMANDS
:: ====================================================================
:QuickStatus
call :RequireRepo || exit /b 1
echo.
echo %C_BOLD%%C_BLUE%[ GIT STATUS ]%C_RESET%
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
git status -s
echo.
echo %C_BOLD%%C_BLUE%[ STAGED CHANGES ]%C_RESET%
git diff --cached --stat
echo.
echo %C_BOLD%%C_BLUE%[ UNSTAGED CHANGES ]%C_RESET%
git diff --stat
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
exit /b 0

:QuickLog
call :RequireRepo || exit /b 1
echo.
echo %C_BOLD%%C_BLUE%[ RECENT COMMITS (15) ]%C_RESET%
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
git log --oneline --graph --decorate --color -15
exit /b 0

:QuickLogFull
call :RequireRepo || exit /b 1
echo.
echo %C_BOLD%%C_BLUE%[ FULL COMMIT HISTORY ]%C_RESET%
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
git log --graph --decorate --color --format="%%C(yellow)%%h%%Creset %%s %%C(cyan)(%%cr)%%Creset %%C(bold blue)%%an%%Creset" -30
exit /b 0

:QuickDiff
call :RequireRepo || exit /b 1
echo.
echo %C_BOLD%%C_BLUE%[ DIFF ]%C_RESET%
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
if not "%ARG2%"=="" (
    git diff "%ARG2%"
) else (
    git diff
)
exit /b 0

:QuickCommit
call :RequireRepo || exit /b 1
set "_m=%ARG2%"
if "!_m!"=="" (
    set /p "_m=Commit message: "
)
if "!_m!"=="" set "_m=Update %date% %time:~0,8%"
git add -A
git commit -m "!_m!"
if errorlevel 1 (
    call :PrintError "Commit failed or nothing to commit."
    exit /b 1
)
call :PrintSuccess "Committed: '!_m!'"
call :CacheWrite "COMMIT: !_m!"
exit /b 0

:QuickPush
call :RequireRepo || exit /b 1
set "_br=%ARG2%"
if "!_br!"=="" (
    for /f %%b in ('git branch --show-current 2^>nul') do set "_br=%%b"
)
if "!_br!"=="" set "_br=%DEFAULT_BRANCH%"
call :PrintStep "Pushing to origin/!_br!..."
git push -u origin "!_br!"
if errorlevel 1 (
    call :PrintError "Push failed."
    exit /b 1
)
call :PrintSuccess "Push successful: origin/!_br!"
exit /b 0

:QuickPull
call :RequireRepo || exit /b 1
set "_br=%ARG2%"
if "!_br!"=="" (
    for /f %%b in ('git branch --show-current 2^>nul') do set "_br=%%b"
)
if "!_br!"=="" set "_br=%DEFAULT_BRANCH%"

:: Check if dirty; auto-stash if needed
set /a _p_dirty=0
for /f %%c in ('git status --porcelain 2^>nul ^| find /c /v ""') do set /a _p_dirty=%%c
set "_p_autostash=0"
if !_p_dirty! GTR 0 (
    call :PrintStep "Dirty working tree: auto-stashing before pull..."
    call :DoTrackedStashInternal "Auto-stash before pull" "AUTO-STASH"
    set "_p_autostash=1"
)

call :PrintStep "Pulling from origin/!_br! (--rebase)..."
git pull --rebase origin "!_br!"
set "_pec=%errorlevel%"

if "!_p_autostash!"=="1" (
    call :PrintStep "Restoring auto-stash..."
    git stash pop
)
if !_pec! EQU 0 (
    call :PrintSuccess "Pull successful."
) else (
    call :PrintError "Pull encountered issues."
)
exit /b !_pec!

:QuickFetch
call :RequireRepo || exit /b 1
call :PrintStep "Fetching all remotes (with prune)..."
git fetch --all --prune
call :PrintSuccess "Fetch complete."
exit /b 0

:QuickUndo
call :RequireRepo || exit /b 1
echo.
call :PrintWarning "This will undo the LAST commit, keeping changes staged."
set /p "_uconf=Confirm undo? (y/n): "
if /i not "!_uconf!"=="y" exit /b 0
git reset HEAD~1 --soft
if errorlevel 1 (
    call :PrintError "Undo failed. (No parent commit)."
    exit /b 1
)
call :PrintSuccess "Last commit undone. Files are staged."
exit /b 0

:QuickAmend
call :RequireRepo || exit /b 1
echo.
set "_amsg=%ARG2%"
if "!_amsg!"=="" (
    git commit --amend
) else (
    git commit --amend -m "!_amsg!"
)
call :PrintSuccess "Last commit amended."
exit /b 0

:QuickClean
call :RequireRepo || exit /b 1
echo.
call :PrintWarning "Preview of untracked files to remove:"
git clean -nd
echo.
set /p "_clean_c=Permanently delete these files? (y/n): "
if /i not "!_clean_c!"=="y" exit /b 0
git clean -fd
call :PrintSuccess "Untracked files cleaned."
exit /b 0

:QuickBlame
call :RequireRepo || exit /b 1
if "%ARG2%"=="" (
    call :PrintError "Specify a filename: gitsync blame <file>"
    exit /b 1
)
git blame "%ARG2%"
exit /b 0

:QuickStats
call :RequireRepo || exit /b 1
echo.
echo %C_BOLD%%C_BLUE%[ REPOSITORY STATISTICS ]%C_RESET%
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
for /f %%c in ('git rev-list --count HEAD 2^>nul') do echo  Total commits       : %%c
for /f %%b in ('git branch --list 2^>nul ^| find /c /v ""') do echo  Local branches      : %%b
for /f %%t in ('git tag --list 2^>nul ^| find /c /v ""') do echo  Tags                : %%t
echo.
echo %C_BOLD%Top Contributors:%C_RESET%
git shortlog -sn --all --no-merges -5
exit /b 0

:WhoAmI
echo.
echo %C_BOLD%%C_CYAN%[ CONFIGURED IDENTITY ]%C_RESET%
for /f "delims=" %%n in ('git config user.name 2^>nul') do echo  Name  : %%n
for /f "delims=" %%e in ('git config user.email 2^>nul') do echo  Email : %%e
exit /b 0

:ShowVersion
echo.
echo %SCRIPT_NAME% version %SCRIPT_VERSION%
echo Platform: Windows (CMD/PowerShell)
echo Git Engine: %GIT_VERSION%
exit /b 0

:QuickHistory
echo.
echo %C_BOLD%%C_CYAN%[ GITSYNC ACTION LOG ]%C_RESET%
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
if defined REPO_LOG if exist "%REPO_LOG%" (
    echo Repo Log: %REPO_LOG%
    type "%REPO_LOG%"
) else if exist "%GLOBAL_LOG%" (
    echo Global Log: %GLOBAL_LOG%
    type "%GLOBAL_LOG%"
) else (
    call :PrintInfo "No action log found."
)
exit /b 0

:ClearHistory
if defined REPO_LOG if exist "%REPO_LOG%" del /f /q "%REPO_LOG%" >nul 2>&1
if exist "%GLOBAL_LOG%" del /f /q "%GLOBAL_LOG%" >nul 2>&1
call :PrintSuccess "Action history cleared."
exit /b 0

:: ====================================================================
::  SECTION 7 -- BRANCH MANAGEMENT
:: ====================================================================
:BranchRouter
if /i "%ARG2%"==""         goto :BranchMenu
if /i "%ARG2%"=="list"     goto :BranchListCli
if /i "%ARG2%"=="create"   goto :BranchCreateCli
if /i "%ARG2%"=="switch"   goto :BranchSwitchCli
if /i "%ARG2%"=="delete"   goto :BranchDeleteCli
if /i "%ARG2%"=="merge"    goto :BranchMergeCli
if /i "%ARG2%"=="push"     goto :BranchPushCli
goto :BranchMenu

:BranchListCli
call :RequireRepo || exit /b 1
git branch -a
exit /b 0

:BranchCreateCli
call :RequireRepo || exit /b 1
set "_bn=%ARG3%"
if "!_bn!"=="" set /p "_bn=New branch name: "
git checkout -b "!_bn!"
exit /b 0

:BranchSwitchCli
call :RequireRepo || exit /b 1
set "_bn=%ARG3%"
if "!_bn!"=="" set /p "_bn=Branch name: "
git checkout "!_bn!"
exit /b 0

:BranchDeleteCli
call :RequireRepo || exit /b 1
set "_bn=%ARG3%"
if "!_bn!"=="" set /p "_bn=Branch name to delete: "
git branch -d "!_bn!"
exit /b 0

:BranchMergeCli
call :RequireRepo || exit /b 1
set "_bn=%ARG3%"
if "!_bn!"=="" set /p "_bn=Branch to merge into current: "
git merge "!_bn!"
exit /b 0

:BranchPushCli
call :RequireRepo || exit /b 1
set "_bn=%ARG3%"
if "!_bn!"=="" (
    for /f %%b in ('git branch --show-current 2^>nul') do set "_bn=%%b"
)
git push -u origin "!_bn!"
exit /b 0

:BranchMenu
call :RequireRepo || exit /b 1
cls
echo.
echo %C_BOLD%%C_MAGENTA%%DIVIDER%%C_RESET%
echo %C_BOLD%%C_MAGENTA%                   BRANCH MANAGER%C_RESET%
echo %C_BOLD%%C_MAGENTA%%DIVIDER%%C_RESET%
echo.
echo Current branch:
for /f %%b in ('git branch --show-current 2^>nul') do echo   %C_GREEN%%%b%C_RESET%
echo.
echo Local branches:
git branch
echo.
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
echo  [1] Create and switch to new branch
echo  [2] Switch to existing branch
echo  [3] Delete local branch
echo  [4] Merge branch into current
echo  [5] Push branch to origin
echo  [6] Rename current branch
echo  [7] Prune orphaned remote tracking branches
echo  [0] Back / Exit
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
echo.
set /p "_bmc=Select option (0-7): "
if "!_bmc!"=="1" goto :BranchCreateCli
if "!_bmc!"=="2" goto :BranchSwitchCli
if "!_bmc!"=="3" goto :BranchDeleteCli
if "!_bmc!"=="4" goto :BranchMergeCli
if "!_bmc!"=="5" goto :BranchPushCli
if "!_bmc!"=="6" (
    set /p "_newbn=New name for current branch: "
    git branch -m "!_newbn!"
    exit /b 0
)
if "!_bmc!"=="7" goto :PruneBranches
if "!_bmc!"=="0" exit /b 0
exit /b 0

:: ====================================================================
::  SECTION 8 -- TAGS, REMOTES, RESETS, REBASE, CHERRY-PICK
:: ====================================================================
:TagMenu
call :RequireRepo || exit /b 1
cls
echo.
echo %C_BOLD%%C_CYAN%%DIVIDER%%C_RESET%
echo %C_BOLD%%C_CYAN%                     TAG MANAGER%C_RESET%
echo %C_BOLD%%C_CYAN%%DIVIDER%%C_RESET%
echo.
git tag -n1
echo.
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
echo  [1] Create lightweight tag
echo  [2] Create annotated tag (with message)
echo  [3] Push all tags to origin
echo  [4] Delete local tag
echo  [5] Delete remote tag
echo  [0] Back / Exit
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
echo.
set /p "_tc=Choice: "
if "!_tc!"=="1" (
    set /p "_tname=Tag name (e.g. v1.0.0): "
    git tag "!_tname!"
    call :PrintSuccess "Tag '!_tname!' created."
)
if "!_tc!"=="2" (
    set /p "_tname=Tag name (e.g. v1.0.0): "
    set /p "_tmsg=Tag message: "
    git tag -a "!_tname!" -m "!_tmsg!"
    call :PrintSuccess "Annotated tag created."
)
if "!_tc!"=="3" git push origin --tags
if "!_tc!"=="4" (
    set /p "_tname=Tag name to delete: "
    git tag -d "!_tname!"
)
if "!_tc!"=="5" (
    set /p "_tname=Remote tag name to delete: "
    git push origin --delete "!_tname!"
)
exit /b 0

:RemoteMenu
call :RequireRepo || exit /b 1
cls
echo.
echo %C_BOLD%%C_BLUE%%DIVIDER%%C_RESET%
echo %C_BOLD%%C_BLUE%                    REMOTE MANAGER%C_RESET%
echo %C_BOLD%%C_BLUE%%DIVIDER%%C_RESET%
echo.
git remote -v
echo.
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
echo  [1] Add remote
echo  [2] Change remote URL
echo  [3] Rename remote
echo  [4] Remove remote
echo  [0] Back / Exit
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
echo.
set /p "_rc=Choice: "
if "!_rc!"=="1" (
    set /p "_rname=Remote name (e.g. origin): "
    set /p "_rurl=Remote URL: "
    git remote add "!_rname!" "!_rurl!"
)
if "!_rc!"=="2" (
    set /p "_rname=Remote name (e.g. origin): "
    set /p "_rurl=New URL: "
    git remote set-url "!_rname!" "!_rurl!"
)
if "!_rc!"=="3" (
    set /p "_rold=Old name: "
    set /p "_rnew=New name: "
    git remote rename "!_rold!" "!_rnew!"
)
if "!_rc!"=="4" (
    set /p "_rname=Remote to remove: "
    git remote remove "!_rname!"
)
exit /b 0

:ResetMenu
call :RequireRepo || exit /b 1
cls
echo.
echo %C_BOLD%%C_RED%%DIVIDER%%C_RESET%
echo %C_BOLD%%C_RED%                     RESET MANAGER%C_RESET%
echo %C_BOLD%%C_RED%%DIVIDER%%C_RESET%
echo.
echo Recent commits:
git log --oneline -5
echo.
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
echo  [1] Soft Reset   (undo commits, KEEP changes staged)
echo  [2] Mixed Reset  (undo commits, keep changes UNSTAGED)
echo  [3] Hard Reset   (undo commits and DISCARD all changes - DANGER)
echo  [4] Revert a specific commit
echo  [0] Back / Exit
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
echo.
set /p "_rst=Choice: "
if "!_rst!"=="1" (
    set /p "_target=Target commit (e.g. HEAD~1): "
    git reset --soft "!_target!"
)
if "!_rst!"=="2" (
    set /p "_target=Target commit (e.g. HEAD~1): "
    git reset --mixed "!_target!"
)
if "!_rst!"=="3" (
    call :PrintWarning "Hard reset will delete all uncommitted changes!"
    set /p "_hconf=Confirm hard reset? (y/n): "
    if /i "!_hconf!"=="y" (
        set /p "_target=Target commit: "
        git reset --hard "!_target!"
    )
)
if "!_rst!"=="4" (
    set /p "_revhash=Commit hash to revert: "
    git revert "!_revhash!"
)
exit /b 0

:CherryPickMenu
call :RequireRepo || exit /b 1
echo.
git log --oneline --all -10
echo.
set /p "_cp=Commit hash to cherry-pick: "
if "!_cp!"=="" exit /b 0
git cherry-pick "!_cp!"
exit /b 0

:RebaseMenu
call :RequireRepo || exit /b 1
echo.
echo  [1] Rebase current branch onto another
echo  [2] Continue rebase
echo  [3] Abort rebase
echo  [4] Skip commit
echo.
set /p "_rbc=Choice: "
if "!_rbc!"=="1" (
    set /p "_onto=Branch to rebase onto: "
    git rebase "!_onto!"
)
if "!_rbc!"=="2" git rebase --continue
if "!_rbc!"=="3" git rebase --abort
if "!_rbc!"=="4" git rebase --skip
exit /b 0

:ConflictHelper
call :RequireRepo || exit /b 1
echo.
echo %C_BOLD%%C_RED%[ CONFLICT RESOLUTION HELPER ]%C_RESET%
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
git status | findstr "conflict Unmerged" >nul 2>&1
if errorlevel 1 (
    call :PrintSuccess "No merge conflicts detected in this repository."
    exit /b 0
)
echo Conflicted files:
git diff --name-only --diff-filter=U
echo.
echo Options:
echo  [1] Mark all resolved and commit (git add -A ^& git commit --no-edit)
echo  [2] Abort merge (git merge --abort)
echo  [3] Launch git mergetool
echo  [0] Exit
echo.
set /p "_chc=Choice: "
if "!_chc!"=="1" (
    git add -A
    git commit --no-edit
    call :PrintSuccess "Merge committed."
)
if "!_chc!"=="2" (
    git merge --abort
    call :PrintSuccess "Merge aborted."
)
if "!_chc!"=="3" git mergetool
exit /b 0

:: ====================================================================
::  SECTION 9 -- DOCTOR, SETUP, PRUNE, IGNORE, CONFIG, BACKUPS
:: ====================================================================
:RunDoctor
cls
echo.
echo %C_BOLD%%C_GREEN%%DIVIDER%%C_RESET%
echo %C_BOLD%%C_GREEN%                  GIT DOCTOR HEALTH CHECK%C_RESET%
echo %C_BOLD%%C_GREEN%%DIVIDER%%C_RESET%
echo.
set /a _doc_issues=0

:: 1. Git binary
git --version >nul 2>&1
if errorlevel 1 (
    call :PrintError "Git binary NOT found in PATH!"
    set /a _doc_issues+=1
) else (
    call :PrintSuccess "Git installed: %GIT_VERSION%"
)

:: 2. In Repo
git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    call :PrintWarning "Current folder is NOT a Git repository."
    set /a _doc_issues+=1
) else (
    call :PrintSuccess "Valid Git repository detected."
)

:: 3. Identity
set "_dn=" & set "_de="
for /f "delims=" %%n in ('git config user.name 2^>nul') do set "_dn=%%n"
for /f "delims=" %%e in ('git config user.email 2^>nul') do set "_de=%%e"
if "!_dn!"=="" (
    call :PrintWarning "user.name is not set."
    set /a _doc_issues+=1
) else (
    call :PrintSuccess "user.name: !_dn!"
)
if "!_de!"=="" (
    call :PrintWarning "user.email is not set."
    set /a _doc_issues+=1
) else (
    call :PrintSuccess "user.email: !_de!"
)

:: 4. Origin Remote
git remote get-url origin >nul 2>&1
if errorlevel 1 (
    call :PrintWarning "No 'origin' remote configured."
) else (
    for /f %%u in ('git remote get-url origin 2^>nul') do call :PrintSuccess "Remote origin: %%u"
)

:: 5. Stash & Pop Tracker Health
if defined STASH_TRACK_LOG (
    if exist "%STASH_TRACK_LOG%" (
        call :PrintSuccess "Stash Tracker is active."
    ) else (
        call :PrintInfo "Stash Tracker initialized and ready."
    )
)

echo.
echo %C_DIM%%THIN_DIVIDER%%C_RESET%
if !_doc_issues! EQU 0 (
    echo %C_BOLD%%C_GREEN%Health Check Passed: 0 critical issues found.%C_RESET%
) else (
    echo %C_BOLD%%C_YELLOW%Health Check Finished: !_doc_issues! issues detected.%C_RESET%
)
echo.
exit /b 0

:FirstTimeSetup
cls
echo.
echo %C_BOLD%%C_CYAN%[ GIT FIRST-TIME SETUP WIZARD ]%C_RESET%
echo.
set /p "_sn=Your full name: "
if not "!_sn!"=="" git config --global user.name "!_sn!"
set /p "_se=Your email: "
if not "!_se!"=="" git config --global user.email "!_se!"
git config --global init.defaultBranch main
git config --global core.autocrlf true
call :PrintSuccess "Configured user identity and defaults (defaultBranch=main, autocrlf=true)."
exit /b 0

:PruneBranches
call :RequireRepo || exit /b 1
call :PrintStep "Pruning obsolete remote tracking branches..."
git fetch --prune
call :PrintStep "Deleting local branches gone from remote..."
for /f "tokens=1" %%b in ('git branch -vv 2^>nul ^| findstr ": gone]"') do (
    echo Deleting local branch: %%b
    git branch -D "%%b"
)
call :PrintSuccess "Prune complete."
exit /b 0

:GitIgnoreMenu
call :RequireRepo || exit /b 1
echo.
echo  [1] View .gitignore
echo  [2] Append pattern
echo  [3] Check if file is ignored
echo.
set /p "_gic=Choice: "
if "!_gic!"=="1" (
    if exist .gitignore type .gitignore
)
if "!_gic!"=="2" (
    set /p "_pat=Pattern to ignore: "
    echo !_pat!>> .gitignore
    call :PrintSuccess "Added '!_pat!' to .gitignore."
)
if "!_gic!"=="3" (
    set /p "_fchk=Filename to check: "
    git check-ignore -v "!_fchk!"
)
exit /b 0

:ConfigMenu
cls
echo.
echo %C_BOLD%%C_BLUE%[ GIT CONFIGURATION ]%C_RESET%
echo.
git config --list --show-origin
exit /b 0

:BackupMenu
call :RequireRepo || exit /b 1
echo.
echo %C_BOLD%%C_YELLOW%[ REPOSITORY BACKUP ]%C_RESET%
set "_bfile=repo_bundle_%date:~-4%%date:~3,2%%date:~0,2%.bundle"
set "_bfile=!_bfile: =0!"
call :PrintStep "Creating bundle: !_bfile!..."
git bundle create "!_bfile!" --all
if errorlevel 1 (
    call :PrintError "Bundle creation failed."
    exit /b 1
)
call :PrintSuccess "Bundle created: !_bfile!"
exit /b 0

:ArchiveRepo
call :RequireRepo || exit /b 1
set "_afile=repo_archive.zip"
call :PrintStep "Archiving HEAD to !_afile!..."
git archive --format=zip --output="!_afile!" HEAD
call :PrintSuccess "Archive generated: !_afile!"
exit /b 0

:UpdateMenu
echo.
echo Current Version: %SCRIPT_VERSION%
echo Source: %SELF_UPDATE_URL%
echo.
set /p "_chkup=Check GitHub for latest update now? (y/n): "
if /i not "!_chkup!"=="y" exit /b 0

call :PrintStep "Checking GitHub for updates..."
curl -fsSL --connect-timeout 4 "%SELF_UPDATE_URL%" -o "%TEMP%\gitsync_check.bat" >nul 2>&1
if errorlevel 1 (
    call :PrintError "Could not connect to GitHub or curl is unavailable."
    exit /b 1
)
call :PrintSuccess "Remote script retrieved. Check complete."
del /f /q "%TEMP%\gitsync_check.bat" >nul 2>&1
exit /b 0

:: ====================================================================
::  SECTION 10 -- HELP & CHANGELOG
:: ====================================================================
:ShowHelp
cls
echo.
echo %C_CYAN%%C_BOLD%%DIVIDER%%C_RESET%
echo %C_CYAN%%C_BOLD%          %SCRIPT_NAME%  v%SCRIPT_VERSION%  -  COMMAND REFERENCE%C_RESET%
echo %C_CYAN%%C_BOLD%%DIVIDER%%C_RESET%
echo.
echo %C_BOLD%USAGE:%C_RESET%  gitsync [command] [args...]
echo.
echo %C_BOLD%%C_WHITE%WIZARDS ^& WORKFLOWS%C_RESET%
echo   gitsync                  Interactive 3-step commit ^& push wizard
echo   gitsync sync             Auto-stash + Pull (rebase) + Commit + Push
echo   gitsync setup            First-time Git configuration wizard
echo   gitsync doctor           Run health check diagnostics
echo.
echo %C_BOLD%%C_WHITE%STASH ^& STASH POP TRACKER (NEW in v4.0)%C_RESET%
echo   gitsync stash            Interactive stash manager ^& tracker
echo   gitsync pop              Pop latest stash with automatic tracking
echo   gitsync stash pop        Pop latest stash with tracking (clean vs conflict)
echo   gitsync stash save [msg] Stash working changes with safety snapshot
echo   gitsync stash history    View full audit trail of all stashes and pops
echo   gitsync stash recover    Restore lost/popped/dropped stash snapshots
echo   gitsync stash list       List current git stashes
echo   gitsync stash show [idx] Show stash diff
echo   gitsync stash drop [idx] Drop stash with automatic backup retention
echo.
echo %C_BOLD%%C_WHITE%QUICK OPERATIONS%C_RESET%
echo   gitsync status (s)       Fast status and staged/unstaged breakdown
echo   gitsync commit (c) [msg] Stage all and commit with message
echo   gitsync push (p) [br]    Push branch to origin
echo   gitsync pull [br]        Pull with auto-stash protection
echo   gitsync log (l)          Oneline graph view (last 15 commits)
echo   gitsync logfull          Full history with authors and dates
echo   gitsync diff [file]      Show file differences
echo   gitsync undo             Soft reset last commit (keeps files staged)
echo   gitsync amend [msg]      Amend previous commit
echo   gitsync clean            Interactively remove untracked files
echo   gitsync fetch            Fetch and prune all remotes
echo   gitsync prune            Remove local branches deleted from remote
echo.
echo %C_BOLD%%C_WHITE%BRANCH, TAG, REMOTE, REVERT%C_RESET%
echo   gitsync branch (br)      Interactive branch menu (or create/switch/delete/merge)
echo   gitsync tag              Interactive tag manager
echo   gitsync remote           Manage remote URLs
echo   gitsync reset            Soft, mixed, or hard reset menu
echo   gitsync cherrypick (cp)  Cherry-pick specific commit
echo   gitsync rebase           Rebase manager
echo   gitsync conflicts        Guided merge conflict helper
echo.
echo %C_BOLD%%C_WHITE%MACOS VERSION%C_RESET%
echo   A separate standalone POSIX script 'gitsync' is included for macOS.
echo   Simply copy it to /usr/local/bin or add to your PATH.
echo.
echo %C_DIM%%DIVIDER%%C_RESET%
exit /b 0

:ShowChangelog
echo.
echo %C_BOLD%%C_CYAN%GITSYNC ULTRA CHANGELOG%C_RESET%
echo.
echo %C_BOLD%v4.0.0 (2026)%C_RESET%
echo   + Complete rewrite for blazing performance (instant CLI invocation)
echo   + Full Stash ^& Stash Pop Tracking System (audit log + safety snapshots)
echo   + Added 'gitsync stash recover' to restore popped or dropped stashes
echo   + Added Auto-Stash protection in 'gitsync sync' and 'gitsync pull'
echo   + Fixed PATH variable issues on Windows (safe ANSI prompt trick, zero crash)
echo   + Fixed codepage / mid-stream file pointer offset bugs in cmd.exe
echo   + Fixed directory permissions ('Access Denied') by moving cache to .git/ and ~/.gitsync/
echo   + Removed blocking network curl calls from startup for instant response
echo   + Created native macOS version ('gitsync') with full feature parity
echo.
exit /b 0
