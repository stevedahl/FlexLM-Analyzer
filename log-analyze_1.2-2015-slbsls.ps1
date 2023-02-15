[void][reflection.assembly]::loadwithpartialname("System.Windows.Forms")

#Function to select the license log file to open.
function Select-FileDialog
{
	param([string]$Title,[string]$Directory,[string]$Filter="All Files (*.*)|*.*")
	$objForm = New-Object System.Windows.Forms.OpenFileDialog
	$objForm.InitialDirectory = $Directory
	$objForm.ShowHelp = $True
	$objForm.Filter = $Filter
	$objForm.Title = $Title
	$Show = $objForm.ShowDialog()
	If ($Show -eq "OK")
	{
		Return $objForm.FileName
	}
	Else
	{
		Write-Error "Operation cancelled by user."
	}
}

#Function to select the file to save the csv format in.
function Save-FileDialog
{
	param([string]$Title,[string]$Directory,[string]$Filter="All Files (*.*)|*.csv")
	$objSaveForm = New-Object System.Windows.Forms.SaveFileDialog
	$objSaveForm.InitialDirectory = $Directory
	$objSaveForm.ShowHelp = $True
	$objSaveForm.OverwritePrompt = $false
	$objSaveForm.Filter = $Filter
	$objSaveForm.Title = $Title
	$Show = $objSaveForm.ShowDialog()
	If ($Show -eq "OK")
	{
		Return $objSaveForm.FileName
	}
	Else
	{
		Write-Error "Operation cancelled by user."
	}
}


#Clear the variables - required if debugging in PowerShell Script Editor
$DATE = ""
$TIMEINTERVAL = ""
$TIME = ""
$FEATURE = ""
$TIMESTAMP = Get-Date
$TIMESTAMP = $TIMESTAMP.AddYears(-100)
$HASHTABLE = @{}


#Ask for file to read log entries from
$file = Select-FileDialog -Title "OPEN LOG FILE == Select a FlexLM Debug Log File"

if ($file -eq $null) {exit}

#Ask for file to save output to.
$csvfile = Save-FileDialog -Title "SAVE CSV FILE == Enter CSV file to record the usage" -Filter "CSV Files|*.csv"

if ($csvfile -eq $null) {exit}

#Load the information from the log file
$content = Get-Content $file

#Load the first Date seen in the log file
foreach ( $line in $content )
{
	if ($line.Contains("TIMESTAMP"))
	{
		if ($line.StartsWith(" "))
		{
			$line = $line -Replace "^ ", "0"
		}
		$t = $line.Split(" ")
		$DATE = $t[4]
		If ($t[4] -eq $null) {$DATE = $t[3]}
		
		$hour = $t[0].Split(":")[0]
		$minute = $t[0].Split(":")[1]
		$minute = [Math]::Floor($minute / 5) * 5
		if ($minute -lt 10) {$minute = "0"+$minute}
		$TIMEINTERVAL = "00" + ":" + "00" + ":00"
		$TIMEINTERVAL = Get-Date $DATE" "$TIMEINTERVAL 
		break
	}
}

#load every feature name used in the log file
foreach ( $line in $content )
{
	if ($line.Contains("OUT:") -or $line.Contains("IN:"))
	{
	    if ($line.StartsWith(" "))
		{
			$line = $line -Replace "^ ", "0"
		}
		$t = $line.Split('"')
		$FEATURE = $t[1]
		$HASHTABLE["$FEATURE"]=0
		
	}
}

#Sort the columns in an alpabetical list to make this easier to read the features.
$tmpcol = $HASHTABLE.keys |Sort-Object 
$columns = "Time"


#Prepare the column header line for the CSV file
for ($e=0;$e -lt $tmpcol.Count; $e++)
{
	$columns = $columns + "`t" + $tmpcol[$e]
}

#Write the column header to the CSV file
Out-File -FilePath $csvfile -InputObject $columns

#Prepare temporary column values
$prevcol = "0"
for ($e=1 ;$e -lt $tmpcol.Count; $e++)
	{
		$prevcol = $prevcol + "`t" + "0"
	}

$count=0

