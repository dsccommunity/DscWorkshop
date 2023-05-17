if ($PSVersionTable.PSVersion.Major -eq 2)
{
    $IgnoreError = 'SilentlyContinue'
}
else
{
    $IgnoreError = 'Ignore'
}

$script:ValidTypes = @(
    [string]
    [System.Security.SecureString]
    [System.Management.Automation.PSCredential]
    [byte[]]
)

$script:PSCredentialHeader = [byte[]](5,12,19,75,80,20,19,11,11,6,11,13)

$script:EccAlgorithmOid = '1.2.840.10045.2.1'

#region Exported functions

function Protect-Data
{
    <#
    .Synopsis
       Encrypts an object using one or more digital certificates and/or passwords.
    .DESCRIPTION
       Encrypts an object using a randomly-generated AES key. AES key information is encrypted using one or more certificate public keys and/or password-derived keys, allowing the data to be securely shared among multiple users and computers.
       If certificates are used, they must be installed in either the local computer or local user's certificate stores, and the certificates' Key Usage extension must allow Key Encipherment (for RSA) or Key Agreement (for ECDH). The private keys are not required for Protect-Data.
    .PARAMETER InputObject
       The object that is to be encrypted. The object must be of one of the types returned by the Get-ProtectedDataSupportedTypes command.
    .PARAMETER Certificate
       Zero or more RSA or ECDH certificates that should be used to encrypt the data. The data can later be decrypted by using the same certificate (with its private key.)  You can pass an X509Certificate2 object to this parameter, or you can pass in a string which contains either a path to a certificate file on the file system, a path to the certificate in the Certificate provider, or a certificate thumbprint (in which case the certificate provider will be searched to find the certificate.)
    .PARAMETER UseLegacyPadding
       Optional switch specifying that when performing certificate-based encryption, PKCS#1 v1.5 padding should be used instead of the newer, more secure OAEP padding scheme.  Some certificates may not work properly with OAEP padding
    .PARAMETER Password
       Zero or more SecureString objects containing password that will be used to derive encryption keys. The data can later be decrypted by passing in a SecureString with the same value.
    .PARAMETER SkipCertificateVerification
       Deprecated parameter, which will be removed in a future release.  Specifying this switch will generate a warning.
    .PARAMETER PasswordIterationCount
       Optional positive integer value specifying the number of iteration that should be used when deriving encryption keys from the specified password(s). Defaults to 50000.
       Higher values make it more costly to crack the passwords by brute force.
    .EXAMPLE
       $encryptedObject = Protect-Data -InputObject $myString -CertificateThumbprint CB04E7C885BEAE441B39BC843C85855D97785D25 -Password (Read-Host -AsSecureString -Prompt 'Enter password to encrypt')

       Encrypts a string using a single RSA or ECDH certificate, and a password. Either the certificate or the password can be used when decrypting the data.
    .EXAMPLE
       $credential | Protect-Data -CertificateThumbprint 'CB04E7C885BEAE441B39BC843C85855D97785D25', 'B5A04AB031C24BCEE220D6F9F99B6F5D376753FB'

       Encrypts a PSCredential object using two RSA or ECDH certificates. Either private key can be used to later decrypt the data.
    .INPUTS
       Object

       Object must be one of the types returned by the Get-ProtectedDataSupportedTypes command.
    .OUTPUTS
       PSObject

       The output object contains the following properties:

       CipherText : An array of bytes containing the encrypted data
       Type : A string representation of the InputObject's original type (used when decrypting back to the original object later.)
       KeyData : One or more structures which contain encrypted copies of the AES key used to protect the ciphertext, and other identifying information about the way this copy of the keys was protected, such as Certificate Thumbprint, Password Hash, Salt values, and Iteration count.
    .LINK
        Unprotect-Data
    .LINK
        Add-ProtectedDataCredential
    .LINK
        Remove-ProtectedDataCredential
    .LINK
        Get-ProtectedDataSupportedTypes
    #>

    [CmdletBinding()]
    [OutputType([psobject])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [ValidateScript({
            if ($script:ValidTypes -notcontains $_.GetType() -and $null -eq ($_ -as [byte[]]))
            {
                throw "InputObject must be one of the following types: $($script:ValidTypes -join ', ')"
            }

            if ($_ -is [System.Security.SecureString] -and $_.Length -eq 0)
            {
                throw 'SecureString argument contained no data.'
            }

            return $true
        })]
        $InputObject,

        [ValidateNotNullOrEmpty()]
        [AllowEmptyCollection()]
        [object[]]
        $Certificate = @(),

        [switch]
        $UseLegacyPadding,

        [ValidateNotNull()]
        [AllowEmptyCollection()]
        [ValidateScript({
            if ($_.Length -eq 0)
            {
                throw 'You may not pass empty SecureStrings to the Password parameter'
            }

            return $true
        })]
        [System.Security.SecureString[]]
        $Password = @(),

        [ValidateRange(1,2147483647)]
        [int]
        $PasswordIterationCount = 50000,

        [switch]
        $SkipCertificateVerification
    )

    begin
    {
        if ($PSBoundParameters.ContainsKey('SkipCertificateVerification'))
        {
            Write-Warning 'The -SkipCertificateVerification switch has been deprecated, and the module now treats that as its default behavior.  This switch will be removed in a future release.'
        }

        $certs = @(
            foreach ($cert in $Certificate)
            {
                try
                {

                    $x509Cert = ConvertTo-X509Certificate2 -InputObject $cert -ErrorAction Stop
                    ValidateKeyEncryptionCertificate -CertificateGroup $x509Cert -ErrorAction Stop
                }
                catch
                {
                    Write-Error -ErrorRecord $_
                }
            }
        )

        if ($certs.Count -eq 0 -and $Password.Count -eq 0)
        {
            throw ('None of the specified certificates could be used for encryption, and no passwords were specified.' +
                  ' Data protection cannot be performed.')
        }
    }

    process
    {
        $plainText = $null
        $payload = $null

        try
        {
            $plainText = ConvertTo-PinnedByteArray -InputObject $InputObject
            $payload = Protect-DataWithAes -PlainText $plainText

            $protectedData = New-Object psobject -Property @{
                CipherText = $payload.CipherText
                HMAC = $payload.HMAC
                Type = $InputObject.GetType().FullName
                KeyData = @()
            }

            $params = @{
                InputObject = $protectedData
                Key = $payload.Key
                InitializationVector = $payload.IV
                Certificate = $certs
                Password = $Password
                PasswordIterationCount = $PasswordIterationCount
                UseLegacyPadding = $UseLegacyPadding
            }

            Add-KeyData @params

            if ($protectedData.KeyData.Count -eq 0)
            {
                Write-Error 'Failed to protect data with any of the supplied certificates or passwords.'
                return
            }
            else
            {
                $protectedData
            }
        }
        finally
        {
            if ($plainText -is [IDisposable]) { $plainText.Dispose() }
            if ($null -ne $payload)
            {
                if ($payload.Key -is [IDisposable]) { $payload.Key.Dispose() }
                if ($payload.IV -is [IDisposable]) { $payload.IV.Dispose() }
            }
        }

    } # process

} # function Protect-Data

