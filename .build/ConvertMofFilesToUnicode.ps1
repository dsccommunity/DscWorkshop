task ConvertMofFilesToUnicode {

    $path = Join-Path -Path $OutputDirectory -ChildPath $MofOutputFolder
    dir -Path $path -Recurse -Filter *.mof | ForEach-Object {
        Write-Host "Converting file $($_.FullName) to Unicode encoding." -ForegroundColor DarkGray
        $content = Get-Content $_.FullName -Encoding UTF8
        $content | Out-File -FilePath $_.FullName -Encoding unicode
    }

}
