# DPM Backup Schedule reporting script
# Builds a html table displaying protection schedule in DPM 
# Tested with SCDPM 2012 R2
# 
# Developed by Gleb Yourchenko, 2014
# E.mail: fnugry@null.net
#

param(
    [String]$DPMServer=$null,
    [String]$OutputFile="c:\backup-schedule.htm")


import-module dataprotectionmanager

# Connect to DPM server (uses local server by default) 
if ( $DPMServer ) { Connect-DPMServer $DPMServer -ErrorAction Stop }


# Initialize calender 
$Calender = @{}
$1Hour = New-TimeSpan -Minutes 60
$WeekDays = ( "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su" )

foreach( $WeekDay in $WeekDays )
{
    $TimeTable = @{}
    for( $d = [datetime] 0; ($d - [datetime] 0).TotalHours -lt 24 ; $d+=$1Hour )
        { $TimeTable.add( $d.ToShortTimeString(), "" ) }
    $Calender.add( $WeekDay, $TimeTable )
}


# Populate calander with schedule data

foreach( $ProtectionGroup in ( Get-DPMProtectionGroup ) ) 
{
    $Schedules = $ProtectionGroup.GetSchedules()
    foreach( $Schedule in $Schedules.keys )
    {
        $Action = $Schedules.item($Schedule)
        if ( $action.JobType -eq "Initialization" ) { continue }

        foreach( $WeekDay in $action.WeekDays )
        {
            $TimeTable = $Calender.Item($WeekDay.toString())
            foreach( $TimeOfDay in $action.TimesOfDay )
            {
                $ts = (([datetime] 0).AddHours($TimeOfDay.Hour)).ToShortTimeString()
                $TimeTable.Item($ts) = $TimeTable.Item($ts) + $ProtectionGroup.Name + " - " + $Action.JobTypeString + "`n" 
            }
        }
       
    }
}



# prepare output table
$table = @()
for( $d = [datetime] 0; ($d - [datetime] 0).TotalHours -lt 24 ; $d+=$1Hour )
{ 
    $ts = $d.ToShortTimeString()
    $te = New-Object("System.Object")
    Add-Member -InputObject $te -MemberType NoteProperty -Name "Time" -value $ts
    
    foreach( $WeekDay in $WeekDays )
    { Add-Member -InputObject $te -MemberType NoteProperty -Name $WeekDay -value $calender.item( $WeekDay ).item($ts) }
    $table += $te   
}

# convert table to Html and store to file
$table | ConvertTo-Html -Title "Backup Schedule" | Out-File $OutputFile -force



