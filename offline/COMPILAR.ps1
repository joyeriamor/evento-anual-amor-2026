param([string]$Dotnet="dotnet",[string]$Destino=(Join-Path $PSScriptRoot "Entrega"))
$ErrorActionPreference="Stop"
$app=Join-Path $PSScriptRoot "AMOR.AccesoOffline/AMOR.AccesoOffline.csproj"
$tests=Join-Path $PSScriptRoot "AMOR.AccesoOffline.Pruebas/AMOR.AccesoOffline.Pruebas.csproj"
Push-Location $PSScriptRoot
try {
 & $Dotnet restore $tests -r win-x64 --locked-mode
 if($LASTEXITCODE -ne 0){throw "Error restaurando dependencias fijadas"}
 & $Dotnet run --project $tests -c Release -r win-x64 --no-restore
 if($LASTEXITCODE -ne 0){throw "Las pruebas fallaron"}
 & $Dotnet publish $app -c Release -r win-x64 --self-contained true -p:PublishSingleFile=false -o $Destino
 if($LASTEXITCODE -ne 0){throw "No se pudo compilar la entrega"}
 Copy-Item (Join-Path $PSScriptRoot "LEEME.txt") $Destino -Force
 $exe=Join-Path $Destino "AMOR.AccesoOffline.exe"
 $v=(Get-Item $exe).VersionInfo
 if($v.FileVersion -ne "2.0.0.0"){throw "Version de ejecutable inesperada"}
 Get-FileHash $exe -Algorithm SHA256
} finally {Pop-Location}
