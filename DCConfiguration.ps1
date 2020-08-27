configuration Configuration
{
   param
   (
        [Parameter(Mandatory)]
        [String]$DomainName,
        [Parameter(Mandatory)]
        [String]$DCName,
        [Parameter(Mandatory)]
        [String]$DPMPName,
        [Parameter(Mandatory)]
        [String]$PSName,
        [Parameter(Mandatory)]
        [String]$DNSIPAddress,
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds
    )

    Import-DscResource -ModuleName AzureLabDSC

    $LogFolder = "TempLog"
    $LogPath = "c:\$LogFolder"
    $CM = "CMTP"
    $DName = $DomainName.Split(".")[0]
    $PSComputerAccount = "$DName\$PSName$"
    $DPMPComputerAccount = "$DName\$DPMPName$"

    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)

    Node LOCALHOST
    {
        LocalConfigurationManager
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }

        SetupDomain FirstDS
        {
            DomainFullName = $DomainName
            SafemodeAdministratorPassword = $DomainCreds
        }

        VerifyComputerJoinDomain WaitForPS
        {
            ComputerName = $PSName
            Ensure = "Present"
            DependsOn = "[SetupDomain]FirstDS"
        }

        VerifyComputerJoinDomain WaitForDPMP
        {
            ComputerName = $DPMPName
            Ensure = "Present"
            DependsOn = "[SetupDomain]FirstDS"
        }


    }
}
