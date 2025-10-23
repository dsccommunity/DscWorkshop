# GPO to DSC Migration Toolkit

## Overview

This toolkit provides a complete solution for migrating Group Policy Objects (GPOs) to DSC (Desired State Configuration) YAML format compatible with the DscWorkshop framework. It automates the export of GPO settings from XML exports and converts them into structured YAML configuration files that can be immediately used in DSC configurations.

## Why This Toolkit?

Group Policy Objects are a common way to manage Windows configurations in enterprise environments. However, migrating to Infrastructure as Code (IaC) with DSC requires converting these settings to a different format. This toolkit:

- **Automates the conversion** from GPO XML exports to DSC-ready YAML files
- **Ensures accuracy** through comprehensive export of 7 different setting types
- **Maintains structure** with organized, commented YAML output
- **Provides quality assurance** tools to validate the export
- **Saves time** - exports hundreds of settings in seconds instead of manual transcription
- **Supports both formats** - Works with Get-GPOReport and RSOP XML formats

## Quick Start

### 1. Export Your GPO

First, export your GPO to XML format using PowerShell:

```powershell
# Export a specific GPO by name
Get-GPOReport -Name "Your GPO Name" -ReportType Xml -Path ".\MyGPO.xml"

# Or export by GUID
Get-GPOReport -Guid "12345678-1234-1234-1234-123456789012" -ReportType Xml -Path ".\MyGPO.xml"
```

### 2. Export All Settings

Run the orchestration script to export all settings at once:

```powershell
.\Export-GpoAllSettings.ps1 -XmlPath ".\MyGPO.xml" -OutputDirectory ".\output"
```

This creates 7 YAML files with all extracted settings:

- `MyGPO-SecurityOptions.yml`
- `MyGPO-AdministrativeTemplates.yml`
- `MyGPO-AuditPolicy.yml`
- `MyGPO-FirewallProfiles.yml`
- `MyGPO-RegistrySettings.yml`
- `MyGPO-UserRightsAssignments.yml`
- `MyGPO-SystemServices.yml`

### 3. Integrate with DscWorkshop

Copy the generated YAML files to your DscWorkshop data structure:

```powershell
# Example: Add to a baseline
Copy-Item ".\output\MyGPO-*.yml" -Destination "..\source\Baselines\"

# Or add to role-specific configuration
Copy-Item ".\output\MyGPO-*.yml" -Destination "..\source\Roles\FileServer\"
```

## Toolkit Components

### export scripts (8 scripts)

#### 1. Export-GpoAllSettings.ps1 (Orchestrator)

Master script that runs all export scripts in sequence.

**Usage:**

```powershell
.\Export-GpoAllSettings.ps1 -XmlPath "GPO.xml" [-OutputDirectory ".\output"] [-Force]
```

**Parameters:**

- `-XmlPath`: Path to the GPO XML export (required)
- `-OutputDirectory`: Where to save YAML files (optional, defaults to XML file directory)
- `-Force`: Overwrite existing files without prompting

**Output:** Complete export summary with file sizes and success/failure status

---

#### 2. Export-GpoSecurityOptions.ps1

Extracts Security Options (32 settings) - registry-based security policies.

**Examples:** Network access settings, user account control, audit policies, authentication settings

**Output format:**

```yaml
RegistryValues:
  Values:
    - Key: HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Lsa
      ValueName: LimitBlankPasswordUse
      ValueData: 1
      ValueType: Dword
      Ensure: Present
      Force: true
```

---

#### 3. Export-GpoAdministrativeTemplates.ps1

Extracts Administrative Templates (54 settings) - ADMX policy settings.

**Examples:** AutoPlay, PowerShell logging, Remote Desktop, WinRM, event log sizes

**Requires:** Manual policy-to-registry mapping (45+ mappings included)

**Output format:**

```yaml
RegistryValues:
  Values:
    # Turn off Autoplay
    # Category: Windows Components/AutoPlay Policies
    # State: Enabled
    - Key: HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer
      ValueName: NoDriveTypeAutoRun
      ValueData: 255
      ValueType: Dword
```

---

#### 4. Export-GpoAuditPolicies.ps1

Extracts Audit Policies (23 settings) - advanced audit configuration.

**Requires:** AuditPolicyDsc module, AuditPolicies composite resource

**Output format:**

```yaml
AuditPolicies:
  Policies:
    - Name: Credential Validation
      AuditFlag: Success
      Ensure: Present
```

---

#### 5. Export-GpoFirewallProfiles.ps1

Extracts Windows Firewall Profiles (3 profiles: Domain, Public, Private).

**Requires:** NetworkingDsc module, FirewallProfiles composite resource

**Output format:**

