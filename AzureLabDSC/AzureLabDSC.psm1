enum Ensure
{
    Absent
    Present
}

enum StartupType
{
    auto
    delayedauto
    demand
}

[DscResource()]
class WaitForDomainReady
{
    [DscProperty(key)]
    [string] $DCName

    [DscProperty(Mandatory=$false)]
    [int] $WaitSeconds = 900

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        $_DCName = $this.DCName
        $_WaitSeconds = $this.WaitSeconds
        Write-Verbose "Domain computer is: $_DCName"
        $testconnection = test-connection -ComputerName $_DCName -ErrorAction Ignore
        while(!$testconnection)
        {
            Write-Verbose "Waiting for Domain ready , will try again 30 seconds later..."
            Start-Sleep -Seconds 30
            $testconnection = test-connection -ComputerName $_DCName -ErrorAction Ignore
        }
        Write-Verbose "Domain is ready now."
    }

    [bool] Test()
    {
         $_DCName = $this.DCName
        Write-Verbose "Domain computer is: $_DCName"
        $testconnection = test-connection -ComputerName $_DCName -ErrorAction Ignore

        if(!$testconnection)
        {
            return $false
        }
        return $true
    }

    [WaitForDomainReady] Get()
    {
        return $this
    }
}

[DscResource()]
class VerifyComputerJoinDomain
{
    [DscProperty(key)]
    [string] $ComputerName

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        $_Computername = $this.ComputerName
        $searcher = [adsisearcher] "(cn=$_Computername)"
        while($searcher.FindAll().count -ne 1)
        {
            Write-Verbose "$_Computername not join into domain yet , will search again after 1 min"
            Start-Sleep -Seconds 60
            $searcher = [adsisearcher] "(cn=$_Computername)"
        }
        Write-Verbose "$_Computername joined into the domain."
    }

    [bool] Test()
    {
        return $false
    }

    [VerifyComputerJoinDomain] Get()
    {
        return $this
    }
}

[DscResource()]
class SetDNS
{
    [DscProperty(key)]
    [string] $DNSIPAddress

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        $_DNSIPAddress = $this.DNSIPAddress
        $dnsset = Get-DnsClientServerAddress | %{$_ | ?{$_.InterfaceAlias.StartsWith("Ethernet") -and $_.AddressFamily -eq 2}}
        Write-Verbose "Set dns: $_DNSIPAddress for $($dnsset.InterfaceAlias)"
        Set-DnsClientServerAddress -InterfaceIndex $dnsset.InterfaceIndex -ServerAddresses $_DNSIPAddress
    }

    [bool] Test()
    {
        $_DNSIPAddress = $this.DNSIPAddress
        $dnsset = Get-DnsClientServerAddress | %{$_ | ?{$_.InterfaceAlias.StartsWith("Ethernet") -and $_.AddressFamily -eq 2}}
        if($dnsset.ServerAddresses -contains $_DNSIPAddress)
        {
            return $true
        }
        return $false
    }

    [SetDNS] Get()
    {
        return $this
    }
}

[DscResource()]
class RegisterTaskScheduler
{
    [DscProperty(key)]
    [string] $TaskName

	[DscProperty(Mandatory)]
    [string] $ScriptName

    [DscProperty(Mandatory)]
    [string] $ScriptPath

	[DscProperty(Mandatory)]
    [string] $ScriptArgument

    [DscProperty(Mandatory)]
    [Ensure] $Ensure

    [DscProperty(NotConfigurable)]
    [Nullable[datetime]] $CreationTime

    [void] Set()
    {
        $_ScriptName = $this.ScriptName
        $_ScriptPath = $this.ScriptPath
        $_ScriptArgument = $this.ScriptArgument

        $ProvisionToolPath = "$env:windir\temp\ProvisionScript"
        if(!(Test-Path $ProvisionToolPath))
        {
            New-Item $ProvisionToolPath -ItemType directory | Out-Null
        }

        $sourceDirctory = "$_ScriptPath\*"
        $destDirctory = "$ProvisionToolPath\"

        Copy-item -Force -Recurse $sourceDirctory -Destination $destDirctory

        $_TaskName = $this.TaskName
		$TaskDescription = "Azure template task"
		$TaskCommand = "c:\windows\system32\WindowsPowerShell\v1.0\powershell.exe"
		$TaskScript = "$ProvisionToolPath\$_ScriptName"

        Write-Verbose "Task script full path is : $TaskScript "

		$TaskArg = "-WindowStyle Hidden -NonInteractive -Executionpolicy unrestricted -file $TaskScript $_ScriptArgument"

        Write-Verbose "command is : $TaskArg"

		$TaskStartTime = [datetime]::Now.AddMinutes(5)
		$service = new-object -ComObject("Schedule.Service")
		$service.Connect()
		$rootFolder = $service.GetFolder("\")
		$TaskDefinition = $service.NewTask(0)
		$TaskDefinition.RegistrationInfo.Description = "$TaskDescription"
		$TaskDefinition.Settings.Enabled = $true
		$TaskDefinition.Settings.AllowDemandStart = $true
		$triggers = $TaskDefinition.Triggers
		#http://msdn.microsoft.com/en-us/library/windows/desktop/aa383915(v=vs.85).aspx
		$trigger = $triggers.Create(1)
		$trigger.StartBoundary = $TaskStartTime.ToString("yyyy-MM-dd'T'HH:mm:ss")
		$trigger.Enabled = $true
		# http://msdn.microsoft.com/en-us/library/windows/desktop/aa381841(v=vs.85).aspx
		$Action = $TaskDefinition.Actions.Create(0)
		$action.Path = "$TaskCommand"
		$action.Arguments = "$TaskArg"
		#http://msdn.microsoft.com/en-us/library/windows/desktop/aa381365(v=vs.85).aspx
		$rootFolder.RegisterTaskDefinition("$_TaskName",$TaskDefinition,6,"System",$null,5)
    }

    [bool] Test()
    {
        $ProvisionToolPath = "$env:windir\temp\ProvisionScript"
        if(!(Test-Path $ProvisionToolPath))
        {
            return $false
        }

        return $true
    }

    [RegisterTaskScheduler] Get()
    {
        return $this
    }
}

[DscResource()]
class AddUserToLocalAdminGroup
{
    [DscProperty(Key)]
    [string] $Name

