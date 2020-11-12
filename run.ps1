Install-Module -Name Pester -RequiredVersion 4.6.0 -force

$testFilePath = "./tests"
# Start a jobs running each of the test files
$testFiles = Get-ChildItem $testFilePath
$resultFileNumber = 0
foreach ($testFile in $testFiles)
{
    $resultFileNumber++
    $testName = Split-Path $testFile -leaf

    # Create the job, be sure to pass argument in from the ArgumentList which 
    # are needed for inside the script block, they are NOT automatically passed.
    Start-Job `
    -ArgumentList $testFile, $resultFileNumber `
    -Name $testName `
    -ScriptBlock {
        param($testFile, $resultFileNumber)

        # Start trace for local debugging if TEST_LOG=true
        # the traces will show you output in the ./testlogs folder and the files
        # are updated as the tests run so you can follow along
        if ($env:TEST_LOGS -eq "true") {
            Start-Transcript -Path "./testlogs/$(Split-Path $testFile -leaf).integrationtest.log"
        }

        # Run the test file
        Write-Host "$testFile to result file #$resultFileNumber"
        $result = Invoke-Pester "$testFile"

        if ($result.FailedCount -gt 0) {
            throw "1 or more assertions failed"
        }
    } 
}

# Poll to give insight into which jobs are still running so you can spot long running ones       
do {
    Write-Host ">> Still running tests @ $(Get-Date -Format "HH:mm:ss")" -ForegroundColor Blue
    Get-Job | Where-Object { $_.State -eq "Running" } | Format-Table -AutoSize 
    Start-Sleep -Seconds 15
} while ((get-job | Where-Object { $_.State -eq "Running" } | Measure-Object).Count -gt 1)

# Catch edge cases by wait for all of them to finish
Get-Job | Wait-Job

$failedJobs = Get-Job | Where-Object { -not ($_.State -eq "Completed")}

# Receive the results of all the jobs, don't stop at errors
Get-Job | Receive-Job -AutoRemoveJob -Wait -ErrorAction 'Continue'

if ($failedJobs.Count -gt 0) {
    Write-Host "Failed Jobs" -ForegroundColor Red
    $failedJobs
    throw "One or more tests failed"
}