$IconRoot = "E:\Users\Rideout421\Pictures\Icons"

Get-ChildItem $IconRoot -File -Recurse |
Select-Object -ExpandProperty BaseName |
Sort-Object -Unique |
Set-Content "D:\Users\Rideout421\Documents\GitHub\IconMatrix\logs\IconNames.txt"