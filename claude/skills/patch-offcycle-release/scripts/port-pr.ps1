#!/usr/bin/env pwsh
# port-pr.ps1 - Cherry-pick a merged GitHub PR into one or more releases/* branches.
#
# Usage:
#   port-pr.ps1 -PR <PR_NUMBER> [-UAT <branch>] [-PPE <branch>] [-Prod <branch>]
#               [-Resume <branch>]
#
# Options:
#   -PR      PR number that was merged into `release`           (required)
#   -UAT     Override the UAT releases/* branch (auto-discovered if omitted)
#   -PPE     Override the PPE releases/* branch (auto-discovered if omitted)
#   -Prod    Override the Prod releases/* branch (auto-discovered if omitted)
#   -Resume  Skip to this specific target branch (after conflict resolution)
#
# Branch auto-discovery:
#   When -UAT / -PPE / -Prod are omitted the script fetches the deployed version
#   from each environment's version endpoint, strips any sub-patch suffix, and
#   constructs the releases/* branch name automatically.  It then resolves the
#   latest patch in that <MAJOR>.<MINOR> series from the remote.
#
#   UAT:  https://author-p163316-e1779207.adobeaemcloud.com/content/tr-settings/endpointsMapping/version.json
#   PPE:  https://author-p163316-e1779165.adobeaemcloud.com/content/tr-settings/endpointsMapping/version.json
#   Prod: https://author-p163316-e1779099.adobeaemcloud.com/content/tr-settings/endpointsMapping/version.json

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PR,

    [string]$UAT    = "",
    [string]$PPE    = "",
    [string]$Prod   = "",
    [string]$Resume = ""
)

$ErrorActionPreference = 'Stop'

# -- helpers ------------------------------------------------------------------

function Die {
    param([string]$Message)
    [Console]::Error.WriteLine("ERROR: $Message")
    exit 1
}

function Info {
    param([string]$Message)
    Write-Host "==> $Message"
}

function Warn {
    param([string]$Message)
    [Console]::Error.WriteLine("WARN: $Message")
}

# Invoke git and abort on non-zero exit.
function Invoke-SafeGit {
    param([string[]]$Arguments)
    & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        Die "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

# safe_push <port-branch>
#
# Aborts with an error if the destination looks like a releases/* branch
# (belt-and-suspenders guard against accidental pushes to protected
# release branches).
function Invoke-SafePush {
    param([string]$PortBranch)
    if ($PortBranch -like "releases/*") {
        Die "Invoke-SafePush: refusing to push to '$PortBranch' — destination must not be a releases/* branch."
    }
    Invoke-SafeGit @("push", "origin", "HEAD:refs/heads/$PortBranch")
}

function Assert-CommandExists {
    param([string]$Command)
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        Die "'$Command' is required but not found."
    }
}

# -- latest-patch resolver ----------------------------------------------------
#
# Given a branch name like "releases/5.85.7", scan all remote branches that share
# the same <MAJOR>.<MINOR> prefix ("releases/5.85.*") and return the one with the
# highest <PATCH> number.  If the supplied branch IS already the latest, it is
# returned unchanged.  If no remote branches match the prefix at all, the supplied
# branch is returned as-is (and a warning is emitted).
#
# Usage: Resolve-LatestPatch "releases/5.85.7"  ->  "releases/5.85.17"

function Resolve-LatestPatch {
    param([string]$InputBranch)

    # Extract the version part, e.g. "5.85.7"
    $version    = $InputBranch -replace '^releases/', ''
    $parts      = $version.Split('.')
    $majorMinor = "$($parts[0]).$($parts[1])"
    [int]$bestPatch = [int]$parts[2]
    $bestBranch = $InputBranch
    $prefix     = "releases/$majorMinor."

    # git branch -r output lines look like "  origin/releases/5.85.17"
    $remoteBranches = & git branch -r
    foreach ($line in $remoteBranches) {
        $remoteBranch = $line.Trim() -replace '^origin/', ''
        if (-not $remoteBranch.StartsWith($prefix)) { continue }

        $candidatePatch = $remoteBranch.Substring($prefix.Length)

        # Accept only pure numeric patch values
        if ($candidatePatch -notmatch '^\d+$') { continue }

        [int]$candidatePatchInt = [int]$candidatePatch
        if ($candidatePatchInt -gt $bestPatch) {
            $bestPatch  = $candidatePatchInt
            $bestBranch = "releases/$majorMinor.$candidatePatch"
        }
    }

    if ($bestBranch -ne $InputBranch) {
        Warn "Patch upgrade: '$InputBranch' -> '$bestBranch' (latest in $majorMinor.x series)"
    }
    else {
        Write-Host "==> $InputBranch is already the latest patch in $majorMinor.x series"
    }

    return $bestBranch
}

