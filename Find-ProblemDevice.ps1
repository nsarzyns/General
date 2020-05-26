function Find-ProblemDevice {
    <#
    .SYNOPSIS
        Find all the devices that have an issue.

    .DESCRIPTION
        Find all the devices that have an issue and output the data about it.

    .PARAMETER LogPath
        Path of the logfile you want it to log to. Default is C:\Temp.
        
    .INPUTS
        Description of objects that can be piped to the script.

    .OUTPUTS
        Device inf object

    .EXAMPLE
        Example of how to run the script.

    .LINK
        Links to further documentation.

    .NOTES
        Detail on what the script does, if this is needed.

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$LogPath = "C:\Temp"
    )
    
    begin {
        if (!("PSLogger" -as [type])) {
            $callingSCript = ($MyInvocation.MyCommand.Name) -split ('.ps1')
            ."\\Server\Path\Here\Logging.ps1"
            $logger = [PSLogger]::new($logPath, $callingScript)
        }
        
        $logger.Notice("Starting $($MyInvocation.MyCommand) script")
        "-----------------------------------------------------"
        Write-Warning -Message "Checking Drivers..."
        $deviceErrorDescription = @{
            1  = "Device is not configured correctly."
            2  = "Windows cannot load the driver for this device."
            3  = "Driver for this device might be corrupted, or the system may be low on memory or other resources."
            4  = "Device is not working properly. One of its drivers or the registry might be corrupted."
            5  = "Driver for the device requires a resource that Windows cannot manage."
            6  = "Boot configuration for the device conflicts with other devices."
            7  = "Cannot filter."
            8  = "Driver loader for the device is missing."
            9  = "Device is not working properly. The controlling firmware is incorrectly reporting the resources for the device."
            10 = "Device cannot start."
            11 = "Device failed."
            12 = "Device cannot find enough free resources to use."
            13 = "Windows cannot verify the device's resources."
            14 = "Device cannot work properly until the computer is restarted."
            15 = "Device is not working properly due to a possible re-enumeration problem."
            16 = "Windows cannot identify all of the resources that the device uses."
            17 = "Device is requesting an unknown resource type."
            18 = "Device drivers must be reinstalled."
            19 = "Failure using the VxD loader."
            20 = "Registry might be corrupted."
            21 = "System failure. If changing the device driver is ineffective, see the hardware documentation. Windows is removing the device."
            22 = "Device is disabled."
            23 = "System failure. If changing the device driver is ineffective, see the hardware documentation."
            24 = "Device is not present, not working properly, or does not have all of its drivers installed."
            25 = "Windows is still setting up the device."
            26 = "Windows is still setting up the device."
            27 = "Device does not have valid log configuration."
            28 = "Device drivers are not installed."
            29 = "Device is disabled. The device firmware did not provide the required resources."
            30 = "Device is using an IRQ resource that another device is using."
            31 = "Device is not working properly.  Windows cannot load the required device drivers."
        }

        $ErrorCodeTable = [hashtable]::new()

        $SessionOption = New-CimSessionOption -Protocol DCOM
        $CimSession = New-CimSession -Name 'Drivers' -SessionOption $SessionOption
        
        $AllDrivers = Get-CimInstance -Query "select * from Win32_PNPsigneddriver where DeviceName!=null" -CimSession $CimSession
        $AllDevices = Get-CimInstance -Query "select configmanagererrorcode,status from Win32_PNPentity" -CimSession $CimSession

    }
    
    process {
        foreach ($Device in $AllDevices) {
            $ErrorCodeTable.Add($Device.DeviceID, $Device)
        }

        $Result = foreach ($Driver in $AllDrivers) {
            [pscustomobject]@{
                DeviceClass            = $Driver.DeviceClass
                Manufacturer           = $Driver.Manufacturer
                DeviceName             = $Driver.DeviceName
                FriendlyName           = $Driver.FriendlyName
                DriverName             = $Driver.DriverName
                InfName                = $Driver.InfName
                Status                 = $ErrorCodeTable[$Driver.DeviceID].Status
                ConfigManagerErrorCode = $ErrorCodeTable[$Driver.DeviceID].ConfigManagerErrorCode
                ErrorDescription       = $deviceErrorDescription[[int]$ErrorCodeTable[$Driver.DeviceID].ConfigManagerErrorCode]
                DriverDate             = $Driver.DriverDate
                DriverVersion          = $Driver.DriverVersion
            }
        }

        ForEach ($ProblemDevice in $Result) {
            if (($ProblemDevice.ConfigManagerErrorCode -ne 0) -and (!$($ProblemDevice.Name) -like "*Cisco*")) {
                $logger.Alert("$ProblemDevice")
                $ProblemDevice
            }
        }
    }
    
    end {
        Get-CimSession -Name 'Drivers' | Remove-CimSession
        $logger.Notice("Finished $($MyInvocation.MyCommand) script")
    }
}