function Unprotect-Data
{
    <#
    .Synopsis
       Decrypts an object that was produced by the Protect-Data command.
    .DESCRIPTION
       Decrypts an object that was produced by the Protect-Data command. If a Certificate is used to perform the decryption, it must be installed in either the local computer or current user's certificate stores (with its private key), and the current user must have permission to use that key.
    .PARAMETER InputObject
       The ProtectedData object that is to be decrypted.
    .PARAMETER Certificate
       An RSA or ECDH certificate that will be used to decrypt the data.  You must have the certificate's private key, and it must be one of the certificates that was used to encrypt the data.  You can pass an X509Certificate2 object to this parameter, or you can pass in a string which contains either a path to a certificate file on the file system, a path to the certificate in the Certificate provider, or a certificate thumbprint (in which case the certificate provider will be searched to find the certificate.)
    .PARAMETER Password
       A SecureString containing a password that will be used to derive an encryption key. One of the InputObject's KeyData objects must be protected with this password.
    .PARAMETER SkipCertificateValidation
       Deprecated parameter, which will be removed in a future release.  Specifying this switch will generate a warning.
    .EXAMPLE
       $decryptedObject = $encryptedObject | Unprotect-Data -Password (Read-Host -AsSecureString -Prompt 'Enter password to decrypt the data')

       Decrypts the contents of $encryptedObject and outputs an object of the same type as what was originally passed to Protect-Data. Uses a password to decrypt the object instead of a certificate.
    .INPUTS
       PSObject

       The input object should be a copy of an object that was produced by Protect-Data.
    .OUTPUTS
       Object

       Object may be any type returned by Get-ProtectedDataSupportedTypes. Specifically, it will be an object of the type specified in the InputObject's Type property.
    .LINK
        Protect-Data
    .LINK
        Add-ProtectedDataCredential
    .LINK
        Remove-ProtectedDataCredential
    .LINK
        Get-ProtectedDataSupportedTypes
    #>

    [CmdletBinding(DefaultParameterSetName = 'Certificate')]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [ValidateScript({
            if (-not (Test-IsProtectedData -InputObject $_))
            {
                throw 'InputObject argument must be a ProtectedData object.'
            }

            if ($null -eq $_.CipherText -or $_.CipherText.Count -eq 0)
            {
                throw 'Protected data object contained no cipher text.'
            }

            $type = $_.Type -as [type]

            if ($null -eq $type -or $script:ValidTypes -notcontains $type)
            {
                throw 'Protected data object specified an invalid type. Type must be one of: ' +
                      ($script:ValidTypes -join ', ')
            }

            return $true
        })]
        $InputObject,

        [Parameter(ParameterSetName = 'Certificate')]
        [object]
        $Certificate,

        [Parameter(Mandatory = $true, ParameterSetName = 'Password')]
        [System.Security.SecureString]
        $Password,

        [switch]
        $SkipCertificateVerification
    )

    begin
    {
        if ($PSBoundParameters.ContainsKey('SkipCertificateVerification'))
        {
            Write-Warning 'The -SkipCertificateVerification switch has been deprecated, and the module now treats that as its default behavior.  This switch will be removed in a future release.'
        }

        $cert = $null

        if ($Certificate)
        {
            try
            {
                $cert = ConvertTo-X509Certificate2 -InputObject $Certificate -ErrorAction Stop

                $params = @{
                    CertificateGroup = $cert
                    RequirePrivateKey = $true
                }

                $cert = ValidateKeyEncryptionCertificate @params -ErrorAction Stop
            }
            catch
            {
                throw
            }
        }
    }

    process
    {
        $plainText = $null
        $aes = $null
        $key = $null
        $iv = $null

        if ($null -ne $Password)
        {
            $params = @{ Password = $Password }
        }
        else
        {
            if ($null -eq $cert)
            {
                $paths = 'Cert:\CurrentUser\My', 'Cert:\LocalMachine\My'

                $cert = :outer foreach ($path in $paths)
                {
                    foreach ($keyData in $InputObject.KeyData)
                    {
                        if ($keyData.Thumbprint)
                        {
                            $certObject = $null
                            try
                            {
                                $certObject = Get-KeyEncryptionCertificate -Path $path -CertificateThumbprint $keyData.Thumbprint -RequirePrivateKey -ErrorAction $IgnoreError
                            } catch { }

                            if ($null -ne $certObject)
                            {
                                $certObject
                                break outer
                            }
                        }
                    }
                }
            }

            if ($null -eq $cert)
            {
                Write-Error -Message 'No decryption certificate for the specified InputObject was found.' -TargetObject $InputObject
                return
            }

            $params = @{
                Certificate = $cert
            }
        }

        try
        {
            $result = Unprotect-MatchingKeyData -InputObject $InputObject @params
            $key = $result.Key
            $iv = $result.IV

            if ($null -eq $InputObject.HMAC)
            {
                throw 'Input Object contained no HMAC code.'
            }

            $hmac = $InputObject.HMAC

            $plainText = (Unprotect-DataWithAes -CipherText $InputObject.CipherText -Key $key -InitializationVector $iv -HMAC $hmac).PlainText

            ConvertFrom-ByteArray -ByteArray $plainText -Type $InputObject.Type -ByteCount $plainText.Count
        }
        catch
        {
            Write-Error -ErrorRecord $_
            return
        }
        finally
        {
            if ($plainText -is [IDisposable]) { $plainText.Dispose() }
            if ($key -is [IDisposable]) { $key.Dispose() }
            if ($iv -is [IDisposable]) { $iv.Dispose() }
        }

    } # process

} # function Unprotect-Data

function Add-ProtectedDataHmac
{
    <#
    .Synopsis
       Adds an HMAC authentication code to a ProtectedData object which was created with a previous version of the module.
    .DESCRIPTION
       Adds an HMAC authentication code to a ProtectedData object which was created with a previous version of the module.  The parameters and requirements are the same as for the Unprotect-Data command, as the data must be partially decrypted in order to produce the HMAC code.
    .PARAMETER InputObject
       The ProtectedData object that is to have an HMAC generated.
    .PARAMETER Certificate
       An RSA or ECDH certificate that will be used to decrypt the data.  You must have the certificate's private key, and it must be one of the certificates that was used to encrypt the data.  You can pass an X509Certificate2 object to this parameter, or you can pass in a string which contains either a path to a certificate file on the file system, a path to the certificate in the Certificate provider, or a certificate thumbprint (in which case the certificate provider will be searched to find the certificate.)
    .PARAMETER Password
       A SecureString containing a password that will be used to derive an encryption key. One of the InputObject's KeyData objects must be protected with this password.
    .PARAMETER SkipCertificateVerification
       Deprecated parameter, which will be removed in a future release.  Specifying this switch will generate a warning.
    .PARAMETER PassThru
       If specified, the command outputs the ProtectedData object after adding the HMAC.
    .EXAMPLE
       $encryptedObject | Add-ProtectedDataHmac -Password (Read-Host -AsSecureString -Prompt 'Enter password to decrypt the key data')

       Adds an HMAC code to the $encryptedObject object.
    .INPUTS
       PSObject

       The input object should be a copy of an object that was produced by Protect-Data.
    .OUTPUTS
       None, or ProtectedData object if the -PassThru switch is used.
    .LINK
        Protect-Data
    .LINK
        Unprotect-Data
    .LINK
        Add-ProtectedDataCredential
    .LINK
        Remove-ProtectedDataCredential
    .LINK
        Get-ProtectedDataSupportedTypes
    #>

    [CmdletBinding(DefaultParameterSetName = 'Certificate')]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [ValidateScript({
            if (-not (Test-IsProtectedData -InputObject $_))
            {
                throw 'InputObject argument must be a ProtectedData object.'
            }

            if ($null -eq $_.CipherText -or $_.CipherText.Count -eq 0)
            {
                throw 'Protected data object contained no cipher text.'
            }

            $type = $_.Type -as [type]

            if ($null -eq $type -or $script:ValidTypes -notcontains $type)
            {
                throw 'Protected data object specified an invalid type. Type must be one of: ' +
                      ($script:ValidTypes -join ', ')
            }

            return $true
        })]
        $InputObject,

        [Parameter(Mandatory = $true, ParameterSetName = 'Certificate')]
        [object]
        $Certificate,

        [Parameter(Mandatory = $true, ParameterSetName = 'Password')]
        [System.Security.SecureString]
        $Password,

        [switch]
        $SkipCertificateVerification,

        [switch]
        $PassThru
    )

    begin
    {
        if ($PSBoundParameters.ContainsKey('SkipCertificateVerification'))
        {
            Write-Warning 'The -SkipCertificateVerification switch has been deprecated, and the module now treats that as its default behavior.  This switch will be removed in a future release.'
        }

        $cert = $null

        if ($Certificate)
        {
            try
            {
                $cert = ConvertTo-X509Certificate2 -InputObject $Certificate -ErrorAction Stop

                $params = @{
                    CertificateGroup = $cert
                    RequirePrivateKey = $true
                }

                $cert = ValidateKeyEncryptionCertificate @params -ErrorAction Stop
            }
            catch
            {
                throw
            }
        }
    }

    process
    {
        $key = $null
        $iv = $null

        if ($null -ne $cert)
        {
            $params = @{ Certificate = $cert }
        }
        else
        {
            $params = @{ Password = $Password }
        }

        try
        {
            $result = Unprotect-MatchingKeyData -InputObject $InputObject @params
            $key = $result.Key
            $iv = $result.IV

            $hmac = Get-Hmac -Key $key -Bytes $InputObject.CipherText

            if ($InputObject.PSObject.Properties['HMAC'])
            {
                $InputObject.HMAC = $hmac
            }
            else
            {
                Add-Member -InputObject $InputObject -Name HMAC -Value $hmac -MemberType NoteProperty
            }

            if ($PassThru)
            {
                $InputObject
            }
        }
        catch
        {
            Write-Error -ErrorRecord $_
            return
        }
        finally
        {
            if ($key -is [IDisposable]) { $key.Dispose() }
            if ($iv -is [IDisposable]) { $iv.Dispose() }
        }

    } # process

} # function Unprotect-Data

