[CmdletBinding()]
param (
  [Parameter(Mandatory)]
  [string] $Environment
)

process {
  $validationErrors = [System.Collections.Generic.List[string]]::new()

  #Enumerate json files

  #Valid JSON
  $repoRootFolder = Split-Path -Path $PSScriptRoot -Parent
  $testConfigPath = Join-Path -Path $repoRootFolder -ChildPath 'config' -AdditionalChildPath $Environment, 'test.json'
  $testConfigAsJson = Get-Content -Path $testConfigPath -Raw
  $testConfigSchemaFilePath = Join-Path -Path $repoRootFolder -ChildPath 'schemas' -AdditionalChildPath 'test.schema.json'
  $testConfigSchema = Get-Content -Path $testConfigSchemaFilePath -Raw

  #Validate is valid json file
  try {
    if ($IsLinux) {
      $r = Invoke-Expression -Command "jq '.' $testConfigPath" -ErrorAction Stop
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
    #Validate against schema
    $null = Test-Json -Json $testConfigAsJson -Schema $testConfigSchema -ErrorAction Stop
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
