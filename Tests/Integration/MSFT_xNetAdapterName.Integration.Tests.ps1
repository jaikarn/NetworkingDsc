$script:DSCModuleName      = 'xNetworking'
$script:DSCResourceName    = 'MSFT_xNetAdapterName'

#region HEADER
# Integration Test Template Version: 1.1.0
[string] $script:moduleRoot = Join-Path -Path $(Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path))) -ChildPath 'Modules\xNetworking'

if ( (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $script:moduleRoot -ChildPath '\DSCResource.Tests\'))
}

Import-Module (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:DSCModuleName `
    -DSCResourceName $script:DSCResourceName `
    -TestType Integration
#endregion

# Configure Loopback Adapter
. (Join-Path -Path (Split-Path -Parent $Script:MyInvocation.MyCommand.Path) -ChildPath 'IntegrationHelper.ps1')

# Using try/finally to always cleanup even if something awful happens.
try
{
    #region Integration Tests
    $ConfigFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:DSCResourceName).config.ps1"
    . $ConfigFile -Verbose -ErrorAction Stop

    Describe "$($script:DSCResourceName)_Integration" {
        BeforeAll {
            $adapterName = 'xNetworkingLBA'
            New-IntegrationLoopbackAdapter -AdapterName $adapterName
            $adapter = Get-NetAdapter -Name $adapterName
            $newAdapterName = 'xNetworkingLBANew'
        }

        #region DEFAULT TESTS
        It 'should compile and apply the MOF without throwing' {
            {
                # This is to pass to the Config
                $configData = @{
                    AllNodes = @(
                        @{
                            NodeName             = 'localhost'
                            NewName              = $newAdapterName
                            Name                 = $adapter.Name
                            PhysicalMediaType    = $adapter.PhysicalMediaType
                            Status               = $adapter.Status
                            MacAddress           = $adapter.MacAddress
                            InterfaceDescription = $adapter.InterfaceDescription
                            InterfaceIndex       = $adapter.InterfaceIndex
                            InterfaceGuid        = $adapter.InterfaceGuid
                        }
                    )
                }

                & "$($script:DSCResourceName)_Config" `
                    -OutputPath $TestDrive `
                    -ConfigurationData $configData
                Start-DscConfiguration -Path $TestDrive `
                    -ComputerName localhost -Wait -Verbose -Force
            } | Should Not Throw
        }

        it 'should reapply the MOF without throwing' {
            {Start-DscConfiguration -Path $TestDrive `
                -ComputerName localhost -Wait -Verbose -Force} | Should Not Throw
        }

        It 'should be able to call Get-DscConfiguration without throwing' {
            { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should Not throw
        }
        #endregion

        It 'Should have set the resource and all the parameters should match' {
            $current = Get-DscConfiguration | Where-Object {$_.ConfigurationName -eq "$($script:DSCResourceName)_Config"}
            $current.Name                     | Should Be $newAdapterName
        }

        AfterAll {
            # Remove Loopback Adapter
            Remove-IntegrationLoopbackAdapter -AdapterName $newAdapterName
        }
    }
    #endregion
}
finally
{
    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion
}
