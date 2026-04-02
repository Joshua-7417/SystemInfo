# SystemInfo
A PowerShell script that collects and displays detailed hardware and software information, including OS, CPU, GPU, RAM, storage, network adapters, installed programs, Windows updates, and running services.

## Usage
Download [SystemInfo](https://github.com/Joshua-7417/SystemInfo/releases/download/v1.0/SystemInfo.ps1)

> [!NOTE]
> By default, Windows may block running scripts. You may need to change your exectuion policy with [Set-ExecutionPolicy](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy).

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


### Run Specific Section with Export
Displays GPU section and exports it to a timestamped .log file to the Desktop.

```
PS> .\SystemInfo.ps1 -Section GPU -Export
```

<img width="972" height="512" alt="Run Specific Section with Export" src="https://github.com/user-attachments/assets/4727322f-4a82-4d76-82c1-c54769650887" />

