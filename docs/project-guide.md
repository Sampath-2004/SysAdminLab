# SysAdminLab - Complete Project Guide

**Owner:** Sampath Kumar Peddagolla  
**Completed:** October 25, 2026  
**Project:** Windows Server and Active Directory home lab  
**Status:** Core lab exercises complete. The three post-recovery VM snapshots are saved by user report. Migration of the temporary Windows 10 client to Windows 11 Pro remains a follow-up.

## Project summary and results

This project simulates a small business network on one laptop. DC01 provides the domain directory, DNS, and Windows DHCP. FS01 provides IT and HR file shares and a separate virtual backup volume. CLIENT01 is the domain workstation used for standard-user testing.

| Capability | Implemented result | Evidence |
|---|---|---|
| Virtual infrastructure | Three VMs on the SysAdminLab NAT Network, 10.10.10.0/24 | Configuration screenshots and user reports, as identified in each milestone |
| Domain and DNS | corp.sampath.test; DC01 at 10.10.10.10 | Initial DNS, service, and domain-controller checks screenshot-verified |
| Domain client and policy | CLIENT01 joined to CORP; LabComputers logon-message GPO applied | Domain sign-in reported; policy banner screenshot-verified |
| Group-based file access | IT and HR folders protected with NTFS and SMB permissions | Folder ACLs screenshot-verified; allowed and denied access passed by user report |
| Windows DHCP | DC01 distributes 10.10.10.100-199, with gateway .1 and DNS .10 | CLIENT01 lease at 10.10.10.100 screenshot-verified |
| User provisioning | Alex Taylor and Maya Patel created from CSV into LabUsers and department groups | Script output and AD properties confirmed by user report |
| Account lifecycle | Alex disabled, fresh sign-in blocked, then re-enabled and sign-in restored | Passed by user report |
| File recovery | Recovery-Test.txt deleted and restored from backup version 10/25/2026-22:05 | Catalog and original baseline screenshot-verified; restoration and matching hash passed by user report |
| Access after recovery | Alex reads the recovered original text; HR remains denied | Explicitly confirmed by user report |
| Final checkpoints | DC01-Backup-Recovery, FS01-Backup-Recovery, CLIENT01-Backup-Recovery | All three saved by user report |

### How to use this guide

The 39 milestones preserve the build sequence from VM installation through the final checkpoint. Every substantive command appears with its VM, shell, purpose, parameter meanings, and effect. Code blocks use PowerShell, Command Prompt, CSV, or plain text labels.

Read the evidence labels carefully: **screenshot-verified** means the displayed output was inspected; **user report** means Sampath confirmed the outcome without supplying that output. An **expected result** describes the target behavior. Planned or untested items are identified explicitly.

All Windows paths inside a VM refer to that VM's own drives. Host paths such as C:\SysAdminLab\ISO refer to the physical laptop. Passwords are excluded from this guide.

The PDF is a reading copy. Long command lines may wrap visually; use the editable Markdown guide or the original script files when copying commands.

## Contents

- Project summary and results
- Lab topology
- Environment and configuration record
- Phase 1 - Virtual machines and base networking
- Phase 2 - Active Directory and DNS
- Phase 3 - Domain client and Group Policy
- Phase 4 - Department groups and file services
- Phase 5 - Windows DHCP
- Phase 6 - PowerShell account automation
- Phase 7 - Backup, recovery, and final checkpoint
- Operating the lab
- Troubleshooting and useful lessons
- Resume project description
- Scope and follow-up work
- Abbreviations and key terms
- Official references

## Lab topology

~~~mermaid
flowchart TB
    subgraph LAN["SysAdminLab NAT Network: 10.10.10.0/24"]
        DC["DC01: 10.10.10.10; AD DS, DNS, DHCP"]
        C["CLIENT01: 10.10.10.100; domain workstation"]
        FS["FS01: 10.10.10.30; IT and HR shares; backup B:"]
        GW["NAT gateway: 10.10.10.1"]
        C -->|"Domain sign-in and DNS"| DC
        C -->|"SMB department files"| FS
        FS -->|"Domain membership"| DC
        C -->|"Outbound route"| GW
    end
    GW --> Internet["Internet"]
~~~

The diagram shows the main authentication, file-access, and outbound relationships. All three VMs share the same NAT Network and configured gateway. DC01 and FS01 keep static addresses; CLIENT01's demonstrated DHCP lease is 10.10.10.100 and can change in a future lease.

### Final server and resource quick reference

| Resource | Configuration |
|---|---|
| Domain / NetBIOS name | corp.sampath.test / CORP |
| Domain controller | DC01; Windows Server 2025 Standard Evaluation, Desktop Experience |
| File server | FS01; Windows Server Desktop Experience; setup used the server ISO, but FS01's final edition was not independently queried |
| FS01 system storage | Original 80 GB VDI; department folders on C:\Shares\IT and C:\Shares\HR |
| FS01 backup storage | Added 40 GB FS01-Backup.vdi; Disk 1 prepared as GPT; B: LabBackup, NTFS, Healthy by user report |
| DHCP scope | SysAdminLab-Clients; 10.10.10.100-10.10.10.199; active |
| DHCP options | Router 10.10.10.1; DNS 10.10.10.10; suffix corp.sampath.test |
| IT share / group | \\FS01\IT / CORP\GG_IT_Users |
| HR share / group | \\FS01\HR / CORP\GG_HR_Users |
| Script location | C:\LabScripts inside DC01 |
| Recovery sample | C:\Shares\IT\Recovery-Test.txt inside FS01 |
| Hash record | C:\Shares\Recovery-Test.sha256.txt inside FS01 |
| Backup recovery version | 10/25/2026-22:05, retained exactly from the catalog |

| Domain account | Department access | Functional test status |
|---|---|---|
| CORP\sampath | IT allowed; HR denied | Sign-in and IT file operations passed by user report |
| CORP\hr.test | HR allowed; IT denied | Sign-in and HR file operations passed by user report |
| CORP\alex.taylor | IT allowed; HR denied | Script provisioning, first sign-in/password change, disable/restore, and recovered-file read passed by user report |
| CORP\maya.patel | Member of GG_HR_Users | Stored AD properties and membership confirmed; first sign-in and share access not tested |

The department groups are global security groups in LabGroups. The accounts are in LabUsers, and CLIENT01 is in LabComputers. The configured GPO is LabComputers-LogonMessage.

## Environment and configuration record

### Host and server

| Item | Configuration |
|---|---|
| Host operating system | Windows 11 Home Single Language, version 25H2 |
| Host processor | Intel Core i5-1240P |
| Host RAM | 32 GB |
| Hardware virtualization | Enabled |
| Hypervisor | Oracle VirtualBox; Expert mode enabled |
| VM name and Windows computer name | DC01 |
| Guest operating system | Windows Server 2025 Standard Evaluation — Desktop Experience |
| Guest RAM | 4096 MB / 4 GB |
| Guest processors | 2 virtual CPUs |
| Guest virtual disk | DC01.vdi; 80 GB capacity |
| Firmware | EFI enabled |
| VM folder | C:\SysAdminLab\DC01 |
| Installation media | C:\SysAdminLab\ISO\Windows Server.iso |
| Baseline snapshot | DC01-Clean-Updated |
| Post-GPO snapshot | DC01-Domain-GPO; saved per user report |

The ISO installed Windows Server 2025. VirtualBox's initially displayed Windows Server 2022 guest profile was a hardware preset.

### First client

| Item | Configuration and evidence |
|---|---|
| VM name / Windows computer name | CLIENT01; rename and hostname result reported by the user |
| Guest operating system | Windows 10 Pro; selected in Setup and desktop observed |
| Installation media | Existing Windows 10 ISO in C:\SysAdminLab\ISO; exact filename not recorded |
| VM folder | C:\SysAdminLab\CLIENT01 |
| Virtual disk | C:\SysAdminLab\CLIENT01\CLIENT01.vdi; new 80 GB disk, full preallocation unchecked |
| Intended hardware allocation | 4096 MB RAM, 2 virtual CPUs, EFI enabled; instructed values, final hardware screen not independently shown |
| Local account | LabAdmin; separate from domain accounts |
| Domain membership | corp.sampath.test; successful domain sign-in and verification results reported |
| Domain user | CORP\sampath / sampath@corp.sampath.test |
| Client snapshot | CLIENT01-Domain-GPO; saved per user report |

Windows 10 Home and Pro reached the end of standard support on October 14, 2025. This existing ISO was chosen for the temporary lab client. Migration to a supported Windows 11 Pro release remains planned; no upgrade or Extended Security Updates enrollment is recorded.

### Network

| Setting | Value |
|---|---|
| VirtualBox attachment | NAT Network |
| Network name | SysAdminLab |
| IPv4 network prefix | 10.10.10.0/24 |
| VirtualBox DHCP | Disabled |
| NAT Network IPv6 option | Disabled for this IPv4 lab |
| Adapter 1 | Enabled; virtual cable connected |
| DC01 IPv4 address | 10.10.10.10 |
| CLIENT01 IPv4 address | 10.10.10.100 via DHCP from DC01; screenshot-verified. Initial static address was 10.10.10.20. |
| FS01 IPv4 address | 10.10.10.30; static lab configuration, source address previously screenshot-verified |
| Windows DHCP server | DC01 at 10.10.10.10; CLIENT01's lease identifies this server |
| Subnet mask | 255.255.255.0 |
| Default gateway | 10.10.10.1 |
| Ethernet DNS client server after promotion | 127.0.0.1 — DC01 itself |
| CLIENT01 DNS server | 10.10.10.10 — DC01; screenshot-verified after enabling DHCP |
| Alternate DNS server | None configured |

DC01's IP address, subnet mask, and gateway were verified in command output. Its preferred DNS client address was initially entered as 10.10.10.10. After promotion, PowerShell confirmed that Ethernet uses 127.0.0.1, the loopback address referring to DC01 itself. The internal DNS service was also queried successfully at 10.10.10.10. CLIENT01 now has the DHCP address 10.10.10.100 and uses DC01 at 10.10.10.10 for DNS. FS01 uses its configured static address 10.10.10.30. All three VMs are attached to SysAdminLab; the lab's configured mask is 255.255.255.0 and gateway is 10.10.10.1.

## Phase 1 - Virtual machines and base networking

### 1. Build the Windows Server VM

**Purpose:** Create a server for learning without purchasing separate physical hardware.

**Procedure:**

1. Install VirtualBox on the physical laptop.
2. Download the official Windows Server 2025 Evaluation ISO and save it in C:\SysAdminLab\ISO.
3. Create DC01 using the resource settings above, attach the ISO, and use manual installation.
4. Install Windows Server 2025 Standard Evaluation with Desktop Experience.
5. Set the Administrator password locally and sign in.
6. In Server Manager → Local Server, change the Windows computer name to DC01 and restart the guest.

**Why these choices:** RAM supplies temporary working memory; virtual CPUs supply processing capacity; the VDI file provides the virtual hard disk. Desktop Experience provides graphical management windows. A clear server name helps identify the machine's intended job: DC01 means the first planned domain controller.

**Verified result:** Windows Server installed and Windows showed DC01 after the rename and restart. Domain-controller functionality is established later through promotion.

### 2. Patch the server and save a baseline

**Purpose:** Start with an updated server and preserve a rollback point before major configuration changes.

**Procedure:**

1. Install available Windows Server and security updates inside DC01.
2. Complete any requested restart.
3. Shut down DC01 normally.
4. In VirtualBox's Snapshots view, take a snapshot named DC01-Clean-Updated.

**Verified result:** Updates were reported complete, and the snapshot appeared in VirtualBox.

**Recovery meaning:** The snapshot captures the updated server before the shared network and static IP changes. Restoring it rolls back the VM's disk and saved settings to that point. A separate backup protects against losing the underlying VM files.

### 3. Create and attach the shared lab network

**Purpose:** Allow future lab VMs to communicate with DC01 while providing an outbound route through VirtualBox.

**Procedure:**

1. Enable Expert mode in VirtualBox Preferences to expose network-management tools.
2. Open Network Manager → NAT Networks.
3. Create SysAdminLab with prefix 10.10.10.0/24 and VirtualBox DHCP disabled.
4. With DC01 powered off, open Settings → Network → Adapter 1.
5. Select NAT Network, choose SysAdminLab, and keep the adapter and virtual cable enabled.
6. Save the settings, start DC01, and sign in.

**Why NAT Network:** Network Address Translation (NAT) supplies the outbound translation function. VirtualBox's shared NAT Network mode also allows attached VMs to communicate with one another.

**Why VirtualBox DHCP is disabled:** Dynamic Host Configuration Protocol (DHCP) automatically assigns addresses. VirtualBox DHCP was disabled so Windows Server could provide the service. At this early stage Windows DHCP was not configured; milestones 21-25 record its later installation and successful client lease.

**Verified result:** SysAdminLab was shown with prefix 10.10.10.0/24 and DHCP disabled. DC01's adapter was configured to use it.

### 4. Assign and verify a static server address

**Purpose:** Give DC01 a consistent network address that other lab computers can use.

Inside DC01, open Run and enter:

~~~text
ncpa.cpl
~~~

**Command meaning and location:** On DC01, ncpa.cpl is a Windows Run shortcut that opens Network Connections. It gives access to the Ethernet adapter's IP and DNS configuration.

Open Ethernet → Properties → Internet Protocol Version 4 (TCP/IPv4). Select manual IP and DNS settings and enter the IP address, mask, and gateway from the network table. For this initial step, set preferred DNS to 10.10.10.10, leave alternate DNS blank, and save. The effective DNS client setting after promotion is recorded in milestone 7.

| Field | Practical meaning |
|---|---|
| IP address | Identifies DC01 on the network |
| Subnet mask | Determines which destinations are on the local subnet |
| Default gateway | Router used to reach destinations beyond the local subnet |
| DNS server | Resolves names and helps clients locate services, including a domain controller |

The /24 prefix corresponds to subnet mask 255.255.255.0. The network identifier is 10.10.10.0; the ordinary host-address range is 10.10.10.1 through 10.10.10.254.

**Verification commands:**

**Where and shell:** Inside DC01, in Command Prompt. Both are diagnostic Windows utilities and also work in Windows PowerShell.

~~~cmd
ipconfig
ping 10.10.10.1
~~~

| Command | Meaning | Reason in this step |
|---|---|---|
| ipconfig | Displays basic network-adapter IP settings | Compare DC01's saved address, mask, and gateway with the lab plan |
| ping 10.10.10.1 | Sends ICMP echo requests to the specified gateway address | Check whether DC01 can reach the virtual gateway |

**Verified output:**

~~~text
IPv4 Address:     10.10.10.10
Subnet Mask:     255.255.255.0
Default Gateway: 10.10.10.1
~~~

Ping received four replies from 10.10.10.1.

**What this confirms:** The saved IPv4 settings are correct and DC01 can reach its virtual gateway. DNS resolution and domain services require separate checks.

**DNS design:** DC01 is configured to use itself because it will host the lab's Active Directory DNS service. Later, domain computers will use the internal DNS server, which can resolve external names through forwarders or root hints.

## Phase 2 - Active Directory and DNS

### 5. Install and verify AD DS and DNS roles

**Purpose:** Add the server capabilities needed for central identity management and name resolution.

**Procedure inside DC01:**

1. Open Server Manager → Manage → Add Roles and Features.
2. Choose Role-based or feature-based installation and select DC01.
3. Select Active Directory Domain Services and DNS Server, accepting required management features.
4. Continue to confirmation and select Install.
5. Verify the two roles using Windows PowerShell:

~~~powershell
Get-WindowsFeature AD-Domain-Services,DNS
~~~

**Command explanation — DC01, Windows PowerShell:** Get-WindowsFeature reads Windows Server role and feature installation status. AD-Domain-Services and DNS are the two feature names; the comma supplies both in one query. We run it after role installation to check that both required components are installed before promotion. This query displays status.

**Verified result:**

~~~text
[X] Active Directory Domain Services    AD-Domain-Services
[X] DNS Server                         DNS
~~~

The [X] markers confirm both roles are installed.

| Role | Purpose |
|---|---|
| Active Directory Domain Services (AD DS) | Central directory for users, computers, and groups; supports domain authentication and management |
| Domain Name System (DNS) | Resolves names and service locations so clients can locate the domain controller and other resources |

### 6. Create the forest and promote DC01

**Purpose:** Establish the lab's central directory so domain users, groups, computers, authentication, and policies can be managed together.

**Procedure inside DC01:**

