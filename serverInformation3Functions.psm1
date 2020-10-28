<# This function searches through the servers folders to try and find if Java is installed 
   Since there are a few folders to check it is just a large else if statement. If found
   then it will return the ProductVersion, if not found then it will return Not installed #>

Function Get-JavaVersion{

    param (
            [string]$server
           )
    try{
        # Get Java Version
        if (Test-Path ("\\$server\C$\Program Files\Java\jre*\bin\java.exe")){

            $java = gci "\\$server\C$\Program Files\Java\jre*\bin\java.exe"
            $javaVersion = $java.VersionInfo.ProductVersion
 
        } elseif (Test-Path ("\\$server\C$\Program Files (x86)\Java\jre*\bin\java.exe")){

            $java = gci "\\$server\C$\Program Files (x86)\Java\jre*\bin\java.exe"
            $javaVersion = $java.VersionInfo.ProductVersion

        } elseif (Test-Path ("\\$server\C$\Program Files (x86)\Java\jdk*\bin\java.exe")){

            $java = gci "\\$server\C$\Program Files (x86)\Java\jdk*\bin\java.exe"
            $javaVersion = $java.VersionInfo.ProductVersion

        } elseif (Test-Path ("\\$server\C$\Program Files\Java\jdk*\bin\java.exe")){

            $java = gci "\\$server\C$\Program Files\Java\jdk*\bin\java.exe"
            $javaVersion = $java.VersionInfo.ProductVersion
                 
        } else {

            $javaVersion = "Java Not Installed"
        
        }

} catch {

    }

    return $javaVersion

}

<# This function gets the physical information of the PC (RAM, CPUName, Cores, NoOfProcessors)
   At the bottom of the function there are four elements that get returned to the main script
   these are accessible by using [0], [1], [2], [3] #>

Function Get-PhysicalInformation{

    param (
    
        [string]$server
    )

    try {
        
        # This finds the RAM on the PC and calculates it into GB instead of bytes
        $physicalRAM = (Get-WMIObject -class Win32_PhysicalMemory -ComputerName $server -ErrorAction SilentlyContinue |
                        Measure-Object -Property capacity -Sum | % {[Math]::Round(($_.sum / 1GB),2)})
        
        # This finds the processer name, number of cores and number of processors
        $cpu = Get-WmiObject -Class Win32_processor -ComputerName $server | Select Name, numberofCores -ErrorAction SilentlyContinue
        $name = $cpu.Name.Split("`n")
        $cores = 0
        $processors = 0

        # This loops through each processor if it has more than one 
        foreach ($c in $cpu.Numberofcores){
            
            $processors++
            $cores += $c 

        }
    
    } catch {
    
        $errorLog = "$server :- $_.Exception"
    
    }

    return $physicalRAM, $cores, $name[0], $processors
}

<# This function finds the servers description and then splits each time "|" is found
   You will find on the server that the description is laid out like so ->
   LiveOrNon | SystemName | ServerType | LinkedDBServer | SystemOwner.
   The reason for splitting is to add the correct word to the correct column in the DB #>
Function Get-ComputerDescription{
    
    param (
    
        [string]$server
    )
    
    try{
        # Get Description of computer
        $description = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $server -ErrorAction SilentlyContinue

        $split = $description.description.Split("|")

        $i = 0
        $strTestOrLive = ""
        $strSystemName = ""
        $strServerType = ""
        $strService = ""

            foreach ($word in $split){
                if ($i -eq 0){
    
                    $strTestOrLive = $word
    
                } elseif ($i -eq 1){
    
                    $strSystemName = $word

                } elseif ($i -eq 2){
    
                    $strServerType = $word

                } elseif ($i -eq 3){
    
                    $strDBServer = $word
    
                } else {
    
                    $strService = $word
    
                }

                $i++
           }

   } catch {
   
        $errorLog = "$server :- $_.Exception"
    
   }

   return $strTestOrLive, $strSystemName, $strServerType, $strDBServer, $strService, $description.Caption, $errorLog

}

<# This last function finds the SQL and NET version that is installed on a particular server.
   To get both, they can be found via the registry #>
Function Get-SQLNETVersions {

    param (
        [string]$server
    )

    try{

        # Get .Net Version
        $regKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $server)
        $netKey = $regKey.OpenSubKey("SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full")

        # if .NET exists
        if ($netKey){
            
            # Pull out the version
            $netVersion = $netKey.GetValue("Version")
        
        } else {
            
            # Else not installed
            $netVersion = ".NET Not Installed"
        
        }

        # Get SQL Version
        $SqlKey = $regKey.OpenSubKey("SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL")

            if($SqlKey){

                # Loop through each instance and pull out the version
                foreach ($instance in $SqlKey.GetValueNames()){

                    $InstanceName = $SqlKey.GetValue("$instance")
                    $InstanceKey = $regKey.OpenSubkey("SOFTWARE\Microsoft\Microsoft SQL Server\$InstanceName\Setup")
                    $SQLversion = $InstanceKey.GetValue("Version")
                }

            } else {
        
                $SQLversion = "SQL Not Installed"
            
            }

    } catch {
    
            $errorLog = "$server :- $_.Exception"
    
    }

    # Returns the values found to the main script
    return $SQLversion, $netVersion, $errorLog

}