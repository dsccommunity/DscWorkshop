$path = Split-Path $MyInvocation.MyCommand.Path

Add-Type -Path $path\Security.Cryptography.dll -ErrorAction Stop

. $path\PinnedArray.ps1
. $path\HMAC.ps1
. $path\Commands.ps1
