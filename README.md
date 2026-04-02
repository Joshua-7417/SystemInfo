# SystemInfo
A PowerShell script that collects and displays detailed hardware and software information, including OS, CPU, GPU, RAM, storage, network adapters, installed programs, Windows updates, and running services.

## Usage

### Method 1 - Run Directly in PowerShell
Open PowerShell and paste the following command:

```
irm https://github.com/Joshua-7417/SystemInfo/releases/latest/download/SystemInfo.ps1 | iex
```

### Method 2 - Download and Run
You can also download the script and run it locally:

Download [SystemInfo](https://github.com/Joshua-7417/SystemInfo/releases/latest/download/SystemInfo.ps1)

> [!NOTE]
> By default, Windows may block running scripts. You may need to change your execution policy with [Set-ExecutionPolicy](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy).

## Parameters
No parameters are required to run the script, but the following optional parameters are available:

| Parameter  | Description                                                                |
|------------|----------------------------------------------------------------------------|
| `-Export`  | Exports a timestamped `.log` file to the Desktop.                          |
| `-Section` | Display only a specific section. If not specified, all sections are shown. |

The script can also be run for specific sections only, with the following available:
| Section       | Description                                  |
|---------------|----------------------------------------------|
| `Uptime`      | Displays system uptime                       |
| `OS`          | Displays operating system information        |
| `Users`       | Displays active user accounts                |
| `CPU`         | Displays CPU details                         |
| `RAM`         | Displays RAM details                         |
| `Motherboard` | Displays motherboard details                 |
| `GPU`         | Displays GPU and monitor information         |
| `Network`     | Displays network adapters and IP information |
| `Storage`     | Displays disk and storage information        |
| `USB`         | Displays connected USB devices               |
| `Hotfixes`    | Displays installed Windows updates           |
| `Programs`    | Displays installed programs                  |
| `Services`    | Displays running Windows services            |

## Examples

### Run All Sections
Runs all sections and prints the results to the console.

```
PS> .\SystemInfo.ps1
```

<img width="972" height="512" alt="Run All Sections" src="https://github.com/user-attachments/assets/b3d9f816-b141-43b9-ac07-f9be2b064b00"/>

### Run All Sections and Export Log
Runs all sections, prints the results to the console, and exports a timestamped .log file to the Desktop.

```
PS> .\SystemInfo.ps1 -Export
```

<img width="972" height="512" alt="Run All Sections and Export Log" src="https://github.com/user-attachments/assets/18348a2c-973c-4cf5-aafb-dfdec0110cd9" />


### Run Specific Section
Displays OS section only.

```
PS> .\SystemInfo.ps1 -Section OS
```

<img width="972" height="512" alt="Run Specific Section" src="https://github.com/user-attachments/assets/a7605abc-cac5-49e1-95ab-f8e68884c1db" />


### Run Specific Section with Export Log
Displays GPU section and exports it to a timestamped .log file to the Desktop.

```
PS> .\SystemInfo.ps1 -Section GPU -Export
```

<img width="972" height="512" alt="Run Specific Section with Export" src="https://github.com/user-attachments/assets/4727322f-4a82-4d76-82c1-c54769650887" />