function Add-ProtectedDataCredential
{
    <#
    .Synopsis
       Adds one or more new copies of an encryption key to an object generated by Protect-Data.
    .DESCRIPTION
       This command can be used to add new certificates and/or passwords to an object that was previously encrypted by Protect-Data. The caller must provide one of the certificates or passwords that already exists in the ProtectedData object to perform this operation.
    .PARAMETER InputObject
       The ProtectedData object which was created by an earlier call to Protect-Data.
    .PARAMETER Certificate
       An RSA or ECDH certificate which was previously used to encrypt the ProtectedData structure's key.
    .PARAMETER Password
       A password which was previously used to encrypt the ProtectedData structure's key.
    .PARAMETER NewCertificate
       Zero or more RSA or ECDH certificates that should be used to encrypt the data. The data can later be decrypted by using the same certificate (with its private key.)  You can pass an X509Certificate2 object to this parameter, or you can pass in a string which contains either a path to a certificate file on the file system, a path to the certificate in the Certificate provider, or a certificate thumbprint (in which case the certificate provider will be searched to find the certificate.)
    .PARAMETER UseLegacyPadding
       Optional switch specifying that when performing certificate-based encryption, PKCS#1 v1.5 padding should be used instead of the newer, more secure OAEP padding scheme.  Some certificates may not work properly with OAEP padding
    .PARAMETER NewPassword
       Zero or more SecureString objects containing password that will be used to derive encryption keys. The data can later be decrypted by passing in a SecureString with the same value.
    .PARAMETER SkipCertificateVerification
       Deprecated parameter, which will be removed in a future release.  Specifying this switch will generate a warning.
    .PARAMETER PasswordIterationCount
       Optional positive integer value specifying the number of iteration that should be used when deriving encryption keys from the specified password(s). Defaults to 50000.
       Higher values make it more costly to crack the passwords by brute force.
    .PARAMETER Passthru
       If this switch is used, the ProtectedData object is output to the pipeline after it is modified.
    .EXAMPLE
       Add-ProtectedDataCredential -InputObject $protectedData -Certificate $oldThumbprint -NewCertificate $newThumbprints -NewPassword $newPasswords

       Uses the certificate with thumbprint $oldThumbprint to add new key copies to the $protectedData object. $newThumbprints would be a string array containing thumbprints, and $newPasswords would be an array of SecureString objects.
    .INPUTS
       [PSObject]

       The input object should be a copy of an object that was produced by Protect-Data.
    .OUTPUTS
       None, or
       [PSObject]
    .LINK
        Unprotect-Data
    .LINK
        Add-ProtectedDataCredential
    .LINK
        Remove-ProtectedDataCredential
    .LINK
        Get-ProtectedDataSupportedTypes
    #>

    [CmdletBinding(DefaultParameterSetName = 'Certificate')]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [ValidateScript({
            if (-not (Test-IsProtectedData -InputObject $_))
            {
                throw 'InputObject argument must be a ProtectedData object.'
            }

            return $true
        })]
        $InputObject,

        [Parameter(Mandatory = $true, ParameterSetName = 'Certificate')]
        [object]
        $Certificate,

        [Parameter(ParameterSetName = 'Certificate')]
        [switch]
        $UseLegacyPaddingForDecryption,

        [Parameter(Mandatory = $true, ParameterSetName = 'Password')]
        [System.Security.SecureString]
        $Password,

        [ValidateNotNull()]
        [AllowEmptyCollection()]
        [object[]]
        $NewCertificate = @(),

        [switch]
        $UseLegacyPadding,

        [ValidateNotNull()]
        [AllowEmptyCollection()]
        [System.Security.SecureString[]]
        $NewPassword = @(),

        [ValidateRange(1,2147483647)]
        [int]
        $PasswordIterationCount = 50000,

        [switch]
        $SkipCertificateVerification,

        [switch]
        $Passthru
    )

    begin
    {
        if ($PSBoundParameters.ContainsKey('SkipCertificateVerification'))
        {
            Write-Warning 'The -SkipCertificateVerification switch has been deprecated, and the module now treats that as its default behavior.  This switch will be removed in a future release.'
        }

        $decryptionCert = $null

        if ($PSCmdlet.ParameterSetName -eq 'Certificate')
        {
            try
            {
                $decryptionCert = ConvertTo-X509Certificate2 -InputObject $Certificate -ErrorAction Stop

                $params = @{
                    CertificateGroup = $decryptionCert
                    RequirePrivateKey = $true
                }

                $decryptionCert = ValidateKeyEncryptionCertificate @params -ErrorAction Stop
            }
            catch
            {
                throw
            }
        }

        $certs = @(
            foreach ($cert in $NewCertificate)
            {
                try
                {
                    $x509Cert = ConvertTo-X509Certificate2 -InputObject $cert -ErrorAction Stop
                    ValidateKeyEncryptionCertificate -CertificateGroup $x509Cert -ErrorAction Stop
                }
                catch
                {
                    Write-Error -ErrorRecord $_
                }
            }
        )

        if ($certs.Count -eq 0 -and $NewPassword.Count -eq 0)
        {
            throw 'None of the specified certificates could be used for encryption, and no passwords were ' +
                  'specified. Data protection cannot be performed.'
        }

    } # begin

    process
    {
        if ($null -ne $decryptionCert)
        {
            $params = @{ Certificate = $decryptionCert }
        }
        else
        {
            $params = @{ Password = $Password }
        }

        $key = $null
        $iv = $null

        try
        {
            $result = Unprotect-MatchingKeyData -InputObject $InputObject @params
            $key = $result.Key
            $iv = $result.IV

            Add-KeyData -InputObject $InputObject -Key $key -InitializationVector $iv -Certificate $certs -Password $NewPassword -PasswordIterationCount $PasswordIterationCount -UseLegacyPadding:$UseLegacyPadding
        }
        catch
        {
            Write-Error -ErrorRecord $_
            return
        }
        finally
        {
            if ($key -is [IDisposable]) { $key.Dispose() }
            if ($iv -is [IDisposable]) { $iv.Dispose() }
        }

        if ($Passthru)
        {
            $InputObject
        }

    } # process

} # function Add-ProtectedDataCredential

function Remove-ProtectedDataCredential
{
    <#
    .Synopsis
       Removes copies of encryption keys from a ProtectedData object.
    .DESCRIPTION
       The KeyData copies in a ProtectedData object which are associated with the specified Certificates and/or Passwords are removed from the object, unless that removal would leave no KeyData copies behind.
    .PARAMETER InputObject
       The ProtectedData object which is to be modified.
    .PARAMETER Certificate
       RSA or ECDH certificates that you wish to remove from this ProtectedData object.  You can pass an X509Certificate2 object to this parameter, or you can pass in a string which contains either a path to a certificate file on the file system, a path to the certificate in the Certificate provider, or a certificate thumbprint (in which case the certificate provider will be searched to find the certificate.)
    .PARAMETER Password
       Passwords in SecureString form which are to be removed from this ProtectedData object.
    .PARAMETER Passthru
       If this switch is used, the ProtectedData object will be written to the pipeline after processing is complete.
    .EXAMPLE
       $protectedData | Remove-ProtectedDataCredential -Certificate $thumbprints -Password $passwords

       Removes certificates and passwords from an existing ProtectedData object.
    .INPUTS
       [PSObject]

       The input object should be a copy of an object that was produced by Protect-Data.
    .OUTPUTS
       None, or
       [PSObject]
    .LINK
       Protect-Data
    .LINK
       Unprotect-Data
    .LINK
       Add-ProtectedDataCredential
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [ValidateScript({
            if (-not (Test-IsProtectedData -InputObject $_))
            {
                throw 'InputObject argument must be a ProtectedData object.'
            }

            return $true
        })]
        $InputObject,

        [ValidateNotNull()]
        [AllowEmptyCollection()]
        [object[]]
        $Certificate,

        [ValidateNotNull()]
        [AllowEmptyCollection()]
        [System.Security.SecureString[]]
        $Password,

        [switch]
        $Passthru
    )

    begin
    {
        $thumbprints = @(
            $Certificate |
            ConvertTo-X509Certificate2 |
            Select-Object -ExpandProperty Thumbprint
        )

        $thumbprints = $thumbprints | Get-Unique
    }

    process
    {
        $matchingKeyData = @(
            foreach ($keyData in $InputObject.KeyData)
            {
                if (Test-IsCertificateProtectedKeyData -InputObject $keyData)
                {
                    if ($thumbprints -contains $keyData.Thumbprint) { $keyData }
                }
                elseif (Test-IsPasswordProtectedKeyData -InputObject $keyData)
                {
                    foreach ($secureString in $Password)
                    {
                        $params = @{
                            Password = $secureString
                            Salt = $keyData.HashSalt
                            IterationCount = $keyData.IterationCount
                        }
                        if ($keyData.Hash -eq (Get-PasswordHash @params))
                        {
                            $keyData
                        }
                    }
                }
            }
        )

        if ($matchingKeyData.Count -eq $InputObject.KeyData.Count)
        {
            Write-Error 'You must leave at least one copy of the ProtectedData object''s keys.'
            return
        }

        $InputObject.KeyData = $InputObject.KeyData | Where-Object { $matchingKeyData -notcontains $_ }

        if ($Passthru)
        {
            $InputObject
        }
    }

} # function Remove-ProtectedDataCredential

function Get-ProtectedDataSupportedTypes
{
    <#
    .Synopsis
       Returns a list of types that can be used as the InputObject in the Protect-Data command.
    .EXAMPLE
       $types = Get-ProtectedDataSupportedTypes
    .INPUTS
       None.
    .OUTPUTS
       Type[]
    .NOTES
       This function allows you to know which InputObject types are supported by the Protect-Data and Unprotect-Data commands in this version of the module. This list may expand over time, will always be backwards-compatible with previously-encrypted data.
    .LINK
       Protect-Data
    .LINK
       Unprotect-Data
    #>

    [CmdletBinding()]
    [OutputType([Type[]])]
    param ( )

    $script:ValidTypes
}