```yaml
FirewallProfiles:
  Profiles:
    - Name: Domain
      Enabled: True
      DefaultInboundAction: Block
      DefaultOutboundAction: Allow
```

---

#### 6. Export-GpoRegistrySettings.ps1

Extracts direct registry operations (116 settings) - registry keys/values to create or delete.

**Handles:** Key creation, value setting, and deletion operations

**Output format:**

```yaml
RegistryValues:
  Values:
    - Key: HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\Explorer
      ValueName: NoAutoplayfornonVolume
      ValueData: 1
      ValueType: Dword
      Ensure: Present
```

---

#### 7. Export-GpoUserRightsAssignments.ps1

Extracts User Rights Assignments (23 rights) - who can perform privileged operations.

**Examples:** Log on locally, access computer from network, create symbolic links

**Requires:** SecurityPolicyDsc module, UserRightsAssignments composite resource

**Output format:**

```yaml
UserRightsAssignments:
  Policies:
    - Policy: Access this computer from the network
      Identity:
        - Administrators
        - Remote Desktop Users
```

---

#### 8. Export-GpoSystemServices.ps1

Extracts System Services (4 services) - service startup configuration.

**Output format:**

```yaml
WindowsServices:
  Services:
    - Name: XblAuthManager
      StartupType: Disabled
      State: Stopped
      Ensure: Present
```

---

### Analysis/QA Scripts (2 scripts)

#### 1. Analyze-YamlDuplicates.ps1

Detects duplicate registry entries within a single YAML file.

**Usage:**

```powershell
.\Analyze-YamlDuplicates.ps1 -YamlFilePath "MySettings.yml" [-ShowDetails]
```

**What it checks:**

- Duplicate Key + ValueName combinations
- Counts occurrences of each duplicate
- Reports total entries, unique entries, and duplicates

**Exit codes:**

- 0 = No duplicates found
- 1 = Duplicates detected

---

#### 2. Compare-YamlFiles.ps1

Compares two YAML files for duplicates and conflicts.

**Usage:**

```powershell
.\Compare-YamlFiles.ps1 -FilePath1 "File1.yml" -FilePath2 "File2.yml" [-ShowDuplicates] [-ShowConflicts]
```

**What it checks:**

- **Duplicates:** Same Key + ValueName + ValueData in both files
- **Conflicts:** Same Key + ValueName but different ValueData

**Use cases:**

- Comparing baseline vs. role-specific settings
- Identifying conflicting policies before deployment
- Validating merge operations

---

## Common Workflows

### Workflow 1: Extract Windows 11 Security Baseline

```powershell
# 1. Export the Microsoft Security Baseline GPO
Get-GPOReport -Name "Win11-24H2-MSFT-Baseline" -ReportType Xml -Path ".\Win11Baseline.xml"

# 2. Extract all settings
.\Export-GpoAllSettings.ps1 -XmlPath ".\Win11Baseline.xml" -OutputDirectory ".\baseline"

# 3. Check for duplicates in each file
Get-ChildItem .\baseline\*.yml | ForEach-Object {
    .\Analyze-YamlDuplicates.ps1 -YamlFilePath $_.FullName
}

# 4. Copy to your baseline folder
Copy-Item .\baseline\*.yml -Destination ..\source\Baselines\Windows11Baseline\
```

### Workflow 2: Merge Multiple GPOs

```powershell
# Extract two GPOs
.\Export-GpoAllSettings.ps1 -XmlPath ".\GPO1.xml" -OutputDirectory ".\gpo1"
.\Export-GpoAllSettings.ps1 -XmlPath ".\GPO2.xml" -OutputDirectory ".\gpo2"

# Compare for conflicts (example: Administrative Templates)
.\Compare-YamlFiles.ps1 `
    -FilePath1 ".\gpo1\GPO1-AdministrativeTemplates.yml" `
    -FilePath2 ".\gpo2\GPO2-AdministrativeTemplates.yml" `
    -ShowConflicts

# Manually resolve conflicts, then merge
```

### Workflow 3: Validate Existing YAML Against GPO

```powershell
# Extract current GPO state
.\Export-GpoAllSettings.ps1 -XmlPath ".\CurrentGPO.xml" -OutputDirectory ".\current"

# Compare with your existing DSC configuration
.\Compare-YamlFiles.ps1 `
    -FilePath1 "..\source\Baselines\MyBaseline-SecurityOptions.yml" `
    -FilePath2 ".\current\CurrentGPO-SecurityOptions.yml" `
    -ShowConflicts -ShowDuplicates
```

---

## DSC Module Requirements

The extracted YAML files require these DSC modules:

| Module | Version | Used By | Purpose |
|--------|---------|---------|---------|
| xPSDesiredStateConfiguration | 9.2.1+ | All registry settings | xRegistry resource |
| SecurityPolicyDsc | 2.10.0.0+ | UserRightsAssignments | User rights management |
| AuditPolicyDsc | 1.4.0.0+ | AuditPolicies | Advanced audit configuration |
| NetworkingDsc | 9.0.0+ | FirewallProfiles | Firewall profile management |
| PSDscResources | Latest | SystemServices | Service resource |

These are typically already included in DscWorkshop's `RequiredModules.psd1`.

---

## Composite Resources

Three composite DSC resources are included in the DscConfig.Demo module:

### 1. UserRightsAssignments

Wraps `SecurityPolicyDsc` UserRightsAssignment resource.

**Location:** `output\RequiredModules\DscConfig.Demo\<version>\DSCResources\UserRightsAssignments\`

**Schema:**

```yaml
UserRightsAssignments:
  Policies:
    - Policy: <string>     # User right name
      Identity:            # Array of accounts/groups
        - <string>
        - <string>
```

---

### 2. AuditPolicies

Wraps `AuditPolicyDsc` AuditPolicySubcategory resource.

**Location:** `output\RequiredModules\DscConfig.Demo\<version>\DSCResources\AuditPolicies\`

**Schema:**

```yaml
AuditPolicies:
  Policies:
    - Name: <string>       # Audit subcategory name
      AuditFlag: <string>  # Success, Failure, or SuccessAndFailure
      Ensure: Present
```

---

### 3. FirewallProfiles

Wraps `NetworkingDsc` FirewallProfile resource.

**Location:** `output\RequiredModules\DscConfig.Demo\<version>\DSCResources\FirewallProfiles\`

**Schema:**

```yaml
FirewallProfiles:
  Profiles:
    - Name: <string>                    # Domain, Public, or Private
      Enabled: <bool>
      DefaultInboundAction: <string>    # Block or Allow
      DefaultOutboundAction: <string>   # Block or Allow
      LogFileName: <string>             # Optional
      LogMaxSizeKilobytes: <int>        # Optional
```

---

## Features

### Comprehensive Coverage

- **255 of 257 settings extracted** (98% coverage)
- Supports 7 different GPO setting types
- Handles complex scenarios (deletions, key-only operations, multiple values)

### Production-Ready Code

- **PowerShell best practices:** CmdletBinding, parameter validation, comment-based help
- **Error handling:** Try/catch blocks with proper exit codes
- **Validation:** ValidateScript attributes for input checking
- **Logging:** Verbose output support with Write-Verbose
- **Safety:** Force parameter to prevent accidental overwrites

### Quality Assurance

- **Duplicate detection** to catch export errors
- **Conflict detection** when merging multiple GPOs
- **Detailed reporting** with file sizes and success counts
- **Exit codes** for CI/CD integration

---

## File Structure

```
GPOs/
├── README.md                                    # This file
├── Export-GpoAllSettings.ps1                   # Orchestrator script
├── Export-GpoSecurityOptions.ps1               # Security Options export
├── Export-GpoAdministrativeTemplates.ps1       # Admin Templates export
├── Export-GpoAuditPolicies.ps1                 # Audit Policies export
├── Export-GpoFirewallProfiles.ps1              # Firewall export
├── Export-GpoRegistrySettings.ps1              # Registry Settings export
├── Export-GpoUserRightsAssignments.ps1         # User Rights export
├── Export-GpoSystemServices.ps1                # System Services export
├── Analyze-YamlDuplicates.ps1                   # QA - Duplicate detection
├── Compare-YamlFiles.ps1                        # QA - File comparison
├── ANALYSIS_SCRIPTS_ENHANCED.md                 # Analysis scripts documentation
├── export_STATUS.md                         # Detailed export status
├── ORCHESTRATOR_README.md                       # Orchestrator documentation
└── PROJECT_SUMMARY.md                           # Project summary
```

---

## Limitations

### Not Extracted (2 settings - low priority/specialized)

- **Windows Firewall GlobalSettings** (1 setting) - Rarely customized
- **Name Resolution Policy Table (NRPT)** (1 setting) - Complex DirectAccess-specific configuration

### Manual Mapping Required

Administrative Templates export requires manual policy-to-registry mapping. The script includes 45+ common mappings, but custom ADMX policies may need additional mappings.

---

## Troubleshooting

### Issue: Script reports duplicates after export

**Cause:** export script bug or GPO contains actual duplicate settings

**Solution:**

```powershell
# Run analysis to identify duplicates
.\Analyze-YamlDuplicates.ps1 -YamlFilePath "Output.yml" -ShowDetails