# -- environment version discovery --------------------------------------------
#
# Fetches the deployed version string from an AEM environment's version endpoint
# and returns only the first three dot-separated segments (MAJOR.MINOR.PATCH),
# discarding any sub-patch suffix (e.g. "5.83.86.2026_0724_..." -> "5.83.86").
#
# Usage: Fetch-EnvVersion <url> <env-label>

$UAT_VERSION_URL  = "https://author-p163316-e1779207.adobeaemcloud.com/content/tr-settings/endpointsMapping/version.json"
$PPE_VERSION_URL  = "https://author-p163316-e1779165.adobeaemcloud.com/content/tr-settings/endpointsMapping/version.json"
$PROD_VERSION_URL = "https://author-p163316-e1779099.adobeaemcloud.com/content/tr-settings/endpointsMapping/version.json"

function Fetch-EnvVersion {
    param(
        [string]$Url,
        [string]$Label
    )

    try {
        # Invoke-RestMethod automatically parses JSON responses into PSCustomObject
        $response = Invoke-RestMethod -Uri $Url -Method Get
    }
    catch {
        Die "Failed to fetch version for $Label from $Url : $_"
    }

    $version = $null

    if ($response -is [PSCustomObject] -and $response.PSObject.Properties['version']) {
        $version = [string]$response.version
    }

    # Fallback: stringify and regex-extract a bare version token
    if ([string]::IsNullOrWhiteSpace($version)) {
        $rawStr = $response | ConvertTo-Json -Compress -Depth 10
        if ($rawStr -match '(\d+\.\d+\.\d+[^""]*)') {
            $version = $Matches[1]
        }
    }

    if ([string]::IsNullOrWhiteSpace($version)) {
        Die "Could not parse version for $Label from response."
    }

    # Keep only MAJOR.MINOR.PATCH - discard everything from the 4th segment onward
    $trimmed = ($version.Split('.') | Select-Object -First 3) -join '.'

    Write-Host "==> Discovered $Label version: $version -> using $trimmed"
    return $trimmed
}

# -- preflight ----------------------------------------------------------------

Assert-CommandExists "git"
Assert-CommandExists "gh"

# Check for unmerged files or uncommitted changes before touching any branches.
$unmergedOutput = & git ls-files --unmerged
if ($unmergedOutput) {
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("ERROR: Your working tree has unmerged files. Resolve them before running this script.")
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("Please review the following files:")
    # Last whitespace-delimited field on each line is the file path
    $unmergedFiles = $unmergedOutput |
        ForEach-Object { ($_ -split '\s+')[-1] } |
        Sort-Object -Unique
    foreach ($f in $unmergedFiles) {
        [Console]::Error.WriteLine("  $f")
    }
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("Options:")
    [Console]::Error.WriteLine("  1. Resolve conflicts, then: git add <files> && git commit")
    [Console]::Error.WriteLine("  2. Abort any in-progress cherry-pick/merge: git cherry-pick --abort  OR  git merge --abort")
    [Console]::Error.WriteLine("  3. Discard changes (destructive): git checkout -- <files>")
    exit 1
}

