# Database Credentials
$params = @{'server' = '**********'; 'Database' = '**********'}

# Store all servers from AD including edushire
$servers = (Get-ADComputer -Filter {OperatingSystem -like "*Windows Server*"}).Name
$servers += (Get-ADComputer -Server "edushire.net" -Filter {OperatingSystem -like "*Windows Server*"}).Name

# Imports the functions module
Import-Module -Name "C:\Powershell\Functions\serverInformation3Functions.psm1"

# $x stores all server objects from the database MonitoringTest on ABNWHHSV437
$x = invoke-sqlcmd @params -query "select * from [MonitoringTest].[dbo].[ServerDescriptions]"


# Loop through each server in AD
foreach ($serverName in $servers) {
          
    # Test the connection of the server and retrieve the IP address         
    $ip = (Test-Connection -ComputerName $serverName -count 1 -ErrorAction SilentlyContinue).IPV4Address.ipaddressTOstring

    # If server is on then check the IP is in the ranges below, if so then the server is located in BrightSolid, if not then its onsite
    if ($ip) {

        if ($ip -like "*" -or
            $ip -like "*" -or 
            $ip -like "*" -or
            $ip -like "*" -or
            $ip -like "*" -or
            $ip -like "*" -or
            $ip -like "*" -or 
            $ip -like "*" -or
            $ip -like "*" -or
            $ip -like "*" -or
            $ip -like "*" -or
            $ip -like "*" -or
            $ip -like "*" -or
            $ip -like "*") {

            $location = "*********"
        }
            
        else {
            
            $location = "**********"
            
        }

        # Runs three functions against the server (check functions file to see what it does)
        $javaVersion = Get-JavaVersion -server $serverName
        $SQLNETVersion = Get-SQLNETVersions -server $serverName
        $physicalInfo = Get-PhysicalInformation -server $serverName

        # The output of the functions are inserted into a Custom Object. If the function returns more than one element
        # then they can be accessed by using the number its positioned e.g [0], [1], and so on
        $serverDetails = [PSCustomObject] @{
            Server             = $serverName
            NetVersion         = $SQLNETVersion[1]
            JavaVersion        = $javaVersion
            SQLVersion         = $SQLNETVersion[0]
            Location           = $location
            RAM                = $physicalInfo[0]
            NumberOfCores      = $physicalInfo[1]
            CPUName            = $physicalInfo[2]
            NumberofProcessors = $physicalInfo[3]
        }

        # Resets to 0 for each AD server to see if the server already exists in the database
        $serverFound = 0
        
        # Loop through each server that is in the DATABASE
        foreach ($server in $x) {
            
            # Sets a variable to make it easier to type
            $computerName = $server.Server.Trim()

            # $serverDetails.Server is from the object above - if this equals a server with the same name in the database
            # then increment $serverFound and store the servers details from the DATABASE in a seperate object
            if ($serverDetails.Server -eq $computerName) {
                $serverFound++
                $dbDetails = [PSCustomObject] @{
                    Server             = $server.Server.Trim()
                    NetVersion         = $server.NetVersion.Trim()
                    JavaVersion        = $server.JavaVersion.Trim()
                    SQLVersion         = $server.SQLVersion.Trim()
                    Location           = $server.Location.Trim()
                    RAM                = $server.RAM
                    NumberOfCores      = $server.NumberOfCores
                    CPUName            = $server.CPUName
                    NumberOfProcessors = $server.NumberOfProcessors
                }
            
                <# This part can be confusing, but essentially it is just comparing $serverDetails to $dbDetails
                 $i is set to 0 and increments if a property is different in either object
                 for example - if this script was ran yesterday and picked up that ******** had a 16 Core processor
                 and overnight BSOL upgraded it to a 32 Core Processor then the object from the database ($dbDetails) would be different to the
                 server object ($serverDetails) #>
                $properties = $dbDetails.psobject.Properties.Name
                $i = 0

                foreach ($property in $properties) {
     
                    $comp = Compare-Object -ReferenceObject $dbDetails -DifferenceObject $serverDetails -Property $property -IncludeEqual 

                    if ($comp.sideindicator -eq "==") {

                        # "$($comp.psobject.Properties.name[0]) - the same"
        
                    }
                    else {
                    
                        $i++
                        # "$($property) - different"
                    }
                }

                ################# Updating Servers ###################
                
                # If $i icremented in the last section then it will jump into this if statement   
                if ($i -gt 0) {
                    
                    # This writes out the differences to the console        
                    Write-Host $dbDetails
                    Write-Host $serverDetails
                    $dbDetails = $serverDetails
                    
                    # Adds a date property so we can see in the DB when it was last changed
                    $dbDetails | Add-Member -MemberType NoteProperty -Name 'Date' -Value (Get-Date)
                    Write-Host "Updating $serverName" -ForegroundColor Magenta


                    # Data preparation for loading data into SQL table - Simple SQL query
                    $updateResults = @"
                            UPDATE [MonitoringTest].[dbo].[ServerDescriptions]
                            SET NetVersion = '$($dbDetails.NetVersion)',
                            JavaVersion =  '$($dbDetails.JavaVersion)',
                            SQLVersion = '$($dbDetails.SQLVersion )',
                            Location = '$($dbDetails.Location)',
                            DateUpdated = '$($dbDetails.Date)',
                            RAM = '$($dbDetails.RAM)',
                            NumberOfCores = '$($dbDetails.NumberOfCores)',
                            CPUName = '$($dbDetails.CPUName)',
                            NumberofProcessors = '$($dbDetails.NumberOfProcessors)'
                            WHERE Server = '$($dbDetails.Server)'

"@  
                    #call the invoke-sqlcmdlet to execute the query - @params is the database details at the top of the script
                    Invoke-sqlcmd @params -Query $updateResults
                
                }

                # If $i didn't increment then no change has been made to the server
                else {
                        
                    Write-Host "No Change To $serverName" -ForegroundColor Green
                        
                }
            }
        }

        ################# Updating Servers End ###################

        ################# Adding Servers ###################

        # if $serverFound (created above) is less than 1 then it wasn't found in the database
        if ($serverFound -lt 1) {
           
            # Look in the functions file to see what this does (essentially gets the computers description)            
            $description = Get-ComputerDescription -server $serverName

            # Sets description to below if the server is offline/permission issue
            if ($description[6]) {
            
                $description[1] = "Could not Connect to Server"

            }

            # Store all details gathered above (description, SQLNETVersion, location, physicalInfo) into another object
            $newServerDetails = [PSCustomObject] @{
                Server             = $serverName
                LiveorNon          = $description[0]
                Description        = $description[1]
                ServerType         = $description[2]
                LinkedDBServer     = $description[3]
                SystemOwner        = $description[4]
                OperatingSystem    = $description[5]
                NetVersion         = $SQLNETVersion[1]
                JavaVersion        = $javaVersion
                SQLVersion         = $SQLNETVersion[0]
                Location           = $location
                RAM                = $physicalInfo[0]
                NumberOfCores      = $physicalInfo[1]
                CPUName            = $physicalInfo[2]
                NumberofProcessors = $physicalInfo[3]
                DateUpdated        = (Get-Date)
            }

            Write-Host "Adding $serverName" -ForegroundColor Yellow
            # Data preparation for loading data into SQL table - simple SQL query for adding to DB
            $InsertResults = @"
                            INSERT INTO [MonitoringTest].[dbo].[ServerDescriptions](Server,LiveorNon,Description,ServerType,LinkedDBServer,SystemOwner,OperatingSystem,NetVersion,JavaVersion,SQLVersion,Location,DateUpdated,RAM, NumberOfCores, CPUName, NumberofProcessors)
                            VALUES ('$($newServerDetails.Server)',
                                    '$($newServerDetails.LiveorNon)',
                                    '$($newServerDetails.Description)',
                                    '$($newServerDetails.ServerType)',
                                    '$($newServerDetails.LinkedDBServer)',
                                    '$($newServerDetails.SystemOwner)',
                                    '$($newServerDetails.OperatingSystem)',
                                    '$($newServerDetails.NetVersion)',
                                    '$($newServerDetails.JavaVersion)',
                                    '$($newServerDetails.SQLVersion)',
                                    '$($newServerDetails.Location)',
                                    '$($newServerDetails.DateUpdated)',
                                    '$($newServerDetails.RAM)',
                                    '$($newServerDetails.NumberOfCores)',
                                    '$($newServerDetails.CPUName)',
                                    '$($newServerDetails.NumberofProcessors)')

"@
            #call the invoke-sqlcmdlet to execute the query
            Invoke-sqlcmd @params -Query $InsertResults

        }

    } else { 
    
        "Could not connect to server $serverName"
    
    }
        

}

