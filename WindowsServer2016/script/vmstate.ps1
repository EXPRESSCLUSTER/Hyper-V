#
# Check the Virtual Machine Status 
#
$ErrorUnknown = 1
$ErrorStopped = 2

# Get the Virtual Machine Status
$vmobj = Get-WmiObject -Namespace root\virtualization\v2 -Query "select * from Msvm_ComputerSystem where elementName='$env:VM'"
$state = $vmobj.EnabledState
# For Debugging
# clplogcmd -m "$state"
if ($state -eq 0)
{
        # Unknown
        exit $ErrorUnknown
}
elseif ($state -eq 3)
{
        # Stopped
        exit $ErrorStopped
}
else
{
        # Other
        exit 0
}
