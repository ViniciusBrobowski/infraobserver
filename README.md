# Automated VM Monitoring & Audit Tool

##  About the Project

This project is a lightweight automated monitoring and auditing solution for Linux virtual machines.

It was developed to demonstrate practical DevOps principles applied to infrastructure environments, focusing on automation, observability, security, and operational reliability.

The tool simulates a real-world scenario where infrastructure teams need periodic visibility into system health and SSH access activity without relying on heavy monitoring stacks.

---

##  Problem It Solves

Small and mid-sized environments often lack:

- Periodic system health visibility
- Structured SSH access auditing
- Consolidated operational evidence
- Automated report delivery
- Secure log handling

This project addresses those gaps by providing:

- Automated metric collection
- SSH access summarization
- Secure artifact generation
- Scheduled execution
- Email-based delivery of operational reports

---

## Core Features

- Memory usage collection (MB + percentage)
- Disk usage analysis (ext4/xfs partitions)
- Uptime and load information
- SSH log auditing (successful & failed attempts)
- Detection of invalid login attempts
- Automatic execution window (07:00 and 20:00 UTC)
- Manual execution mode (custom hour range)
- Structured report generation
- Log packaging (.tar.gz)
- GPG encryption of artifacts
- Automated email delivery via msmtp
- Configuration via `.env`
- Cron-based scheduling

---

##  DevOps Principles Applied

###  Automation
Scheduled execution using cron with intelligent time-window handling.

###  Observability
System metric consolidation and SSH activity summarization.

###  Security by Design
- Encrypted artifacts using GPG
- Secrets externalized via `.env`
- Controlled SMTP authentication
- Log segregation

### Infrastructure Troubleshooting
Resolution of real-world issues involving:

- Cron environment isolation
- PATH configuration
- File permissions
- SMTP configuration per user
- Service-level debugging

###  Version Control & Structure
Project organized with semantic versioning and Git-based lifecycle management.

---

##  Usage

### Automatic Mode
Runs only within predefined time windows (07:00 and 20:00 UTC):

```bash
./export-logs.sh