################# Adding Servers End ###################

################# Decommissioned Servers #################

# Loops through each server in the database
foreach ($server in $x) {

    $j = 0

    # Sets a variable to make it easier to type
    $dbComputer = $server.Server.Trim()

    # Searches for $dbComputer in $servers (AD servers) - if found increment $j
    if ($servers.Contains($dbComputer)) {
        
        $j++

    }

    # if server not found then $j will be 0 - this will then insert the server information into the DB table (DecommissionedServers)
    # then delete the server from the main DB table (ServerDescriptions)
    if ($j -eq 0) {

        Write-Host "$($dbComputer) has been decommissioned" -ForegroundColor RED
        # Data preparation for loading data into SQL table

        $insertDecommission = @"
        INSERT INTO [MonitoringTest].[dbo].[DecommissionedServers](Server,LiveorNon,Description,ServerType,LinkedDBServer,SystemOwner,OperatingSystem,Location, RAM, NumberOfCores, CPUName, NumberOfProcessors, DateDecommissioned)
        VALUES ('$($server.Server)',
                '$($server.LiveorNon)',
                '$($server.Description)',
                '$($server.ServerType)',
                '$($server.LinkedDBServer)',
                '$($server.SystemOwner)',
                '$($server.OperatingSystem)',
                '$($server.Location)',
                '$($server.RAM)',
                '$($server.NumberOfCores)',
                '$($server.CPUName)',
                '$($server.NumberOfProcessors)',
                 '$(Get-Date)')

"@
        #call the invoke-sqlcmdlet to execute the query
        Invoke-sqlcmd @params -Query $insertDecommission

        $deleteResults = @"
                    DELETE FROM [MonitoringTest].[dbo].[ServerDescriptions]
                    WHERE Server = '$($dbComputer)'

"@
        #call the invoke-sqlcmdlet to execute the query
        Invoke-sqlcmd @params -Query $deleteResults

    }
}

################# Decommissioned Servers End #################