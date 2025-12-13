param([string[]]$Files)

# Create backup directory if it doesn't exist
$backupDir = "$env:TEMP\backup"
if (!(Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

# Function to extract GitHub repo info from URL
function Get-GitHubRepoFromUrl {
    param([string]$url)
    
    if ($url -match 'https://github\.com/([^/]+)/([^/]+)/releases/download/') {
        return @{
            Homepage = "https://github.com/$($matches[1])/$($matches[2])"
            Owner = $matches[1]
            Repo = $matches[2]
        }
    }
    return $null
}

# Function to fetch GitHub repo info via API
function Get-GitHubRepoInfo {
    param([string]$owner, [string]$repo)
    
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repo" -ErrorAction Stop -UserAgent "PowerShell"
        return @{
            Description = $response.description
            License = $response.license.spdx_id
        }
    } catch {
        Write-Host "Warning: Failed to fetch GitHub repo info for $owner/$repo" -ForegroundColor Yellow
        return $null
    }
}

foreach ($file in $Files) {
    # Add .json extension if not already ending with .json
    if ($file -notlike "*.json") {
    $file = "$file.json"
    }
    
    if (!(Test-Path $file)) {
        Write-Host "File not found: $file" -ForegroundColor Red
        continue
    }
    
    Write-Host "Processing: $file"
    
    # Backup original file
    $backupFile = Join-Path $backupDir "$([System.IO.Path]::GetFileName($file)).bak"
    Copy-Item $file $backupFile -Force
    
    # Read and parse JSON
    $json = Get-Content $file -Raw | ConvertFrom-Json
    
    # Remove unwanted keys
    if ($json.PSObject.Properties['extract_dir']) {
        $json.PSObject.Properties.Remove('extract_dir')
    }
    if ($json.PSObject.Properties['depends']) {
        $json.PSObject.Properties.Remove('depends')
    }
    
    # Try to extract GitHub info from URL
    $githubInfo = Get-GitHubRepoFromUrl -url $json.url
    if ($githubInfo) {
        Write-Host "Detected GitHub repository: $($githubInfo.Homepage)" -ForegroundColor Cyan
        
         # Add or update homepage
         if ($json.PSObject.Properties['homepage']) {
             $json.homepage = $githubInfo.Homepage
         } else {
             $json | Add-Member -MemberType NoteProperty -Name 'homepage' -Value $githubInfo.Homepage
         }
         
         # Fetch repo info from GitHub API
         Write-Host "Fetching GitHub repository info..." -ForegroundColor Cyan
         $repoInfo = Get-GitHubRepoInfo -owner $githubInfo.Owner -repo $githubInfo.Repo
         
         if ($repoInfo) {
            # Update description if available
            if ($repoInfo.Description) {
                if ($json.PSObject.Properties['description']) {
                    $json.description = $repoInfo.Description
                } else {
                    $json | Add-Member -MemberType NoteProperty -Name 'description' -Value $repoInfo.Description
                }
            }
            
            # Update license if available
            if ($repoInfo.License) {
                if ($json.PSObject.Properties['license']) {
                    $json.license = $repoInfo.License
                } else {
                    $json | Add-Member -MemberType NoteProperty -Name 'license' -Value $repoInfo.License
                }
            }
        }
    } else {
        # Add description if missing
        if (!$json.PSObject.Properties['description']) {
            $json | Add-Member -MemberType NoteProperty -Name 'description' -Value ''
        }

        # Add homepage if missing
        if (!$json.PSObject.Properties['homepage']) {
            $json | Add-Member -MemberType NoteProperty -Name 'homepage' -Value ''
        }
    }
    
    # Ask if amd64-only
    Write-Host "Is this software amd64-only? (Y/N): " -NoNewline
    $response = [System.Console]::ReadKey($true).KeyChar.ToString().ToUpper()
    Write-Host $response
    
    if ($response -eq 'Y') {
        # Move url and hash to architecture.x64
        $url = $json.url
        $hash = $json.hash
        $json.PSObject.Properties.Remove('url')
        $json.PSObject.Properties.Remove('hash')
        $architecture = @{
            '64bit' = [ordered]@{
                url = $url
                hash = $hash
            }
        }
        $json | Add-Member -MemberType NoteProperty -Name 'architecture' -Value $architecture -Force
        # amd64-only key order
        $orderedKeys = @('version', 'description', 'homepage', 'license', 'architecture', 'bin')
    } else {
        # 非amd64-only key order
        $orderedKeys = @('version', 'description', 'homepage', 'license', 'url', 'hash', 'bin')
    }
    $orderedJson = [ordered]@{}
    foreach ($key in $orderedKeys) {
        if ($json.PSObject.Properties[$key]) {
            $orderedJson[$key] = $json.$key
        }
    }
    # Add remaining keys
    foreach ($prop in $json.PSObject.Properties) {
        if ($prop.Name -notin $orderedKeys) {
            $orderedJson[$prop.Name] = $prop.Value
        }
    }
    # Convert to JSON with 4-space indentation and save
    $orderedJson | ConvertTo-Json -Depth 10 | ForEach-Object {
        $_ -replace '  ', '    '
    } | Set-Content $file -Encoding UTF8
    
    Write-Host "Completed: $file (backup: $backupFile)" -ForegroundColor Green

    # Ask if user wants to open the file in editor
    Write-Host "Do you want to open the file in editor? (Y/N): " -NoNewline
    $response = [System.Console]::ReadKey($true).KeyChar.ToString().ToUpper()
    Write-Host $response

    if ($response -eq 'Y') {
        Start-Process "C:\Tool\Notepad3.exe" $file
    }
}