function Get-KeyEncryptionCertificate
{
    <#
    .Synopsis
       Finds certificates which can be used by Protect-Data and related commands.
    .DESCRIPTION
       Searches the given path, and all child paths, for certificates which can be used by Protect-Data. Such certificates must support Key Encipherment (for RSA) or Key Agreement (for ECDH) usage, and by default, must not be expired and must be issued by a trusted authority.
    .PARAMETER Path
       Path which should be searched for the certifictes. Defaults to the entire Cert: drive.
    .PARAMETER CertificateThumbprint
       Thumbprints which should be included in the search. Wildcards are allowed. Defaults to '*'.
    .PARAMETER SkipCertificateVerification
       Deprecated parameter, which will be removed in a future release.  Specifying this switch will generate a warning.
    .PARAMETER RequirePrivateKey
       If this switch is used, the command will only output certificates which have a usable private key on this computer.
    .EXAMPLE
       Get-KeyEncryptionCertificate -Path Cert:\CurrentUser -RequirePrivateKey

       Searches for certificates which support key encipherment (RSA) or key agreement (ECDH) and have a private key installed. All matching certificates are returned.
    .EXAMPLE
       Get-KeyEncryptionCertificate -Path Cert:\CurrentUser\TrustedPeople

       Searches the current user's Trusted People store for certificates that can be used with Protect-Data. Certificates do not need to have a private key available to the current user.
    .INPUTS
       None.
    .OUTPUTS
       [System.Security.Cryptography.X509Certificates.X509Certificate2]
    .LINK
       Protect-Data
    .LINK
       Unprotect-Data
    .LINK
       Add-ProtectedDataCredential
    .LINK
       Remove-ProtectedDataCredential
    #>

    [CmdletBinding()]
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
    param (
        [ValidateNotNullOrEmpty()]
        [string]
        $Path = 'Cert:\',

        [string]
        $CertificateThumbprint = '*',

        [switch]
        $SkipCertificateVerification,

        [switch]
        $RequirePrivateKey
    )

    if ($PSBoundParameters.ContainsKey('SkipCertificateVerification'))
    {
        Write-Warning 'The -SkipCertificateVerification switch has been deprecated, and the module now treats that as its default behavior.  This switch will be removed in a future release.'
    }

    # Suppress error output if we're doing a wildcard search (unless user specifically asks for it via -ErrorAction)
    # This is a little ugly, may rework this later now that I've made Get-KeyEncryptionCertificate public. Originally
    # it was only used to search for a single thumbprint, and threw errors back to the caller if no suitable cert could
    # be found. Now I want it to also be used as a search tool for users to identify suitable certificates. Maybe just
    # needs to be two separate functions, one internal and one public.

    if (-not $PSBoundParameters.ContainsKey('ErrorAction') -and
        $CertificateThumbprint -notmatch '^[A-F\d]+$')
    {
        $ErrorActionPreference = $IgnoreError
    }

    $certGroups = GetCertificateByThumbprint -Path $Path -Thumbprint $CertificateThumbprint -ErrorAction $IgnoreError |
                  Group-Object -Property Thumbprint

    if ($null -eq $certGroups)
    {
        throw "Certificate '$CertificateThumbprint' was not found."
    }

    foreach ($group in $certGroups)
    {
        ValidateKeyEncryptionCertificate -CertificateGroup $group.Group -RequirePrivateKey:$RequirePrivateKey
    }

} # function Get-KeyEncryptionCertificate

#endregion

#region Helper functions

function ConvertTo-X509Certificate2
{
    [CmdletBinding()]
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [object[]] $InputObject = @()
    )

    process
    {
        foreach ($object in $InputObject)
        {
            if ($null -eq $object) { continue }

            $possibleCerts = @(
                $object -as [System.Security.Cryptography.X509Certificates.X509Certificate2]
                GetCertificateFromPSPath -Path $object
            ) -ne $null

            if ($object -match '^[A-F\d]+$' -and $possibleCerts.Count -eq 0)
            {
                $possibleCerts = @(GetCertificateByThumbprint -Thumbprint $object)
            }

            $cert = $possibleCerts | Select-Object -First 1

            if ($null -ne $cert)
            {
                $cert
            }
            else
            {
                Write-Error "No certificate with identifier '$object' of type $($object.GetType().FullName) was found."
            }
        }
    }
}

function GetCertificateFromPSPath
{
    [CmdletBinding()]
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) { return }
    $resolved = Resolve-Path -LiteralPath $Path

    switch ($resolved.Provider.Name)
    {
        'FileSystem'
        {
            # X509Certificate2 has a constructor that takes a fileName string; using the -as operator is faster than
            # New-Object, and works just as well.

            return $resolved.ProviderPath -as [System.Security.Cryptography.X509Certificates.X509Certificate2]
        }

        'Certificate'
        {
            return (Get-Item -LiteralPath $Path) -as [System.Security.Cryptography.X509Certificates.X509Certificate2]
        }
    }
}

function GetCertificateByThumbprint
{
    [CmdletBinding()]
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Thumbprint,

        [ValidateNotNullOrEmpty()]
        [string]
        $Path = 'Cert:\'
    )

    return Get-ChildItem -Path $Path -Recurse -Include $Thumbprint |
           Where-Object { $_ -is [System.Security.Cryptography.X509Certificates.X509Certificate2] } |
           Sort-Object -Property HasPrivateKey -Descending
}

function Protect-DataWithAes
{
    [CmdletBinding(DefaultParameterSetName = 'KnownKey')]
    param (
        [Parameter(Mandatory = $true)]
        [byte[]]
        $PlainText,

        [byte[]]
        $Key,

        [byte[]]
        $InitializationVector,

        [switch]
        $NoHMAC
    )

    $aes = $null
    $memoryStream = $null
    $cryptoStream = $null

    try
    {
        $aes = New-Object System.Security.Cryptography.AesCryptoServiceProvider

        if ($null -ne $Key) { $aes.Key = $Key }
        if ($null -ne $InitializationVector) { $aes.IV = $InitializationVector }

        $memoryStream = New-Object System.IO.MemoryStream
        $cryptoStream = New-Object System.Security.Cryptography.CryptoStream(
            $memoryStream, $aes.CreateEncryptor(), 'Write'
        )

        $cryptoStream.Write($PlainText, 0, $PlainText.Count)
        $cryptoStream.FlushFinalBlock()

        $properties = @{
            CipherText = $memoryStream.ToArray()
            HMAC = $null
        }

        $hmacKeySplat = @{
            Key = $Key
        }

        if ($null -eq $Key)
        {
            $properties['Key'] = New-Object PowerShellUtils.PinnedArray[byte](,$aes.Key)
            $hmacKeySplat['Key'] = $properties['Key']
        }

        if ($null -eq $InitializationVector)
        {
            $properties['IV'] = New-Object PowerShellUtils.PinnedArray[byte](,$aes.IV)
        }

        if (-not $NoHMAC)
        {
            $properties['HMAC'] = Get-Hmac @hmacKeySplat -Bytes $properties['CipherText']
        }

        New-Object psobject -Property $properties
    }
    finally
    {
        if ($null -ne $aes) { $aes.Clear() }
        if ($cryptoStream -is [IDisposable]) { $cryptoStream.Dispose() }
        if ($memoryStream -is [IDisposable]) { $memoryStream.Dispose() }
    }
}

function Get-Hmac
{
    [OutputType([byte[]])]
    param (
        [Parameter(Mandatory = $true)]
        [byte[]] $Key,

        [Parameter(Mandatory = $true)]
        [byte[]] $Bytes
    )

    $hmac = $null
    $sha = $null

    try
    {
        $sha = New-Object System.Security.Cryptography.SHA256CryptoServiceProvider
        $hmac = New-Object PowerShellUtils.FipsHmacSha256(,$sha.ComputeHash($Key))
        return ,$hmac.ComputeHash($Bytes)
    }
    finally
    {
        if ($null -ne $hmac) { $hmac.Clear() }
        if ($null -ne $sha)  { $sha.Clear() }
    }
}

function Unprotect-DataWithAes
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [byte[]]
        $CipherText,

        [Parameter(Mandatory = $true)]
        [byte[]]
        $Key,

        [Parameter(Mandatory = $true)]
        [byte[]]
        $InitializationVector,

        [byte[]]
        $HMAC
    )

    $aes = $null
    $memoryStream = $null
    $cryptoStream = $null
    $buffer = $null

    if ($null -ne $HMAC)
    {
        Assert-ValidHmac -Key $Key -Bytes $CipherText -Hmac $HMAC
    }

    try
    {
        $aes = New-Object System.Security.Cryptography.AesCryptoServiceProvider -Property @{
            Key = $Key
            IV = $InitializationVector
        }

        # Not sure exactly how long of a buffer we'll need to hold the decrypted data. Twice
        # the ciphertext length should be more than enough.
        $buffer = New-Object PowerShellUtils.PinnedArray[byte](2 * $CipherText.Count)

        $memoryStream = New-Object System.IO.MemoryStream(,$buffer)
        $cryptoStream = New-Object System.Security.Cryptography.CryptoStream(
            $memoryStream, $aes.CreateDecryptor(), 'Write'
        )

        $cryptoStream.Write($CipherText, 0, $CipherText.Count)
        $cryptoStream.FlushFinalBlock()

        $plainText = New-Object PowerShellUtils.PinnedArray[byte]($memoryStream.Position)
        [Array]::Copy($buffer.Array, $plainText.Array, $memoryStream.Position)

        return New-Object psobject -Property @{
            PlainText = $plainText
        }
    }
    finally
    {
        if ($null -ne $aes) { $aes.Clear() }
        if ($cryptoStream -is [IDisposable]) { $cryptoStream.Dispose() }
        if ($memoryStream -is [IDisposable]) { $memoryStream.Dispose() }
        if ($buffer -is [IDisposable]) { $buffer.Dispose() }
    }
}

function Assert-ValidHmac
{
    [OutputType([void])]
    param (
        [Parameter(Mandatory = $true)]
        [byte[]] $Key,

        [Parameter(Mandatory = $true)]
        [byte[]] $Bytes,

        [Parameter(Mandatory = $true)]
        [byte[]] $Hmac
    )

    $recomputedHmac = Get-Hmac -Key $Key -Bytes $Bytes

    if (-not (ByteArraysAreEqual $Hmac $recomputedHmac))
    {
        throw 'Decryption failed due to invalid HMAC.'
    }
}