1. Open Server Manager's notification flag and select Promote this server to a domain controller.
2. Select Add a new forest and enter corp.sampath.test as the root domain name. The .test suffix is reserved for testing.
3. On Domain Controller Options, select Windows Server 2025 for the forest and domain functional levels. Keep DNS Server and Global Catalog selected, and Read-only domain controller unselected.
4. Set and privately retain a strong Directory Services Restore Mode (DSRM) password. It is used for recovery; routine domain sign-in uses the Administrator account's existing password.
5. Leave Create DNS delegation unchecked for this new private lab domain. The warning about an unavailable authoritative parent DNS zone does not block this setup.
6. Use CORP as the NetBIOS domain name and keep the database, log, and SYSVOL paths below.
7. Continue through Review Options and Prerequisites Check. The checks passed, with the expected DNS delegation warning. Select Install and allow the automatic restart.
8. Sign in as CORP\Administrator using the existing Windows Server Administrator password. Open Server Manager → Tools → Active Directory Users and Computers.

| Directory setting | Configured value |
|---|---|
| Forest root and domain DNS name | corp.sampath.test |
| NetBIOS domain name | CORP |
| First domain controller | DC01 |
| Forest and domain functional levels selected in the wizard | Windows Server 2025 |
| DNS Server / Global Catalog | Selected |
| Read-only domain controller | Unselected |
| AD DS database folder | C:\Windows\NTDS |
| Database log folder | C:\Windows\NTDS |
| SYSVOL folder | C:\Windows\SYSVOL |

**What the paths store:** The AD DS database stores directory objects such as accounts, groups, and computers. Its transaction logs record database changes for recovery. SYSVOL stores shared Group Policy files and scripts.

**Verified result:** DC01 restarted after promotion, the sign-in screen displayed CORP\Administrator, and sign-in succeeded. Active Directory Users and Computers displayed corp.sampath.test. This confirms that the domain exists and the management console can access it. Basic DNS, service, and share checks were then completed in milestone 7.

**Why a new forest:** A forest is the top-level Active Directory structure. This lab starts with one forest, one domain, and one domain controller. The NetBIOS name CORP provides the short domain prefix in CORP\Administrator.

### 7. Verify the domain controller's basic services and DNS

**Purpose:** Check that DC01 publishes the names, services, and shared folders needed by domain computers before adding a client.

Run the following commands inside DC01 in Windows PowerShell:

~~~powershell
Resolve-DnsName DC01.corp.sampath.test -Server 10.10.10.10 -Type A
Get-Service NTDS,DNS,Netlogon,DFSR
net share
Get-DnsClientServerAddress -AddressFamily IPv4
Resolve-DnsName _ldap._tcp.dc._msdcs.corp.sampath.test -Type SRV
Resolve-DnsName microsoft.com -Type A
~~~

Run each command separately so its output is easy to inspect.

**Command meanings — all executed on DC01 in Windows PowerShell:**

| Command or parameter | Meaning and reason for using it here |
|---|---|
| Resolve-DnsName DC01.corp.sampath.test -Server 10.10.10.10 -Type A | Looks up DC01's IPv4 address by querying the DNS server explicitly at 10.10.10.10. Checks the server's own host record |
| Resolve-DnsName | Queries the supplied name; the following name is the target |
| -Server 10.10.10.10 | Chooses the DNS server to query for this command |
| -Type A | Requests an IPv4 address record |
| Get-Service NTDS,DNS,Netlogon,DFSR | Reads the status of these four services. Commas select the service names; Running is the expected state |
| net share | Windows utility that lists this server's shared resources. Used to find SYSVOL and NETLOGON |
| Get-DnsClientServerAddress -AddressFamily IPv4 | Reads configured IPv4 DNS-server addresses for local network interfaces. Checks which DNS server DC01's Ethernet adapter uses |
| -AddressFamily IPv4 | Limits the displayed DNS-server addresses to the IPv4 family |
| Resolve-DnsName _ldap._tcp.dc._msdcs.corp.sampath.test -Type SRV | Queries the domain-controller service-location record. We check the returned target and port so clients can discover DC01 |
| -Type SRV | Requests service-location records, which include a target hostname and port |
| Resolve-DnsName microsoft.com -Type A | Looks up a public hostname using the current resolver configuration. Checks external name resolution through DC01 |

These commands query information. The DNS tests check names and records; service status and share output provide separate checks of the server baseline.

| Check | Verified result | What it confirms |
|---|---|---|
| DC01 host record | DC01.corp.sampath.test resolves to 10.10.10.10 | The server's DNS name maps to its lab IPv4 address |
| Core services | NTDS, DNS, Netlogon, and DFSR all Running | The directory, DNS, domain logon, and SYSVOL replication services are running |
| Domain shares | SYSVOL and NETLOGON present | The shared locations for policy files and sign-in scripts are published |
| Ethernet DNS client setting | 127.0.0.1 | DC01 queries its own DNS service |
| Domain-controller service record | _ldap._tcp.dc._msdcs.corp.sampath.test returns dc01.corp.sampath.test, port 389, with address 10.10.10.10 | The DNS record used to discover a domain controller is available |
| External DNS query | microsoft.com returns an IPv4 A record | External names can be resolved through DC01's current DNS configuration |

The NETLOGON share points to C:\Windows\SYSVOL\sysvol\corp.sampath.test\SCRIPTS. SYSVOL points to C:\Windows\SYSVOL\sysvol.

**Service meanings:** NTDS is Active Directory Domain Services. DNS handles name resolution. Netlogon supports domain logon and registration of domain-controller DNS records. DFSR means Distributed File System Replication and is used to replicate SYSVOL between domain controllers; this lab currently has one domain controller.

**Scope of verification:** These checks establish the initial server baseline. Client domain joining and user sign-in were subsequently tested in milestones 9–10. The first Group Policy exercise was verified in milestone 11.

### 8. Save the configured domain-controller checkpoint

**Purpose:** Preserve the verified initial domain-controller configuration before adding the workstation.

1. Shut down DC01 normally from inside the guest, using the Windows shutdown controls or:

~~~cmd
shutdown /s /t 0
~~~

**Command meaning — DC01, Command Prompt or Windows PowerShell:** shutdown is a Windows power-control utility. The /s option requests shutdown; /t 0 sets a zero-second delay. Its purpose here is to power off the guest before taking the snapshot. This changes the VM's power state. Windows shutdown controls were offered as an alternative; the exact shutdown method was not separately confirmed.

2. After VirtualBox shows Powered Off, open Snapshots → Take.
3. Name the snapshot DC01-AD-Configured.
4. Start DC01 again before testing the client.

**Result:** The user reported that this snapshot was saved. It captures the domain-controller baseline before the client join and the first standard user account.

## Phase 3 - Domain client and Group Policy

### 9. Install, configure, and join CLIENT01

**Purpose:** Add a workstation to the company-style network so domain accounts can sign in to another computer.

**VM installation:**

1. In VirtualBox, create CLIENT01 in C:\SysAdminLab\CLIENT01, attach the existing Windows 10 ISO, and disable unattended installation.
2. Use the intended hardware allocation in the client table and create a new 80 GB CLIENT01.vdi with full preallocation unchecked.
3. Before starting Setup, attach Adapter 1 to NAT Network → SysAdminLab. Keep the adapter and virtual cable enabled.
4. In Windows Setup, select Windows 10 Pro, choose Custom installation, select the 80 GB unallocated drive, and allow Windows to create its partitions.
5. Complete the offline setup using Continue with limited setup. Create the local account LabAdmin and retain its password privately.
6. Inside Windows, run sysdm.cpl, open Computer Name → Change, set the name to CLIENT01, and restart.

**Windows Run shortcut:** sysdm.cpl opens System Properties on the VM where it is entered. Its Computer Name tab is used first to rename CLIENT01 and later to join the domain.

**Static client network:**

Open ncpa.cpl → Ethernet → Properties → Internet Protocol Version 4 (TCP/IPv4), and enter:

| Field | Value |
|---|---|
| IP address | 10.10.10.20 |
| Subnet mask | 255.255.255.0 |
| Default gateway | 10.10.10.1 |
| Preferred DNS | 10.10.10.10 |
| Alternate DNS | Blank |

The client uses DC01 for DNS so it can locate domain services. DHCP is still disabled, so the client receives its address through this manual configuration.

**Connection test:** With DC01 running, open PowerShell on CLIENT01 and run:

~~~powershell
hostname
Test-NetConnection DC01.corp.sampath.test -Port 389
~~~

The user reported hostname CLIENT01, RemoteAddress 10.10.10.10, and TcpTestSucceeded True. This establishes name resolution and TCP connectivity to the directory service port; the domain join and sign-in provide the subsequent identity test.

**Command meanings at this stage:** hostname displays the local Windows computer name, so CLIENT01 is the expected result after the rename and restart. Test-NetConnection is a PowerShell diagnostic cmdlet; the supplied server name is its destination and -Port 389 selects the TCP port to test. We use these checks before joining CLIENT01 to the domain to identify name or reachability problems early. The detailed parameter and output guide is repeated for the current FS01 exercise below.

**Domain join:**

1. On CLIENT01, run sysdm.cpl → Computer Name → Change.
2. Select Domain and enter corp.sampath.test.
3. When prompted, use CORP\Administrator and the existing DC01 Administrator password to authorize the join.
4. Accept the domain welcome and restart CLIENT01.
5. Use Other user on the sign-in screen for a domain account.

The domain Administrator credentials authorize the join. LabAdmin remains a local workstation account. The standard domain user created in milestone 10 is used for the workstation sign-in.

**Evidence:** The Windows 10 desktop, new virtual disk, and shared NAT Network attachment were observed in screenshots. The user reported saving the client settings, the successful connection test, and the later domain sign-in. No separate secure-channel test has been run.

### 10. Create the first standard user and verify domain sign-in

**Purpose:** Practice centralized account creation and show that a user stored on DC01 can sign in on CLIENT01.

**On DC01, signed in as CORP\Administrator:**

1. Open Server Manager → Tools → Active Directory Users and Computers.
2. Right-click corp.sampath.test → New → Organizational Unit.
3. Name it LabUsers and keep Protect container from accidental deletion selected.
4. Select LabUsers → New → User and enter the account details below.
5. Set a temporary password privately. Keep User must change password at next logon selected. Leave User cannot change password, Password never expires, and Account is disabled unselected, then finish account creation.

| Account field | Value |
|---|---|
| First / last name | Sampath / Peddagolla |
| Displayed full name | Sampath Peddagolla |
| User logon name | sampath |
| User Principal Name (UPN) | sampath@corp.sampath.test |
| Short domain sign-in name | CORP\sampath |
| OU location | corp.sampath.test/LabUsers |
| Intended access | Standard domain user; no additional privileged membership configured |

**First sign-in on CLIENT01:**

1. Select Other user.
2. Enter sampath@corp.sampath.test, or CORP\sampath, and the temporary password.
3. When required, enter the current temporary password in the old-password field and choose a different compliant password in both new-password fields.
4. Finish signing in to the desktop.

**Password troubleshooting:** Windows initially rejected a proposed password for length, complexity, or history requirements, then showed a credential error during a later attempt. The exact cause was not independently established. Guidance clarified the current temporary password versus a rejected proposed password and recommended a new password excluding the account and full-name tokens. The user subsequently reported a successful sign-in. No password-policy change or administrator password reset was recorded, and no passwords are stored in this guide.

For a future policy-related rejection, inspect the actual default domain policy on DC01 rather than guessing its configured minimum:

~~~powershell
Get-ADDefaultDomainPasswordPolicy |
    Select-Object MinPasswordLength,ComplexityEnabled,PasswordHistoryCount,MinPasswordAge
~~~

This diagnostic command has not yet been run in the lab. The suggested 16-character password recipe was guidance, not a measured domain minimum.

**Command explanation — DC01, Windows PowerShell; reference diagnostic only:**

| Part | Meaning and purpose |
|---|---|
| Get-ADDefaultDomainPasswordPolicy | Reads the default password policy for the signed-in domain; used to check the actual configured rules |
| Pipe symbol at the end of the first line | Sends the retrieved policy object into the next command |
| Select-Object | Chooses which properties to display from that object |
| MinPasswordLength | Minimum permitted password length in characters |
| ComplexityEnabled | Whether the domain's complexity requirement is enabled |
| PasswordHistoryCount | Number of previous passwords retained for reuse restrictions |
| MinPasswordAge | Minimum interval before a user can ordinarily change a password again |

The two lines form one PowerShell pipeline. It reads and displays policy settings. Its output has not been captured, so this guide does not assign measured values to these rules.

**Sign-in verification:** On CLIENT01, open normal Command Prompt by running cmd and execute:

~~~cmd
whoami
hostname
echo %LOGONSERVER%
~~~

| Command | Expected result, confirmed by user report | Meaning |
|---|---|---|
| whoami | corp\sampath | The current session uses the domain account |
| hostname | CLIENT01 | The session is on the intended workstation |
| echo %LOGONSERVER% | \\DC01 | The session identifies DC01 as its logon server |

**Where and purpose:** These checks ran on CLIENT01 in Command Prompt after the standard user signed in. whoami identifies the current account; hostname identifies the workstation; echo prints the value of the LOGONSERVER environment variable. The percent-sign variable syntax belongs to Command Prompt. Together, the checks identify the user, computer, and logon server for the tested session. All three display information.

The user reported that all three outputs matched. No screenshot of this command output was supplied. The LabUsers OU and user-creation form were visually observed earlier.

**Result:** The initial two-computer domain works for the first standard-user sign-in. Computer organization and the first policy exercise follow in milestone 11. Group-based access remains to be configured.

### 11. Organize CLIENT01 and deploy the first Group Policy

**Purpose:** Organize workstation identities in a dedicated OU and demonstrate that a centrally managed computer setting reaches CLIENT01.

**Create the computer OU and move the workstation account:**

1. On DC01, open Server Manager → Tools → Active Directory Users and Computers.
2. Right-click corp.sampath.test → New → Organizational Unit.
3. Enter LabComputers, keep Protect container from accidental deletion selected, and save.
4. Open the domain's Computers container, right-click CLIENT01 → Move, and select LabComputers.
5. Open LabComputers and confirm CLIENT01 appears there.

**Verified result:** A screenshot showed the LabComputers OU selected and CLIENT01 listed with type Computer.

The computer account represents the workstation inside the directory. Moving it changes its directory location. An OU provides a place to link Group Policy for a chosen set of computers; LabUsers separately holds the first domain user.

**Create and link the policy on DC01:**

1. Open Server Manager → Tools → Group Policy Management.
2. Expand Forest: corp.sampath.test → Domains → corp.sampath.test.
3. Right-click LabComputers → Create a GPO in this domain, and Link it here.
4. Name the policy LabComputers-LogonMessage.
5. Expand LabComputers, right-click the policy, and select Edit.

The Group Policy Management Editor screenshot showed LabComputers-LogonMessage associated with DC01.CORP.SAMPATH.TEST.

**Configure the sign-in message:**

In the editor, navigate to Computer Configuration → Policies → Windows Settings → Security Settings → Local Policies → Security Options.

Double-click each of the following settings, select Define this policy setting, enter its value, and save with Apply → OK:

| Policy setting | Value or reproduction example |
|---|---|
| Interactive logon: Message title for users attempting to log on | SysAdminLab |
| Interactive logon: Message text for users attempting to log on | Example: Welcome to SysAdminLab. Use your assigned domain account to sign in. |

Computer Configuration is used because this message belongs to the workstation's sign-in process. The GPO is linked to LabComputers, which currently contains CLIENT01.

**Apply and test on CLIENT01:**

1. Keep DC01 running and switch to CLIENT01.
2. Open Command Prompt using Run as administrator. If prompted while signed in as the standard user, supply CLIENT01\LabAdmin and its privately retained local password.
3. Refresh the computer settings:

~~~cmd
gpupdate /target:computer /force
~~~

**Command explanation — CLIENT01, elevated Command Prompt:** gpupdate is a Windows utility for refreshing Group Policy. The /target:computer option selects computer settings, and /force reapplies settings even when they have not changed. It was used after creating the logon-message GPO so CLIENT01 would process the policy before the restart test. This applies configuration to the computer; it is a configuration action rather than a status query.

4. Wait for the computer-policy update to finish successfully, then restart CLIENT01.
5. Observe the message before signing in.

The /target:computer option limits the refresh to computer settings. The /force option reapplies settings. LabAdmin authorizes the elevated local command; the workstation's domain identity is used for computer policy processing.

**Verified result:** The supplied CLIENT01 screenshot displayed the title SysAdminLab, a welcome message directing the user to sign in with the assigned domain account, and an OK button. This verifies the visible result of the first policy exercise. A separate screenshot of the gpupdate completion output was not provided.

**What this demonstrates:** The workstation is organized in Active Directory, the computer policy was created centrally on DC01, and the configured sign-in message is active on CLIENT01.

