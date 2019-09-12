function Get-DscMofVersion {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Path
    )

    process {
        if (-not (Test-Path -Path $Path)) {
            Write-Error "The MOF file '$Path' cannot be found."
            return
        }

        $content = Get-Content -Path $Path

        $xRegistryDscVersion = $content | Select-String -Pattern '\[xRegistry\]DscVersion' -Context 0, 10
        if (-not $xRegistryDscVersion) {
            Write-Error "No version information found in MOF file '$Path'. The version information must be added using the 'xRegistry' named 'DscVersion'."
            return
        }

        $valueData = $xRegistryDscVersion.Context.PostContext | Select-String -Pattern 'ValueData' -Context 0, 1
        if (-not $valueData) {
            Write-Error "Found the resource 'xRegistry' named 'DscVersion' in '$Path' but no ValueData in the expected range (10 lines after defining '[xRegistry]DscVersion'."
            return
        }

        try {
            $value = $valueData.Context.PostContext[0].Trim().Replace('"', '')
            [System.Version]$value
        }
        catch {
            Write-Error "ValueData could not be converted into 'System.Version'. The value taken from the MOF file was '$value'"
            return
        }
    }
}

function Get-DscMofEnvironment {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Path
    )

    process {
        if (-not (Test-Path -Path $Path)) {
            Write-Error "The MOF file '$Path' cannot be found."
            return
        }

        $content = Get-Content -Path $Path

        $xRegistryDscEnvironment = $content | Select-String -Pattern '\[xRegistry\]DscEnvironment' -Context 0, 10
        if (-not $xRegistryDscEnvironment) {
            Write-Error "No environment information found in MOF file '$Path'. The environment information must be added using the 'xRegistryx' named 'DscEnvironment'."
            return
        }

        $valueData = $xRegistryDscEnvironment.Context.PostContext | Select-String -Pattern 'ValueData' -Context 0, 1
        if (-not $valueData) {
            Write-Error "Found the resource 'xRegistry' named 'DscEnvironment' in '$Path' but no ValueData in the expected range (10 lines after defining '[xRegistry]DscEnvironment'."
            return
        }

        $valueData.Context.PostContext[0].Trim().Replace('"', '')
    }
}