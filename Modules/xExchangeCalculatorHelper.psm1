<#
    .SYNOPSIS
        Reads a Servers.csv file generated by the Exchange Server Role
        Requirements Calculator, and generates a Database Map which can be
        used in the DiskToDBMap parameter of the xExchAutoMountPoint resource.

    .PARAMETER ServersCsvPath
        The full path to the Servers.csv file to read.

    .PARAMETER ServerNameInCsv
        The server name within the Server.csv file to look up database
        settings for.

    .PARAMETER DbNameReplacements
        A Hashtable containing case sensitive replacements to make to the
        databases discoverd for this server. For each Hashtable key/value pair,
        the key is the content to look for in the original string, and the
        value is what that content should be changed to. If multiple changes
        are requested, the order that the replacements are made in is not
        guaranteed.
#>
function Get-DBMapFromServersCsv
{
    [CmdletBinding()]
    [OutputType([System.String[]])]
    param
    (
        [Parameter(Mandatory=$true)]
        [System.String]
        $ServersCsvPath,

        [Parameter(Mandatory=$true)]
        [System.String]
        $ServerNameInCsv,

        [Parameter()]
        [System.Collections.Hashtable]
        $DbNameReplacements = @{}
    )

    if (!(Test-Path -Path $ServersCsvPath))
    {
        throw 'Unable to access file specified in ServersCsvPath'
    }

    [System.Object[]] $serverData = Import-Csv -Path $ServersCsvPath | Where-Object -FilterScript {$_.ServerName -like $ServerNameInCsv}

    if ($serverData.Count -ne 1)
    {
        throw 'Failed to find single entry for server in Servers.Csv file'
    }

    $dbPerVolume = $serverData.DbPerVolume

    if ($null -eq $dbPerVolume -or $dbPerVolume -le 0)
    {
        throw 'DbPerVolume for server is null or less than 0'
    }

    # Turn the DbMap from string into an array
    if ([String]::IsNullOrEmpty($serverData.DbMap))
    {
        throw 'No data specified in DbMap for server'
    }

    [System.String[]] $dbMapIn = $serverData.DbMap.Split(',')

    # Determine the appropriate size for the output array
    $disksRequired = $dbMapIn.Count / $dbPerVolume

    # Create the output variable
    [System.String[]] $dbMapOut = New-Object -TypeName 'System.String[]' -ArgumentList $disksRequired

    # Loop through the DbMap in increments of dbPerVolume and figure out which DB's will go on a single disk
    for ($i = 0; $i -lt $dbMapIn.Count; $i += $dbPerVolume)
    {
        [System.Text.StringBuilder] $diskBuilder = New-Object System.Text.StringBuilder

        # Loop through the individual DB's for this disk
        for ($j = $i; $j -lt $i + $dbPerVolume; $j++)
        {
            # This isn't the first DB on the disk so prepend a comma
            if ($j -gt $i)
            {
                $diskBuilder.Append(',') | Out-Null
            }

            # Make any requested replacements in the DB name
            $currentDb = Update-StringContent -StringIn $dbMapIn[$j] -Replacements $DbNameReplacements

            # Add the db to the current disk string
            $diskBuilder.Append($currentDb) | Out-Null
        }

        # Add the finished disk to the output variable
        $dbMapOut[$i / $dbPerVolume] = $diskBuilder.ToString()
    }

    return $dbMapOut
}

<#
    .SYNOPSIS
        Reads a MailboxDatabases.csv file generated by the Exchange Server Role
        Requirements Calculator, finds the databases within the .CSV file
        corresponding to the specified server, and returns an array of objects
        containing these databases and their properties.

    .PARAMETER MailboxDatabasesCsvPath
        The full path to the MailboxDatabases.csv file to read.

    .PARAMETER ServerNameInCsv
        The server name within the MailboxDatabases.csv file to look up
        database settings for.

    .PARAMETER DbNameReplacements
        A Hashtable containing case sensitive replacements to make to the
        databases discoverd for this server. For each Hashtable key/value pair,
        the key is the content to look for in the original string, and the
        value is what that content should be changed to. If multiple changes
        are requested, the order that the replacements are made in is not
        guaranteed.
