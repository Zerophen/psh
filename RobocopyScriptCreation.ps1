$dataDrives = @()
$dataDrives = Get-PSDrive -PSProvider FileSystem | where {$_.Free -gt 0 -AND $_.Root -notlike "C:\"}

$transferFolders = @()
$newobj = @()

$roboScripts = @()

ForEach ($x in $dataDrives)
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

ForEach ($x in $transferFolders)
{
    $roboCopySyncSwitches = '" /E /ZB /DCOPY:T /COPYALL /IPG:5 /R:1 /W:1 /V /TEE /LOG:c:\netxus\Robocopy_' + $env:COMPUTERNAME + '_' + $x.Folder + '.log'
    $roboCopyFinalizeSwitches = '" /mir /sec /DCOPY:T /COPYALL /IPG:5 /R:1 /W:1 /V /TEE /LOG:c:\netxus\Robocopy_' + $env:COMPUTERNAME + '_' + $x.Folder + 'mir.log'
    
    $newobj = New-Object -TypeName psobject
    $newobj | add-member -MemberType NoteProperty -Name Sync -Value ('robocopy "\\' + $env:COMPUTERNAME + '\' + $x.DriveLetter + '$\' + $x.Folder + '" "' + $x.DriveLetter + ':\' + $x.Folder + $roboCopySyncSwitches)
    $newobj | add-member -MemberType NoteProperty -Name Final -Value ('robocopy "\\' + $env:COMPUTERNAME + '\' + $x.DriveLetter + '$\' + $x.Folder + '" "' + $x.DriveLetter + ':\' + $x.Folder + $roboCopyFinalizeSwitches)
    $roboScripts += $newobj
    $roboScripts | Format-List | Out-File C:\Netxus\Robocopy_Scripts.txt -Append
}
