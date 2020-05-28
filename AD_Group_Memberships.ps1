$ADGroups = Get-ADGroup -Filter * 
$CSVData = @()
$DateTime = Get-Date -f "yyyy-MM"
$CSVFile = "C:\temp\AD_Groups"+$DateTime+".csv" 
$member = $NULL

ForEach ($ADGroup in $ADGroups)
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
     } 
}
 $CSVData  | Sort-Object Name,Members | Export-Csv $CSVFile -NoTypeInformation