# Check for modified-but-not-staged files (working tree differs from index).
$unstagedFiles = & git diff --name-only
if ($unstagedFiles) {
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("ERROR: You have modified files that have not been staged:")
    [Console]::Error.WriteLine("")
    foreach ($f in $unstagedFiles) {
        [Console]::Error.WriteLine("  $f")
    }
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("Options:")
    [Console]::Error.WriteLine("  1. Stage and commit:      git add <files> && git commit -m 'WIP'")
    [Console]::Error.WriteLine("  2. Stash (recommended):   git stash push -u -m 'stash before port'")
    [Console]::Error.WriteLine("  3. Discard (destructive): git checkout -- <files>")
    exit 1
}

# Check for remaining uncommitted changes (staged but not committed).
# Untracked files (??) are intentionally excluded — they cannot affect cherry-picks.
$dirty = (& git status --porcelain) | Where-Object { $_ -notmatch '^\?\?' }
if ($dirty) {
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("ERROR: Your working tree has uncommitted changes. Commit or stash them before running this script.")
    [Console]::Error.WriteLine("")
    & git status --short
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("Options:")
    [Console]::Error.WriteLine("  1. Commit:                git add -A && git commit -m 'WIP'")
    [Console]::Error.WriteLine("  2. Stash (recommended):   git stash push -u -m 'stash before port'")
    [Console]::Error.WriteLine("  3. Discard (destructive): git checkout -- . && git clean -fd")
    exit 1
}

Info "Verifying PR #$PR..."
$prJsonRaw = (& gh pr view $PR --json state,baseRefName) -join ""
if ($LASTEXITCODE -ne 0) { Die "Failed to fetch PR info for #$PR" }
$prJson = $prJsonRaw | ConvertFrom-Json
$prState = $prJson.state
if ($prState -ne "MERGED" -and $prState -ne "CLOSED") {
    Die "PR #$PR must be merged or closed to be ported (state: $prState)."
}
if ($prJson.baseRefName -ne "release") {
    Die "PR #$PR is not targeting 'release' (base branch: $($prJson.baseRefName)). Only PRs targeting 'release' can be ported."
}

Info "Fetching latest remote state..."
Invoke-SafeGit @("fetch", "--all", "--prune")

# -- resolve latest patch per environment -------------------------------------

Info "Discovering deployed versions..."
if ([string]::IsNullOrEmpty($UAT)) {
    $uatVersion = Fetch-EnvVersion -Url $UAT_VERSION_URL -Label "UAT"
    $UAT = "releases/$uatVersion"
}
if ([string]::IsNullOrEmpty($PPE)) {
    $ppeVersion = Fetch-EnvVersion -Url $PPE_VERSION_URL -Label "PPE"
    $PPE = "releases/$ppeVersion"
}
if ([string]::IsNullOrEmpty($Prod)) {
    $prodVersion = Fetch-EnvVersion -Url $PROD_VERSION_URL -Label "Prod"
    $Prod = "releases/$prodVersion"
}

Info "Resolving latest patch in each MAJOR.MINOR series..."
$UAT  = Resolve-LatestPatch $UAT
$PPE  = Resolve-LatestPatch $PPE
$Prod = Resolve-LatestPatch $Prod

# -- collect commits ----------------------------------------------------------

$commitsJsonRaw = (& gh pr view $PR --json commits) -join ""
if ($LASTEXITCODE -ne 0) { Die "Failed to fetch commits for PR #$PR" }
$commits = @(
    ($commitsJsonRaw | ConvertFrom-Json).commits |
    ForEach-Object { $_.oid } |
    Where-Object { $_ }
)

$useMergeParent = $false

if ($commits.Count -eq 0) {
    if ($prState -eq "MERGED") {
        Warn "No individual commits found; falling back to merge commit with -m 1."
        $mergeCommitJsonRaw = (& gh pr view $PR --json mergeCommit) -join ""
        if ($LASTEXITCODE -ne 0) { Die "Failed to fetch merge commit for PR #$PR" }
        $mergeSha = ($mergeCommitJsonRaw | ConvertFrom-Json).mergeCommit.oid
        if ([string]::IsNullOrEmpty($mergeSha)) {
            Die "Could not determine merge commit SHA for PR #$PR."
        }
        $commits = @($mergeSha)
        $useMergeParent = $true
    }
    else {
        Die "No commits found for closed PR #$PR. The head branch may have been deleted."
    }
}

