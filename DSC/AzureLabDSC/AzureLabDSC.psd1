@{

    # Script module or binary module file associated with this manifest.
    RootModule = 'AzureLabDSC.psm1'

    DscResourcesToExport = @(
        'WaitForDomainReady',
        'VerifyComputerJoinDomain',
        'SetDNS',
        'RegisterTaskScheduler',
        'AddUserToLocalAdminGroup',
        'JoinDomain',
        'SetupDomain'
    )

    # Version number of this module.
    ModuleVersion = '1.0'

    # ID used to uniquely identify this module
    GUID = '20a74417-2f6b-4936-9025-22ad89094529'

    # Author of this module
    Author = 'Microsoft Corporation'

    # Company or vendor of this module
    CompanyName = 'Microsoft Corporation'

    # Copyright statement for this module
    Copyright = '(c) 2014 Microsoft. All rights reserved.'

    # Description of the functionality provided by this module
    # Description = ''

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.0'

    # Name of the Windows PowerShell host required by this module
    # PowerShellHostName = ''
    }
