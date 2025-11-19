# Scripts Directory

Automation scripts for IT operations, environmental reviews, and utilities.

## Available Scripts

### IT-EnvironmentalReview.ps1

Comprehensive PowerShell script for performing IT environmental assessments and system health checks.

#### Features

- **System Information**: Hardware specs, OS details, BIOS info, processor details
- **Disk Analysis**: Disk space, usage statistics, capacity warnings
- **Memory Monitoring**: RAM usage and availability
- **Network Configuration**: Active adapters, IP addresses, DNS servers, gateways
- **Software Inventory**: Complete list of installed applications (optional)
- **Windows Updates**: Pending updates and security patches status
- **Services Review**: All Windows services status with critical service monitoring
- **Security Assessment**: Firewall status, antivirus products, UAC settings
- **Event Log Analysis**: Recent system and application errors (optional)
- **User Account Audit**: Local users and administrators inventory

#### Requirements

- PowerShell 5.1 or higher
- Windows operating system
- Administrator privileges (recommended for complete information gathering)

#### Usage

**Basic usage** (generates both HTML and JSON reports):
```powershell
.\IT-EnvironmentalReview.ps1
```

**Specify output location**:
```powershell
.\IT-EnvironmentalReview.ps1 -OutputPath "C:\Reports"
```

**Full comprehensive scan with all options**:
```powershell
.\IT-EnvironmentalReview.ps1 -OutputPath "C:\Reports" -IncludeSoftware -IncludeEventLogs -ExportFormat Both
```

**Quick scan (skip software inventory and event logs)**:
```powershell
.\IT-EnvironmentalReview.ps1 -IncludeSoftware:$false -IncludeEventLogs:$false -ExportFormat HTML
```

**JSON output only**:
```powershell
.\IT-EnvironmentalReview.ps1 -ExportFormat JSON
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-OutputPath` | String | Current directory | Directory where reports will be saved |
| `-IncludeSoftware` | Switch | Enabled by default | Include detailed software inventory. Use `-IncludeSoftware:$false` to skip |
| `-IncludeEventLogs` | Switch | Enabled by default | Include event log analysis (last 24 hours). Use `-IncludeEventLogs:$false` to skip |
| `-ExportFormat` | String | Both | Output format: HTML, JSON, or Both |

#### Output

The script generates timestamped reports in the specified output directory:

- **HTML Report**: Interactive, styled report with tables and color-coded status indicators
  - File format: `ITEnvironmentalReview_COMPUTERNAME_YYYYMMDD_HHMMSS.html`
  - Features: Executive summary, detailed tables, visual status indicators

- **JSON Report**: Machine-readable structured data for automation/integration
  - File format: `ITEnvironmentalReview_COMPUTERNAME_YYYYMMDD_HHMMSS.json`
  - Features: Complete data structure, easy parsing for scripts

#### Key Findings

The script provides immediate console feedback including:
- System uptime
- Memory usage percentage
- Disk space status with warnings
- Critical service alerts

#### Status Indicators

- **OK**: System parameter within normal operating range
- **WARNING**: Parameter approaching concerning levels (e.g., <20% disk free)
- **CRITICAL**: Parameter requires immediate attention (e.g., <10% disk free, stopped critical services)

#### Examples

**Monthly IT audit**:
```powershell
.\IT-EnvironmentalReview.ps1 -OutputPath "\\fileserver\IT-Audits\$(Get-Date -Format 'yyyy-MM')" -IncludeSoftware -IncludeEventLogs
```

**Quick health check**:
```powershell
.\IT-EnvironmentalReview.ps1 -IncludeSoftware:$false -IncludeEventLogs:$false
```

**Automated monitoring with task scheduler**:
```powershell
# Create scheduled task to run daily
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File C:\Scripts\IT-EnvironmentalReview.ps1 -OutputPath C:\Reports"
$trigger = New-ScheduledTaskTrigger -Daily -At 2am
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "Daily IT Environmental Review" -Description "Automated system health check"
```

#### Troubleshooting

**Permission errors**: Run PowerShell as Administrator

**Execution policy**: If script won't run, update execution policy:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**WMI/CIM errors**: Ensure WMI service is running:
```powershell
Get-Service Winmgmt | Start-Service
```

#### Best Practices

1. **Regular Reviews**: Schedule weekly or monthly automated reviews
2. **Baseline Comparison**: Keep historical reports to track changes over time
3. **Alert Thresholds**: Review WARNING and CRITICAL findings immediately
4. **Document Actions**: Note remediation steps taken for audit trails
5. **Share Reports**: Distribute HTML reports to stakeholders for transparency

#### Integration

The JSON output can be integrated with:
- SIEM systems
- Monitoring dashboards
- Configuration management databases (CMDB)
- Ticketing systems for automated alert creation
- PowerBI or other analytics platforms

#### Version History

- **v1.0**: Initial release with comprehensive system review capabilities

---

## Contributing

To add new scripts to this directory:

1. Include comprehensive help documentation (comment-based help for PowerShell)
2. Add error handling and logging
3. Update this README with usage examples
4. Test on multiple systems/environments
5. Include parameter validation