#>
function Get-DBListFromMailboxDatabasesCsv
{
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSObject[]])]
    param
    (
        [Parameter(Mandatory=$true)]
        [System.String]
        $MailboxDatabasesCsvPath,

        [Parameter(Mandatory=$true)]
        [System.String]
        $ServerNameInCsv,

        [Parameter()]
        [System.Collections.Hashtable]
        $DbNameReplacements = @{}
    )

    if (!(Test-Path -Path $MailboxDatabasesCsvPath))
    {
        throw 'Unable to access file specified in MailboxDatabasesCsvPath'
    }

    [System.Object[]] $relevantDBs = Import-Csv -Path $MailboxDatabasesCsvPath | Where-Object -FilterScript {$_.Server -like $ServerNameInCsv}

    # Create the output variable
    [System.Management.Automation.PSObject[]] $dbList = New-Object -TypeName 'System.Management.Automation.PSObject[]' -ArgumentList $relevantDBs.Count

    # Loop through each database, and if it belongs to this server, at it to the list
    for ($i = 0; $i -lt $relevantDBs.Count; $i++)
    {
        $dbIn = $relevantDBs[$i]

        # Build a custom object to hold all the DB props
        $currentDBProps = @{
            Name                              = Update-StringContent -StringIn $dbIn.Name -Replacements $DbNameReplacements
            LogFolderPath                     = Update-StringContent -StringIn $dbIn.LogFolderPath -Replacements $DbNameReplacements
            DeletedItemRetention              = $dbIn.DeletedItemRetention
            GC                                = $dbIn.GC
            OAB                               = $dbIn.OAB
            RetainDeletedItemsUntilBackup     = $dbIn.RetainDeletedItemsUntilBackup
            IndexEnabled                      = $dbIn.IndexEnabled
            CircularLoggingEnabled            = $dbIn.CircularLoggingEnabled
            ProhibitSendReceiveQuota          = $dbIn.ProhibitSendReceiveQuota
            ProhibitSendQuota                 = $dbIn.ProhibitSendQuota
            IssueWarningQuota                 = $dbIn.IssueWarningQuota
            AllowFileRestore                  = $dbIn.AllowFileRestore
            BackgroundDatabaseMaintenance     = $dbIn.BackgroundDatabaseMaintenance
            IsExcludedFromProvisioning        = $dbIn.IsExcludedFromProvisioning
            IsSuspendedFromProvisioning       = $dbIn.IsSuspendedFromProvisioning
            MailboxRetention                  = $dbIn.MailboxRetention
            MountAtStartup                    = $dbIn.MountAtStartup
            EventHistoryRetentionPeriod       = $dbIn.EventHistoryRetentionPeriod
            AutoDagExcludeFromMonitoring      = $dbIn.AutoDagExcludeFromMonitoring
            CalendarLoggingQuota              = $dbIn.CalendarLoggingQuota
            IsExcludedFromInitialProvisioning = $dbIn.IsExcludedFromInitialProvisioning
            DataMoveReplicationConstraint     = $dbIn.DataMoveReplicationConstraint
            RecoverableItemsQuota             = $dbIn.RecoverableItemsQuota
            RecoverableItemsWarningQuota      = $dbIn.RecoverableItemsWarningQuota
        }

        if ($null -ne $dbIn.DBFilePath)
        {
            $currentDBProps.Add('DBFilePath', (Update-StringContent -StringIn $dbIn.DBFilePath -Replacements $DbNameReplacements))
        }
        elseif ($null -ne $dbIn.EDBFilePath)
        {
            $currentDBProps.Add('DBFilePath', (Update-StringContent -StringIn $dbIn.EDBFilePath -Replacements $DbNameReplacements))
        }
        else
        {
            throw 'Unable to locate column containing database file path'
        }

        $dbList[$i] = New-Object -TypeName PSObject -Property $currentDBProps
    }

    return $dbList
}

