[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
 Set-ExecutionPolicy Unrestricted -scope Process 



$mydownloads = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path

$MyTemp =(Get-Item $mydownloads).fullname

 
 try
 {

$response = Invoke-WebRequest -Uri https://github.com/Louisjreeves/MiscRepair/raw/main/CornersTestandGraph.zip -OutFile $mytemp\CornersTestandGraph.zip
 } catch 
 {
    $StatusCode = $_.Exception.Response.StatusCode.value__
  }
  

      Expand-Archive -Path $mydownloads\CornersTestandGraph.zip -DestinationPath $mydownloads\CornersTestandGraph -Force
 
 
 $activedirectory= "C:\Users\*\Downloads\CornersTestandGraph\"
 cd c:\
 set-location $mydownloads
  .\CornersTestandGraph.ps1