function ByteArraysAreEqual([byte[]] $First, [byte[]] $Second)
{
    if ($null -eq $First)  { $First = @() }
    if ($null -eq $Second) { $Second = @() }

    if ($First.Length -ne $Second.Length) { return $false }

    $length = $First.Length
    for ($i = 0; $i -lt $length; $i++)
    {
        if ($First[$i] -ne $Second[$i]) { return $false }
    }

    return $true
}

function Add-KeyData
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [byte[]]
        $Key,

        [Parameter(Mandatory = $true)]
        [byte[]]
        $InitializationVector,

        [ValidateNotNull()]
        [AllowEmptyCollection()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2[]]
        $Certificate = @(),

        [switch]
        $UseLegacyPadding,

        [ValidateNotNull()]
        [AllowEmptyCollection()]
        [System.Security.SecureString[]]
        $Password = @(),

        [ValidateRange(1,2147483647)]
        [int]
        $PasswordIterationCount = 50000
    )

    if ($certs.Count -eq 0 -and $Password.Count -eq 0)
    {
        return
    }

    $useOAEP = -not $UseLegacyPadding

    $InputObject.KeyData += @(
        foreach ($cert in $Certificate)
        {
            $match = $InputObject.KeyData |
                     Where-Object { $_.Thumbprint -eq $cert.Thumbprint }

            if ($null -ne $match) { continue }
            Protect-KeyDataWithCertificate -Certificate $cert -Key $Key -InitializationVector $InitializationVector -UseLegacyPadding:$UseLegacyPadding
        }

        foreach ($secureString in $Password)
        {
            $match = $InputObject.KeyData |
                     Where-Object {
                        $params = @{
                            Password = $secureString
                            Salt = $_.HashSalt
                            IterationCount = $_.IterationCount
                        }

                        $null -ne $_.Hash -and $_.Hash -eq (Get-PasswordHash @params)
                     }

            if ($null -ne $match) { continue }
            Protect-KeyDataWithPassword -Password $secureString -Key $Key -InitializationVector $InitializationVector -IterationCount $PasswordIterationCount
        }
    )

} # function Add-KeyData

function Unprotect-MatchingKeyData
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $InputObject,

        [Parameter(Mandatory = $true, ParameterSetName = 'Certificate')]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $Certificate,

        [Parameter(Mandatory = $true, ParameterSetName = 'Password')]
        [System.Security.SecureString]
        $Password
    )

    if ($PSCmdlet.ParameterSetName -eq 'Certificate')
    {
        $keyData = $InputObject.KeyData |
                    Where-Object { (Test-IsCertificateProtectedKeyData -InputObject $_) -and $_.Thumbprint -eq $Certificate.Thumbprint } |
                    Select-Object -First 1

        if ($null -eq $keyData)
        {
            throw "Protected data object was not encrypted with certificate '$($Certificate.Thumbprint)'."
        }

        try
        {
            return Unprotect-KeyDataWithCertificate -KeyData $keyData -Certificate $Certificate
        }
        catch
        {
            throw
        }
    }
    else
    {
        $keyData =
        $InputObject.KeyData |
        Where-Object {
            (Test-IsPasswordProtectedKeyData -InputObject $_) -and
            $_.Hash -eq (Get-PasswordHash -Password $Password -Salt $_.HashSalt -IterationCount $_.IterationCount)
        } |
        Select-Object -First 1

        if ($null -eq $keyData)
        {
            throw 'Protected data object was not encrypted with the specified password.'
        }

        try
        {
            return Unprotect-KeyDataWithPassword -KeyData $keyData -Password $Password
        }
        catch
        {
            throw
        }
    }

} # function Unprotect-MatchingKeyData

function ValidateKeyEncryptionCertificate
{
    [CmdletBinding()]
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
    param (
        [System.Security.Cryptography.X509Certificates.X509Certificate2[]]
        $CertificateGroup,

        [switch]
        $RequirePrivateKey
    )

    process
    {
        $Certificate = $CertificateGroup[0]

        $isEccCertificate = $Certificate.GetKeyAlgorithm() -eq $script:EccAlgorithmOid

        if (($Certificate.PublicKey.Key -isnot [System.Security.Cryptography.RSACryptoServiceProvider] -and
            $Certificate.PublicKey.Key -isnot [System.Security.Cryptography.RSACng]) -and
            -not $isEccCertificate)
        {
            Write-Error "Certficiate '$($Certificate.Thumbprint)' is not an RSA or ECDH certificate."
            return
        }

        if ($isEccCertificate)
        {
            $neededKeyUsage = [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::KeyAgreement
        }
        else
        {
            $neededKeyUsage = [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::KeyEncipherment
        }

        $keyUsageFlags = 0

        foreach ($extension in $Certificate.Extensions)
        {
            if ($extension -is [System.Security.Cryptography.X509Certificates.X509KeyUsageExtension])
            {
                $keyUsageFlags = $keyUsageFlags -bor $extension.KeyUsages
            }
        }

        if (($keyUsageFlags -band $neededKeyUsage) -ne $neededKeyUsage)
        {
            Write-Error "Certificate '$($Certificate.Thumbprint)' does not have the required $($neededKeyUsage.ToString()) Key Usage flag."
            return
        }

        if ($RequirePrivateKey)
        {
            $Certificate = $CertificateGroup |
                           Where-Object { TestPrivateKey -Certificate $_ } |
                           Select-Object -First 1

            if ($null -eq $Certificate)
            {
                Write-Error "Could not find private key for certificate '$($CertificateGroup[0].Thumbprint)'."
                return
            }
        }

        $Certificate

    } # process

} # function ValidateKeyEncryptionCertificate

function TestPrivateKey([System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate)
{
    if (-not $Certificate.HasPrivateKey) { return $false }
    if ($Certificate.PrivateKey -is [System.Security.Cryptography.RSACryptoServiceProvider] -or $Certificate.PrivateKey -is [System.Security.Cryptography.RSACng])
    {
        return $true
    }

    $cngKey = $null
    try
    {
        if ([Security.Cryptography.X509Certificates.X509CertificateExtensionMethods]::HasCngKey($Certificate))
        {
            $cngKey = [Security.Cryptography.X509Certificates.X509Certificate2ExtensionMethods]::GetCngPrivateKey($Certificate)
            return $null -ne $cngKey -and
                   ($cngKey.AlgorithmGroup -eq [System.Security.Cryptography.CngAlgorithmGroup]::Rsa -or
                    $cngKey.AlgorithmGroup -eq [System.Security.Cryptography.CngAlgorithmGroup]::ECDiffieHellman)
        }
    }
    catch
    {
        return $false
    }
    finally
    {
        if ($cngKey -is [IDisposable]) { $cngKey.Dispose() }
    }
}

function Get-KeyGenerator
{
    [CmdletBinding(DefaultParameterSetName = 'CreateNew')]
    [OutputType([System.Security.Cryptography.Rfc2898DeriveBytes])]
    param (
        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]
        $Password,

        [Parameter(Mandatory = $true, ParameterSetName = 'RestoreExisting')]
        [byte[]]
        $Salt,

        [ValidateRange(1,2147483647)]
        [int]
        $IterationCount = 50000
    )

    $byteArray = $null

    try
    {
        $byteArray = Convert-SecureStringToPinnedByteArray -SecureString $Password

        if ($PSCmdlet.ParameterSetName -eq 'RestoreExisting')
        {
            $saltBytes = $Salt
        }
        else
        {
            $saltBytes = Get-RandomBytes -Count 32
        }

        New-Object System.Security.Cryptography.Rfc2898DeriveBytes($byteArray, $saltBytes, $IterationCount)
    }
    finally
    {
        if ($byteArray -is [IDisposable]) { $byteArray.Dispose() }
    }

} # function Get-KeyGenerator

function Get-PasswordHash
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]
        $Password,

        [Parameter(Mandatory = $true)]
        [byte[]]
        $Salt,

        [ValidateRange(1, 2147483647)]
        [int]
        $IterationCount = 50000
    )

    $keyGen = $null

    try
    {
        $keyGen = Get-KeyGenerator @PSBoundParameters
        [BitConverter]::ToString($keyGen.GetBytes(32)) -replace '[^A-F\d]'
    }
    finally
    {
        if ($keyGen -is [IDisposable]) { $keyGen.Dispose() }
    }

} # function Get-PasswordHash

function Get-RandomBytes
{
    [CmdletBinding()]
    [OutputType([byte[]])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateRange(1,1000)]
        $Count
    )

    $rng = $null

    try
    {
        $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
        $bytes = New-Object byte[]($Count)
        $rng.GetBytes($bytes)

        ,$bytes
    }
    finally
    {
        if ($rng -is [IDisposable]) { $rng.Dispose() }
    }

} # function Get-RandomBytes