    [DscProperty(Key)]
    [string] $DomainName

    [void] Set()
    {
        $_DomainName = $($this.DomainName).Split(".")[0]
        $_Name = $this.Name
        $AdminGroupName = (Get-WmiObject -Class Win32_Group -Filter 'LocalAccount = True AND SID = "S-1-5-32-544"').Name
        $GroupObj = [ADSI]"WinNT://$env:COMPUTERNAME/$AdminGroupName"
	    Write-Verbose "[$(Get-Date -format HH:mm:ss)] add $_Name to administrators group"
	    $GroupObj.Add("WinNT://$_DomainName/$_Name")

    }

    [bool] Test()
    {
        $_DomainName = $($this.DomainName).Split(".")[0]
        $_Name = $this.Name
        $AdminGroupName = (Get-WmiObject -Class Win32_Group -Filter 'LocalAccount = True AND SID = "S-1-5-32-544"').Name
        $GroupObj = [ADSI]"WinNT://$env:COMPUTERNAME/$AdminGroupName"
        if($GroupObj.IsMember("WinNT://$_DomainName/$_Name") -eq $true)
        {
            return $true
        }
        return $false
    }

    [AddUserToLocalAdminGroup] Get()
    {
        return $this
    }

}

[DscResource()]
class JoinDomain
{
    [DscProperty(Key)]
    [string] $DomainName

    [DscProperty(Mandatory)]
    [System.Management.Automation.PSCredential] $Credential

    [void] Set()
    {
        $_credential = $this.Credential
        $_DomainName = $this.DomainName
        $_retryCount = 100
        try
        {
            Add-Computer -DomainName $_DomainName -Credential $_credential -ErrorAction Stop
            $global:DSCMachineStatus = 1
        }
        catch
        {
            Write-Verbose "Failed to join into the domain , retry..."
            $CurrentDomain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
            $count = 0
            $flag = $false
            while($CurrentDomain -ne $_DomainName)
            {
                if($count -lt $_retryCount)
                {
                    $count++
                    Write-Verbose "retry count: $count"
                    Start-Sleep -Seconds 30
                    Add-Computer -DomainName $_DomainName -Credential $_credential -ErrorAction Ignore

                    $CurrentDomain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
                }
                else
                {
                    $flag = $true
                    break
                }
            }
            if($flag)
            {
                Add-Computer -DomainName $_DomainName -Credential $_credential
            }
            $global:DSCMachineStatus = 1
        }
    }

    [bool] Test()
    {
        $_DomainName = $this.DomainName
        $CurrentDomain = (Get-WmiObject -Class Win32_ComputerSystem).Domain

        if($CurrentDomain -eq $_DomainName)
        {
            return $true
        }

        return $false
    }

    [JoinDomain] Get()
    {
        return $this
    }

}

[DscResource()]
class SetupDomain
{
    [DscProperty(Key)]
    [string] $DomainFullName

    [DscProperty(Mandatory)]
    [System.Management.Automation.PSCredential] $SafemodeAdministratorPassword

    [void] Set()
    {
        $_DomainFullName = $this.DomainFullName
        $_SafemodeAdministratorPassword = $this.SafemodeAdministratorPassword

        $ADInstallState = Get-WindowsFeature AD-Domain-Services
        if(!$ADInstallState.Installed)
        {
            $Feature = Install-WindowsFeature -Name AD-Domain-Services -IncludeAllSubFeature -IncludeManagementTools
        }

        $NetBIOSName = $_DomainFullName.split('.')[0]
        Import-Module ADDSDeployment
        Install-ADDSForest -SafeModeAdministratorPassword $_SafemodeAdministratorPassword.Password `
            -CreateDnsDelegation:$false `
            -DatabasePath "C:\Windows\NTDS" `
            -DomainName $_DomainFullName `
            -DomainNetbiosName $NetBIOSName `
            -LogPath "C:\Windows\NTDS" `
            -InstallDNS:$true `
            -NoRebootOnCompletion:$false `
            -SysvolPath "C:\Windows\SYSVOL" `
            -Force:$true

        $global:DSCMachineStatus = 1
    }

    [bool] Test()
    {
        $_DomainFullName = $this.DomainFullName
        $_SafemodeAdministratorPassword = $this.SafemodeAdministratorPassword
        $ADInstallState = Get-WindowsFeature AD-Domain-Services
        if(!($ADInstallState.Installed))
        {
            return $false
        }
        else
        {
            while($true)
            {
                try
                {
                    $domain = Get-ADDomain -Identity $_DomainFullName -ErrorAction Stop
                    Get-ADForest -Identity $domain.Forest -Credential $_SafemodeAdministratorPassword -ErrorAction Stop

                    return $true
                }
                catch
                {
                    Write-Verbose "Waitting for Domain ready..."
                    Start-Sleep -Seconds 30
                }
            }

        }

        return $true
    }

    [SetupDomain] Get()
    {
        return $this
    }

}
