# SystemInfo
A PowerShell script that collects and displays detailed hardware and software information, including OS, CPU, GPU, RAM, storage, network adapters, installed programs, Windows updates, and running services.

## Usage
Download [SystemInfo.ps1](https://raw.githubusercontent.com/Joshua-7417/SystemInfo/main/SystemInfo.ps1)

> [!NOTE]
> By default, Windows may block running scripts. You may need to change your exectuion policy with [Set-ExecutionPolicy](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy).

### Run All Sections
Runs all sections and prints the results to the console.

```
PS> .\SystemInfo.ps1
```

### Run All Sections and Export Log
Runs all sections, prints the results to the console, and exports a timestamped .log file to the Desktop.

```
PS> .\SystemInfo.ps1 -Export
```

### Run Specific Section
Displays OS section only.

```
PS> .\SystemInfo.ps1 -Section GPU
```

### Run Specific Section with Export
Displays GPU section and exports it to a timestamped .log file to the Desktop.

```
PS> .\SystemInfo.ps1 -Section GPU -Export
```