### 12. Save snapshots of the working domain and client

**Purpose:** Preserve the domain membership, first standard user, computer OU, and working sign-in-message policy before the department and file-server exercises.

1. Shut down CLIENT01 from inside Windows, then shut down DC01 normally.
2. Wait until both show Powered Off in VirtualBox.
3. For each VM, open Snapshots → Take and use the names below.
4. Start DC01 first, then CLIENT01.

| VM | Snapshot name | Stage preserved |
|---|---|---|
| DC01 | DC01-Domain-GPO | Domain, joined workstation account, first standard user, OUs, and first GPO |
| CLIENT01 | CLIENT01-Domain-GPO | Joined client with the tested sign-in message |

**Result:** The user reported both snapshots saved. These snapshots precede the creation of LabGroups and the HR test account.

## Phase 4 - Department groups and file services

### 13. Create department security groups and the HR test account

**Purpose:** Establish department membership before assigning shared-folder permissions.

**Create the groups on DC01:**

1. Open Active Directory Users and Computers as CORP\Administrator.
2. Right-click corp.sampath.test → New → Organizational Unit.
3. Create LabGroups with accidental-deletion protection selected.
4. Right-click LabGroups → New → Group. Create each group below, choosing Group scope: Global and Group type: Security.

| Group name | Department | Member established |
|---|---|---|
| GG_IT_Users | Information Technology | CORP\sampath |
| GG_HR_Users | Human Resources | CORP\hr.test |

GG is the lab's naming prefix for Global Group. A global group collects accounts from the same domain. A security group can receive resource permissions, allowing access to be managed through membership.

**Assign Sampath to IT:**

1. Open LabGroups → GG_IT_Users → Properties → Members → Add.
2. Enter sampath, select Check Names, confirm Sampath Peddagolla resolves, and save with OK → Apply.

**Create the HR test user:**

1. Right-click LabUsers → New → User.
2. Enter first name HR, last name Test, and user logon name hr.test, retaining the suffix @corp.sampath.test.
3. Set a strong temporary password privately. Keep User must change password at next logon selected and the other account-creation boxes unselected.
4. Finish the wizard.
5. Open LabGroups → GG_HR_Users → Members → Add.
6. Enter hr.test, select Check Names, and save with OK → Apply.

| HR account field | Configured value |
|---|---|
| Display name | HR Test |
| User Principal Name | hr.test@corp.sampath.test |
| Short sign-in name | CORP\hr.test |
| Directory location | corp.sampath.test/LabUsers |
| Department group | GG_HR_Users |

**Verified results:** Screenshots showed both security groups in LabGroups, Sampath in GG_IT_Users' Members tab, and HR Test in GG_HR_Users' Members tab. Both member entries pointed to corp.sampath.test/LabUsers. Global scope was selected in the instructions; a separate General-tab screenshot of scope was not supplied.

**Stage scope:** HR Test's successful client sign-in and department access are recorded in milestone 20; the initial forced-password-change prompt was not separately reported. FS01 permissions are recorded in milestones 17-18. Sign out and sign back in after changing a user's group membership so a new session includes that membership.

### 14. Set up FS01 and verify its domain membership

**Status:** The user reports Windows Server setup complete after selecting the new 80 GB unallocated disk. A screenshot confirms hostname FS01, source address 10.10.10.30, and successful TCP connectivity to DC01 at 10.10.10.10:389. Following the domain-join and restart instructions, the user reported Test-ComputerSecureChannel returned True. The mask, gateway, and preferred-DNS values below were instructed and were not separately displayed in the screenshot.

**VM build instructions used for this stage:** Create a new FS01 VM in C:\SysAdminLab\FS01 using C:\SysAdminLab\ISO\Windows Server.iso, manual installation, a new 80 GB VDI, 4096 MB RAM, two virtual CPUs, and EFI enabled. Attach Adapter 1 to NAT Network → SysAdminLab. The instructed edition was Windows Server 2025 Standard Evaluation with Desktop Experience. Select the new unallocated disk during Setup, complete installation, and privately set the local Administrator password. Final edition and hardware-allocation screens were not independently captured; the graphical desktop and disk were observed.

**Execution location:** Windows PowerShell inside the FS01 guest VM. Keep DC01 running.

| Intended FS01 setting | Value |
|---|---|
| Windows computer name | FS01 |
| IPv4 address | 10.10.10.30 |
| Subnet mask | 255.255.255.0 |
| Default gateway | 10.10.10.1 |
| Preferred DNS | 10.10.10.10 |
| Alternate DNS | Blank |

Set the computer name through sysdm.cpl → Computer Name → Change, then restart. Set the Ethernet IPv4 values through ncpa.cpl. These are Windows Run shortcuts, used here on FS01.

**Clipboard integration during setup:** To enable host-to-guest copying, eject the Windows installation ISO, choose VirtualBox Devices → Insert Guest Additions CD Image, and open the mounted CD inside the guest. Run VBoxWindowsAdditions.exe, install and restart, then choose Devices → Shared Clipboard → Host to Guest. The installer adds guest integration drivers and applications. The user reported completing this step while preparing FS01; completion on each of the other VMs was not separately confirmed.

#### Check 1: Identify the local computer

~~~powershell
hostname
~~~

**Meaning:** hostname displays the Windows computer name. It is a Windows utility that works inside PowerShell.

**Purpose and reason:** Confirm that the guest was renamed to FS01 and that the command is being executed on the intended computer after its restart. The VirtualBox VM label and the guest's Windows computer name are separate settings.

**Observed output from the FS01 screenshot:**

~~~text
FS01
~~~

**Effect and actual result:** Displays information. The screenshot confirms the Windows computer name is FS01.

#### Check 2: Test the connection to the domain controller

~~~powershell
Test-NetConnection DC01.corp.sampath.test -Port 389
~~~

| Command part | Meaning |
|---|---|
| Test-NetConnection | PowerShell cmdlet that diagnoses a network connection |
| DC01.corp.sampath.test | Destination's fully qualified domain name: computer DC01 in corp.sampath.test |
| -Port | Parameter selecting the destination TCP port |
| 389 | LDAP port used by the domain controller |

LDAP means Lightweight Directory Access Protocol. Active Directory uses LDAP for directory access. TCP means Transmission Control Protocol. A port number identifies a service endpoint on a computer.

**Purpose and reason:** Before attempting the domain join, check that FS01 resolves the intended server name and can establish a TCP connection to its LDAP endpoint. This helps locate network problems before working on domain membership.

**Observed output from the FS01 screenshot:**

~~~text
ComputerName     : DC01.corp.sampath.test
RemoteAddress    : 10.10.10.10
RemotePort       : 389
InterfaceAlias   : Ethernet
SourceAddress    : 10.10.10.30
TcpTestSucceeded : True
~~~

| Output field | Meaning in this lab |
|---|---|
| RemoteAddress | Address reached for DC01; expected 10.10.10.10 |
| RemotePort | Tested destination port; expected 389 |
| InterfaceAlias | Local adapter used for the test |
| SourceAddress | FS01's address used for the connection; expected 10.10.10.30 |
| TcpTestSucceeded | True indicates that the TCP connection test succeeded |

**How to interpret the result:** The expected address and a successful TCP test establish this particular name-resolution and connection check. The subsequent secure-channel test below provides the member-server trust check. Active Directory also uses other services and ports, so port 389 alone is not a complete domain-health test.

If the name does not resolve, first review FS01's DNS setting and whether DC01 is running. If the name resolves but the TCP test fails, investigate the network path, service availability, and firewall rules before changing settings.

**Effect and actual result:** Performs diagnostic queries and a connection attempt without changing the configured network or joining the domain. The screenshot confirms the expected destination, source address, port, and TcpTestSucceeded True.

#### Join FS01 to the domain

**Where and shell:** Inside FS01, open Windows PowerShell using Run as administrator. Keep DC01 running.

~~~powershell
Add-Computer -DomainName corp.sampath.test -Credential CORP\Administrator -Restart
~~~

| Command part | Meaning and purpose in this step |
|---|---|
| Add-Computer | Joins this local computer, FS01, to the domain and creates its computer account if needed |
| -DomainName corp.sampath.test | Specifies the domain to join |
| -Credential CORP\Administrator | Uses the domain account authorized to perform the join; enter its password privately at the prompt |
| -Restart | Restarts FS01 after a successful join to complete the change |

**Reason:** Make the file server a member of the same managed domain as the users and workstation, ready for domain-based access administration.

**Effect and expected result:** Changes domain membership and restarts FS01 after success. Following restart, sign in as FS01\Administrator with the local FS01 Administrator password.

**Actual result:** Following these join and restart instructions, the user reported the secure-channel check below returned True. This confirms the domain relationship by user report; the Add-Computer completion output was not independently captured.

#### After restart: Verify the member server's secure channel

**Where and shell:** Inside FS01 after joining and restarting, use Windows PowerShell opened with Run as administrator.

~~~powershell
Test-ComputerSecureChannel
~~~

**Meaning:** Tests the trust channel between the local domain-member computer and its domain. The command uses the member computer's domain relationship.

**Reason:** Verify that FS01 can communicate through its domain trust before configuring shares.

**Reported result on FS01:**

~~~text
True
~~~

True indicates a working channel; False indicates a failed test. This is the diagnostic form with no repair parameter. This check is for FS01 as a member server; it is not the domain-controller check for DC01.

**Actual result:** The user reported True. This verifies a working domain secure channel for FS01 by user report. No screenshot of this particular output was supplied.

### 15. Install the File Server role on FS01

**Purpose:** Prepare the file-server role before creating IT and HR shared folders and assigning permissions. SMB means Server Message Block, the protocol CLIENT01 will use to access the shares.

**Where and shell:** Windows PowerShell opened with Run as administrator inside FS01.

~~~powershell
Get-WindowsFeature FS-FileServer
~~~

| Command part | Meaning and reason for use |
|---|---|
| Get-WindowsFeature | Reads Windows Server role and feature installation status on the local server |
| FS-FileServer | Internal role-service name for File Server; selects the component we need to check |

**Reason at this stage:** Determine whether the File Server role service is already installed before preparing shares.

**Output interpretation:**

| Result | Meaning |
|---|---|
| [X] File Server / Installed | Role service is already installed |
| [ ] File Server / Available | Role service is available to install |

**Effect and actual result:** Reads status. The user reported Available, indicating that the role service is ready to install. No screenshot of this output was provided. File shares and department permissions have not yet been configured.

#### Install the File Server role service

**Where and shell:** Inside FS01, in Windows PowerShell opened with Run as administrator.

~~~powershell
Install-WindowsFeature -Name FS-FileServer -IncludeManagementTools
~~~

| Command part | Meaning |
|---|---|
| Install-WindowsFeature | Installs the selected Windows Server role service and its required dependencies |
| -Name FS-FileServer | Selects the File Server role service |
| -IncludeManagementTools | Includes applicable management tools |

**Reason:** Enable FS01's File Server role service before preparing the IT and HR shared folders.

**Effect:** Changes the role configuration on FS01. Administrator elevation is required. The command targets the local server and does not request an automatic restart.

**Expected result and interpretation:**

| Output | Meaning |
|---|---|
| Success: True | Installation succeeded |
| Exit Code: Success | Successful installation completion |
| Restart Needed: No | Continue with the next setup step |
| Restart Needed: Yes | Restart FS01 through Windows before continuing |

**Actual result:** The user reported Exit Code Success and no restart required. This records successful installation by user report. No installation-output screenshot was supplied.

### 16. Create the department folders on FS01

**Where and shell:** Inside the FS01 VM, in Windows PowerShell opened with Run as administrator. The C: paths below belong to the virtual file server.

~~~powershell
New-Item -ItemType Directory -Path "C:\Shares\IT","C:\Shares\HR" -Force
~~~

| Command part | Meaning |
|---|---|
| New-Item | Creates items in the filesystem |
| -ItemType Directory | Creates folders |
| -Path | Specifies the full destination paths |
| "C:\Shares\IT","C:\Shares\HR" | Two folder paths; the comma supplies both to the command |
| -Force | Creates missing parent folders and allows existing directories to be returned |

**Reason at this stage:** Give IT and HR separate folder locations so department permissions can be assigned independently before sharing them with CLIENT01.

| Folder on FS01 | Department group planned for access |
|---|---|
| C:\Shares\IT | CORP\GG_IT_Users |
| C:\Shares\HR | CORP\GG_HR_Users |

**Effect and expected result:** Creates the local folders, including the parent C:\Shares if needed. Output should list IT and HR under C:\Shares. Department permissions and named SMB shares follow in later steps.

**Actual result:** The user reported completing the New-Item command for both folders. Folder creation is recorded as complete by user report; no output screenshot was supplied for independent review.

### 17. Configure and inspect department folder permissions

**Where and shell:** Inside the FS01 VM, in Windows PowerShell opened with Run as administrator. These commands target only the newly created IT and HR folders.

**Purpose:** Give each department's security group Modify permission on its own folder. Preserve Full control for the local Administrators group and Windows SYSTEM account. Remove inherited permission entries so broad permissions inherited from C:\Shares do not grant other ordinary users access.

NTFS means New Technology File System. NTFS permissions govern access to the folders and files on FS01. SMB share permissions will be configured in a later step; this step does not create network shares.

#### Assign the permissions

Run these commands one at a time:

~~~powershell
icacls "C:\Shares\IT" /grant:r "Administrators:(OI)(CI)F" "SYSTEM:(OI)(CI)F" "CORP\GG_IT_Users:(OI)(CI)M" /inheritancelevel:r
icacls "C:\Shares\HR" /grant:r "Administrators:(OI)(CI)F" "SYSTEM:(OI)(CI)F" "CORP\GG_HR_Users:(OI)(CI)M" /inheritancelevel:r
~~~

| Command part | Meaning and reason |
|---|---|
| icacls | Native Windows utility that displays or changes a file or folder's discretionary access control list; it can run from PowerShell |
| C:\Shares\IT / C:\Shares\HR | The specific folder whose permissions are being changed |
| /grant:r | Grants the listed permissions and replaces prior explicit grants for each listed identity; it does not erase unrelated explicit entries |
| Administrators:(OI)(CI)F | Gives the local Administrators group Full control on the department folder, with inheritance to files and subfolders |
| SYSTEM:(OI)(CI)F | Gives the Windows SYSTEM account Full control on the folder, with inheritance to files and subfolders |
| CORP\GG_IT_Users:(OI)(CI)M | Gives the IT department group Modify access to IT |
| CORP\GG_HR_Users:(OI)(CI)M | Gives the HR department group Modify access to HR |
| (OI) | Object inherit: files created beneath the folder inherit this permission |
| (CI) | Container inherit: subfolders inherit this permission |
| F | Full control, including the ability to change permissions |
| M | Modify: read, create, edit, and delete content; does not grant permission-management rights |
| /inheritancelevel:r | Disables inheritance from the parent folder and removes inherited permission entries, while retaining explicit entries |
| Quotes around each identity-and-permission argument | Keep the entire argument together so PowerShell passes its parentheses and punctuation to icacls correctly |

**Effect and expected result:** Changes the two folders' access permissions. Each command should report Successfully processed 1 files; Failed processing 0 files. The word files is also used by icacls for a folder. The department groups receive Modify rather than Full control.

#### Inspect the resulting permissions

After both commands succeed, run:

~~~powershell
icacls "C:\Shares\*"
~~~

| Command part | Meaning |
|---|---|
| icacls with no permission-changing switches | Displays the existing access-control entries; it does not modify them |
| C:\Shares\* | The wildcard selects the items immediately inside C:\Shares, which should be the IT and HR folders |

**Reason:** Check the actual permissions before creating SMB shares and testing client access. IT should list Administrators and SYSTEM with F, plus CORP\GG_IT_Users with M. HR should list Administrators and SYSTEM with F, plus CORP\GG_HR_Users with M. Names may be displayed with prefixes such as BUILTIN\Administrators or NT AUTHORITY\SYSTEM. Unexpected extra entries or an error require review before proceeding.

**Actual result:** Verified in the user's screenshot image(20261025-034559).png. Each permission-setting command reported Successfully processed 1 files; Failed processing 0 files. The inspection reported Successfully processed 2 files; Failed processing 0 files. The displayed ACLs were:

| Folder | Identity | Observed permissions |
|---|---|---|
| C:\Shares\IT | CORP\GG_IT_Users | (OI)(CI)(M) |
| C:\Shares\HR | CORP\GG_HR_Users | (OI)(CI)(M) |
| Both folders | NT AUTHORITY\SYSTEM | (OI)(CI)(F) |
| Both folders | BUILTIN\Administrators | (F), plus a separate (OI)(CI)(F) entry |

