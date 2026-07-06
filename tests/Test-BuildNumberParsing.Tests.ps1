<#
.SYNOPSIS
    Unit tests for Windows build-number extraction in the *-headless.ps1 builder scripts.
    Author: kelexine (https://github.com/kelexine)
    Run: Invoke-Pester ./tests/Test-BuildNumberParsing.Tests.ps1
#>

function Get-TestBuildNumber {
    param([string]$FullVersion)
    if ($FullVersion -match '(\d+\.\d+)$') {
        return $Matches[1]
    }
    return ""
}

Describe "Windows build number extraction" {

    It "extracts <build>.<ubr> from a standard 4-segment version string" {
        Get-TestBuildNumber -FullVersion "10.0.26200.8655" | Should -Be "26200.8655"
    }

    It "extracts correctly for an older Windows 11 build" {
        Get-TestBuildNumber -FullVersion "10.0.22631.4602" | Should -Be "22631.4602"
    }

    It "extracts correctly when the UBR is a single digit" {
        Get-TestBuildNumber -FullVersion "10.0.26100.1" | Should -Be "26100.1"
    }

    It "matches the whole string for a bare 2-segment version" {
        # Anchored only at the end, so "10.0" is itself a valid \d+\.\d+ match.
        # Not expected in practice (Get-WindowsImage.Version is always 4-segment).
        Get-TestBuildNumber -FullVersion "10.0" | Should -Be "10.0"
    }

    It "returns an empty string for a completely empty version" {
        Get-TestBuildNumber -FullVersion "" | Should -Be ""
    }

    It "returns an empty string for non-numeric garbage" {
        Get-TestBuildNumber -FullVersion "not-a-version" | Should -Be ""
    }

    It "is resilient to a trailing 5th segment by still capturing the last two" {
        Get-TestBuildNumber -FullVersion "10.0.26200.8655.1" | Should -Be "8655.1"
    }
}

Describe "Consistency across all three maker scripts" {

    $repoRoot = Split-Path -Parent $PSScriptRoot
    $scripts = @(
        "$repoRoot\scripts\tiny11maker-headless.ps1",
        "$repoRoot\scripts\tiny11coremaker-headless.ps1",
        "$repoRoot\scripts\nano11builder-headless.ps1"
    )

    foreach ($scriptPath in $scripts) {
        $scriptName = Split-Path -Leaf $scriptPath

        It "$scriptName contains the build-number capture block" {
            Test-Path $scriptPath | Should -Be $true
            $content = Get-Content -Path $scriptPath -Raw
            $content | Should -Match ([regex]::Escape('$script:DetectedBuildNumber'))
            $content | Should -Match ([regex]::Escape("'(\d+\.\d+)$'"))
        }

        It "$scriptName defines Write-BuildInfo" {
            $content = Get-Content -Path $scriptPath -Raw
            $content | Should -Match "function Write-BuildInfo"
        }
    }
}
