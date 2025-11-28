# Debug Container Tools Reference

Comprehensive list of tools available in `nicolaka/netshoot` debug container for Kubernetes debugging.

## Network Connectivity Tools

- [ ] `ping` - ICMP echo requests for basic connectivity testing
- [ ] `traceroute` - Trace network path to destination
- [ ] `mtr` - Enhanced traceroute with real-time statistics
- [ ] `nmap` - Network mapper for port scanning and discovery
- [ ] `netcat` (`nc`) - TCP/UDP connection testing and data transfer
- [ ] `telnet` - Plain text protocol testing
- [ ] `socat` - Advanced socket relay tool

## DNS Tools

- [ ] `nslookup` - Query DNS servers for name resolution
- [ ] `dig` - DNS lookup utility with detailed output
- [ ] `host` - Simple DNS lookup utility
- [ ] `dnsperf` - DNS performance testing

## HTTP/API Testing

- [ ] `curl` - Transfer data with URLs (HTTP, HTTPS, FTP, etc.)
- [ ] `wget` - Network downloader
- [ ] `httpie` - User-friendly HTTP client
- [ ] `ab` (Apache Bench) - HTTP load testing tool

## Packet Capture & Analysis

- [ ] `tcpdump` - Packet analyzer and capture tool
- [ ] `tshark` - Terminal-based Wireshark
- [ ] `tcpflow` - TCP flow recorder
- [ ] `ngrep` - Network grep for packet analysis

## Network Monitoring

- [ ] `iftop` - Real-time bandwidth monitoring per connection
- [ ] `nethogs` - Per-process network bandwidth usage
- [ ] `iptraf-ng` - Interactive network traffic monitor
- [ ] `bmon` - Bandwidth monitor with graphs
- [ ] `vnstat` - Network traffic statistics

## Network Performance

- [ ] `iperf` - Network throughput testing
- [ ] `iperf3` - Updated network performance tool
- [ ] `speedtest-cli` - Command-line speed test
- [ ] `ethtool` - Network interface configuration

## TLS/SSL & Security

- [ ] `openssl` - SSL/TLS toolkit for certificates and encryption
- [ ] `cfssl` - CloudFlare SSL toolkit
- [ ] `certstrap` - Certificate management
- [ ] `sslyze` - SSL/TLS scanner

## System Monitoring

- [ ] `htop` - Interactive process viewer
- [ ] `top` - System resource monitor
- [ ] `ps` - Process status
- [ ] `vmstat` - Virtual memory statistics
- [ ] `iostat` - CPU and I/O statistics
- [ ] `mpstat` - Multiprocessor statistics
- [ ] `pidstat` - Per-process statistics

## Process & System Tracing

- [ ] `strace` - System call tracer
- [ ] `ltrace` - Library call tracer
- [ ] `lsof` - List open files and network connections
- [ ] `fuser` - Identify processes using files/sockets

## Network Configuration

- [ ] `ip` - Modern network configuration tool
- [ ] `ifconfig` - Legacy network interface configuration
- [ ] `route` - Routing table management
- [ ] `ss` - Socket statistics (modern netstat)
- [ ] `netstat` - Network statistics (legacy)
- [ ] `arp` - ARP cache management
- [ ] `arping` - Send ARP requests
- [ ] `bridge` - Ethernet bridge administration

## Container & Kubernetes

- [ ] `kubectl` - Kubernetes command-line tool
- [ ] `helm` - Kubernetes package manager
- [ ] `crictl` - Container runtime interface CLI
- [ ] `calicoctl` - Calico networking CLI (if using Calico)
- [ ] `docker` - Docker client (if socket available)

## Text Processing

- [ ] `jq` - JSON processor
- [ ] `yq` - YAML processor
- [ ] `awk` - Pattern scanning and processing
- [ ] `sed` - Stream editor
- [ ] `grep` - Pattern matching
- [ ] `cut` - Text column extraction
- [ ] `sort` - Sort lines
- [ ] `uniq` - Filter duplicate lines

## File System Tools

- [ ] `ls` - List directory contents
- [ ] `cat` - Concatenate and display files
- [ ] `less` / `more` - Page through text
- [ ] `tail` - Display end of file
- [ ] `head` - Display beginning of file
- [ ] `find` - Search for files
- [ ] `tree` - Directory tree visualization
- [ ] `du` - Disk usage
- [ ] `df` - Disk space usage

## Text Editors

- [ ] `vim` - Vi improved text editor
- [ ] `nano` - Simple text editor
- [ ] `vi` - Classic text editor

## Scripting & Programming

- [ ] `bash` - Bourne Again Shell
- [ ] `sh` - POSIX shell
- [ ] `python3` - Python interpreter
- [ ] `perl` - Perl interpreter

## Compression & Archives

- [ ] `tar` - Archive files
- [ ] `gzip` / `gunzip` - Compress files
- [ ] `bzip2` / `bunzip2` - Compress files
- [ ] `zip` / `unzip` - Zip compression

## Download & Transfer

- [ ] `rsync` - Remote file synchronization
- [ ] `scp` - Secure copy
- [ ] `sftp` - Secure FTP

## Miscellaneous Utilities

- [ ] `which` - Locate command
- [ ] `whereis` - Locate binary, source, manual
- [ ] `man` - Manual pages
- [ ] `env` - Environment variables
- [ ] `echo` - Display text
- [ ] `printf` - Formatted output
- [ ] `date` - Date and time
- [ ] `bc` - Calculator
- [ ] `screen` - Terminal multiplexer
- [ ] `tmux` - Terminal multiplexer

---

## Learning Path Suggestions

### Beginner Priority (Essential Tools)
1. `ping`, `curl`, `nslookup`
2. `kubectl`, `ls`, `cat`, `grep`
3. `netstat`/`ss`, `ps`, `top`

### Intermediate Priority (Deep Debugging)
4. `dig`, `tcpdump`, `lsof`
5. `strace`, `htop`, `jq`
6. `nc`, `telnet`, `iperf3`

### Advanced Priority (Performance & Security)
7. `tshark`, `mtr`, `openssl`
8. `iftop`, `nethogs`, `nmap`
9. `crictl`, `helm`, `calicoctl`

## Study Resources

- Official man pages: `man <tool-name>` inside debug container
- TL;DR pages: Quick examples for each tool
- Online resources: Each tool typically has extensive documentation