The extra folder-only Administrators Full-control entry is redundant with its other Full-control entry and does not broaden department access. No broad Users or Everyone entry was displayed. This confirms folder configuration; network access and cross-department denial are still untested.

### 18. Create and inspect the IT and HR SMB shares

**Where and shell:** Inside FS01, in Windows PowerShell opened with Run as administrator.

**Purpose:** Publish the two existing department folders for CLIENT01 to reach over the lab network. SMB means Server Message Block. Department users receive Change permission at the share level; local administrators receive Full permission.

Run each creation command once:

~~~powershell
New-SmbShare -Name "IT" -Path "C:\Shares\IT" -FullAccess "BUILTIN\Administrators" -ChangeAccess "CORP\GG_IT_Users"
New-SmbShare -Name "HR" -Path "C:\Shares\HR" -FullAccess "BUILTIN\Administrators" -ChangeAccess "CORP\GG_HR_Users"
~~~

| Command part | Meaning |
|---|---|
| New-SmbShare | Creates a network share for an existing folder |
| -Name IT / -Name HR | Sets the share name used after the server name in a network path |
| -Path | Selects the existing local department folder on FS01 |
| -FullAccess BUILTIN\Administrators | Grants the local administrators Full share access |
| -ChangeAccess CORP\GG_IT_Users / CORP\GG_HR_Users | Grants the matching department group Change share access for reading, creating, editing, and deleting content |

**Effect and expected result:** Changes FS01's share configuration and returns information about each new share. IT should map to C:\Shares\IT; HR should map to C:\Shares\HR. The intended network paths are \\FS01\IT and \\FS01\HR. Existing NTFS permissions still apply.

Inspect both share ACLs:

~~~powershell
Get-SmbShareAccess -Name "IT","HR"
~~~

| Command part | Meaning and reason |
|---|---|
| Get-SmbShareAccess | Reads the share's access-control entries so the granted identities and rights can be checked |
| -Name | Chooses the share names to inspect |
| "IT","HR" | A comma-separated array selecting both department shares |

**Effect:** Read-only; this inspection does not change permissions.

| Share | AccountName expected | AccessControlType expected | AccessRight expected |
|---|---|---|---|
| IT | BUILTIN\Administrators | Allow | Full |
| IT | CORP\GG_IT_Users | Allow | Change |
| HR | BUILTIN\Administrators | Allow | Full |
| HR | CORP\GG_HR_Users | Allow | Change |

**Actual result:** The user reported that the result matched the expected share-access entries after running the creation and inspection instructions. Share creation and the expected Administrators Full / matching department Change entries are recorded as complete by user report, without an output screenshot. This is configuration evidence; client access is tested separately below.

### 19. Test IT-user access from CLIENT01

**Where:** Inside CLIENT01. Keep DC01 and FS01 running. Use the standard CORP\sampath account for the test.

**Purpose:** Demonstrate that a department user can work with files in the allowed share and is denied access to the other department. A successful file operation verifies practical access beyond the server's permission listings.

#### Refresh the sign-in session and verify the account

1. On CLIENT01, use Start, the user/account icon, and Sign out. Sign in again as CORP\sampath. A full sign-out and sign-in refreshes group membership in the user's session.
2. Open Command Prompt on CLIENT01 through Windows+R, type cmd, and press Enter. Run:

~~~cmd
whoami
~~~

| Command part | Meaning |
|---|---|
| whoami | Displays the account running this Command Prompt |

**Reason and effect:** Read-only identity check. Expected output is corp\sampath; capitalization may differ. Testing with the standard user makes the result meaningful because an administrator has access to both departments.

#### Test the allowed IT share

On CLIENT01, press Windows+R and enter this network path:

~~~text
\\FS01\IT
~~~

| Path part | Meaning |
|---|---|
| \\ | Begins a UNC (Universal Naming Convention) network path |
| FS01 | The server hosting the share |
| IT | The SMB share name, mapped to C:\Shares\IT on FS01 |

In File Explorer, create a text file such as IT-Test.txt, enter a sentence, and save it. Reopen it, edit and save the content, then delete that test file.

**Effect and expected result:** The path opens the network share. The file actions change only the disposable test file on FS01 through CLIENT01. Opening, creating, reading, editing, and deleting should all succeed for CORP\sampath.

#### Test denied HR access with the same account

Remain signed in as CORP\sampath. Press Windows+R and enter:

~~~text
\\FS01\HR
~~~

The path syntax is the same; HR selects the share mapped to C:\Shares\HR on FS01. Expected result: Windows reports Access denied or that the user does not have permission. A credential prompt is not a confirmed denial result; cancel and report it so that the test can be checked without switching identities.

| Test | Account | Expected result | Actual result |
|---|---|---|---|
| Identity check on CLIENT01 | CORP\sampath | whoami shows corp\sampath | Included in procedure; output not separately supplied |
| IT share: open, create, read, edit, delete test file | CORP\sampath | Allowed | Passed by user report |
| HR share: open | CORP\sampath | Denied | Passed by user report |

**Actual result:** When asked whether the IT file test passed and HR access was denied, the user answered yes. Both outcomes are recorded as passed by user report, without screenshots or a separate whoami output. These results demonstrate permitted IT file operations and denied cross-department HR access in the instructed standard-user session.

### 20. Test HR-user sign-in and reciprocal access

**Where:** Inside CLIENT01; keep DC01 and FS01 running.

**Purpose:** Test the second department with its own standard account. This checks that the HR share is usable by its intended group and that IT access is denied to HR.

1. Sign out of CLIENT01 using Start, the account icon, and Sign out. Sign in as CORP\hr.test with the temporary password set when the HR Test user was created. If prompted to change the password at first sign-in, set a new password privately.
2. Open a normal Command Prompt on CLIENT01 using Windows+R and cmd, then run:

~~~cmd
whoami
~~~

| Command part | Meaning and reason |
|---|---|
| whoami | Reads the current account name; expected output is corp\hr.test, confirming this test uses the HR domain account |

**Effect:** Read-only identity query; it does not change the account or permissions.

3. Use Windows+R to open each network path below while signed in as HR Test:

| UNC path on CLIENT01 | Action and expected result |
|---|---|
| \\FS01\HR | Folder opens. Create a disposable text file such as HR-Test.txt, write and save text, reopen and edit it, then delete it. All file operations should succeed. |
| \\FS01\IT | Opening the share is denied; Windows should report Access denied or no permission. |

These are UNC (Universal Naming Convention) paths: FS01 identifies the file server and HR or IT identifies the share. Opening a path through Run launches File Explorer; these paths are not PowerShell commands. Creating, editing, and deleting the test file changes that file on FS01 through the network.

A credential prompt is not a confirmed access-denial result. Cancel and report it instead of supplying another account for the test.

| Test | Expected | Actual |
|---|---|---|
| HR Test's first domain sign-in | Successful; first-sign-in password change completed if requested | HR-account session confirmed by user report; password-change prompt not separately reported |
| whoami on CLIENT01 | corp\hr.test | Included in procedure; output not separately supplied |
| HR share file operations as HR Test | Allowed | Passed by user report |
| IT share access as HR Test | Denied | Passed by user report |

**Actual result:** The user explicitly confirmed that HR file operations worked and only IT access was denied while following the HR-account test instructions. Both reciprocal access checks are recorded as passed by user report, without screenshots or a separate whoami output. The first-sign-in password-change prompt was not separately described, and no password is recorded here.

The department-access exercise is complete by user report: CORP\sampath has working IT access and denied HR access; CORP\hr.test has working HR access and denied IT access.

#### Historical file-sharing snapshot plan

DC01-FileShares, FS01-FileShares, and CLIENT01-FileShares were suggested after the first share tests. Their creation was not confirmed. They are not listed as completed snapshots. The later three-VM Backup-Recovery checkpoint in milestone 39 was explicitly confirmed by the user.

## Phase 5 - Windows DHCP

### 21. Install the DHCP Server role on DC01

**Where and shell:** Inside DC01, signed in as CORP\Administrator, in Windows PowerShell opened with Run as administrator.

**Purpose:** Add DHCP (Dynamic Host Configuration Protocol) services to DC01 for this lab. DHCP will later assign an IP address, subnet mask, gateway, and DNS settings automatically to CLIENT01. DC01 already has the static address 10.10.10.10.

~~~powershell
Install-WindowsFeature -Name DHCP -IncludeManagementTools
~~~

| Command part | Meaning and reason |
|---|---|
| Install-WindowsFeature | Installs the selected Windows Server role and required components on the local server |
| -Name DHCP | Selects the DHCP Server role |
| -IncludeManagementTools | Includes the relevant management tools, such as the DHCP console and PowerShell management module |

**Effect:** Changes DC01's installed server-role configuration. Run locally in DC01's elevated Windows PowerShell. Keep the existing manual IPv4 settings on all three VMs at this stage.

| Output field | Expected result |
|---|---|
| Success | True |
| Restart Needed | No |
| Exit Code | Success |

**Reason for the sequence:** Install the role first; authorize DC01 in Active Directory and configure its DHCP address pool and network options afterward. CLIENT01 can then be switched to automatic addressing and its lease verified. DC01 and FS01 will retain their static server addresses.

**Actual result:** The user reported matching the expected installation result: Success True, RestartNeeded No, and ExitCode Success. Installation is recorded as successful by user report; no output screenshot was supplied. Authorization and address-pool setup are documented in the following steps.

### 22. Authorize DC01 as a DHCP server in Active Directory

**Where and shell:** Inside DC01, signed in as CORP\Administrator, in the elevated Windows PowerShell window used for role installation.

**Purpose:** Register DC01 in Active Directory's authorized DHCP-server list before configuring address assignment.

#### Register the server

~~~powershell
Add-DhcpServerInDC -DnsName "DC01.corp.sampath.test" -IPAddress 10.10.10.10
~~~

| Command part | Meaning |
|---|---|
| Add-DhcpServerInDC | Adds a DHCP server to the authorized-server list in Active Directory and triggers its authorization check |
| -DnsName | Identifies the DHCP server by its full DNS hostname |
| DC01.corp.sampath.test | The lab server being authorized |
| -IPAddress 10.10.10.10 | Registers DC01's existing static address, rather than a client lease address |

**Effect:** Changes the authorization entries stored in AD. The command normally returns to the prompt without output. Use the following query to check the resulting entry.

#### Check the authorization entry

~~~powershell
Get-DhcpServerInDC
~~~

| Command part | Meaning and reason |
|---|---|
| Get-DhcpServerInDC | Reads Active Directory's authorized DHCP-server list so the server name and IP can be checked |

**Effect:** Read-only directory query.

| IPAddress expected | DnsName expected |
|---|---|
| 10.10.10.10 | DC01.corp.sampath.test |

Hostname capitalization may differ. This verifies the authorization record; address-pool configuration and client leasing will be checked in later steps.

**Actual result:** The user confirmed that Get-DhcpServerInDC matched the expected entry: 10.10.10.10 and DC01.corp.sampath.test. The authorization record is confirmed by user report, without a screenshot. The successful client lease is subsequently demonstrated in milestone 24.

### 23. Create the client DHCP scope and network options

**Where and shell:** Inside DC01, signed in as CORP\Administrator, in Windows PowerShell opened with Run as administrator.

**Purpose:** Prepare a pool of client addresses on the existing SysAdminLab network and specify the network settings that DHCP clients will receive. A scope defines the pool and subnet; a lease is a temporary IP-address assignment to a client.

| Scope setting in the instructions | Value | Reason in this lab |
|---|---|---|
| Name | SysAdminLab-Clients | Identifies the client pool |
| Scope ID / subnet | 10.10.10.0/24 | The existing shared NAT Network |
| Start and end | 10.10.10.100 through 10.10.10.199 | 100 client addresses; existing static addresses are outside this range |
| Subnet mask | 255.255.255.0 | Matches the lab subnet |
| State | Active | Enables the scope to respond to client requests |
| Router / default gateway | 10.10.10.1 | VirtualBox NAT gateway |
| DNS server | 10.10.10.10 | DC01 resolves the AD domain and other names |
| DNS domain | corp.sampath.test | Connection-specific DNS suffix supplied to clients |

VirtualBox's built-in DHCP was disabled earlier for SysAdminLab. DC01 and FS01 retain their static addresses; CLIENT01's switch to automatic addressing follows server-side configuration and inspection.

#### Create the address pool

~~~powershell
Add-DhcpServerv4Scope -Name "SysAdminLab-Clients" -StartRange 10.10.10.100 -EndRange 10.10.10.199 -SubnetMask 255.255.255.0 -State Active
~~~

| Command part | Meaning |
|---|---|
| Add-DhcpServerv4Scope | Creates an IPv4 DHCP scope on the local server |
| -Name | Sets its descriptive label |
| -StartRange / -EndRange | Sets the first and last client addresses, inclusive |
| -SubnetMask | Sets the subnet mask |
| -State Active | Enables the scope |

**Effect and reason:** Changes DC01's DHCP configuration. The selected pool is separate from the existing server and gateway addresses.

#### Set gateway and DNS options

~~~powershell
Set-DhcpServerv4OptionValue -ScopeId 10.10.10.0 -Router 10.10.10.1 -DnsServer 10.10.10.10 -DnsDomain "corp.sampath.test"
~~~

| Command part | Meaning |
|---|---|
| Set-DhcpServerv4OptionValue | Sets DHCPv4 options to give clients |
| -ScopeId 10.10.10.0 | Applies these options to this subnet's scope |
| -Router 10.10.10.1 | Supplies the default gateway |
| -DnsServer 10.10.10.10 | Supplies DC01 as the DNS server |
| -DnsDomain corp.sampath.test | Supplies the DNS suffix |

**Effect and reason:** Changes the selected scope's options so clients receive domain-aware name resolution and a route beyond the local subnet. The scope ID is its network identifier, not DC01's host address.

#### Inspect the pool and options

Run these read-only commands after both configuration commands complete:

~~~powershell
Get-DhcpServerv4Scope -ScopeId 10.10.10.0
Get-DhcpServerv4OptionValue -ScopeId 10.10.10.0
~~~

| Command part | Meaning and reason |
|---|---|
| Get-DhcpServerv4Scope | Reads scope settings so the range, mask, name, and active state can be checked |
| Get-DhcpServerv4OptionValue | Reads the configured scope options so gateway and DNS values can be checked |
| -ScopeId 10.10.10.0 | Selects the lab's client scope for either query |

**Expected result:** The scope query should show SysAdminLab-Clients, ScopeId 10.10.10.0, State Active, StartRange 10.10.10.100, EndRange 10.10.10.199, and mask 255.255.255.0. The options query should include router 10.10.10.1, DNS server 10.10.10.10, and DNS domain corp.sampath.test. Configuration commands may return to the prompt without output; these queries inspect the saved settings.

**Actual result:** The user reported completing the step after the four commands were provided. Step completion is recorded by user report; the full scope and option-query outputs were not supplied. The subsequent CLIENT01 screenshot verifies an assigned address within this pool and the intended gateway, DNS server, and DNS suffix, as recorded in milestone 24.

### 24. Switch CLIENT01 to DHCP and inspect its lease

**Where:** Inside CLIENT01. Keep DC01 and FS01 running. Sign out of the current standard-user session and sign in as CLIENT01\LabAdmin, the client VM's local administrator, to change the adapter settings.

**Purpose:** Demonstrate that DC01 supplies a client lease and network settings automatically. This change applies to CLIENT01's Ethernet adapter. DC01 and FS01 continue using their existing static server addresses.

#### Enable automatic IP and DNS settings

Press Windows+R inside CLIENT01 and enter:

~~~text
ncpa.cpl
~~~

| Command part | Meaning and reason |
|---|---|
| ncpa.cpl | Opens Network Connections, where CLIENT01's Ethernet adapter settings can be changed |

This opens a Control Panel applet; running the shortcut alone does not change network configuration.

1. Right-click Ethernet and select Properties.
2. Select Internet Protocol Version 4 (TCP/IPv4), then Properties.
3. Select Obtain an IP address automatically.
4. Select Obtain DNS server address automatically.
5. Select OK and close the adapter properties.

**Effect:** Replaces CLIENT01's manual IPv4 and DNS configuration with DHCP-provided settings. Its previous static address was 10.10.10.20; the expected DHCP address will be in the configured client pool.

#### Request a lease and inspect the assigned settings

Inside CLIENT01, open Command Prompt with Run as administrator and run these commands one at a time:

~~~cmd
ipconfig /renew
ipconfig /all
~~~

| Command part | Meaning and reason |
|---|---|
| ipconfig | Windows utility for TCP/IP configuration |
| /renew | Requests or renews DHCP configuration on DHCP-enabled adapters |
| /all | Displays full adapter settings, including the DHCP server, DNS servers, and lease information |

