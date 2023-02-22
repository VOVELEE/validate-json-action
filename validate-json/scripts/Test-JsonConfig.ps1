[CmdletBinding()]
param (
  [Parameter(Mandatory)]
  [string] $Environment,

  [Parameter()]
  [string] $ConfigurationFileName = 'test.json',

  [Parameter()]
  [string] $SchemaFileName = 'test.schema.json',

  [Parameter()]
  [string] $RepoRootFolder = $env:GITHUB_WORKSPACE
)

process {
  $validationErrors = [System.Collections.Generic.List[string]]::new()

  #Variables
  $actionRootFolder = Split-Path -Path $PSScriptRoot -Parent
  $testConfigPath = Join-Path -Path $RepoRootFolder -ChildPath 'config' -AdditionalChildPath $Environment
  $testConfigFilePath = Join-Path -Path $testConfigPath -ChildPath $ConfigurationFileName
  $testConfigSchemaFilePath = Join-Path -Path $actionRootFolder -ChildPath 'schemas' -AdditionalChildPath $SchemaFileName

  #Validate schema and json file can be found
  if (-not (Test-Path -Path $testConfigFilePath)) {
    Write-Error -Message "JSON file '$ConfigurationFileName' not found under $testConfigFilePath." -ErrorAction Stop
  }

  if (-not (Test-Path -Path $testConfigSchemaFilePath)) {
    Write-Error -Message "Schema file '$testConfigSchemaFilePath' not found under $testConfigFilePath." -ErrorAction Stop
  }

  #Validate only one JSON file is located
  $testConfigDirectoryItems = Get-ChildItem -Path $testConfigPath -ErrorAction Stop
  if ($testConfigDirectoryItems.Count -gt 2) {
    $validationErrors.Add("Only '$ConfigurationFileName' is expected under $testConfigPath. Current items: $($testConfigDirectoryItems.Count)")
  }

  $PSVersionTable
  #Validate is valid json file
  $testConfigAsJson = Get-Content -Path $testConfigFilePath -Raw
  $testConfigSchema = Get-Content -Path $testConfigSchemaFilePath -Raw
  try {
    if ($IsLinux) {
      $r = Invoke-Expression -Command "jq '.' $testConfigFilePath" -ErrorAction Stop
      if ($LASTEXITCODE -ne 0) {
        Write-Error -Message $r -ErrorAction Stop
      }
    }

    if ($IsWindows) {
      $null = $testConfigAsJson | ConvertFrom-Json -Depth 100 -ErrorAction Stop
    }
  } catch {
    $validationErrors.Add("Provided file is not valid JSON. Details: $_")
  }

  try {
    if ($IsWindows) {
      #Validate against schema
      #Temporary stopped on Linux because of .NET Core issue
      $null = Test-Json -Json $testConfigAsJson -Schema $testConfigSchema -ErrorAction Stop
    }
  } catch {
    $validationErrors.Add("Provided JSON does not pass schema. Details: $_")
  }

  #Additional validations
  $testConfig = $testConfigAsJson | ConvertFrom-Json -ErrorAction Stop
  $testNumber = 0
  foreach ($test in $testConfig) {
    if ($test.name -in @('schedule', 'loader')) {
      $schedule = $test.schedule

      if ($null -eq $schedule) {
        $validationErrors.Add("Provided JSON does not pass schema. Details: Schedule parameter is missing in #/[$testNumber]")
      }
    }

    $testNumber++
  }

  if ($validationErrors.Count) {
    Write-Error -Message "Validation errors found. Errors: $($validationErrors -join ', ')" -ErrorAction Stop
  }
}
