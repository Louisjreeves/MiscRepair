[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
 
$mydownloads = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path

$MyTemp =(Get-Item $mydownloads).fullname
$myloca = $PsScriptRoot
$myloca = "$mytemp\4CornersTestandGraph\"
 
 try
 {

$response = Invoke-WebRequest -Uri https://github.com/Louisjreeves/MiscRepair/raw/main/CornersTestandGraph.zip -OutFile $mytemp\CornersTestandGraph.zip
 } catch 
 {
    $StatusCode = $_.Exception.Response.StatusCode.value__
  }
  

      Expand-Archive -Path $mydownloads\CornersTestandGraph.zip -DestinationPath $mydownloads\CornersTestandGraph -Force
 
 
 
 
 set-location $myloca
  .\CornersTestandGraph.ps1