**Effect:** Renewal can update the assigned network configuration. The /all query is read-only. Inspect the Ethernet adapter section.

| Ethernet field | Expected result |
|---|---|
| DHCP Enabled | Yes |
| IPv4 Address | An address from 10.10.10.100 through 10.10.10.199 |
| Subnet Mask | 255.255.255.0 |
| Default Gateway | 10.10.10.1 |
| DHCP Server | 10.10.10.10 |
| DNS Servers | 10.10.10.10 |
| Connection-specific DNS Suffix | corp.sampath.test |
| Lease Obtained / Lease Expires | Assigned lease timestamps; exact times depend on execution |

The DHCP Server field identifies which server supplied the lease. Checking it alongside the address range and DNS values confirms that the client obtained the intended configuration from DC01.

**Actual result:** Verified in the user's screenshot image(20261025-194537).png. Host Name is CLIENT01. Ethernet shows DHCP Enabled Yes, IPv4 10.10.10.100 (Preferred), mask 255.255.255.0, gateway 10.10.10.1, DHCP Server 10.10.10.10, DNS Servers 10.10.10.10, and connection-specific DNS suffix corp.sampath.test. Lease Obtained and Lease Expires timestamps are present. This verifies a DHCP lease with the intended client configuration; a separate /renew completion message was not shown. Continued domain and share access after the address change is checked next.

### 25. Confirm the server lease and continued domain/share access

**Purpose:** Match the client's observed lease to DC01's lease records, check CLIENT01's machine trust, and confirm a standard domain user can still use the file share after the addressing change.

#### Check the lease record on DC01

**Where and shell:** Inside DC01, as CORP\Administrator, in Windows PowerShell opened with Run as administrator.

~~~powershell
Get-DhcpServerv4Lease -ScopeId 10.10.10.0
~~~

| Command part | Meaning and reason |
|---|---|
| Get-DhcpServerv4Lease | Reads active DHCPv4 leases so the server's record can be matched to CLIENT01 |
| -ScopeId 10.10.10.0 | Selects the lab's client-address scope |

**Effect and expected result:** Read-only query. Look for 10.10.10.100, a hostname identifying CLIENT01, and AddressState Active. Hostname capitalization or a domain suffix may vary.

#### Check CLIENT01's domain trust

**Where and shell:** Inside CLIENT01, in the CLIENT01\LabAdmin session, open Windows PowerShell with Run as administrator.

~~~powershell
Test-ComputerSecureChannel
~~~

| Command part | Meaning and reason |
|---|---|
| Test-ComputerSecureChannel | Tests the local domain member's secure channel to its domain using Netlogon |

**Effect and expected result:** Tests the trust without repairing it; expected output is True. This check is applied to CLIENT01, a domain member. It verifies that machine trust still works after the client acquired its DHCP settings.

#### Check the standard user's file access

On CLIENT01, sign out of LabAdmin and sign in as CORP\sampath. Press Windows+R and open:

~~~text
\\FS01\IT
~~~

This UNC path identifies the IT share on FS01. Create a disposable text file such as DHCP-Test.txt, enter text and save it, then reopen and delete the test file.

**Effect and expected result:** Changes only the disposable test file on FS01. Successful domain sign-in and file operations demonstrate that the standard user still reaches the permitted share after the client address changed.

| Check | Expected | Actual |
|---|---|---|
| DC01 lease record | CLIENT01 / 10.10.10.100 / Active | Passed by user report |
| Secure-channel test on CLIENT01 | True | Passed by user report |
| CORP\sampath sign-in and IT share file operations | Successful | Passed by user report |

**Actual result:** The user confirmed that all three final checks passed. DC01's matching active client lease, CLIENT01's True secure-channel result, and successful CORP\sampath IT-share file operations are recorded by user report; no additional screenshots or command outputs were supplied for these checks. Together with the client lease screenshot, these results complete the planned DHCP exercise.

## Phase 6 - PowerShell account automation

### 26. Prepare CSV input for account-management automation

**Where and shell:** Inside DC01, signed in as CORP\Administrator, in Windows PowerShell opened with Run as administrator. Notepad is used to save the input file on DC01's virtual C: drive.

**Purpose:** Prepare structured input for a script that will create two fictional domain users, place them in LabUsers, and add them to the appropriate existing department group. Account creation itself follows file preparation and inspection.

#### Create the working folder

~~~powershell
New-Item -ItemType Directory -Path "C:\LabScripts" -Force
~~~

| Command part | Meaning and reason |
|---|---|
| New-Item | Creates an item in the filesystem |
| -ItemType Directory | Makes a folder |
| -Path C:\LabScripts | Selects the folder inside DC01 where input and scripts will be kept |
| -Force | Creates missing parents and allows an already existing directory to be returned |

**Effect and expected result:** Creates or returns the LabScripts folder. For a directory, this command preserves existing contents. It changes the local filesystem only.

#### Create the CSV file in Notepad

CSV means Comma-Separated Values. The first line names the columns; each following line supplies one user's details. Open Notepad on DC01 and enter:

~~~csv
FirstName,LastName,Username,Department
Alex,Taylor,alex.taylor,IT
Maya,Patel,maya.patel,HR
~~~

| Column | Meaning |
|---|---|
| FirstName | User's given name |
| LastName | User's surname |
| Username | Planned domain sign-in name |
| Department | IT or HR; the creation script will select the corresponding security group |

Use File, Save As with these values:

| Save field | Value |
|---|---|
| Full file path | C:\LabScripts\NewUsers.csv |
| Save as type | All Files (*.*) |
| Encoding | UTF-8 |

The planned user-to-group mapping is:

| Planned account | Department | Planned security group |
|---|---|---|
| CORP\alex.taylor | IT | GG_IT_Users |
| CORP\maya.patel | HR | GG_HR_Users |

A temporary password will be entered interactively during the later account-creation step.

#### Import and inspect the two records

Return to DC01's elevated Windows PowerShell and run:

~~~powershell
Import-Csv -Path "C:\LabScripts\NewUsers.csv"
~~~

| Command part | Meaning and reason |
|---|---|
| Import-Csv | Reads CSV rows into PowerShell objects; the headings become property names |
| -Path | Selects the input file to read |

**Effect and expected result:** Reads the file so the headings and values can be checked before provisioning. Expected output contains two records: Alex Taylor / alex.taylor / IT and Maya Patel / maya.patel / HR. This inspection leaves AD accounts unchanged.

**Actual result:** The user confirmed the CSV preparation and inspection step. Folder/file preparation and inspection are recorded by user report; the actual Import-Csv output was not supplied. Account creation is performed by the next script.

### 27. Create domain users and department memberships from CSV

**Where and shell:** Inside DC01, signed in as CORP\Administrator. Save the script in a new Notepad window, then run it in Windows PowerShell opened with Run as administrator.

**Purpose:** Read each CSV record, create an enabled user in LabUsers, require a password change at first sign-in, and add the user to the existing department group. This is the first account-provisioning automation exercise.

#### Save the script

Use File, Save As in a new Notepad window. File name: C:\LabScripts\New-LabUsers.ps1. Save as type: All Files (*.*). Encoding: UTF-8. A .ps1 file contains a PowerShell script.

~~~powershell
$ErrorActionPreference = "Stop"
Import-Module ActiveDirectory

$OU = "OU=LabUsers,DC=corp,DC=sampath,DC=test"
$Groups = @{
    IT = "GG_IT_Users"
    HR = "GG_HR_Users"
}
$Users = Import-Csv -Path "C:\LabScripts\NewUsers.csv"

$null = Get-ADOrganizationalUnit -Identity $OU
foreach ($Group in $Groups.Values) {
    $null = Get-ADGroup -Identity $Group
}

foreach ($User in $Users) {
    $Username = $User.Username.Trim()
    $Department = $User.Department.Trim()

    if ($Username -notmatch '^[a-z][a-z0-9._-]{0,19}$') {
        throw "Invalid username: $Username"
    }
    if (-not $Groups.ContainsKey($Department)) {
        throw "Unknown department: $Department"
    }
    if (Get-ADUser -Filter "SamAccountName -eq '$Username'") {
        Write-Host "SKIPPED: $Username already exists"
        continue
    }

    $GroupName = $Groups[$Department]
    $Password = Read-Host "Temporary password for $Username" -AsSecureString
    $FullName = "$($User.FirstName.Trim()) $($User.LastName.Trim())"
    $Parameters = @{
        Name = $FullName
        DisplayName = $FullName
        GivenName = $User.FirstName.Trim()
        Surname = $User.LastName.Trim()
        SamAccountName = $Username
        UserPrincipalName = "$Username@corp.sampath.test"
        Department = $Department
        Path = $OU
        AccountPassword = $Password
        Enabled = $true
        ChangePasswordAtLogon = $true
    }

    try {
        New-ADUser @Parameters
        Add-ADGroupMember -Identity $GroupName -Members $Username
        Write-Host "CREATED: $Username -> $GroupName"
    }
    catch {
        Write-Warning "FAILED: $Username - $($_.Exception.Message)"
    }
}
~~~

#### Script commands: meanings, reasons, and effects

All commands in this script run on DC01 as part of the script invocation below.

| Command or setting | Meaning and reason | Effect |
|---|---|---|
| $ErrorActionPreference = Stop | Makes command errors terminating so they can be caught or stop processing | Sets script error behavior |
| Import-Module ActiveDirectory | Loads the AD management commands used below | Changes the current PowerShell session |
| Import-Csv -Path | Reads the prepared NewUsers.csv input | Read-only file access |
| Get-ADOrganizationalUnit -Identity $OU | Checks that the target LabUsers OU exists, using its distinguished name | Read-only AD query |
| Get-ADGroup -Identity $Group | Checks that both configured department groups exist before user creation begins | Read-only AD query |
| Get-ADUser -Filter | Searches for the CSV username so an existing account is skipped | Read-only AD query |
| Read-Host ... -AsSecureString | Prompts separately for each new user's temporary password, masks input, and returns a SecureString | Reads private console input |
| New-ADUser @Parameters | Creates the account using the named values in the Parameters hashtable | Changes AD user objects |
| Add-ADGroupMember -Identity $GroupName -Members $Username | Adds the newly created username to the mapped IT or HR group | Changes AD group membership |
| Write-Host | Displays CREATED or SKIPPED status | Console output |
| Write-Warning | Displays FAILED with the caught error message | Console output |

#### Values supplied to New-ADUser

| Hashtable key / parameter | Meaning in this script |
|---|---|
| Name | Full name used for the new directory object |
| DisplayName | Full name displayed for the person |
| GivenName / Surname | First and last names from the CSV |
| SamAccountName | Short domain sign-in name, such as alex.taylor |
| UserPrincipalName | Username followed by @corp.sampath.test |
| Department | IT or HR, read from the CSV |
| Path | OU=LabUsers,DC=corp,DC=sampath,DC=test |
| AccountPassword | SecureString read at the console prompt |
| Enabled = $true | Enables the new account for sign-in |
| ChangePasswordAtLogon = $true | Requires the user to change the temporary password at first sign-in |

#### PowerShell constructs used

| Construct | Meaning and purpose |
|---|---|
| $variable = value | Stores settings or a value for later use |
| @{ ... } | Hashtable; used for department-to-group mapping and named New-ADUser parameters |
| @Parameters | Splatting: passes the hashtable entries as named command parameters |
| foreach | Repeats group checks or account processing for each item |
| $User.FirstName and similar properties | Reads the corresponding CSV column |
| .Trim() | Removes surrounding whitespace from imported field values |
| $Groups.Values | Enumerates the two configured group names for preflight checks |
| .ContainsKey() and $Groups[$Department] | Validates the department and retrieves its group name |
| -notmatch and the username pattern | Accepts 1-20 letters/digits/dots/underscores/hyphens with a letter first; prevents malformed usernames entering the filter |
| if / throw | Checks a condition and stops on invalid input |
| continue | Skips the current CSV record when the username already exists |
| $null = query | Discards a successful lookup's display output while allowing errors to surface |
| $(...) inside a quoted string | Inserts the value of an expression into the output text |
| $true | Boolean true, used to enable the account and require its password change |
| try / catch and $_.Exception.Message | Catches account/group operation errors and prints a readable FAILED message |

Existing usernames are skipped without password resets or membership changes. Account creation and group assignment are separate operations; a FAILED row can leave a partially completed account and needs inspection before retrying. CREATED is printed only after both operations return successfully.

#### Run the saved script

Inside DC01's elevated Windows PowerShell, run:

~~~powershell
& "C:\LabScripts\New-LabUsers.ps1"
~~~

The & call operator runs the script at the quoted path. The script reads C:\LabScripts\NewUsers.csv and applies its AD changes under the signed-in administrator.

Enter a temporary password privately when prompted for each new user. Guidance for this lab is 16 or more characters with upper/lowercase letters, a number, and a symbol, excluding the person's names or username. The actual domain minimum length has not been queried; 16 is guidance, not a measured policy value.

Expected messages on a successful first run:

~~~text
CREATED: alex.taylor -> GG_IT_Users
CREATED: maya.patel -> GG_HR_Users
~~~

An already-existing username produces SKIPPED. A FAILED message needs review; neither it nor SKIPPED proves that provisioning completed. Account properties and group memberships will be queried after the run.

**Actual result:** The user reported matching both expected CREATED messages: alex.taylor to GG_IT_Users, and maya.patel to GG_HR_Users. Script execution and these success messages are recorded by user report, without a screenshot. Stored account properties and memberships are queried next. No temporary password is recorded in this guide.

### 28. Verify the CSV-provisioned accounts

**Where and shell:** Inside DC01, as CORP\Administrator, in Windows PowerShell opened with Run as administrator.

**Purpose:** Read the saved AD values after provisioning to verify the accounts' enabled state, department, OU location, and direct group membership.

Run one command for each new user:

~~~powershell
Get-ADUser -Identity alex.taylor -Properties Department,MemberOf | Select-Object Name,SamAccountName,Enabled,Department,DistinguishedName,MemberOf
Get-ADUser -Identity maya.patel -Properties Department,MemberOf | Select-Object Name,SamAccountName,Enabled,Department,DistinguishedName,MemberOf
~~~

| Command part | Meaning and reason |
|---|---|
| Get-ADUser | Retrieves the account's stored AD properties |
| -Identity alex.taylor / maya.patel | Selects the corresponding sign-in name |
| -Properties Department,MemberOf | Requests department and group-membership attributes in addition to default properties |
| Pipeline | Passes the account object from Get-ADUser to Select-Object |
| Select-Object | Selects only the listed properties for inspection |
| Name / SamAccountName | Displays the full object name and short sign-in name |
| Enabled | Shows whether the account is enabled |
| Department | Shows IT or HR |
| DistinguishedName | Shows the directory object's full path, allowing LabUsers OU placement to be checked |
| MemberOf | Shows direct group-membership distinguished names, allowing the department-group assignment to be checked |

**Effect:** Both commands are read-only; they query AD and select output properties.

| Account | Expected Name | Enabled | Department | DistinguishedName must include | MemberOf must include |
|---|---|---|---|---|---|
| alex.taylor | Alex Taylor | True | IT | OU=LabUsers | CN=GG_IT_Users |
| maya.patel | Maya Patel | True | HR | OU=LabUsers | CN=GG_HR_Users |

A distinguished name (DN) identifies an object's directory path. For example, Alex's expected path is CN=Alex Taylor,OU=LabUsers,DC=corp,DC=sampath,DC=test. CN means Common Name; OU means Organizational Unit; the DC components in this path mean Domain Component.

**Actual result:** The user confirmed that both accounts matched the expected values. Alex Taylor / alex.taylor is enabled, in IT and LabUsers, with GG_IT_Users membership. Maya Patel / maya.patel is enabled, in HR and LabUsers, with GG_HR_Users membership. These stored-value checks are recorded by user report; no query-output screenshot was supplied. First-sign-in and resource-access tests follow.

### 29. Test the scripted user's first sign-in and share access

**Where:** Inside CLIENT01. Keep DC01 and FS01 running.

**Purpose:** Test a representative script-created account through first sign-in, the required password change, and actual file access. Alex's account should receive the same IT access pattern already demonstrated with Sampath.

1. Sign out of CLIENT01. Choose Other user and sign in as CORP\alex.taylor using the temporary password entered when the provisioning script ran.
2. When Windows requires a password change, set a new password and finish signing in. Use a different password that meets the domain policy and excludes the person's names. Password values are kept outside this guide.
3. Open a normal Command Prompt through Windows+R and cmd, then run:

~~~cmd
whoami
~~~