Info "Commits to port ($($commits.Count)):"
foreach ($sha in $commits) {
    Write-Host "  $sha"
}

# -- build target list --------------------------------------------------------

$envLabels   = [System.Collections.Generic.List[string]]@("UAT", "PPE")
$envBranches = [System.Collections.Generic.List[string]]@($UAT, $PPE)

$ppeCoversProd = $false
if ($Prod -eq $PPE) {
    Info "Prod ($Prod) == PPE ($PPE) after patch resolution - skipping duplicate Prod port."
    $ppeCoversProd = $true
}
else {
    Info "Prod ($Prod) differs from PPE ($PPE) - adding separate Prod target."
    $envLabels.Add("Prod")
    $envBranches.Add($Prod)
}

# -- port-branch collision check ----------------------------------------------
# Fail fast if ANY local port branch already exists for this PR across ALL
# target environments.  The user must delete stale branches manually so there
# is no risk of accidentally reusing or overwriting prior work.

$existingPortBranches = @()
for ($i = 0; $i -lt $envLabels.Count; $i++) {
    $pb = "port/pr-$PR-to-$($envBranches[$i] -replace '/', '-')"
    $null = & git show-ref --verify --quiet "refs/heads/$pb" 2>&1
    if ($LASTEXITCODE -eq 0) {
        $existingPortBranches += $pb
    }
}

if ($existingPortBranches.Count -gt 0) {
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("ERROR: The following local port branch(es) already exist for PR #$PR :")
    [Console]::Error.WriteLine("")
    foreach ($b in $existingPortBranches) {
        [Console]::Error.WriteLine("  $b")
    }
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("Please delete them manually before running this script again:")
    [Console]::Error.WriteLine("")
    foreach ($b in $existingPortBranches) {
        [Console]::Error.WriteLine("  git branch -D $b")
    }
    [Console]::Error.WriteLine("")
    exit 1
}

# -- cherry-pick loop ---------------------------------------------------------

$repoJsonRaw = (& gh repo view --json url) -join ""
if ($LASTEXITCODE -ne 0) { Die "Failed to fetch repo URL" }
$repoUrl = ($repoJsonRaw | ConvertFrom-Json).url

$skipping = -not [string]::IsNullOrEmpty($Resume)