function Protect-KeyDataWithCertificate
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $Certificate,

        [byte[]]
        $Key,

        [byte[]]
        $InitializationVector,

        [switch] $UseLegacyPadding
    )

    if ($Certificate.PublicKey.Key -is [System.Security.Cryptography.RSACryptoServiceProvider] -or $Certificate.PublicKey.Key -is [System.Security.Cryptography.RSACng])
    {
        Protect-KeyDataWithRsaCertificate -Certificate $Certificate -Key $Key -InitializationVector $InitializationVector -UseLegacyPadding:$UseLegacyPadding
    }
    elseif ($Certificate.GetKeyAlgorithm() -eq $script:EccAlgorithmOid)
    {
        Protect-KeyDataWithEcdhCertificate -Certificate $Certificate -Key $Key -InitializationVector $InitializationVector
    }
}

function Protect-KeyDataWithRsaCertificate
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $Certificate,

        [byte[]]
        $Key,

        [byte[]]
        $InitializationVector,

        [switch] $UseLegacyPadding
    )

    $useOAEP = -not $UseLegacyPadding

    try
    {
        if ($Certificate.PublicKey.Key -is [System.Security.Cryptography.RSACryptoServiceProvider])
        {
            New-Object psobject -Property @{
                Key = $Certificate.PublicKey.Key.Encrypt($key, $useOAEP)
                IV = $Certificate.PublicKey.Key.Encrypt($InitializationVector, $useOAEP)
                Thumbprint = $Certificate.Thumbprint
                LegacyPadding = [bool] $UseLegacyPadding
            }
        }
        else
        {
            if (-not $useOAEP)
            {
                throw 'RSA encryption with PKCS#1 v1.5 padding is not supported with CNG keys.'
            }

            New-Object psobject -Property @{
                Key = $Certificate.PublicKey.Key.Encrypt($key, [System.Security.Cryptography.RSAEncryptionPadding]::OaepSHA1)
                IV = $Certificate.PublicKey.Key.Encrypt($InitializationVector, [System.Security.Cryptography.RSAEncryptionPadding]::OaepSHA1)
                Thumbprint = $Certificate.Thumbprint
                LegacyPadding = [bool] $UseLegacyPadding
            }
        }
    }
    catch
    {
        Write-Error -ErrorRecord $_
    }
}

function Protect-KeyDataWithEcdhCertificate
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $Certificate,

        [byte[]]
        $Key,

        [byte[]]
        $InitializationVector
    )

    $publicKey = $null
    $ephemeralKey = $null
    $ecdh = $null
    $derivedKey = $null

    try
    {
        $publicKey = Get-EcdhPublicKey -Certificate $cert

        $ephemeralKey = [System.Security.Cryptography.CngKey]::Create($publicKey.Algorithm)
        $ecdh = [System.Security.Cryptography.ECDiffieHellmanCng]$ephemeralKey

        $derivedKey = New-Object PowerShellUtils.PinnedArray[byte](
            ,($ecdh.DeriveKeyMaterial($publicKey) | Select-Object -First 32)
        )

        if ($derivedKey.Count -ne 32)
        {
            # This shouldn't happen, but just in case...
            throw "Error:  Key material derived from ECDH certificate $($Certificate.Thumbprint) was less than the required 32 bytes"
        }

        $ecdhIv = Get-RandomBytes -Count 16

        $encryptedKey = Protect-DataWithAes -PlainText $Key -Key $derivedKey -InitializationVector $ecdhIv -NoHMAC
        $encryptedIv  = Protect-DataWithAes -PlainText $InitializationVector -Key $derivedKey -InitializationVector $ecdhIv -NoHMAC

        New-Object psobject -Property @{
            Key = $encryptedKey.CipherText
            IV = $encryptedIv.CipherText
            EcdhPublicKey = $ecdh.PublicKey.ToByteArray()
            EcdhIV = $ecdhIv
            Thumbprint = $Certificate.Thumbprint
        }
    }
    finally
    {
        if ($publicKey -is [IDisposable]) { $publicKey.Dispose() }
        if ($ephemeralKey -is [IDisposable]) { $ephemeralKey.Dispose() }
        if ($null -ne $ecdh) { $ecdh.Clear() }
        if ($derivedKey -is [IDisposable]) { $derivedKey.Dispose() }
    }
}

function Get-EcdhPublicKey([System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate)
{
    # If we get here, we've already verified that the certificate has the Key Agreement usage extension,
    # and that it is an ECC algorithm cert, meaning we can treat the OIDs as ECDH algorithms.  (These OIDs
    # are shared with ECDSA, for some reason, and the ECDSA magic constants are different.)

    $magic = @{
        '1.2.840.10045.3.1.7' = [uint32]0x314B4345L # BCRYPT_ECDH_PUBLIC_P256_MAGIC
        '1.3.132.0.34'        = [uint32]0x334B4345L # BCRYPT_ECDH_PUBLIC_P384_MAGIC
        '1.3.132.0.35'        = [uint32]0x354B4345L # BCRYPT_ECDH_PUBLIC_P521_MAGIC
    }

    $algorithm = Get-AlgorithmOid -Certificate $Certificate

    if (-not $magic.ContainsKey($algorithm))
    {
        throw "Certificate '$($Certificate.Thumbprint)' returned an unknown Public Key Algorithm OID: '$algorithm'"
    }

    $size = (($cert.GetPublicKey().Count - 1) / 2)

    $keyBlob = [byte[]]@(
        [System.BitConverter]::GetBytes($magic[$algorithm])
        [System.BitConverter]::GetBytes($size)
        $cert.GetPublicKey() | Select-Object -Skip 1
    )

    return [System.Security.Cryptography.CngKey]::Import($keyBlob, [System.Security.Cryptography.CngKeyBlobFormat]::EccPublicBlob)
}


function Get-AlgorithmOid([System.Security.Cryptography.X509Certificates.X509Certificate] $Certificate)
{
    $algorithmOid = $Certificate.GetKeyAlgorithm();

    if ($algorithmOid -eq $script:EccAlgorithmOid)
    {
        $algorithmOid = DecodeBinaryOid -Bytes $Certificate.GetKeyAlgorithmParameters()
    }

    return $algorithmOid
}

function DecodeBinaryOid([byte[]] $Bytes)
{
    # Thanks to Vadims Podans (http://sysadmins.lv/) for this cool technique to take a byte array
    # and decode the OID without having to use P/Invoke to call the CryptDecodeObject function directly.

    [byte[]] $ekuBlob = @(
        48
        $Bytes.Count
        $Bytes
    )

    $asnEncodedData = New-Object System.Security.Cryptography.AsnEncodedData(,$ekuBlob)
    $enhancedKeyUsage = New-Object System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension($asnEncodedData, $false)

    return $enhancedKeyUsage.EnhancedKeyUsages[0].Value
}

function Unprotect-KeyDataWithCertificate
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $KeyData,

        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $Certificate
    )

    if ($Certificate.PublicKey.Key -is [System.Security.Cryptography.RSACryptoServiceProvider] -or $Certificate.PublicKey.Key -is [System.Security.Cryptography.RSACng])
    {
        Unprotect-KeyDataWithRsaCertificate -KeyData $KeyData -Certificate $Certificate
    }
    elseif ($Certificate.GetKeyAlgorithm() -eq $script:EccAlgorithmOid)
    {
        Unprotect-KeyDataWithEcdhCertificate -KeyData $KeyData -Certificate $Certificate
    }
}

function Unprotect-KeyDataWithEcdhCertificate
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $KeyData,

        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $Certificate
    )

    $doFinallyBlock = $true
    $key = $null
    $iv = $null
    $derivedKey = $null
    $publicKey = $null
    $privateKey = $null
    $ecdh = $null

    try
    {
        $privateKey = [Security.Cryptography.X509Certificates.X509Certificate2ExtensionMethods]::GetCngPrivateKey($Certificate)

        if ($privateKey.AlgorithmGroup -ne [System.Security.Cryptography.CngAlgorithmGroup]::ECDiffieHellman)
        {
            throw "Certificate '$($Certificate.Thumbprint)' contains a non-ECDH key pair."
        }

        if ($null -eq $KeyData.EcdhPublicKey -or $null -eq $KeyData.EcdhIV)
        {
            throw "Certificate '$($Certificate.Thumbprint)' is a valid ECDH certificate, but the stored KeyData structure is missing the public key and/or IV used during encryption."
        }

        $publicKey = [System.Security.Cryptography.CngKey]::Import($KeyData.EcdhPublicKey, [System.Security.Cryptography.CngKeyBlobFormat]::EccPublicBlob)
        $ecdh = [System.Security.Cryptography.ECDiffieHellmanCng]$privateKey

        $derivedKey = New-Object PowerShellUtils.PinnedArray[byte](,($ecdh.DeriveKeyMaterial($publicKey) | Select-Object -First 32))
        if ($derivedKey.Count -ne 32)
        {
            # This shouldn't happen, but just in case...
            throw "Error:  Key material derived from ECDH certificate $($Certificate.Thumbprint) was less than the required 32 bytes"
        }

        $key = (Unprotect-DataWithAes -CipherText $KeyData.Key -Key $derivedKey -InitializationVector $KeyData.EcdhIV).PlainText
        $iv = (Unprotect-DataWithAes -CipherText $KeyData.IV -Key $derivedKey -InitializationVector $KeyData.EcdhIV).PlainText

        $doFinallyBlock = $false

        return New-Object psobject -Property @{
            Key = $key
            IV = $iv
        }
    }
    catch
    {
        throw
    }
    finally
    {
        if ($doFinallyBlock)
        {
            if ($key -is [IDisposable]) { $key.Dispose() }
            if ($iv -is [IDisposable]) { $iv.Dispose() }
        }

        if ($derivedKey -is [IDisposable]) { $derivedKey.Dispose() }
        if ($privateKey -is [IDisposable]) { $privateKey.Dispose() }
        if ($publicKey -is [IDisposable]) { $publicKey.Dispose() }
        if ($null -ne $ecdh) { $ecdh.Clear() }
    }
}

