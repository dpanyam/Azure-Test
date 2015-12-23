Import-Module AzureRM.SiteRecovery

# Step 1: Set the subscription
$UserName = "<user@live.com>"
$Password = "<password>"
$AzureSubscriptionName = "prod_sub1"

$SecurePassword = ConvertTo-SecureString -AsPlainText $Password -Force
$Cred = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $securePassword
Add-AzureAccount -Credential $Cred;
$AzureSubscription = Select-AzureSubscription -SubscriptionName $AzureSubscriptionName

# Step 2: Create a Site Recovery vault
$VaultName = "<testvault123>"
$VaultGeo  = "<Southeast Asia>"
$OutputPathForSettingsFile = "<c:\>"

#Step 3: Generate a vault registration key
$VaultName = "<testvault123>"
$VaultGeo  = "<Southeast Asia>"
$OutputPathForSettingsFile = "<c:\>"

$VaultSetingsFile = Get-AzureSiteRecoveryVaultSettingsFile -Location $VaultGeo -Name $VaultName -Path $OutputPathForSettingsFile;

$VaultSettingFilePath = $vaultSetingsFile.FilePath 
$VaultContext = Import-AzureSiteRecoveryVaultSettingsFile -Path $VaultSettingFilePath -ErrorAction Stop

#Step 4: Install the Azure Site Recovery Provider

#create a directory
pushd C:\ASR\

# Extract the files using the downloaded provider
AzureSiteRecoveryProvider.exe /x:. /q

#Install the provider
.\SetupDr.exe /i
$installationRegPath = "hklm:\software\Microsoft\Microsoft System Center Virtual Machine Manager Server\DRAdapter"
do
{
                $isNotInstalled = $true;
                if(Test-Path $installationRegPath)
                {
                                $isNotInstalled = $false;
                }
}While($isNotInstalled)

# Register the server in the vault
$BinPath = $env:SystemDrive+"\Program Files\Microsoft System Center 2012 R2\Virtual Machine Manager\bin"
pushd $BinPath
$encryptionFilePath = "C:\temp\"
.\DRConfigurator.exe /r /Credentials $VaultSettingFilePath /vmmfriendlyname $env:COMPUTERNAME /dataencryptionenabled $encryptionFilePath /startvmmservice

# Step 5: Create an Azure storage account
$StorageAccountName = "teststorageacc1"
$StorageAccountGeo  = "Southeast Asia"

New-AzureStorageAccount -StorageAccountName $StorageAccountName -Label $StorageAccountName -Location $StorageAccountGeo;

# Step 6: Install the Azure Recovery Services Agent
marsagentinstaller.exe /q /nu

# Step 7: Configure cloud protection settings

# Create a cloud protection profile to Azure
$ReplicationFrequencyInSeconds = "300";
$ProfileResult = New-AzureSiteRecoveryProtectionProfileObject -ReplicationProvider  HyperVReplica -RecoveryAzureSubscription $AzureSubscriptionName `
-RecoveryAzureStorageAccount $StorageAccountName -ReplicationFrequencyInSeconds     $ReplicationFrequencyInSeconds;

# Get a protection container
$PrimaryCloud = "testcloud"
$protectionContainer = Get-AzureSiteRecoveryProtectionContainer -Name $PrimaryCloud;    

# Start the association of the protection container with the cloud
$associationJob = Start-AzureSiteRecoveryProtectionProfileAssociationJob -  ProtectionProfile $profileResult -PrimaryProtectionContainer $protectionContainer;      

# Check job is completed
$job = Get-AzureSiteRecoveryJob -Id $associationJob.JobId;
if($job -eq $null -or $job.StateDescription -ne "Completed")
    {
        $isJobLeftForProcessing = $true;
    }

# If job is not yet completed wait another minute
do
{
if($isJobLeftForProcessing)
    {
    Start-Sleep -Seconds 60
    }
 }While($isJobLeftForProcessing)


#Step 8: Configure network mapping
$Servers = Get-AzureSiteRecoveryServer
$Networks = Get-AzureSiteRecoveryNetwork -Server $Servers[0]

$Subscriptions = Get-AzureSubscription
$AzureVmNetworks = Get-AzureVNetSite
New-AzureSiteRecoveryNetworkMapping -PrimaryNetwork $Networks[0] -AzureSubscriptionId $Subscriptions[0].SubscriptionId -AzureVMNetworkId $AzureVmNetworks[0].Id

#Step 9: Enable protection for virtual machines
$ProtectionContainer = Get-AzureSiteRecoveryProtectionContainer -Name $CloudName
$protectionEntity = Get-AzureSiteRecoveryProtectionEntity -Name $VMName -ProtectionContainer $protectionContainer
$jobResult = Set-AzureSiteRecoveryProtectionEntity -ProtectionEntity $protectionEntity -Protection Enable -Force

# Create a Recovery Plan
# Store the below xml file in a location
<#
<?xml version="1.0" encoding="utf-16"?>
<RecoveryPlan Id="d0323b26-5be2-471b-addc-0a8742796610" Name="rp-test"  PrimaryServerId="9350a530-d5af-435b-9f2b-b941b5d9fcd5"  SecondaryServerId="21a9403c-6ec1-44f2-b744-b4e50b792387" Description=""     Version="V2014_07">
  <Actions />
  <ActionGroups>
    <ShutdownAllActionGroup Id="ShutdownAllActionGroup">
      <PreActionSequence />
      <PostActionSequence />
    </ShutdownAllActionGroup>
    <FailoverAllActionGroup Id="FailoverAllActionGroup">
      <PreActionSequence />
      <PostActionSequence />
    </FailoverAllActionGroup>
    <BootActionGroup Id="DefaultActionGroup">
      <PreActionSequence />
      <PostActionSequence />
      <ProtectionEntity PrimaryProtectionEntityId="d4c8ce92-a613-4c63-9b03- cf163cc36ef8" />
    </BootActionGroup>
  </ActionGroups>
  <ActionGroupSequence>
    <ActionGroup Id="ShutdownAllActionGroup" ActionId="ShutdownAllActionGroup"  Before="FailoverAllActionGroup" />
    <ActionGroup Id="FailoverAllActionGroup" ActionId="FailoverAllActionGroup"  After="ShutdownAllActionGroup" Before="DefaultActionGroup" />
    <ActionGroup Id="DefaultActionGroup" ActionId="DefaultActionGroup" After="FailoverAllActionGroup"/>
  </ActionGroupSequence>
</RecoveryPlan>
#>

$TemplatePath = "C:\RPTemplatePath.xml";
$RPCreationJob = New-AzureSiteRecoveryRecoveryPlan -File $TemplatePath -WaitForCompletion;

# Run a test failover
$RPObject = Get-AzureSiteRecoveryRecoveryPlan -Name $RPName;
$jobIDResult = Start-AzureSiteRecoveryTestFailoverJob -RecoveryPlan $RPObject -Direction PrimaryToRecovery;

Do
{
                $job = Get-AzureSiteRecoveryJob -Id $associationJob.JobId;
                Write-Host "Job State:{0}, StateDescription:{1}" -f Job.State, $job.StateDescription;
                if($job -eq $null -or $job.StateDescription -ne "Completed")
                {
                                $isJobLeftForProcessing = $true;
                }
if($isJobLeftForProcessing)
                {
                                Start-Sleep -Seconds 60
                }
}While($isJobLeftForProcessing)











