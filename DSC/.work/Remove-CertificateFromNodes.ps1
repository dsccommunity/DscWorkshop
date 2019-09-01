Push-Location
Set-Location -Path $env:BHProjectPath\DscConfigData\AllNodes
$files = dir -Recurse -Filter *.yml

foreach ($file in $files) {
    $y = $file | Get-Content -Raw | ConvertFrom-Yaml -Ordered
    if ($y.CertificateFile) {
        $y.Remove('CertificateFile')
        if (-not $y.ContainsKey('PSDscAllowPlainTextPassword')) {
            $y.Add('PSDscAllowPlainTextPassword', $true)
        }
        $y | ConvertTo-Yaml -OutFile $file.FullName -Options EmitDefaults -Force
    }
}

Pop-Location