function Unprotect-KeyDataWithRsaCertificate
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $KeyData,

        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $Certificate
    )

    $useOAEP = -not $keyData.LegacyPadding

    $key = $null
    $iv = $null
    $doFinallyBlock = $true

    try
    {
        $key = DecryptRsaData -Certificate $Certificate -CipherText $keyData.Key -UseOaepPadding:$useOAEP
        $iv = DecryptRsaData -Certificate $Certificate -CipherText $keyData.IV -UseOaepPadding:$useOAEP

        $doFinallyBlock = $false

        return New-Object psobject -Property @{
            Key = $key
            IV = $iv
        }
    }
    catch
    {
        throw
    }
    finally
    {
        if ($doFinallyBlock)
        {
            if ($key -is [IDisposable]) { $key.Dispose() }
            if ($iv -is [IDisposable]) { $iv.Dispose() }
        }
    }
}

function DecryptRsaData([System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate,
                     [byte[]] $CipherText,
                     [switch] $UseOaepPadding)
{
    if ($Certificate.PrivateKey -is [System.Security.Cryptography.RSACryptoServiceProvider] -or $Certificate.PrivateKey -is [System.Security.Cryptography.RSACng])
    {
        if (-not $UseOaepPadding)
        {
            return New-Object PowerShellUtils.PinnedArray[byte](
                ,$Certificate.PrivateKey.Decrypt($CipherText, [System.Security.Cryptography.RSAEncryptionPadding]::Pkcs1)
            )
        }
        else
        {
            return New-Object PowerShellUtils.PinnedArray[byte](
                ,$Certificate.PrivateKey.Decrypt($CipherText, [System.Security.Cryptography.RSAEncryptionPadding]::OaepSHA1)
            )
        }
    }

    # By the time we get here, we've already validated that either the certificate has an RsaCryptoServiceProvider
    # object in its PrivateKey property, or we can fetch an RSA CNG key.

    $cngKey = $null
    $cngRsa = $null
    try
    {
        $cngKey = [Security.Cryptography.X509Certificates.X509Certificate2ExtensionMethods]::GetCngPrivateKey($Certificate)
        $cngRsa = [Security.Cryptography.RSACng]$cngKey

        if (-not $UseOaepPadding)
        {
            return New-Object PowerShellUtils.PinnedArray[byte](
                ,$cngRsa.Decrypt($CipherText, [System.Security.Cryptography.RSAEncryptionPadding]::Pkcs1)
            )
        }
        else
        {
            return New-Object PowerShellUtils.PinnedArray[byte](
                ,$cngRsa.Decrypt($CipherText, [System.Security.Cryptography.RSAEncryptionPadding]::OaepSHA1)
            )
        }
    }
    catch
    {
        throw
    }
    finally
    {
        if ($cngKey -is [IDisposable]) { $cngKey.Dispose() }
        if ($null -ne $cngRsa) { $cngRsa.Clear() }
    }
}

function Protect-KeyDataWithPassword
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]
        $Password,

        [Parameter(Mandatory = $true)]
        [byte[]]
        $Key,

        [Parameter(Mandatory = $true)]
        [byte[]]
        $InitializationVector,

        [ValidateRange(1,2147483647)]
        [int]
        $IterationCount = 50000
    )

    $keyGen = $null
    $ephemeralKey = $null
    $ephemeralIV = $null

    try
    {
        $keyGen = Get-KeyGenerator -Password $Password -IterationCount $IterationCount
        $ephemeralKey = New-Object PowerShellUtils.PinnedArray[byte](,$keyGen.GetBytes(32))
        $ephemeralIV = New-Object PowerShellUtils.PinnedArray[byte](,$keyGen.GetBytes(16))

        $hashSalt = Get-RandomBytes -Count 32
        $hash = Get-PasswordHash -Password $Password -Salt $hashSalt -IterationCount $IterationCount

        $encryptedKey = (Protect-DataWithAes -PlainText $Key -Key $ephemeralKey -InitializationVector $ephemeralIV -NoHMAC).CipherText
        $encryptedIV = (Protect-DataWithAes -PlainText $InitializationVector -Key $ephemeralKey -InitializationVector $ephemeralIV -NoHMAC).CipherText

        New-Object psobject -Property @{
            Key = $encryptedKey
            IV = $encryptedIV
            Salt = $keyGen.Salt
            IterationCount = $keyGen.IterationCount
            Hash = $hash
            HashSalt = $hashSalt
        }
    }
    catch
    {
        throw
    }
    finally
    {
        if ($keyGen -is [IDisposable]) { $keyGen.Dispose() }
        if ($ephemeralKey -is [IDisposable]) { $ephemeralKey.Dispose() }
        if ($ephemeralIV -is [IDisposable]) { $ephemeralIV.Dispose() }
    }

} # function Protect-KeyDataWithPassword

function Unprotect-KeyDataWithPassword
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $KeyData,

        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]
        $Password
    )

    $keyGen = $null
    $key = $null
    $iv = $null
    $ephemeralKey = $null
    $ephemeralIV = $null

    $doFinallyBlock = $true

    try
    {
        $params = @{
            Password = $Password
            Salt = $KeyData.Salt.Clone()
            IterationCount = $KeyData.IterationCount
        }

        $keyGen = Get-KeyGenerator @params
        $ephemeralKey = New-Object PowerShellUtils.PinnedArray[byte](,$keyGen.GetBytes(32))
        $ephemeralIV = New-Object PowerShellUtils.PinnedArray[byte](,$keyGen.GetBytes(16))

        $key = (Unprotect-DataWithAes -CipherText $KeyData.Key -Key $ephemeralKey -InitializationVector $ephemeralIV).PlainText
        $iv = (Unprotect-DataWithAes -CipherText $KeyData.IV -Key $ephemeralKey -InitializationVector $ephemeralIV).PlainText

        $doFinallyBlock = $false

        return New-Object psobject -Property @{
            Key = $key
            IV = $iv
        }
    }
    catch
    {
        throw
    }
    finally
    {
        if ($keyGen -is [IDisposable]) { $keyGen.Dispose() }
        if ($ephemeralKey -is [IDisposable]) { $ephemeralKey.Dispose() }
        if ($ephemeralIV -is [IDisposable]) { $ephemeralIV.Dispose() }

        if ($doFinallyBlock)
        {
            if ($key -is [IDisposable]) { $key.Dispose() }
            if ($iv -is [IDisposable]) { $iv.Dispose() }
        }
    }
} # function Unprotect-KeyDataWithPassword

function ConvertTo-PinnedByteArray
{
    [CmdletBinding()]
    [OutputType([PowerShellUtils.PinnedArray[byte]])]
    param (
        [Parameter(Mandatory = $true)]
        $InputObject
    )

    try
    {
        switch ($InputObject.GetType().FullName)
        {
            ([string].FullName)
            {
                $pinnedArray = Convert-StringToPinnedByteArray -String $InputObject
                break
            }

            ([System.Security.SecureString].FullName)
            {
                $pinnedArray = Convert-SecureStringToPinnedByteArray -SecureString $InputObject
                break
            }

            ([System.Management.Automation.PSCredential].FullName)
            {
                $pinnedArray = Convert-PSCredentialToPinnedByteArray -Credential $InputObject
                break
            }

            default
            {
                $byteArray = $InputObject -as [byte[]]

                if ($null -eq $byteArray)
                {
                    throw 'Something unexpected got through our parameter validation.'
                }
                else
                {
                    $pinnedArray = New-Object PowerShellUtils.PinnedArray[byte](
                        ,$byteArray.Clone()
                    )
                }
            }

        }

        $pinnedArray
    }
    catch
    {
        throw
    }

} # function ConvertTo-PinnedByteArray

function ConvertFrom-ByteArray
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [byte[]]
        $ByteArray,

        [Parameter(Mandatory = $true)]
        [ValidateScript({
            if ($script:ValidTypes -notcontains $_)
            {
                throw "Invalid type specified. Type must be one of: $($script:ValidTypes -join ', ')"
            }

            return $true
        })]
        [type]
        $Type,

        [UInt32]
        $StartIndex = 0,

        [Nullable[UInt32]]
        $ByteCount = $null
    )

    if ($null -eq $ByteCount)
    {
        $ByteCount = $ByteArray.Count - $StartIndex
    }

    if ($StartIndex + $ByteCount -gt $ByteArray.Count)
    {
        throw 'The specified index and count values exceed the bounds of the array.'
    }

    switch ($Type.FullName)
    {
        ([string].FullName)
        {
            Convert-ByteArrayToString -ByteArray $ByteArray -StartIndex $StartIndex -ByteCount $ByteCount
            break
        }

        ([System.Security.SecureString].FullName)
        {
            Convert-ByteArrayToSecureString -ByteArray $ByteArray -StartIndex $StartIndex -ByteCount $ByteCount
            break
        }

        ([System.Management.Automation.PSCredential].FullName)
        {
            Convert-ByteArrayToPSCredential -ByteArray $ByteArray -StartIndex $StartIndex -ByteCount $ByteCount
            break
        }

        ([byte[]].FullName)
        {
            $array = New-Object byte[]($ByteCount)
            [Array]::Copy($ByteArray, $StartIndex, $array, 0, $ByteCount)

            ,$array
            break
        }

        default
        {
            throw 'Something unexpected got through parameter validation.'
        }
    }

} # function ConvertFrom-ByteArray