<#
    .SYNOPSIS
        Reads a MailboxDatabasesCopies.csv file generated by the Exchange
        Server Role Requirements Calculator, finds the databases within the
        .CSV file corresponding to the specified server, and returns an array
        of objects containing these databases and their properties.

    .PARAMETER MailboxDatabaseCopiesCsvPath
        The full path to the MailboxDatabasesCopies.csv file to read.

    .PARAMETER ServerNameInCsv
        The server name within the MailboxDatabasesCopies.csv file to look up
        database settings for.

    .PARAMETER DbNameReplacements
        A Hashtable containing case sensitive replacements to make to the
        databases discoverd for this server. For each Hashtable key/value pair,
        the key is the content to look for in the original string, and the
        value is what that content should be changed to. If multiple changes
        are requested, the order that the replacements are made in is not
        guaranteed.
#>
function Get-DBListFromMailboxDatabaseCopiesCsv
{
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSObject[]])]
    param
    (
        [Parameter(Mandatory=$true)]
        [System.String]
        $MailboxDatabaseCopiesCsvPath,

        [Parameter(Mandatory=$true)]
        [System.String]
        $ServerNameInCsv,

        [Parameter()]
        [System.Collections.Hashtable]
        $DbNameReplacements = @{}
    )

    if (!(Test-Path -Path $MailboxDatabaseCopiesCsvPath))
    {
        throw 'Unable to access file specified in MailboxDatabaseCopiesCsvPath'
    }

    [System.Object[]] $relevantDBs = Import-Csv -Path $MailboxDatabaseCopiesCsvPath | Where-Object -FilterScript {$_.Server -like $ServerNameInCsv}

    # Create the output variable
    [System.Management.Automation.PSObject[]] $dbList = New-Object -TypeName 'System.Management.Automation.PSObject[]' -ArgumentList $relevantDBs.Count

    # Loop through each database, and if it belongs to this server, at it to the list
    for ($i = 0; $i -lt $relevantDBs.Count; $i++)
    {
        $dbIn = $relevantDBs[$i]

        # Build a custom object to hold all the DB props
        $dbList[$i] = New-Object -TypeName PSObject -Property @{
            Name                 = Update-StringContent -StringIn $dbIn.Name -Replacements $DbNameReplacements
            ActivationPreference = $dbIn.ActivationPreference
            ReplayLagTime        = $dbIn.ReplayLagTime
            TruncationLagTime    = $dbIn.TruncationLagTime
        }
    }

    # Sort copies by order of ActivationPreference, so lowest numbered copies get added first.
    if ($dbList.Count -gt 0)
    {
        $dbList = $dbList | Sort-Object -Property ActivationPreference, Name
    }

    return $dbList
}

<#
    .SYNOPSIS
        Takes a given string, and makes replacements to the string content
        based off the key/values pairs defined in the Replacements hashtable.

    .PARAMETER StringIn
        The string to update the contents of.

    .PARAMETER Replacements
        A Hashtable containing case sensitive replacements to make to the
        given string. For each Hashtable key/value pair, the key is the content
        to look for in the original string, and the value is what that content
        should be changed to. If multiple changes are requested, the order that
        the replacements are made in is not guaranteed.
#>
function Update-StringContent
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter()]
        [System.String]
        $StringIn,

        [Parameter()]
        [System.Collections.Hashtable]
        $Replacements = @{}
    )

    if ($Replacements.Count -gt 0)
    {
        foreach ($key in $Replacements.Keys)
        {
            $StringIn = $StringIn.Replace($key, $Replacements[$key])
        }
    }

    return $StringIn
}

Export-ModuleMember -Function *