| Command part | Meaning and reason |
|---|---|
| whoami | Reads the identity running this Command Prompt; expected output is corp\alex.taylor so the share test is tied to the script-created standard user |

**Effect:** Read-only identity check.

4. Use Windows+R to open each UNC path below while signed in as Alex:

| Path | Action and expected result |
|---|---|
| \\FS01\IT | Opens. Create Alex-Test.txt, enter and save text, reopen and edit/save it, then delete the test file. All operations should succeed. |
| \\FS01\HR | Access denied or a no-permission message. |

The UNC paths select department shares on FS01. File operations change only the disposable test file; the HR check should be denied for this IT user.

| Check | Expected | Actual |
|---|---|---|
| Alex's first sign-in and required password change | Successful | Passed by user report |
| whoami on CLIENT01 | corp\alex.taylor | Included in procedure; output not separately supplied |
| IT share file operations | Allowed | Passed by user report |
| HR share access | Denied | Passed by user report |

**Actual result:** The user confirmed that Alex's password change, IT file operations, and HR denial all worked. These functional outcomes are recorded by user report, without screenshots or separate whoami output. Maya's directory properties and group membership are confirmed by user report, but her first sign-in has not been tested.

### 30. Practice controlled account disablement and restoration

**Purpose:** Simulate the AD account-disable part of offboarding with the fictional alex.taylor account, test a fresh sign-in, and restore the account afterward for continued lab use.

#### Save the disablement script on DC01

**Where:** Inside DC01, as CORP\Administrator. Open a new Notepad window and save the script as C:\LabScripts\Disable-LabUser.ps1, with Save as type All Files (*.*) and Encoding UTF-8.

~~~powershell
param(
    [Parameter(Mandatory = $true)]
    [string]$Username
)

$ErrorActionPreference = "Stop"
Import-Module ActiveDirectory
$User = Get-ADUser -Identity $Username
$LabOU = "OU=LabUsers,DC=corp,DC=sampath,DC=test"

if ($User.DistinguishedName -notlike "*,$LabOU") {
    throw "The account must be in LabUsers."
}

Disable-ADAccount -Identity $User
Get-ADUser -Identity $User | Select-Object SamAccountName,Enabled
~~~

| Command or construct | Meaning and reason | Effect |
|---|---|---|
| param and [string]$Username | Accepts the target username as a script argument | Reads input |
| [Parameter(Mandatory = $true)] | Requires a username when the script runs | Validates required input |
| $ErrorActionPreference = Stop | Stops processing if a command fails | Sets script error behavior |
| Import-Module ActiveDirectory | Loads the AD commands | Changes the PowerShell session |
| Get-ADUser -Identity $Username | Reads the target account, including its directory path | Read-only AD query |
| $LabOU | Stores the allowed LabUsers OU's distinguished name | Stores a setting |
| -notlike with the OU suffix pattern | Rejects an account outside the allowed OU before any disablement | Checks scope |
| throw | Stops the script when the OU check fails | Stops processing |
| Disable-ADAccount -Identity $User | Disables the specific account that passed the scope check | Changes AD account state |
| Get-ADUser -Identity $User | Reads the stored account state again after disablement | Read-only AD query |
| Pipeline and Select-Object SamAccountName,Enabled | Pass the account object onward and display its username and enabled flag | Selects output properties |

#### Run the script and verify disabled state

**Where and shell:** Inside DC01, in Windows PowerShell opened with Run as administrator, as CORP\Administrator.

~~~powershell
& "C:\LabScripts\Disable-LabUser.ps1" -Username alex.taylor
~~~

The & operator runs the script; -Username supplies alex.taylor to its mandatory parameter. Expected output: SamAccountName alex.taylor, Enabled False. Disablement retains the directory account for this lab exercise.

#### Test a fresh sign-in on CLIENT01

Keep DC01 running and reachable. On CLIENT01, fully sign out of Alex's existing session, then try to sign in again as CORP\alex.taylor with the new password set at first sign-in. Expected result: a message that the account is disabled and sign-in is blocked.

Fully signing out is part of this test: it checks a new domain sign-in rather than relying on an already-open desktop or share session. This exercise does not test termination of existing sessions or ticket revocation.

#### Restore the account on DC01

After the blocked-sign-in test, return to DC01's elevated Windows PowerShell and run:

~~~powershell
Enable-ADAccount -Identity alex.taylor
Get-ADUser -Identity alex.taylor | Select-Object SamAccountName,Enabled
~~~

| Command part | Meaning and reason |
|---|---|
| Enable-ADAccount | Re-enables the test account after the exercise |
| -Identity alex.taylor | Selects Alex's account by its short domain sign-in name |
| Get-ADUser and Select-Object | Read the resulting username and enabled flag |

**Effect and expected result:** Enable-ADAccount changes the AD account state. The following query is read-only and should show alex.taylor with Enabled True. Then sign in again on CLIENT01 using Alex's current password; sign-in should succeed.

| Check | Expected | Actual |
|---|---|---|
| Disablement script scope and execution | alex.taylor processed in LabUsers | Completed by user report; script output not separately supplied |
| AD query after disablement | Enabled False | Passed by user report |
| Fresh CLIENT01 sign-in while disabled | Blocked as account disabled | Passed by user report |
| AD query after restoration | Enabled True | Passed by user report |
| CLIENT01 sign-in after restoration | Successful | Passed by user report |

**Actual result:** The user confirmed the requested sequence: Enabled False, blocked sign-in while disabled, Enabled True after restoration, and successful sign-in afterward. These outcomes are recorded by user report without screenshots. Alex is restored to enabled state for continued lab use. This exercise demonstrates reversible AD account disablement and fresh authentication checks; it does not demonstrate termination of existing sessions or complete organizational offboarding.

## Phase 7 - Backup, recovery, and final checkpoint

### 31. Install Windows Server Backup on FS01

**Purpose:** Install Windows Server Backup (WSB), then back up sample department files and prove that a deleted file can be restored with its contents intact.

**Where and shell:** Inside FS01, in Windows PowerShell opened with Run as administrator, using an administrator account. These commands run in the file-server guest, not DC01, CLIENT01, or the host laptop.

~~~powershell
Install-WindowsFeature -Name Windows-Server-Backup -IncludeManagementTools
Get-WindowsFeature -Name Windows-Server-Backup
~~~

Run the installation command first and wait for it to finish. If its RestartNeeded value is Yes, restart FS01 before running the verification command.

| Command or parameter | Meaning and reason | Effect |
|---|---|---|
| Install-WindowsFeature | Installs the selected server feature on the local FS01 server | Changes installed Windows components |
| -Name Windows-Server-Backup | Selects the built-in Windows Server Backup feature | Identifies the feature to install |
| -IncludeManagementTools | Includes management tools associated with the selected feature | Adds available management components |
| Get-WindowsFeature | Reads the installation state of the selected feature | Read-only query |
| -Name Windows-Server-Backup in the query | Limits the result to this backup feature | Selects the result |

**Expected results:** Installation reports Success True. The verification query reports Windows Server Backup with Install State Installed, typically displayed with [X]. Installation alone does not create a backup.

**Actual result:** The user confirmed that installation showed Success True and the verification query showed Installed. These results are recorded by user report without a screenshot. RestartNeeded was not separately reported. No backup job, backup copy, or recovery has been configured or tested yet.

### 32. Add FS01's virtual backup disk

**Where:** VirtualBox Manager on the Windows host laptop. Shut down FS01 through its Windows Start menu first and wait for VirtualBox to show Powered Off.

**Purpose:** Provide a separate destination disk for the upcoming file-backup exercise. Department files remain the backup source on FS01's existing C: volume. This additional virtual disk is a lab destination on the same laptop; it does not protect against loss of the laptop or its underlying storage.

1. Select FS01 in VirtualBox Manager and open Settings, then Storage.
2. Select Controller: SATA and use Add Disk, then Hard Disk.
3. In the Hard Disk Selector, choose Create and enter the following settings.

| Setting | Planned value and reason |
|---|---|
| Image file type | VDI (VirtualBox Disk Image), the native virtual disk format |
| Capacity | 40 GB, sufficient for this small sample-file backup exercise |
| Storage allocation | Dynamically allocated; the host image grows as data is written, up to its configured capacity |
| Host file location | C:\SysAdminLab\FS01\FS01-Backup.vdi |
| Attachment | A second disk on FS01's existing SATA controller |

4. Finish creating the image, select FS01-Backup.vdi in the selector, and click Choose.
5. Inspect the Storage page: FS01 should have its original 80 GB system disk and the added 40 GB backup disk. Save with OK, start FS01, and sign in as an administrator.

**Effect:** Creating the VDI writes a new disk-image file on the host; attaching it changes FS01's virtual hardware configuration. These instructions do not initialize, partition, or format a guest disk.

**Expected result:** Two virtual hard disks attached to FS01, with the new image named FS01-Backup.vdi and capacity 40 GB.

**Actual result:** The creation-dialog screenshot showed 40.00 GB, VDI format, and Pre-allocate Full Size unchecked. The subsequent Hard Disk Selector screenshot, image(20261025-214313).png, showed FS01-Backup.vdi with Virtual Size 40.00 GB and Actual Size 2.00 MB under Not Attached. This verifies that the new image was created, while attachment was still pending at the time of that screenshot. After receiving the Choose, save-settings, start-FS01, and administrator-sign-in instructions, the user confirmed reaching the desktop. Subsequent attachment and boot are therefore recorded by user report; no final Storage-page screenshot was supplied. The host file location was instructed but not independently shown. Those guest-disk details were unverified at this checkpoint; milestones 33-36 record the subsequent disk preparation and backup catalog.

### 33. Identify FS01's backup disk inside Windows

**Where and shell:** Inside FS01, in Windows PowerShell opened with Run as administrator, using an administrator account.

~~~powershell
Get-Disk
~~~

| Command | Meaning and reason | Effect |
|---|---|---|
| Get-Disk | Lists disks visible to the local Windows guest, including disk numbers, sizes, operational state, and partition styles; used to identify the new 40 GB disk before any disk changes | Read-only inventory |

**Expected result:** Two disks: the existing approximately 80 GB system disk and the new approximately 40 GB disk. The new, uninitialized disk should show Partition Style RAW. In this output, RAW means the disk has no initialized partition table; it is not a filesystem format selected for the backup.

**Decision:** Use the reported disk number and RAW partition style to target the newly added backup disk. The disk number is established by the user's inventory result, not assumed from the order in which disks were added.

**Actual result:** The user reported that the new disk is Number 1 with RAW partition style. This identifies the backup disk inside FS01 by user report. The complete command output, including size, operational state, and other disks, was not supplied. The 40 GB capacity is confirmed for the new image by the earlier selector screenshot. The disk was still uninitialized at this check; its subsequent preparation is recorded in milestone 34.

### 34. Prepare Disk 1 as FS01's backup volume

**Where and shell:** Inside FS01, in Windows PowerShell opened with Run as administrator, using an administrator account. The target is the newly added, blank 40 GB Disk 1 identified above.

**Purpose:** Write a GPT partition table, create a backup data partition, and format it as NTFS with the drive letter B: and label LabBackup. This creates a usable storage destination; it does not create a backup.

Run the following steps one at a time. If a command reports an error, stop and inspect that result before entering the next step.

#### Initialize the new disk

~~~powershell
Initialize-Disk -Number 1 -PartitionStyle GPT -ErrorAction Stop
~~~

| Command or parameter | Meaning and reason | Effect |
|---|---|---|
| Initialize-Disk | Prepares a RAW disk for first use by writing a partition table | Changes disk metadata |
| -Number 1 | Selects the new disk number reported from FS01's inventory | Limits the target to Disk 1 |
| -PartitionStyle GPT | Uses the GUID Partition Table layout | Sets the partition-table format |
| -ErrorAction Stop | Treats a reported command error as terminating for this operation | Stops that failed operation |

**Expected result:** Successful return to the prompt, often with no output because PassThru was not requested. Disk 1's partition style becomes GPT; its backup data partition has not yet been created.

#### Create and format the backup data partition

~~~powershell
New-Partition -DiskNumber 1 -UseMaximumSize -DriveLetter B -ErrorAction Stop |
    Format-Volume -FileSystem NTFS -NewFileSystemLabel "LabBackup" -ErrorAction Stop
~~~

| Command or parameter | Meaning and reason | Effect |
|---|---|---|
| New-Partition | Creates a data partition on the selected disk | Changes the disk's partition layout |
| -DiskNumber 1 | Targets the newly initialized backup disk | Limits where the partition is created |
| -UseMaximumSize | Uses the maximum space available for this new partition | Sets the data partition's size |
| -DriveLetter B | Assigns B: as the backup volume's access letter | Creates the drive-letter assignment |
| Pipeline operator | Sends the newly created partition object directly to Format-Volume | Keeps formatting tied to that returned partition |
| Format-Volume | Creates a filesystem on the new partition | Formats the target partition |
| -FileSystem NTFS | Selects New Technology File System for this Windows backup volume | Sets the filesystem |
| -NewFileSystemLabel LabBackup | Assigns the readable volume label LabBackup | Labels the formatted volume |
| -ErrorAction Stop on each cmdlet | Makes a failure terminate the affected operation; if partition creation fails, it supplies no successful new partition for formatting | Error handling |

If Windows requests format confirmation, confirm only the newly created backup partition. B: is the chosen backup drive letter; if partition creation reports that the letter is unavailable, stop and resolve the assignment before proceeding. No Force or Clear-Disk operation is used.

**Expected result:** The format operation returns a volume with drive letter B, label LabBackup, NTFS filesystem, and approximately 40 GB capacity. The filesystem's reported capacity is slightly below the virtual disk capacity because of partition metadata and reserved space.

#### Verify the resulting volume

~~~powershell
Get-Volume -DriveLetter B
~~~

| Command or parameter | Meaning and reason | Effect |
|---|---|---|
| Get-Volume | Reads volume configuration, health, size, and remaining space | Read-only query |
| -DriveLetter B | Selects the volume assigned the backup letter | Limits the query |

**Expected result:** DriveLetter B, FileSystemLabel LabBackup, FileSystem NTFS, HealthStatus Healthy, and Size approximately 40 GB.

**Actual result:** The user confirmed that the verification result matched B, LabBackup, NTFS, Healthy, and approximately 40 GB. The preparation procedure and resulting volume are recorded as completed by user report; no output screenshot or separate post-initialization Get-Disk query was supplied. At this stage the backup destination was ready; the first backup follows in milestone 35.

### 35. Create recovery test data and take the first file backup

**Where and shell:** Inside FS01, in Windows PowerShell opened with Run as administrator, using an administrator account. All C: and B: paths in this stage refer to drives inside FS01.

**Purpose:** Back up actual sample data in the department folders to B:, and retain a SHA-256 content fingerprint for the later recovery check. The test file will be deleted and restored only after the backup has completed and its catalog has been checked.

#### Create and read the sample file

~~~powershell
Set-Content -Path "C:\Shares\IT\Recovery-Test.txt" -Value "SysAdminLab recovery test - original file content." -Encoding UTF8 -ErrorAction Stop
Get-Content -Path "C:\Shares\IT\Recovery-Test.txt" -ErrorAction Stop
~~~

| Command or parameter | Meaning and reason | Effect |
|---|---|---|
| Set-Content | Creates the named test text file, or replaces its content if the same file already exists | Writes the lab sample file |
| -Path C:\Shares\IT\Recovery-Test.txt | Places the sample inside the existing IT department folder that will be backed up | Selects the file |
| -Value | Supplies the original text we expect to recover | Sets test content |
| -Encoding UTF8 | Writes the text using UTF-8 encoding | Controls stored text encoding |
| Get-Content | Reads the saved text so it can be checked before backup | Read-only file check |
| -ErrorAction Stop | Makes a reported command error terminate that operation | Error handling |

**Expected result:** Set-Content normally returns no output. Get-Content displays: SysAdminLab recovery test - original file content.

#### Save a content fingerprint for comparison after recovery

~~~powershell
(Get-FileHash -Path "C:\Shares\IT\Recovery-Test.txt" -Algorithm SHA256 -ErrorAction Stop).Hash |
    Set-Content -Path "C:\Shares\Recovery-Test.sha256.txt" -Encoding ASCII -ErrorAction Stop
~~~

| Command or construct | Meaning and reason | Effect |
|---|---|---|
| Get-FileHash -Path | Reads the test file and calculates its content fingerprint | Reads the original file |
| -Algorithm SHA256 | Uses the 256-bit Secure Hash Algorithm for later content comparison | Selects the hash algorithm |
| Parentheses and .Hash | Complete the calculation, then extract just the hash string | Selects a result property |
| Pipeline | Sends that hash string to Set-Content | Passes the value onward |
| Set-Content -Path C:\Shares\Recovery-Test.sha256.txt | Saves the baseline outside the IT test file, so it remains available when that test file is deleted | Writes the hash record |
| -Encoding ASCII | Saves the hexadecimal hash as plain ASCII text | Controls the record's encoding |
| -ErrorAction Stop | Terminates the affected operation on a reported error | Error handling |

