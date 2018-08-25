#requires -RunAsAdministrator
# Test-xDscResource requires administrator privileges, so we may as well enforce that here.

end
{
    Get-Module xDscResourceDesigner -All | Remove-Module -Force
    Import-Module $PSScriptRoot\xDscResourceDesigner.psd1 -ErrorAction Stop

    Describe 'xDscResourceDesigner' {
        It 'Should not error if imported twice' {
            Get-Module xDscResourceDesigner -All | Remove-Module -Force
            { Import-Module $PSScriptRoot\xDscResourceDesigner.psd1 -ErrorAction Stop } | Should Not Throw
        }
    }

    Describe Test-xDscResource {
        Context 'A module with a psm1 file but no matching schema.mof' {
            Setup -Dir TestResource
            Setup -File TestResource\TestResource.psm1 -Content (Get-TestDscResourceModuleContent)

            It 'Should fail the test' {
                $null = $($result = Test-xDscResource -Name $TestDrive\TestResource) 2>&1
                $result | Should Be $false
            }
        }

        Context 'A module with a schema.mof file but no psm1 file' {
            Setup -Dir TestResource
            Setup -File TestResource\TestResource.schema.mof -Content (Get-TestDscResourceSchemaContent)

            It 'Should fail the test' {
                $null = $($result = Test-xDscResource -Name $TestDrive\TestResource) 2>&1
                $result | Should Be $false
            }
        }

        Context 'A resource with both required files, valid contents' {
            Setup -Dir TestResource
            Setup -File TestResource\TestResource.schema.mof -Content (Get-TestDscResourceSchemaContent)
            Setup -File TestResource\TestResource.psm1 -Content (Get-TestDscResourceModuleContent)

            It 'Should pass the test' {
                $result = Test-xDscResource -Name $TestDrive\TestResource
                $result | Should Be $true
            }
        }
    }

    Describe New-xDscResourceProperty {
        $hash = @{ Result = $null }

        It 'Allows the use of the ValidateSet parameter' {
            $scriptBlock = {
                $hash.Result = New-xDscResourceProperty  -Name Ensure  -Type String  -Attribute Required  -ValidateSet 'Present','Absent'
            }

            $scriptBlock | Should Not Throw

            $hash.Result.Values.Count | Should Be 2
            $hash.Result.Values[0]    | Should Be 'Present'
            $hash.Result.Values[1]    | Should Be 'Absent'

            $hash.Result.ValueMap.Count | Should Be 2
            $hash.Result.ValueMap[0]    | Should Be 'Present'
            $hash.Result.ValueMap[1]    | Should Be 'Absent'
        }

        It 'Allows the use of the ValueMap and Values parameters' {
            $scriptBlock = {
                $hash.Result = New-xDscResourceProperty  -Name Ensure  -Type String  -Attribute Required  -Values 'Present','Absent' -ValueMap 'Present','Absent'
            }

            $scriptBlock | Should Not Throw

            $hash.Result.Values.Count | Should Be 2
            $hash.Result.Values[0]    | Should Be 'Present'
            $hash.Result.Values[1]    | Should Be 'Absent'

            $hash.Result.ValueMap.Count | Should Be 2
            $hash.Result.ValueMap[0]    | Should Be 'Present'
            $hash.Result.ValueMap[1]    | Should Be 'Absent'
        }

        It 'Does not allow ValidateSet and Values / ValueMap to be used together' {
            $scriptBlock = {
                New-xDscResourceProperty  -Name Ensure `
                                          -Type String `
                                          -Attribute Required `
                                          -Values 'Present','Absent' `
                                          -ValueMap 'Present','Absent' `
                                          -ValidateSet 'Present', 'Absent'
            }

            $scriptBlock | Should Throw 'Parameter set cannot be resolved'
        }
    }

    InModuleScope xDscResourceDesigner {
        function Get-xDSCSchemaFriendlyName
        {
            Param(
                $Path
            )
            $cimClass = 0
            Try
            {
                [System.Void](Test-xDscSchemaInternal -Schema $Path -SchemaCimClass ([ref]$cimClass) -ErrorAction Stop 2>&1)
                if($cimClass -ne 0)
                {
                    $FriendlyName = $cimClass.CimClassQualifiers.Where{$_.Name -eq 'FriendlyName'}.Value
                }
            }
            Catch
            {
                Throw
            }
            return $FriendlyName
        }
        Describe 'Creating and updating resources' {
            Context 'Creating and updating a DSC Resource' {
                Setup -Dir TestResource
                #region Create New Resource
                $ResourceProperties = $(
                    New-xDscResourceProperty -Name KeyProperty -Type String -Attribute Key
                    New-xDscResourceProperty -Name RequiredProperty -Type String -Attribute Required
                    New-xDscResourceProperty -Name WriteProperty -Type String -Attribute Write
                    New-xDscResourceProperty -Name ReadProperty -Type String -Attribute Read
                )
                New-xDscResource -Name TestResource -FriendlyName cTestResource -Path $TestDrive -Property $ResourceProperties -Force
                $OriginalFriendlyName = Get-xDSCSchemaFriendlyName -Path "$TestDrive\DSCResources\TestResource\TestResource.schema.mof"
                $NewSchemaContent = Get-Content -Path "$TestDrive\DSCResources\TestResource\TestResource.schema.mof" -Raw
                $NewModuleContent = Get-Content -Path "$TestDrive\DSCResources\TestResource\TestResource.psm1" -Raw

                It 'Creates a valid module script and schema' {
                    Test-xDscResource -Name "$TestDrive\DSCResources\TestResource" | Should Be $true
                }

                #endregion

                #region Update Resource using exact same config (should result in unchanged resource)
                Update-xDscResource -Path "$TestDrive\DSCResources\TestResource" -Property $ResourceProperties -Force
                $UpdatedFriendlyName = Get-xDSCSchemaFriendlyName -Path "$TestDrive\DSCResources\TestResource\TestResource.schema.mof"
                $UpdatedSchemaContent = Get-Content -Path "$TestDrive\DSCResources\TestResource\TestResource.schema.mof" -Raw
                $UpdatedModuleContent = Get-Content -Path "$TestDrive\DSCResources\TestResource\TestResource.psm1" -Raw

                It 'Updated Module Script and Schema should be equal to original' {
                    $NewSchemaContent -eq $UpdatedSchemaContent | Should Be $true
                    $NewModuleContent -eq $UpdatedModuleContent | Should Be $true
                }

                #endregion

                #region Update Resurce again using same config but specify new FriendlyName
                Update-xDscResource -Path "$TestDrive\DSCResources\TestResource" -Property $ResourceProperties -FriendlyName TestResource -Force
                $ChangedFriendlyName = Get-xDSCSchemaFriendlyName -Path "$TestDrive\DSCResources\TestResource\TestResource.schema.mof"

                It 'Changes friendly name in Schema when using -FriendlyName with Update-xDscResource' {
                    $OriginalFriendlyName -ne $ChangedFriendlyName | Should Be $true
                    $ChangedFriendlyName -eq 'TestResource' | Should Be $true
                }

                #endregion

                #region Change FrientlyName back to original value and validate that schema is identical to original schema
                Update-xDscResource -Path "$TestDrive\DSCResources\TestResource" -Property $ResourceProperties -FriendlyName cTestResource -Force
                $RestoredSchemaContent = Get-Content -Path "$TestDrive\DSCResources\TestResource\TestResource.schema.mof" -Raw

                It 'Changes ONLY friendly name in Schema when using -FriendlyName with Update-xDscResource' {
                    $NewSchemaContent -eq $RestoredSchemaContent | Should Be $true
                }

                #endregion



            }
        }
    }
}

begin
{
    function Get-TestDscResourceModuleContent
    {
        $content = @'
            function Get-TargetResource
            {
                [OutputType([hashtable])]
                [CmdletBinding()]
                param (
                    [Parameter(Mandatory)]
                    [string] $KeyProperty,

                    [Parameter(Mandatory)]
                    [string] $RequiredProperty
                )

                return @{
                    KeyProperty      = $KeyProperty
                    RequiredProperty = 'Required Property'
                    WriteProperty    = 'Write Property'
                    ReadProperty     = 'Read Property'
                }
            }

            function Set-TargetResource
            {
                [CmdletBinding()]
                param (
                    [Parameter(Mandatory)]
                    [string] $KeyProperty,

                    [Parameter(Mandatory)]
                    [string] $RequiredProperty,

                    [string] $WriteProperty
                )
            }

            function Test-TargetResource
            {
                [OutputType([bool])]
                [CmdletBinding()]
                param (
                    [Parameter(Mandatory)]
                    [string] $KeyProperty,

                    [Parameter(Mandatory)]
                    [string] $RequiredProperty,

                    [string] $WriteProperty
                )

                return $false
            }
'@

        return $content
    }

    function Get-TestDscResourceSchemaContent
    {
        $content = @'
[ClassVersion("1.0.0"), FriendlyName("cTestResource")]
class TestResource : OMI_BaseResource
{
    [Key] string KeyProperty;
    [required] string RequiredProperty;
    [write] string WriteProperty;
    [read] string ReadProperty;
};
'@

        return $content
    }

}
