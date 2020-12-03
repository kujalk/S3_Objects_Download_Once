<#
Purpose - Download S3 files for once by keeping track using Tag value
Requirements - AWS PowerShell installed
Developer - K.Janarthanan
Date - 3/12/2020
Version - 1 
#>

Param(
    [Parameter(Mandatory)]
    [string]$ConfigFile
)

try 
{
    if(-not(Test-Path -Path $ConfigFile -PathType Leaf))
    {
        throw "Config file not found"
    }

    $Config = Get-Content -path $ConfigFile -EA Stop | ConvertFrom-Json

    if(-not($Config.AWSConfigProfile))
    {
        Write-Host "No any AWS Config Profile found in config file. Exiting from script" -ForegroundColor Yellow
        exit 0
    }

    #Set AWS Profile. To get available profile issue "Get-AWSCredential -ListProfileDetail"
    Set-AWSCredential -ProfileName $Config.AWSConfigProfile  -EA Stop

    if(-not($Config.BucketDetails))
    {
        Write-Host "No any Bucket details found in config file. Exiting from script" -ForegroundColor Yellow
        exit 0
    }

    foreach($Item in $Config.BucketDetails)
    {
        Write-Host "`nWorking on Bucket : $($Item.BucketName)" -ForegroundColor Magenta

        if(Test-Path -path $Item.DownloadPath)
        {
            #Get all objects names from the Bucket
            $AllObjects = (Get-S3Object -BucketName $Item.BucketName -EA Stop).Key
            Write-Host "Total Object Found - $($AllObjects.Count)"
            $SkippedObjects = 0
            $DownloadedObects = 0

            #Download Object from S3 to local folder
            foreach($Object in $AllObjects)
            {
                Write-Host "`nObject : $Object" -ForegroundColor Green

                try 
                {
                    $S3Object = Get-S3ObjectTagSet -BucketName $Item.BucketName -Key $Object -EA Stop | Where-Object {$_.Key -eq "Downloaded" -and $_.Value -eq "True"}

                    if($S3Object)
                    {
                        Write-Host "Download Tag is set to this object already. Therefore skipping Downloading" -ForegroundColor Yellow
                        $SkippedObjects +=1
                    }
                    else 
                    {
                        #Downloading the objects
                        Write-Host "Downloding the object" -ForegroundColor Green
                        Read-S3Object -BucketName $Item.BucketName -Key $Object -File ("{0}\{1}" -f $Item.DownloadPath,$Object) -EA Stop
                        Write-Host "Successfully Downloded the object" -ForegroundColor Green

                        #Set the Tag value Downloaded
                        Write-Host "Setting the object Tag Downloaded=True" -ForegroundColor Green
                        Write-S3ObjectTagSet -BucketName $Item.BucketName -Key $Object -Tagging_TagSet @( @{ Key="Downloaded"; Value="True"}) -EA Stop
                        $DownloadedObects +=1
                    }
                }
                catch
                {
                    Write-Host "Error occured while working on the object. Error is $_" -ForegroundColor Red
                }
            }
           
        }
        else 
        {
            Write-Host "Folder $($Item.DownloadPath) is not found. Therefore skipping downloading of files" -ForegroundColor Red    
        }  
        
        Write-Host "`nTotal Objects : $($AllObjects.Count)"
        Write-Host "Skipped Downloads : $SkippedObjects"
        Write-Host "Downloaded Objects : $DownloadedObects"
        
    }

    Write-Host "`nDone with the script" -ForegroundColor Green
}
catch 
{
    Write-Host "Error Occured : $_" -ForegroundColor Red
}