for ($i = 0; $i -lt $envLabels.Count; $i++) {
    $envLabel     = $envLabels[$i]
    $targetBranch = $envBranches[$i]

    if ($skipping) {
        if ($targetBranch -eq $Resume) {
            $skipping = $false
        }
        else {
            Info "Skipping $envLabel ($targetBranch) - resuming at $Resume."
            continue
        }
    }

    $portBranch = "port/pr-$PR-to-$($targetBranch -replace '/', '-')"

    Info "--------------------------------------------------"
    Info "Environment : $envLabel"
    Info "Target      : $targetBranch"
    Info "Port branch : $portBranch"
    Info "--------------------------------------------------"

    # Check out the port branch from the remote target.
    # --no-track ensures no upstream is set, so a plain `git push` can never
    # silently resolve to a releases/* branch — every push in this script uses
    # an explicit refspec via Invoke-SafePush.
    Invoke-SafeGit @("checkout", "--no-track", "-b", $portBranch, "origin/$targetBranch")

    # Cherry-pick
    $cherryPickFailed = $false
    $failedIdx        = 0
    $commitIdx        = 0
    foreach ($sha in $commits) {
        if ($useMergeParent) {
            & git cherry-pick -m 1 $sha
        }
        else {
            & git cherry-pick $sha
        }
        $pickExit = $LASTEXITCODE

        if ($pickExit -ne 0) {
            # Distinguish an empty cherry-pick (change already applied) from a real
            # conflict.  git ls-files --unmerged lists files with conflict markers;
            # an empty cherry-pick leaves this list empty even though git paused.
            $unmergedCheck = & git ls-files --unmerged
            if (-not $unmergedCheck) {
                Warn "Commit $sha is already present in $targetBranch - skipping."
                & git cherry-pick --skip
            }
            else {
                $cherryPickFailed = $true
                $failedIdx        = $commitIdx
                break
            }
        }
        $commitIdx++
    }

    if ($cherryPickFailed) {
        # Commits that still need to be applied after the conflict is resolved.
        $remainingAfterConflict = @($commits | Select-Object -Skip ($failedIdx + 1))

        Write-Host ""
        Write-Host "======================================================================" -ForegroundColor Red
        Write-Host "ACTION REQUIRED — Cherry-pick conflict on $envLabel ($targetBranch)" -ForegroundColor Red
        Write-Host "======================================================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "You must resolve the conflicts manually before this script can continue."
        Write-Host ""
        Write-Host "Steps:"
        Write-Host "  1. git status          (see which files have conflict markers)"
        Write-Host "  2. git diff            (review each conflict in detail)"
        Write-Host "  3. Edit each conflicted file and fix the <<<<<<<  =======  >>>>>>> markers"
        Write-Host "  4. git add <resolved-files>"
        Write-Host "  5. git cherry-pick --continue"
        if ($remainingAfterConflict.Count -gt 0) {
            Write-Host ""
            Write-Host "  The following $($remainingAfterConflict.Count) commit(s) come after the conflict and must"
            Write-Host "  also be cherry-picked before pushing:"
            Write-Host ""
            Write-Host "  6. git cherry-pick $($remainingAfterConflict -join ' ')"
            Write-Host "     (skip any that are empty: git cherry-pick --skip)"
            Write-Host ""
            Write-Host "  7. Verify all commits are on the port branch:"
            Write-Host "     git log origin/$targetBranch..HEAD --oneline"
            Write-Host ""
            Write-Host "  8. git push origin `"HEAD:refs/heads/$portBranch`""
        }
        else {
            Write-Host "  6. git push origin `"HEAD:refs/heads/$portBranch`""
        }
        Write-Host ""
        Write-Host "After completing those steps, re-run this script with:"
        Write-Host "  -Resume $targetBranch"
        Write-Host ""
        Write-Host "If running via the agent, reply to the agent once conflicts are resolved."
        Write-Host "======================================================================"
        exit 1
    }

    # If every commit was already present the port branch is identical to the
    # target — nothing to port for this environment.
    $aheadCount = [int](& git rev-list --count "origin/$targetBranch..HEAD").Trim()
    if ($aheadCount -eq 0) {
        Info "All commits already present in $targetBranch - no port needed for $envLabel."
        Invoke-SafeGit @("checkout", "-")
        Invoke-SafeGit @("branch", "-D", $portBranch)
        continue
    }

    # Push using Invoke-SafePush, which uses an explicit refspec and refuses to push
    # to any releases/* destination.
    Invoke-SafePush $portBranch

    # Print compare URL
    $compareUrl = "$repoUrl/compare/$targetBranch...${portBranch}?expand=1"
    Write-Host ""
    Write-Host "OK: Port branch pushed. Open a PR at:"
    Write-Host "  $compareUrl"
    Write-Host ""

    # Open a Draft PR - this is the primary handoff mechanism to the Deployer.
    if ($envLabel -eq "PPE" -and $ppeCoversProd) {
        $prTitle = "Port PR #$PR -> $targetBranch (PPE + Prod)"
        $prBody  = @"
Ports the changes from #$PR into the **PPE and Prod** environment branch ``$targetBranch``.

> **Note:** PPE and Prod are currently on the same branch (``$targetBranch``). This PR covers both environments.
"@
    }
    else {
        $prTitle = "Port PR #$PR -> $targetBranch ($envLabel)"
        $prBody  = "Ports the changes from #$PR into the **$envLabel** environment branch ``$targetBranch``."
    }

    & gh pr create `
        --base  $targetBranch `
        --head  $portBranch `
        --title $prTitle `
        --body  $prBody `
        --draft
    if ($LASTEXITCODE -ne 0) { Die "Failed to create draft PR for $envLabel" }
}

Info "Done. All environment branches processed."