function Convert-StringToPinnedByteArray
{
    [CmdletBinding()]
    [OutputType([PowerShellUtils.PinnedArray[byte]])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $String
    )

    New-Object PowerShellUtils.PinnedArray[byte](
        ,[System.Text.Encoding]::UTF8.GetBytes($String)
    )
}

function Convert-SecureStringToPinnedByteArray
{
    [CmdletBinding()]
    [OutputType([PowerShellUtils.PinnedArray[byte]])]
    param (
        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]
        $SecureString
    )

    try
    {
        $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($SecureString)
        $byteCount = $SecureString.Length * 2
        $pinnedArray = New-Object PowerShellUtils.PinnedArray[byte]($byteCount)

        [System.Runtime.InteropServices.Marshal]::Copy($ptr, $pinnedArray, 0, $byteCount)

        $pinnedArray
    }
    catch
    {
        throw
    }
    finally
    {
        if ($null -ne $ptr)
        {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeGlobalAllocUnicode($ptr)
        }
    }

} # function Convert-SecureStringToPinnedByteArray

function Convert-PSCredentialToPinnedByteArray
{
    [CmdletBinding()]
    [OutputType([PowerShellUtils.PinnedArray[byte]])]
    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    $passwordBytes = $null
    $pinnedArray = $null

    try
    {
        $passwordBytes = Convert-SecureStringToPinnedByteArray -SecureString $Credential.Password
        $usernameBytes = [System.Text.Encoding]::Unicode.GetBytes($Credential.UserName)
        $sizeBytes = [System.BitConverter]::GetBytes([uint32]$usernameBytes.Count)

        if (-not [System.BitConverter]::IsLittleEndian) { [Array]::Reverse($sizeBytes) }

        $doFinallyBlock = $true

        try
        {
            $bufferSize = $passwordBytes.Count +
                          $usernameBytes.Count +
                          $script:PSCredentialHeader.Count +
                          $sizeBytes.Count
            $pinnedArray = New-Object PowerShellUtils.PinnedArray[byte]($bufferSize)

            $destIndex = 0

            [Array]::Copy(
                $script:PSCredentialHeader, 0, $pinnedArray.Array, $destIndex, $script:PSCredentialHeader.Count
            )
            $destIndex += $script:PSCredentialHeader.Count

            [Array]::Copy($sizeBytes, 0, $pinnedArray.Array, $destIndex, $sizeBytes.Count)
            $destIndex += $sizeBytes.Count

            [Array]::Copy($usernameBytes, 0, $pinnedArray.Array, $destIndex, $usernameBytes.Count)
            $destIndex += $usernameBytes.Count

            [Array]::Copy($passwordBytes.Array, 0, $pinnedArray.Array, $destIndex, $passwordBytes.Count)

            $doFinallyBlock = $false
            $pinnedArray
        }
        finally
        {
            if ($doFinallyBlock)
            {
                if ($pinnedArray -is [IDisposable]) { $pinnedArray.Dispose() }
            }
        }
    }
    catch
    {
        throw
    }
    finally
    {
        if ($passwordBytes -is [IDisposable]) { $passwordBytes.Dispose() }
    }

} # function Convert-PSCredentialToPinnedByteArray

function Convert-ByteArrayToString
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [byte[]]
        $ByteArray,

        [Parameter(Mandatory = $true)]
        [UInt32]
        $StartIndex,

        [Parameter(Mandatory = $true)]
        [UInt32]
        $ByteCount
    )

    [System.Text.Encoding]::UTF8.GetString($ByteArray, $StartIndex, $ByteCount)
}

function Convert-ByteArrayToSecureString
{
    [CmdletBinding()]
    [OutputType([System.Security.SecureString])]
    param (
        [Parameter(Mandatory = $true)]
        [byte[]]
        $ByteArray,

        [Parameter(Mandatory = $true)]
        [UInt32]
        $StartIndex,

        [Parameter(Mandatory = $true)]
        [UInt32]
        $ByteCount
    )

    $chars = $null
    $memoryStream = $null
    $streamReader = $null

    try
    {
        $ss = New-Object System.Security.SecureString
        $memoryStream = New-Object System.IO.MemoryStream($ByteArray, $StartIndex, $ByteCount)
        $streamReader = New-Object System.IO.StreamReader($memoryStream, [System.Text.Encoding]::Unicode, $false)
        $chars = New-Object PowerShellUtils.PinnedArray[char](1024)

        while (($read = $streamReader.Read($chars, 0, $chars.Count)) -gt 0)
        {
            for ($i = 0; $i -lt $read; $i++)
            {
                $ss.AppendChar($chars[$i])
            }
        }

        $ss.MakeReadOnly()
        $ss
    }
    finally
    {
        if ($streamReader -is [IDisposable]) { $streamReader.Dispose() }
        if ($memoryStream -is [IDisposable]) { $memoryStream.Dispose() }
        if ($chars -is [IDisposable]) { $chars.Dispose() }
    }

} # function Convert-ByteArrayToSecureString

function Convert-ByteArrayToPSCredential
{
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCredential])]
    param (
        [Parameter(Mandatory = $true)]
        [byte[]]
        $ByteArray,

        [Parameter(Mandatory = $true)]
        [UInt32]
        $StartIndex,

        [Parameter(Mandatory = $true)]
        [UInt32]
        $ByteCount
    )

    $message = 'Byte array is not a serialized PSCredential object.'

    if ($ByteCount -lt $script:PSCredentialHeader.Count + 4) { throw $message }

    for ($i = 0; $i -lt $script:PSCredentialHeader.Count; $i++)
    {
        if ($ByteArray[$StartIndex + $i] -ne $script:PSCredentialHeader[$i]) { throw $message }
    }

    $i = $StartIndex + $script:PSCredentialHeader.Count

    $sizeBytes = $ByteArray[$i..($i+3)]
    if (-not [System.BitConverter]::IsLittleEndian) { [array]::Reverse($sizeBytes) }

    $i += 4
    $size = [System.BitConverter]::ToUInt32($sizeBytes, 0)

    if ($ByteCount -lt $i + $size) { throw $message }

    $userName = [System.Text.Encoding]::Unicode.GetString($ByteArray, $i, $size)
    $i += $size

    try
    {
        $params = @{
            ByteArray = $ByteArray
            StartIndex = $i
            ByteCount = $StartIndex + $ByteCount - $i
        }
        $secureString = Convert-ByteArrayToSecureString @params
    }
    catch
    {
        throw $message
    }

    New-Object System.Management.Automation.PSCredential($userName, $secureString)

} # function Convert-ByteArrayToPSCredential

function Test-IsProtectedData
{
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [psobject]
        $InputObject
    )

    $isValid = $true

    $cipherText = $InputObject.CipherText -as [byte[]]
    $type = $InputObject.Type -as [string]

    if ($null -eq $cipherText -or $cipherText.Count -eq 0 -or
        [string]::IsNullOrEmpty($type) -or
        $null -eq $InputObject.KeyData)
    {
        $isValid = $false
    }

    if ($isValid)
    {
        foreach ($object in $InputObject.KeyData)
        {
            if (-not (Test-IsKeyData -InputObject $object))
            {
                $isValid = $false
                break
            }
        }
    }

    return $isValid

} # function Test-IsProtectedData

function Test-IsKeyData
{
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [psobject]
        $InputObject
    )

    $isValid = $true

    $key = $InputObject.Key -as [byte[]]
    $iv = $InputObject.IV -as [byte[]]

    if ($null -eq $key -or $null -eq $iv -or $key.Count -eq 0 -or $iv.Count -eq 0)
    {
        $isValid = $false
    }

    if ($isValid)
    {
        $isCertificate = Test-IsCertificateProtectedKeyData -InputObject $InputObject
        $isPassword = Test-IsPasswordProtectedKeydata -InputObject $InputObject
        $isValid = $isCertificate -or $isPassword
    }

    return $isValid

} # function Test-IsKeyData

function Test-IsPasswordProtectedKeyData
{
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [psobject]
        $InputObject
    )

    $isValid = $true

    $salt = $InputObject.Salt -as [byte[]]
    $hash = $InputObject.Hash -as [string]
    $hashSalt = $InputObject.HashSalt -as [byte[]]
    $iterations = $InputObject.IterationCount -as [int]

    if ($null -eq $salt -or $salt.Count -eq 0 -or
        $null -eq $hashSalt -or $hashSalt.Count -eq 0 -or
        $null -eq $iterations -or $iterations -eq 0 -or
        $null -eq $hash -or $hash -notmatch '^[A-F\d]+$')
    {
        $isValid = $false
    }

    return $isValid

} # function Test-IsPasswordProtectedKeyData

function Test-IsCertificateProtectedKeyData
{
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [psobject]
        $InputObject
    )

    $isValid = $true

    $thumbprint = $InputObject.Thumbprint -as [string]

    if ($null -eq $thumbprint -or $thumbprint -notmatch '^[A-F\d]+$')
    {
        $isValid = $false
    }

    return $isValid

} # function Test-IsCertificateProtectedKeyData

#endregion