**Expected result:** No console output. The baseline record contains a 64-character hexadecimal SHA-256 value. It is included in the C:\Shares backup and will remain in place during the later deletion of only the test file. Matching the recovered file's hash against this saved baseline provides strong evidence that its contents were restored intact.

#### Start a one-time file backup

Run this only after the sample text check and hash-record command have succeeded:

~~~powershell
wbadmin start backup -backupTarget:B: -include:C:\Shares -vssCopy
~~~

| Command or option | Meaning and reason | Effect |
|---|---|---|
| wbadmin | Native Windows backup administration utility, run here from elevated PowerShell | Invokes the backup service |
| start backup | Starts a one-time backup operation | Creates backup data |
| -backupTarget:B: | Stores the backup on FS01's prepared LabBackup volume | Selects the destination |
| -include:C:\Shares | Includes the Shares folder and its contents, including IT, HR, and the baseline record | Selects the source |
| -vssCopy | Uses Volume Shadow Copy Service copy-backup mode | Specifies the VSS backup type |

Review the displayed source and destination; if prompted to start the operation, enter Y and press Enter. Leave FS01 running and wait for the backup to finish. If any command fails, stop and inspect the error before continuing.

**Scope:** This exercise backs up the selected department files. Full-server, bare-metal, and AD system-state recovery are not configured by this command. The second VDI remains on the same physical laptop, as noted in milestone 32.

**Expected result:** A successful backup-completion message. Catalog verification and a controlled deleted-file recovery follow after completion is reported.

**Actual result:** The user reached the native backup-start confirmation prompt, received instructions to enter Y, and subsequently reported being done with the backup. The final backup-job success output was not supplied. The subsequent screenshot in milestone 36 verifies an available backup catalog entry, the original sample content, and the saved hash baseline. Those catalog checks corroborate that a recoverable backup version is recorded; actual file recovery is tested separately.

### 36. Check the backup catalog and recovery-test prerequisites

**Where and shell:** Inside FS01, in Windows PowerShell opened with Run as administrator, using an administrator account.

**Purpose:** Confirm that Windows can find FS01's backup on B:, identify its exact version and supported recovery types, and check the original test data and saved hash before a controlled deletion.

~~~powershell
wbadmin get versions -backupTarget:B: -machine:FS01
~~~

| Command or option | Meaning and reason | Effect |
|---|---|---|
| wbadmin get versions | Lists catalog information about backup versions, including time, version identifier, location, and supported recovery types | Read-only catalog query |
| -backupTarget:B: | Queries the prepared backup destination | Selects the location |
| -machine:FS01 | Selects backups of FS01 at that destination | Selects the backed-up computer |

**Expected result:** A backup entry with its Version identifier and a Can recover entry that supports file recovery. Use the exact identifier shown by Windows for the subsequent recovery command; do not substitute an assumed date or time. Listing the catalog is a prerequisite check and does not itself prove recovery works.

~~~powershell
Get-Content -Path "C:\Shares\IT\Recovery-Test.txt","C:\Shares\Recovery-Test.sha256.txt" -ErrorAction Stop
~~~

| Command or parameter | Meaning and reason | Effect |
|---|---|---|
| Get-Content | Reads the original sample file and saved baseline record | Read-only file query |
| -Path with two comma-separated paths | Selects both files, in the order shown | Reads each listed file |
| -ErrorAction Stop | Stops this query on a reported error, such as a missing prerequisite file | Error handling |

**Expected result:** The original text, SysAdminLab recovery test - original file content., followed by the saved 64-character hexadecimal hash. A missing file, an error, or an unexpected backup catalog result needs investigation before the deletion-and-restore exercise.

**Actual result:** Screenshot image(20261025-221003).png verifies the following catalog and file-check output:

| Verified item | Observed value |
|---|---|
| Backup time, as displayed by the guest | 10/25/2026 3:05 PM |
| Backup target | Fixed Disk labeled LabBackup(B:) |
| Version identifier | 10/25/2026-22:05 |
| Can recover | Volume(s), File(s) |
| Original test-file text | SysAdminLab recovery test - original file content. |
| Saved SHA-256 baseline | 833170925B8F7BEF1A0CE86F8B60313021D847AB1BCAD2550D3B65B1E9701223 |

The exact version identifier shown by the catalog is retained for recovery. This screenshot confirms that the original file and baseline are present and that file recovery is offered; it does not yet demonstrate a successful restoration.

### 37. Recover the deleted test file and verify its contents

**Where and shell:** Inside FS01, in Windows PowerShell opened with Run as administrator, using an administrator account. The synthetic test file is C:\Shares\IT\Recovery-Test.txt. Its backup and saved baseline were checked in milestone 36.

**Purpose:** Simulate deletion of the sample file, restore it from the verified backup version, then compare the recovered text and SHA-256 hash with the original baseline.

#### Delete the sample file and confirm it is absent

~~~powershell
Remove-Item -LiteralPath "C:\Shares\IT\Recovery-Test.txt" -ErrorAction Stop
Test-Path -LiteralPath "C:\Shares\IT\Recovery-Test.txt"
~~~

| Command or parameter | Meaning and reason | Effect |
|---|---|---|
| Remove-Item | Deletes the synthetic test file to create the recovery scenario | Deletes the selected file |
| -LiteralPath | Uses the exact file path without interpreting wildcard characters | Limits the deletion to the named test file |
| -ErrorAction Stop | Terminates the operation on a reported deletion error | Error handling |
| Test-Path -LiteralPath | Checks whether the named file exists afterward | Read-only existence check |

**Expected result:** Deletion normally produces no output. Test-Path returns False. Continue to recovery after this absence check succeeds.

#### Restore from the selected backup

~~~powershell
wbadmin start recovery -version:10/25/2026-22:05 -itemtype:File -items:C:\Shares\IT\Recovery-Test.txt -backupTarget:B: -machine:FS01
~~~

| Command or option | Meaning and reason | Effect |
|---|---|---|
| wbadmin start recovery | Starts recovery using the chosen backup version | Restores backed-up data |
| -version:10/25/2026-22:05 | Selects the exact version verified in the catalog screenshot | Chooses the recovery point |
| -itemtype:File | Requests file recovery | Selects the recovery type |
| -items:C:\Shares\IT\Recovery-Test.txt | Identifies the individual sample file in that backup | Limits the recovery item |
| -backupTarget:B: | Reads the backup from LabBackup | Selects the backup location |
| -machine:FS01 | Identifies the backed-up computer at that location | Selects the computer |

The command uses the original file location, with no alternate recovery target. Review the displayed recovery details and enter Y if asked to start. Wait for successful completion before the next check; inspect any error before proceeding.

#### Read the recovered text and compare hashes

~~~powershell
Get-Content -Path "C:\Shares\IT\Recovery-Test.txt" -ErrorAction Stop
$ExpectedHash = Get-Content -Path "C:\Shares\Recovery-Test.sha256.txt" -ErrorAction Stop
$RestoredFile = Get-FileHash -Path "C:\Shares\IT\Recovery-Test.txt" -Algorithm SHA256 -ErrorAction Stop
$RestoredFile.Hash -eq $ExpectedHash
~~~

| Command or construct | Meaning and reason | Effect |
|---|---|---|
| Get-Content on Recovery-Test.txt | Displays the recovered sentence | Read-only content check |
| $ExpectedHash = Get-Content on Recovery-Test.sha256.txt | Reads the pre-backup baseline and stores it for comparison | Reads a file and assigns a session variable |
| $RestoredFile = Get-FileHash | Calculates the recovered file's SHA-256 result and stores the returned object | Reads the restored file and assigns a session variable |
| -Algorithm SHA256 | Uses the same hash algorithm as the original baseline | Selects the hash algorithm |
| .Hash | Extracts the hash string from the returned hash object | Reads an object property |
| -eq | Compares the recovered hash with the saved original hash | Returns a Boolean comparison result |
| -ErrorAction Stop | Stops a failed read or calculation, such as a missing file | Error handling |

**Expected result:** Get-Content displays the original sentence. The final comparison returns True, giving strong evidence that the recovered file's bytes match the saved original baseline. This checks content integrity; milestone 38 records the subsequent standard-user access test.

| Recovery check | Expected | Actual |
|---|---|---|
| Test file absent after controlled deletion | Test-Path False | Procedure completion reported; exact Boolean not separately supplied |
| Recovery operation | Successful completion | Completed by user report |
| Recovered text | Original sentence | Confirmed by user report through the CLIENT01 access check in milestone 38 |
| Restored SHA-256 vs. original baseline | True | Explicitly confirmed by user report |

**Actual result:** The user reported completing the deletion/recovery procedure and subsequently explicitly confirmed that the final FS01 hash comparison returned True. The recovered original text was also confirmed through the standard-user check in milestone 38. Content recovery and the matching hash are recorded by user report; the deletion Boolean and recovery-job output were not separately supplied as screenshots.

### 38. Verify restored-file access from CLIENT01

**Where:** Inside CLIENT01. Keep DC01 and FS01 running. Sign in as the standard domain account CORP\alex.taylor.

**Purpose:** Check that an authorized IT user can read the recovered file through the SMB share, and confirm the final hash result from FS01. Opening the file as an administrator alone does not establish the standard user's effective access.

Open a normal Command Prompt and run:

~~~cmd
whoami
~~~

| Command | Meaning and reason | Effect |
|---|---|---|
| whoami | Shows the current sign-in identity; expected corp\alex.taylor ties the share check to the standard IT test user | Read-only identity query |

Use Windows+R to open these UNC paths:

| Path | Expected result and purpose |
|---|---|
| \\FS01\IT\Recovery-Test.txt | Opens and shows SysAdminLab recovery test - original file content.; demonstrates standard-user read access to the recovered file |
| \\FS01\HR | Access denied; checks that the IT user's department restriction still applies |

Close the recovered text file after reading it. Confirm whether the final hash comparison already run on FS01 returned True. These checks read the recovered file and its access behavior; they do not change its content.

**Actual result:** The user explicitly confirmed all three requested outcomes: the recovered file opens for Alex with its original text, HR access is denied, and the earlier FS01 hash comparison returned True. These are passed by user report. The whoami query was included in the procedure; its exact output was not separately supplied. The completed checks demonstrate restored-file read access for the IT user, continued department separation, and a content hash matching the original baseline.

### 39. Save the post-recovery lab checkpoint

**Where:** Shut down each guest through its own Windows Start menu, then use VirtualBox Manager on the host laptop.

**Purpose:** Preserve the working domain, DHCP, file shares, account automation state, and verified recovery result before further changes. A VirtualBox snapshot captures that VM's virtual disk state and settings at the checkpoint.

1. Shut down CLIENT01, then FS01, then DC01 through Windows.
2. Wait until all three VMs show Powered Off in VirtualBox Manager.
3. For each VM, open Snapshots and select Take. Use the names below.

| VM | New snapshot name |
|---|---|
| DC01 | DC01-Backup-Recovery |
| FS01 | FS01-Backup-Recovery |
| CLIENT01 | CLIENT01-Backup-Recovery |

4. Confirm all three named snapshots are listed. Leave the VMs powered off while the project guide is consolidated.

**Effect:** Writes new VirtualBox snapshot metadata and disk checkpoint state. No snapshot restoration is requested in this step. The separate file backup already created on B: remains part of the recovery exercise.

**Expected result:** Each VM lists its named post-recovery snapshot, with the three guests powered off.

**Actual result:** The user confirmed that all three named post-recovery snapshots were saved after the shutdown procedure. Snapshot creation and the powered-off checkpoint are recorded by user report; final snapshot-list screenshots were not supplied. The earlier file-sharing snapshots remain historically unconfirmed. No restoration of the complete three-VM snapshot set was tested.

## Operating the lab

| Task | Procedure and reason |
|---|---|
| Start the lab | Start DC01 first and allow domain services to become ready; then start FS01 and CLIENT01 |
| Shut down the lab | Use Windows shutdown on CLIENT01, then FS01, then DC01 |
| Review commands | Use the milestone for the intended VM; the command tables distinguish read-only checks from changes |
| Use standard accounts | Use a department user for share-access checks so administrator rights do not obscure the intended permissions |
| Use scripts | NewUsers.csv, New-LabUsers.ps1, and Disable-LabUser.ps1 belong in DC01's C:\LabScripts; their full source and use are in milestones 26-30 |
| Review file recovery | The known recovery point and the SHA-256 comparison procedure are in milestones 36-38 |
| Review saved state | The three post-recovery snapshots are recorded in milestone 39; the guests were shut down for that checkpoint |

## Troubleshooting and useful lessons

| Situation | Explanation and resolution used |
|---|---|
| Ctrl+Alt+Delete affected the host | Send it through the VM's Input > Keyboard menu, or use the VirtualBox host-key shortcut described during setup |
| Copy and paste did not work in a VM | Install Guest Additions inside the guest, restart it, and enable the relevant Shared Clipboard direction; the completed setup step was user-reported, while functionality in every guest was not independently demonstrated |
| Windows installation ISO occupied the virtual CD drive | Eject that ISO before mounting the Guest Additions CD image |
| DNS delegation warning during promotion | The new private test domain has no authoritative parent DNS zone to update; the wizard's prerequisites passed and domain creation succeeded |
| Promotion restarted automatically | The subsequent CORP administrator sign-in and AD checks established that promotion completed |
| A department user received Access denied | Denial for the other department is the intended result; use the correct standard account and refresh sign-in after group membership changes |
| Role installation reported no restart needed | A successful install with RestartNeeded No does not require an extra restart for that role-install step |
| Newly added backup disk showed RAW | It needed initialization and a partition/filesystem before use; the identified Disk 1 became B: LabBackup through milestone 34 |
| Backup asked for confirmation | The selected source and target were reviewed, then Y started the one-time backup |
| Secure-channel checks | Test-ComputerSecureChannel was used on domain members; DC01's health was checked with domain-controller and DNS checks instead |

The guide records useful resolutions and final configurations rather than every routine click, delay, or typing correction.

## Resume project description

**Windows Server and Active Directory Home Lab | Personal Project**

- Built a three-VM lab with Active Directory Domain Services, DNS, Windows DHCP, domain joining, and Group Policy.
- Secured IT and HR SMB shares with NTFS permissions and department security groups; automated two domain users from CSV with PowerShell and tested account disablement/restoration.
- Backed up department files, restored a deleted test file, confirmed its SHA-256 hash matched the original, and verified access through a standard domain account.

Present this as a home lab project. The recorded tests support these statements; no production employment, certification, cloud deployment, or measured recovery-time claim is implied.

## Scope and follow-up work

The core lab is complete through the reported three-VM post-recovery checkpoint. The build and command record, configuration tables, topology, results, and glossary have been consolidated into this guide.

| Follow-up or limit | Current status |
|---|---|
| Supported client migration | Windows 11 Pro migration remains planned. The current guest is Windows 10 Pro; no upgrade or Extended Security Updates enrollment was verified |
| Backup coverage | A one-time file backup and single-file recovery were exercised; full-server, system-state, scheduled, and off-host backup/recovery were not implemented |
| Physical failure protection | Both virtual disks are on the same laptop; the added backup VDI does not protect against loss of that physical storage |
| Maya's functional tests | AD properties and group membership were checked; first sign-in and resource access were not tested |
| Historical file-sharing snapshots | Creation of the three earlier FileShares snapshots remains unconfirmed; the later Backup-Recovery snapshots were confirmed by user report |
| Complete VM-set restoration | Snapshot creation was reported; a coordinated restoration of all three VMs was not tested |
| Timing and scale | No measured recovery duration, bulk-user scale beyond the two CSV accounts, or production load test was recorded |
| Additional projects | Linux administration, monitoring, cloud infrastructure, and certification study are separate next projects |

## Abbreviations and key terms

