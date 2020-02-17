#############################################################################################
#   Robocopy creation script                                                                #
#   
#   This script will scan the C: drive and any extra local data drives for folders and      #
#   create robocopy transfer strings that can be used to sync data.  This should be ran     #
#   from the source server.  This will work propertly on PowerShell v5.                     #
#   
#   Written by Jason D                                                                      #
#   v 1.0                                                                                   #
#   2/15/2020                                                                               #
#
#############################################################################################

$dataDrives = @()
$dataDrives = Get-PSDrive -PSProvider FileSystem | where {$_.Free -gt 0 -AND $_.Root -notlike "C:\"}
$cDrives = Get-PSDrive -PSProvider FileSystem | where {$_.Root -like "C:\"}
$transferFolders = @()
$newobj = @()
$roboScripts = @()
$cSubFolders = @()

If (Test-Path C:\Temp\Robocopy_Scripts_DataDrives.txt)
{
    Remove-Item -Path C:\Temp\Robocopy_Scripts_DataDrives.txt
    Remove-Item -Path C:\Temp\Robocopy_Scripts_C_Drive.txt
}

$foldersToIgnore = @(
    'Program Files (x86)',
    'Program Files',
    'PerfLogs',
    'Drivers',
    'Users',
    'Temp',
    'Windows',
    'Intel',
    'Dell')
 
ForEach ($s in (Get-Childitem -path C:\ -Directory | where {$foldersToIgnore -notcontains $_.Name}))
{
    $i = 0

    
    If ((Get-Childitem ('C:\' + $s) -directory).Count -gt 1)
    {
        ForEach ($subfolders in (Get-ChildItem ('C:\' + $s) -directory))
        {
            $newobj = New-Object -TypeName psobject
            $newobj | add-member -MemberType NoteProperty -Name Folder -Value $s
            $newobj | add-member -MemberType NoteProperty -Name SubFolder -Value (Get-ChildItem ('C:\' + $s) -Directory).Name[$i]
            $newobj | add-member -MemberType NoteProperty -Name DriveLetter -Value 'C'
            $transferFolders += $newobj
            $i++
        }
    }
    Else 
    {
        $newobj = New-Object -TypeName psobject
        $newobj | add-member -MemberType NoteProperty -Name Folder -Value $s
        $newobj | add-member -MemberType NoteProperty -Name SubFolder -Value (Get-ChildItem ('C:\' + $s) -Directory).Name
        $newobj | add-member -MemberType NoteProperty -Name DriveLetter -Value 'C'
        $transferFolders += $newobj
    }
}

ForEach ($x in $dataDrives | where {$_.DisplayRoot -notlike "\\*"})
{
    $i = 0

    ForEach ($t in (Get-ChildItem $x.Root -Directory))
    {
        $newobj = New-Object -TypeName psobject
        If ((Get-ChildItem $x.Root -Directory).Count -gt 1)
        {
            $newobj | add-member -MemberType NoteProperty -Name Folder -Value (Get-ChildItem $x.Root -Directory).Name[$i]
        }
        Else
        {
            $newobj | add-member -MemberType NoteProperty -Name Folder -Value (Get-ChildItem $x.Root -Directory).Name
        }
        $newobj | add-member -MemberType NoteProperty -Name DriveLetter -Value $x
        $transferFolders += $newobj
        $i++
    }
}
$speed = Read-Host -Prompt "Do you want to slow down the copy process to run during the day? y/n"
If($speed -eq 'y') {
    $IPG = '/IPG:5'
}
else {
    $IPG = $null
}

ForEach ($x in $transferFolders)
{
    $roboCopySyncSwitches = '" /E /ZB /DCOPY:T /COPYALL /IPG:5 /R:1 /W:1 /V /TEE /LOG:c:\netxus\Robocopy_' + $env:COMPUTERNAME + '_' + $x.Folder + '.log'
    $roboCopyFinalizeSwitches = '" /mir /sec /DCOPY:T /COPYALL /R:1 /W:1 /V /TEE /LOG:c:\netxus\Robocopy_' + $env:COMPUTERNAME + '_' + $x.Folder + '_mir.log'
    
    $newobj = New-Object -TypeName psobject
    
    If ($x.DriveLetter -notlike "C")
    {
        $newobj | add-member -MemberType NoteProperty -Name Sync -Value ('robocopy "\\' + $env:COMPUTERNAME + '\' + $x.DriveLetter + '$\' + $x.Folder + '" "' + $x.DriveLetter + ':\' + $x.Folder + $roboCopySyncSwitches)
        $newobj | add-member -MemberType NoteProperty -Name Final -Value ('robocopy "\\' + $env:COMPUTERNAME + '\' + $x.DriveLetter + '$\' + $x.Folder + '" "' + $x.DriveLetter + ':\' + $x.Folder + $roboCopyFinalizeSwitches)
        $roboScriptsData += $newobj
    }
    Else
    {
        $newobj | add-member -MemberType NoteProperty -Name Sync -Value ('robocopy "\\' + $env:COMPUTERNAME + '\' + $x.DriveLetter + '$\' + $x.Folder + '\' + $x.SubFolder + '" "' + $x.DriveLetter + ':\' + $x.Folder + '\' + $x.SubFolder + $roboCopySyncSwitches)
        $newobj | add-member -MemberType NoteProperty -Name Final -Value ('robocopy "\\' + $env:COMPUTERNAME + '\' + $x.DriveLetter + '$\' + $x.Folder + '\' + $x.SubFolder + '" "' + $x.DriveLetter + ':\' + $x.Folder + '\' + $x.SubFolder  + $roboCopyFinalizeSwitches)
        $roboScriptsC += $newobj
    }
    
}
$roboScriptsData | Format-List | Out-File C:\Temp\Robocopy_Scripts_DataDrives.txt -Append
$roboScriptC | Format-List | Out-File C:\Netxus\Temp_Scripts_C_Drive.txt -Append
Write-Host "Robocopy script document has been placed in C:\Netxus\Robocopy_Scripts.txt"
Read-Host -Prompt "Press Enter to continue"