#Read through the license log file one line at a time.
foreach ( $line in $content )
{
	$count = $count + 1
	
	$OLDTIMESTAMP = $TIMESTAMP
	
	#If the time is before 10am, insert a 0 in place of the empty space character.
	if ($line.StartsWith(" "))
	{
		$line = $line -Replace "^ ", "0"
	}
	$t = $line.Split(" ")
	$TIME = $t[0]
	if ($line.Contains(":")) { $TIMESTAMP = Get-Date $DATE" "$TIME }
		
	#Record the current date.
	if ($line.Contains("TIMESTAMP"))
	{
		$DATE = $t[3]
	}
	
	
	while ($TIMESTAMP -gt $TIMEINTERVAL.AddMinutes(5))
	{
		if ($OLDTIMESTAMP -lt $TIMESTAMP)
		{
			$prevcol = [string]($HASHTABLE.get_Item($tmpcol[0]))
			for ($e=1 ;$e -lt $tmpcol.Count; $e++)
			{
				$prevcol = $prevcol + "`t" + $HASHTABLE.get_Item($tmpcol[$e])
			}
			$columns = [string]$TIMEINTERVAL + "`t" + $prevcol
		}
		else 
		{
			$columns = [string]$TIMEINTERVAL + "`t" + $prevcol
		}
		
		#Write the Timeinterval to the CSV file
		Out-File -FilePath $csvfile -InputObject $columns -Append 
		Write-Progress -Activity "Processing LogFile" -Status "Date Current Processing: $TIMEINTERVAL" -percentComplete ($count / $content.Count*100)
		$TIMEINTERVAL = $TIMEINTERVAL.AddMinutes(5)
	}	
	
#	while ($TIMESTAMP -gt $TIMEINTERVAL.AddMinutes(5))
#	{
#		if ($TIMESTAMP -lt $TIMEINTERVAL.AddMinutes(10) -And $HASHTABLE.get_Item($tmpcol[$0]) -ne $null )
#		{
#			
#			$prevcol = $HASHTABLE.get_Item($tmpcol[$0])
#			for ($e=1 ;$e -lt $tmpcol.Count; $e++)
#			{
#				$prevcol = $prevcol + "`t" + $HASHTABLE.get_Item($tmpcol[$e])
#			}
#			$columns = [string]$TIMEINTERVAL + "`t" + $prevcol
#		}
#		else 
#		{
#			$columns = [string]$TIMEINTERVAL + "`t" + $prevcol
#		}
#		
#		#Write the Timeinterval to the CSV file
#		Out-File -FilePath $csvfile -InputObject $columns -Append 
#		Write-Progress -Activity "Processing LogFile" -Status "Date Current Processing: $TIMEINTERVAL" -percentComplete ($count / $content.Count*100)
#		$TIMEINTERVAL = $TIMEINTERVAL.AddMinutes(5)
#	}	
	

	
	#Record when a license is checked back in.
	#If the feature is parallel, then the total number of licenses used is recorded.
	if ($line.Contains("OUT:"))
	{
		$FEATURE = $line.Split('"')[1]
		$tmp = $HASHTABLE.get_item($FEATURE)
		If ($FEATURE -eq "parallel") { 
			$tmp = $tmp + $line.Split("(")[2].split(" ")[0]
			}
		else {
			$tmp += 1
			}
		$HASHTABLE.set_item($FEATURE,$tmp)
	}
	
	#record when a license is checked back in
	if ($line.Contains("IN:"))
	{
		$FEATURE = $line.Split('"')[1]
		$tmp = $HASHTABLE.get_item($FEATURE)
		If ($FEATURE -eq "parallel") { 
			$tmp = $tmp - $line.Split("(")[2].split(" ")[0]
			}
		else {
			$tmp -= 1
			}
		$HASHTABLE.set_item($FEATURE,$tmp)
	}
	
	#Possible use to log denied access attempts
	if ($line.Contains("DENIED:"))
	{
		$FEATURE = $line.Split('"')[1]
	}
	
	If ($line.Contains("This log is intended for debug purposes only") -or $line.Contains("TCP_NODELAY NOT enabled"))
	{
		for ($e=0 ;$e -lt $tmpcol.Count; $e++)
		{
			$HASHTABLE.set_Item($tmpcol[$e],0)
		}
	}
	
#	If ($line.Contains("SERVER line says SLBID"))
#	{
#		for ($e=0 ;$e -lt $tmpcol.Count; $e++)
#		{
#			$HASHTABLE.set_Item($tmpcol[$e],0)
#		}
#	}
	

	
}