# Fix manually in YAML file or report as bug
```

---

### Issue: Settings missing from export

**Cause:** Unsupported setting type or extension namespace

**Solution:**

1. Check export_STATUS.md for known limitations
2. Examine XML file for extension type (q1, q2, q3, q4, q6, q8)
3. File issue or manually add mapping to appropriate export script

---

### Issue: DSC compilation fails with extracted YAML

**Cause:** Missing DSC module or composite resource

**Solution:**

```powershell
# Ensure all required modules are in RequiredModules.psd1
Get-Content ..\RequiredModules.psd1

# Verify composite resources exist
Test-Path ..\output\RequiredModules\DscConfig.Demo\*\DSCResources\UserRightsAssignments
Test-Path ..\output\RequiredModules\DscConfig.Demo\*\DSCResources\AuditPolicies
Test-Path ..\output\RequiredModules\DscConfig.Demo\*\DSCResources\FirewallProfiles
```

---

## Examples

### Example 1: Extract and Deploy Security Baseline

```powershell
# Step 1: Export GPO
Get-GPOReport -Name "Security-Baseline-2024" -ReportType Xml -Path ".\SecurityBaseline.xml"

# Step 2: Extract all settings
.\Export-GpoAllSettings.ps1 -XmlPath ".\SecurityBaseline.xml" -OutputDirectory ".\baseline2024"

# Step 3: Validate export
Get-ChildItem .\baseline2024\*.yml | ForEach-Object {
    Write-Host "Checking $($_.Name)..." -ForegroundColor Cyan
    .\Analyze-YamlDuplicates.ps1 -YamlFilePath $_.FullName
}

# Step 4: Copy to baseline
New-Item -Path ..\source\Baselines\Security2024 -ItemType Directory -Force
Copy-Item .\baseline2024\*.yml -Destination ..\source\Baselines\Security2024\

# Step 5: Reference in baseline configuration
# Edit ..\source\Baselines\Security2024.yml and add configurations
```

---

### Example 2: Compare Dev vs Prod GPO

```powershell
# Extract both environments
Get-GPOReport -Name "AppServer-Dev" -ReportType Xml -Path ".\Dev.xml"
Get-GPOReport -Name "AppServer-Prod" -ReportType Xml -Path ".\Prod.xml"

.\Export-GpoAllSettings.ps1 -XmlPath ".\Dev.xml" -OutputDirectory ".\dev"
.\Export-GpoAllSettings.ps1 -XmlPath ".\Prod.xml" -OutputDirectory ".\prod"

# Compare each setting type
$settingTypes = @(
    'SecurityOptions',
    'AdministrativeTemplates',
    'AuditPolicy',
    'FirewallProfiles',
    'RegistrySettings',
    'UserRightsAssignments',
    'SystemServices'
)

foreach ($type in $settingTypes) {
    Write-Host "`n=== Comparing $type ===" -ForegroundColor Yellow
    .\Compare-YamlFiles.ps1 `
        -FilePath1 ".\dev\Dev-$type.yml" `
        -FilePath2 ".\prod\Prod-$type.yml" `
        -ShowConflicts
}
```

---

## Integration with DscWorkshop

### Step 1: Extract GPO Settings

Use this toolkit to extract GPO settings to YAML files.

### Step 2: Organize in Datum Structure

Place YAML files in appropriate Datum layers:

```
source/
├── Baselines/              # Organization-wide baselines
│   └── Security2024/
│       ├── SecurityOptions.yml
│       ├── AuditPolicy.yml
│       └── ...
├── Roles/                  # Role-specific configurations
│   ├── FileServer/
│   │   └── FileServer-SecurityOptions.yml
│   └── WebServer/
│       └── WebServer-FirewallProfiles.yml
├── Locations/              # Location-specific settings
│   └── Europe/
│       └── Europe-UserRightsAssignments.yml
└── Environments/           # Environment-specific overrides
    ├── Dev/
    └── Prod/
```

### Step 3: Reference in Configuration

Reference the settings in your node configuration:

```yaml
# Example: source/AllNodes/Server01.yml
NodeName: Server01
Configurations:
  - SecurityOptions
  - AuditPolicies
  - UserRightsAssignments
  - FirewallProfiles

# The YAML files will be automatically merged by Datum
```

### Step 4: Build and Deploy

Run the DscWorkshop build process:

```powershell
.\build.ps1 -ResolveDependency -Tasks build
```

---

## Support

For issues or questions:

1. Check documentation in this folder (*.md files)
2. Review script help: `Get-Help .\Export-GpoAllSettings.ps1 -Full`
3. File issue in DscWorkshop repository

---

## License

This toolkit is part of the DscWorkshop project and follows the same license.
