#############################################
#   AD attribute backup / restore script    #
#
#   Written by Jason D                      #
#   v 1.0                                   #
#   2/15/2020                               #
#
#   Primary use would be for migrating to   #
#   O365 with Azure AD Connect implemented  #
#   where AD attribute backup / restore     #
#   is necessary, but any AD attribute can  #
#   be modified                             #
#   
#   
#
#############################################




If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$pwd'; & '$PSCommandPath';`"";
}

Do {
$backupRestore = Read-Host "Press 1 to backup attributes, 2 to restore: "
}until ($backupRestore -eq 1 -or $backupRestore -eq 2)

$global:domainString = (Get-ADRootDSE).DefaultNamingContext

function BackupAttributes
{
    $OU = Read-Host "Enter the OU you want to backup: "
    $o365Options = @()
    Do {
    $o365Options = Read-Host "Do you want to save the default O365 attributes? (mail, mailNickname, LegacyExchangeDN, proxyaddresses) y/n: "
    }until ($o365Options -eq 'y' -or $o365Options -eq 'n')

    If ($o365Options -eq "y")
    {
        $attributeChoice = @('mail','mailNickname','LegacyExchangeDN','proxyaddresses')
    }
    Else
    {
        $attributeChoice = Read-Host "Enter the attribute you want to change (as listed in Attribute Editor): "
    }

    $ADBackup = @()
    $searchString = @()

    If ($OU -eq "Users")
    {    
        $searchString = (Get-ADUser -SearchBase ("CN=" + $OU + "," + $global:domainString) -Filter *)
    }
    Else
    {
        $searchString = (Get-ADUser -SearchBase ("OU=" + $OU + "," + $global:domainString) -Filter *)
    }

    If ($o365Options -eq "y")
    { 
        ForEach ($t in $attributeChoice)
        {
            $ADBackup = @()

            ForEach ($x in $searchString)
            {
                $currentUserProperties = Get-aduser -Identity $x.Name -properties $t

                $newobj = New-Object -TypeName psobject
                $newobj | add-member -MemberType NoteProperty -Name Name -Value $currentUserProperties.Name
                $newobj | add-member -MemberType NoteProperty -Name DistinguishedName -Value $currentUserProperties.DistinguishedName
                $newobj | add-member -MemberType NoteProperty -Name OU -Value $OU
                $newobj | add-member -MemberType NoteProperty -Name AttributeName -Value $t
                $newobj | add-member -MemberType NoteProperty -Name $t -Value  $currentUserProperties.$t
                $ADBackup += $newobj
            }
            $DateTime = ((get-date -format "yyyymmddhhmmss") + "_" + $t)
            $ADBackup | Export-Clixml .\$DateTime.xml
        }
    }
    Else
    {
        ForEach ($x in $searchString)
        {
            $newvar = Get-aduser -Identity $x.Name -properties $attributeChoice
            $newobj = New-Object -TypeName psobject
            $newobj | add-member -MemberType NoteProperty -Name Name -Value $newvar.Name
            $newobj | add-member -MemberType NoteProperty -Name DistinguishedName -Value $newvar.DistinguishedName
            $newobj | add-member -MemberType NoteProperty -Name OU -Value $OU
            $newobj | add-member -MemberType NoteProperty -Name AttributeName -Value $attributeChoice
            $newobj | add-member -MemberType NoteProperty -Name $attributeChoice -Value  $newvar.$attributeChoice
            $ADBackup += $newobj
        }
        $SaveFormat = ((get-date -format "yyyymmddhhmmss") + "_" + $attributeChoice)
        $ADBackup | Export-Clixml .\$SaveFormat.xml
    }
}

function RestoreAttributes
{
    Read-Host -Prompt "This will attempt to import and restore data from XMLs in this folder, ALL attributes will be restored. Press Enter to Continue"
    $i = 0

    ForEach ($x in (Get-Childitem *.xml))
    {
        $global:ImportData = Import-Clixml -path (".\" + $x.Name)
        
        ForEach ($t in $global:ImportData)
        {
            Get-ADUser -Identity ($global:ImportData.DistinguishedName[$i]) | set-aduser -Replace @{$global:importdata.AttributeName[$i] = $global:importdata.$global:attributename[$i]}
            
            $i++
        }
    }
}

If ($backupRestore -eq 1)
{
    BackupAttributes
}
Else 
{
    RestoreAttributes
}
