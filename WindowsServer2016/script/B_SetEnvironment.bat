rem ==========================================
rem Parameters
rem ------------------------------------------
rem VM         : Virtual Machine Name
rem ID         : ID of Virtual Machine
rem SourcePath : Source Directory Path
rem DestPath   : Destination Directory Path
rem RestorePath: Virtual Machine Directory Path
rem VhdPath    : Virtual Hard Disk Directory Path
rem ==========================================
set VM=ws2016-VM
set ID=12345678-ABCD-1234-ABCD-123456789ABC
set SourcePath=X:\vm\ws2016-VM\Virtual Machines
set DestPath=X:\bak
set RestorePath=X:\vm\ws2016-VM
set VhdPath=X:\vm\ws2016-VM\Virtual Hard Disks
set VMCX1=%SourcePath%\%ID%.vmcx
set VMRS1=%SourcePath%\%ID%.vmrs
set VMCX2=%DestPath%\%ID%.vmcx
set VMRS2=%DestPath%\%ID%.vmrs