| Term | Full form or meaning | Use in this project |
|---|---|---|
| VM | Virtual Machine | Software-created computer such as DC01 |
| WSB | Windows Server Backup | Feature installed on FS01 for the backup and recovery exercise; installation confirmed by user report |
| OS | Operating System | Windows Server manages the guest computer |
| ISO | Optical disk image format, associated with ISO 9660 | Installation media stored as a file |
| CPU | Central Processing Unit | Processes instructions |
| vCPU | Virtual Central Processing Unit | Processing capacity presented to the VM |
| RAM | Random Access Memory | Temporary working memory |
| MB / GB | Megabyte / Gigabyte | Units used for memory and storage settings |
| VDI | VirtualBox Disk Image | The VM's virtual hard-disk file |
| SATA | Serial Advanced Technology Attachment (Serial ATA) | Virtual storage-controller interface used to attach FS01's additional backup disk |
| GUI | Graphical User Interface | Visual management windows and controls |
| EFI | Extensible Firmware Interface | Firmware interface used during startup |
| NAT | Network Address Translation | Translates addresses for traffic between networks |
| NAT Network | A shared VirtualBox network mode | Connects lab VMs and provides an outbound NAT route |
| NIC | Network Interface Card | The VM's virtual network adapter |
| IP | Internet Protocol | Network addressing and routing |
| IPv4 / IPv6 | Internet Protocol version 4 / version 6 | Addressing protocols; this lab is configured using IPv4 |
| CIDR | Classless Inter-Domain Routing | Prefix notation such as /24 |
| DHCP | Dynamic Host Configuration Protocol | Automatic address and network-setting assignment |
| DHCP scope | Address pool and subnet configuration on a DHCP server | Client pool: 10.10.10.100 through 10.10.10.199 |
| Lease | Temporary assignment of an IP address to a client | CLIENT01's screenshot shows 10.10.10.100 leased from DC01 |
| DHCP options | Additional network settings delivered with a lease | Router, DNS server, and DNS domain in this lab |
| Scope ID | Identifier of a DHCP scope, expressed as its subnet address | 10.10.10.0 identifies the lab scope |
| DNS | Domain Name System | Name and service-location resolution |
| A record | DNS address record | Maps a name such as DC01.corp.sampath.test to an IPv4 address |
| SRV | Service record | Publishes a service's hostname and port so clients can find it |
| LDAP | Lightweight Directory Access Protocol | The service-discovery record in this lab identifies DC01 on port 389 |
| DFSR | Distributed File System Replication | Service used for SYSVOL replication between domain controllers |
| NETLOGON | Domain-controller share name | Publishes the domain's sign-in scripts folder |
| Loopback | Address referring to the same computer | 127.0.0.1 lets DC01 use its own DNS service |
| AD | Active Directory | Microsoft's directory technologies; here, the domain directory context |
| DS in AD DS | Domain Services | The last two words of the Windows role name |
| AD DS | Active Directory Domain Services | Central domain directory and identity services |
| DC | Domain Controller | Server configured to provide AD DS for a domain |
| TCP | Transmission Control Protocol | Transport protocol named in the TCP/IPv4 settings |
| ICMP | Internet Control Message Protocol | Used by ping for echo requests and replies |
| LAN | Local Area Network | A locally grouped network of devices |
| RSAT | Remote Server Administration Tools | Tools used to manage Windows Server roles |
| PowerShell | Windows command shell and scripting environment | Administrative commands and later automation |
| Cmdlet | A PowerShell command | For example, Get-WindowsFeature |
| Parameter | An option or argument controlling a command | -Port 389 chooses the destination TCP port for Test-NetConnection |
| Pipeline | Passing one command's output objects to another command | Sends the domain password-policy object to Select-Object |
| Native Windows utility | Windows program that can run in a command shell | hostname, net share, and gpupdate are examples |
| Command Prompt / CMD | Windows command shell | Used for the sign-in verification and computer-policy refresh |
| Port | Number identifying a service endpoint | TCP 389 is used for the LDAP connection test |
| Host / Guest | Physical virtualization computer / OS inside a VM | Laptop / Windows Server in DC01 |
| Hypervisor | Software that creates and runs VMs | Oracle VirtualBox |
| Static IP | Manually configured IP address | Keeps DC01 at a consistent address |
| Gateway | Router used for other networks | 10.10.10.1 in this lab |
| Snapshot | VM rollback checkpoint | DC01-Clean-Updated preserves the baseline |
| Promotion | Configuring a server as a domain controller | Completed for DC01 |
| Domain | Managed identity and policy environment | corp.sampath.test contains the lab's directory objects |
| Forest | Top-level Active Directory structure | Created with corp.sampath.test as its first domain |
| FQDN | Fully Qualified Domain Name | Complete DNS name of a computer or domain |
| NetBIOS | Network Basic Input/Output System | CORP is the short domain name used in CORP\Administrator |
| GC | Global Catalog | Directory search service selected for the first domain controller |
| RODC | Read-only Domain Controller | Not selected; DC01 is a writable domain controller |
| Functional level | AD capability level based on supported domain-controller versions | Windows Server 2025 selected for this new forest and domain |
| DSRM | Directory Services Restore Mode | Domain-controller recovery mode; password set and kept privately |
| SYSVOL | System Volume | Shared Group Policy files and scripts on a domain controller |
| NTDS | NT Directory Services | Name used for the AD DS database folder and directory service |
| OU | Organizational Unit | Organizes domain objects |
| DN | Distinguished Name | Full AD object path used to verify the account's location |
| CN in a DN | Common Name | Identifies an object such as CN=Alex Taylor or CN=GG_IT_Users |
| DC in a DN | Domain Component | DC=corp,DC=sampath,DC=test represents the domain's name components |
| ADUC | Active Directory Users and Computers | Console used to organize LabUsers, LabComputers, and their accounts |
| UPN | User Principal Name | Full sign-in name such as sampath@corp.sampath.test |
| Local account | User account stored on one computer | LabAdmin belongs to CLIENT01 |
| Domain account | User account managed by AD DS | CORP\sampath can authenticate through the domain |
| Computer account | Directory identity for a domain member | Created for CLIENT01 when it joins the domain |
| Domain join | Registering a computer as a domain member | Connects CLIENT01 to corp.sampath.test |
| LOGONSERVER | Windows environment variable identifying the session's logon server | Expected value \\DC01 in the client session |
| GPO | Group Policy Object | LabComputers-LogonMessage applies the workstation sign-in message |
| GPMC | Group Policy Management Console | Creates and links the domain GPO; its editor configures the settings |
| Policy link | Association between a GPO and a scope such as an OU | Links LabComputers-LogonMessage to LabComputers |
| Computer Configuration | GPO settings processed for the computer | Holds the sign-in-message settings |
| gpupdate | Windows Group Policy refresh command | Reapplies computer settings on CLIENT01 |
| Elevation | Running a process with administrator privileges | Used for the client computer-policy refresh |
| GG | Global Group; the lab's group-name prefix | GG_IT_Users and GG_HR_Users organize department membership |
| IT | Information Technology | Department represented by GG_IT_Users |
| HR | Human Resources | Department represented by GG_HR_Users |
| Security group | Collection of accounts that can be assigned resource permissions | Used for the coming department-folder access exercise |
| Global group | Group scope whose account members come from the same domain | Selected for the department membership groups |
| FS | File Server; the role indicated by the name FS01 | Domain member being prepared to host department folders |
| SMB | Server Message Block | Protocol used to access file shares from CLIENT01 |
| Secure channel | Trust communication between a member computer and its domain | Test-ComputerSecureChannel returned True on FS01 per user report |
| ACL | Access Control List | Defines access permissions |
| UNC | Universal Naming Convention | Network path syntax such as \\FS01\IT, identifying a server and share |
| DACL | Discretionary Access Control List | The part of a security descriptor that lists which identities are allowed or denied access; managed here with icacls |
| ACE | Access Control Entry | One permission entry in an access control list |
| NTFS | New Technology File System | Windows filesystem used for department permissions and FS01's B: backup volume |
| GPT | GUID Partition Table | Partition-table layout used in Disk 1's preparation procedure, completed by user report |
| GUID | Globally Unique Identifier | The identifier type named in GUID Partition Table |
| RAW partition style | Disk state with no initialized partition table | User-reported initial state of FS01's new Disk 1; RAW is not a chosen filesystem here |
| VSS | Volume Shadow Copy Service | Windows service used by the copy-backup procedure |
| Backup catalog | Record of available backup versions and recovery information | Queried to find FS01's exact recovery version on B: |
| SHA-256 | Secure Hash Algorithm with a 256-bit result | Selected for the original and recovered test-file content comparison |
| Hash | Content fingerprint calculated from file bytes | Saved before backup for a later recovery comparison |
| UTF-8 | 8-bit Unicode Transformation Format | Text encoding selected for the recovery test file |
| ASCII | American Standard Code for Information Interchange | Plain-text encoding selected for the saved hexadecimal hash |
| CSV | Comma-Separated Values | Input file for planned Alex Taylor and Maya Patel account provisioning |
| Offboarding | Process of removing access when a person leaves | This lab simulates the AD account-disable part using Alex, then restores the test account |

## Official references

- [Windows Server 2025 Evaluation](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2025)
- [VirtualBox: Creating a new VM](https://docs.oracle.com/en/virtualization/virtualbox/7.2/user/create-vm.html)
- [VirtualBox: Working with VMs and snapshots](https://docs.oracle.com/en/virtualization/virtualbox/7.2/user/working-with-vms.html)
- [VirtualBox: Virtual networking](https://docs.oracle.com/en/virtualization/virtualbox/7.2/user/networkingdetails.html)
- [Microsoft: DNS client configuration](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/best-practices-for-dns-client-settings)
- [Microsoft: Install AD DS](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/deploy/install-active-directory-domain-services--level-100-)
- [Microsoft: AD DS configuration wizard pages](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/deploy/ad-ds-installation-and-removal-wizard-page-descriptions)
- [IANA: Special-use domain names](https://www.iana.org/assignments/special-use-domain-names)
- [Microsoft: Get-WindowsFeature](https://learn.microsoft.com/en-us/powershell/module/servermanager/get-windowsfeature)
- [Microsoft: Join a computer to a domain](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/join-computer-to-domain)
- [Microsoft: Manage Active Directory user accounts](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage-user-accounts-in-windows-server)
- [Microsoft: Password complexity requirements](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/security-policy-settings/password-must-meet-complexity-requirements)
- [Microsoft: Get-ADDefaultDomainPasswordPolicy](https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-addefaultdomainpasswordpolicy?view=windowsserver2025-ps)
- [Microsoft: Windows 10 Home and Pro lifecycle](https://learn.microsoft.com/en-us/lifecycle/products/windows-10-home-and-pro)
- [Microsoft: Default containers and organizational units](https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/redirect-users-computers-containers)
- [Microsoft: Working with GPOs in GPMC](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/dn789193(v=ws.11))
- [Microsoft: Interactive logon message settings and Group Policy mapping](https://learn.microsoft.com/windows/client-management/mdm/policy-csp-localpoliciessecurityoptions)
- [Microsoft: gpupdate](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/gpupdate)
- [Microsoft: Active Directory security groups](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/understand-security-groups)
- [Microsoft: hostname](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/hostname)
- [Microsoft: Test-NetConnection](https://learn.microsoft.com/en-us/powershell/module/nettcpip/test-netconnection?view=windowsserver2025-ps)
- [Microsoft: Resolve-DnsName](https://learn.microsoft.com/en-us/powershell/module/dnsclient/resolve-dnsname?view=windowsserver2025-ps)
- [Microsoft: Get-DnsClientServerAddress](https://learn.microsoft.com/en-us/powershell/module/dnsclient/get-dnsclientserveraddress?view=windowsserver2025-ps)
- [Microsoft: Get-Service](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-service?view=powershell-5.1)
- [Microsoft: Select-Object](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/select-object?view=powershell-5.1)
- [Microsoft: AD services and network ports](https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/config-firewall-for-ad-domains-and-trusts)
- [Microsoft: Add-Computer](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/add-computer?view=powershell-5.1)
- [Microsoft: Test-ComputerSecureChannel](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/test-computersecurechannel?view=powershell-5.1)
- [Oracle: VirtualBox Guest Additions](https://docs.oracle.com/en/virtualization/virtualbox/7.2/user/guestadditions.html)
- [Microsoft: SMB file-sharing overview](https://learn.microsoft.com/en-us/windows-server/storage/file-server/file-server-smb-overview)
- [Microsoft: Install-WindowsFeature](https://learn.microsoft.com/en-us/powershell/module/servermanager/install-windowsfeature?view=windowsserver2025-ps)
- [Microsoft: New-Item](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/new-item?view=powershell-5.1)
- [Microsoft: icacls](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/icacls)
- [Microsoft: New-SmbShare](https://learn.microsoft.com/en-us/powershell/module/smbshare/new-smbshare?view=windowsserver2025-ps)
- [Microsoft: Get-SmbShareAccess](https://learn.microsoft.com/en-us/powershell/module/smbshare/get-smbshareaccess?view=windowsserver2025-ps)
- [Microsoft: Install and configure DHCP Server](https://learn.microsoft.com/en-us/windows-server/networking/technologies/dhcp/quickstart-install-configure-dhcp-server)
- [Microsoft: Add-DhcpServerInDC](https://learn.microsoft.com/en-us/powershell/module/dhcpserver/add-dhcpserverindc?view=windowsserver2025-ps)
- [Microsoft: Get-DhcpServerInDC](https://learn.microsoft.com/en-us/powershell/module/dhcpserver/get-dhcpserverindc?view=windowsserver2025-ps)
- [Microsoft: Add-DhcpServerv4Scope](https://learn.microsoft.com/en-us/powershell/module/dhcpserver/add-dhcpserverv4scope?view=windowsserver2025-ps)
- [Microsoft: Set-DhcpServerv4OptionValue](https://learn.microsoft.com/en-us/powershell/module/dhcpserver/set-dhcpserverv4optionvalue?view=windowsserver2025-ps)
- [Microsoft: Get-DhcpServerv4Scope](https://learn.microsoft.com/en-us/powershell/module/dhcpserver/get-dhcpserverv4scope?view=windowsserver2025-ps)
- [Microsoft: Get-DhcpServerv4OptionValue](https://learn.microsoft.com/en-us/powershell/module/dhcpserver/get-dhcpserverv4optionvalue?view=windowsserver2025-ps)
- [Microsoft: ipconfig](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/ipconfig)
- [Microsoft: Get-DhcpServerv4Lease](https://learn.microsoft.com/en-us/powershell/module/dhcpserver/get-dhcpserverv4lease?view=windowsserver2025-ps)
- [Microsoft: Import-Csv](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/import-csv?view=powershell-5.1)
- [Microsoft: Import-Module](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/import-module?view=powershell-5.1)
- [Microsoft: Get-ADOrganizationalUnit](https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-adorganizationalunit?view=windowsserver2025-ps)
- [Microsoft: Get-ADGroup](https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-adgroup?view=windowsserver2025-ps)
- [Microsoft: Get-ADUser](https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-aduser?view=windowsserver2025-ps)
- [Microsoft: New-ADUser](https://learn.microsoft.com/en-us/powershell/module/activedirectory/new-aduser?view=windowsserver2025-ps)
- [Microsoft: Add-ADGroupMember](https://learn.microsoft.com/en-us/powershell/module/activedirectory/add-adgroupmember?view=windowsserver2025-ps)
- [Microsoft: Read-Host](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/read-host?view=powershell-5.1)
- [Microsoft: Disable-ADAccount](https://learn.microsoft.com/en-us/powershell/module/activedirectory/disable-adaccount?view=windowsserver2025-ps)
- [Microsoft: Enable-ADAccount](https://learn.microsoft.com/en-us/powershell/module/activedirectory/enable-adaccount?view=windowsserver2025-ps)
- [Microsoft: Get-Disk](https://learn.microsoft.com/en-us/powershell/module/storage/get-disk?view=windowsserver2025-ps)
- [Microsoft: Initialize-Disk](https://learn.microsoft.com/en-us/powershell/module/storage/initialize-disk?view=windowsserver2025-ps)
- [Microsoft: New-Partition](https://learn.microsoft.com/en-us/powershell/module/storage/new-partition?view=windowsserver2025-ps)
- [Microsoft: Format-Volume](https://learn.microsoft.com/en-us/powershell/module/storage/format-volume?view=windowsserver2025-ps)
- [Microsoft: Get-Volume](https://learn.microsoft.com/en-us/powershell/module/storage/get-volume?view=windowsserver2025-ps)
- [Microsoft: Set-Content](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/set-content?view=powershell-5.1)
- [Microsoft: Get-Content](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-content?view=powershell-5.1)
- [Microsoft: Get-FileHash](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-filehash?view=powershell-5.1)
- [Microsoft: wbadmin start backup](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/wbadmin-start-backup)
- [Microsoft: wbadmin get versions](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/wbadmin-get-versions)
- [Microsoft: wbadmin start recovery](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/wbadmin-start-recovery)
- [Microsoft: Remove-Item](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/remove-item?view=powershell-5.1)
- [Microsoft: Test-Path](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/test-path?view=powershell-5.1)
