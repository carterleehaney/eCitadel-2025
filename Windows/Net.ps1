while ($true) {

$rulesDir = "C:\ProgramData\Rules"
$prevRules = Join-Path $rulesDir "rules_previous.xml"  
$currentRules = Join-Path $rulesDir "rules_current.xml" 
$diffTextFile = Join-Path $rulesDir "rules_diff.txt"    
$diffHTML = Join-Path $rulesDir "differences.html"      

if (-not (Test-Path $rulesDir)) {
    New-Item -Path $rulesDir -ItemType Directory | Out-Null
}

netsh wfp show filters file="$currentRules"

function Get-ReadableRules {
    param ($xmlPath)
    $xml = [xml](Get-Content $xmlPath)  
    $rules = @()  

    foreach ($item in $xml.wfpdiag.filters.item) {
        $ruleInfo = @{
            Name       = $item.displayData.name  
            ID         = $item.filterId          
            Layer      = $item.layerKey          
            Weight     = $item.effectiveWeight.uint64  
            Conditions = if ($item.filterCondition.item) {
                ($item.filterCondition.item | ForEach-Object {
                    "$($_.fieldKey) = $($_.conditionValue.ChildNodes | Where-Object { $_.NodeType -eq 'Element' } | ForEach-Object { $_.'#text' })"
                }) -join "; "
            } else {
                "None"  
            }
            Action     = $item.action.type  
        }
        $rules += [pscustomobject]$ruleInfo
    }

    return $rules | Sort-Object ID
}

Add-Type -AssemblyName PresentationFramework

$new = Get-ReadableRules -xmlPath $currentRules

if (Test-Path $prevRules) {
    $old = Get-ReadableRules -xmlPath $prevRules

    $diff = Compare-Object -ReferenceObject $old -DifferenceObject $new -Property Name, ID, Layer, Weight, Conditions, Action -IncludeEqual:$false

    if ($diff) {
        Write-Host "`n--- Differences Detected in Rules ---`n" -ForegroundColor Yellow

        [System.Windows.MessageBox]::Show("Rule Changes Detected.", "Monitor Alert", "OK", "Warning")

        $diffFormatted = @() 
        $diffText = @()       

        foreach ($entry in $diff) {
            $status = if ($entry.SideIndicator -eq '=>') { 'NEW' } else { 'REMOVED' }
            $line = "${status}: Name: $($entry.Name); ID: $($entry.ID); Layer: $($entry.Layer); Action: $($entry.Action); Conditions: $($entry.Conditions)"
            $diffText += $line  

            $diffFormatted += [pscustomobject]@{
            Status     = $status
            Name       = $entry.Name
            ID         = $entry.ID
            Layer      = $entry.Layer
            Weight     = $entry.Weight
            Action     = $entry.Action
            Conditions = $entry.Conditions
            }

            Write-Host "${status}: Name: " -NoNewline
            Write-Host "$($entry.Name)" -ForegroundColor Red -NoNewline
            Write-Host "; ID: $($entry.ID); Layer: $($entry.Layer); Weight: " -NoNewline
            Write-Host "$($entry.Weight)" -ForegroundColor Red -NoNewline
            Write-Host "; Action: " -NoNewline
            Write-Host "$($entry.Action)" -ForegroundColor Red -NoNewline
            Write-Host "; Conditions: $($entry.Conditions)"
        }

        $diffText | Out-File $diffTextFile -Encoding UTF8

    } else {
        Write-Host "No changes detected in rules." -ForegroundColor Green
        if (Test-Path $diffTextFile) { Remove-Item $diffTextFile }
        if (Test-Path $diffHTML) { Remove-Item $diffHTML }
    }
} else {
    Write-Host "No previous rules found. Saving current rules as baseline."
}

Copy-Item -Path $currentRules -Destination $prevRules -Force

Start-Sleep 60
}