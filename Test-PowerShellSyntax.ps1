<#
.SYNOPSIS
Validates PowerShell syntax across cloned single-run repositories.
#>
[CmdletBinding()]
param(
    [string]$RootPath=(Split-Path $PSScriptRoot -Parent),
    [string]$ReportPath=(Join-Path $PSScriptRoot 'SyntaxValidation.csv')
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$results=New-Object System.Collections.Generic.List[object]

try{
    if(-not(Test-Path $RootPath)){throw "Root path not found: $RootPath"}
    $files=Get-ChildItem -Path $RootPath -Filter '*.ps1' -File -Recurse|
        Where-Object{$_.FullName -notmatch '[\\/]\.git[\\/]'}

    foreach($file in $files){
        $tokens=$null
        $errors=$null
        [void][System.Management.Automation.Language.Parser]::ParseFile(
            $file.FullName,
            [ref]$tokens,
            [ref]$errors
        )

        if($errors.Count -eq 0){
            $results.Add([pscustomobject]@{File=$file.FullName;Valid=$true;Line='';Message=''})
            Write-Host "[OK] $($file.FullName)" -ForegroundColor Green
        }else{
            foreach($parseError in $errors){
                $results.Add([pscustomobject]@{
                    File=$file.FullName
                    Valid=$false
                    Line=$parseError.Extent.StartLineNumber
                    Message=$parseError.Message
                })
                Write-Host "[ERROR] $($file.FullName):$($parseError.Extent.StartLineNumber) $($parseError.Message)" -ForegroundColor Red
            }
        }
    }

    $results|Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8
    $invalid=@($results|Where-Object{-not $_.Valid})
    Write-Host "Checked $($files.Count) script(s). Report: $ReportPath" -ForegroundColor Cyan
    if($invalid.Count -gt 0){exit 1}else{exit 0}
}catch{Write-Error $_.Exception.Message;exit 1}
