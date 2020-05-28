$ADGroups = Get-ADGroup -Filter * 
$i = 0
$CSVData = @()
$DateTime = Get-Date -f "yyyy-MM"
$CSVFile = "C:\temp\AD_Groups"+$DateTime+".csv" 
$member = $NULL

foreach ($ADGroup in $ADGroups)
{
     $membersArr = @() 
     $MembersArr = Get-ADGroup -filter {Name -eq $ADGroup.Name} | Get-ADGroupMember | select Name
     ForEach ($Member in $MembersArr)
     {
        $newobj = New-Object -TypeName psobject
        $newobj | add-member -MemberType NoteProperty -Name GroupName -Value $ADGroup.Name
        $newobj | add-member -MemberType NoteProperty -Name Category -Value $ADGroup.GroupCategory
        $newobj | add-member -MemberType NoteProperty -Name Scope -Value $ADGroup.GroupScope
        $newobj | add-member -MemberType NoteProperty -Name Members -Value $Member.Name
        $CSVData += $newobj
        #$i++
    } 
}
 $CSVData  | Sort-Object Name | Export-Csv $CSVFile -NoTypeInformation 
    #$newobj | add-member -MemberType NoteProperty -Name $t -Value  $currentUserProperties.$t
