# Automated Installation and Configuration of Wazuh, Graylog, Shuffle, and DFIR-IRs

Welcome to the repository for automated installation and configuration of Wazuh, Graylog, Shuffle, and DFIR-IRs. This project simplifies and accelerates the deployment of a complete security stack for monitoring, incident response, and automation.

## Table of Contents

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Features](#features)
- [Installation](#installation)
  - [Step 1: Clone the Repository](#step-1-clone-the-repository)
  - [Step 2: Configure Environment Variables](#step-2-configure-environment-variables)
  - [Step 3: Run the Installer](#step-3-run-the-installer)
- [Components Overview](#components-overview)
  - [Wazuh](#wazuh)
  - [Graylog](#graylog)
  - [Shuffle](#shuffle)
  - [DFIR-IRs](#dfir-irs)
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Introduction

This project is designed to automate the deployment of:

1. **Wazuh**: A powerful open-source security platform for threat detection and response.
2. **Graylog**: A centralized log management tool for log collection, analysis, and monitoring.
3. **Shuffle**: An automation platform for security workflows and playbooks.
4. **DFIR-IRIS**: A set of tools for digital forensics and incident response.

By using this repository, you can deploy these tools quickly and focus on securing your infrastructure rather than spending time on manual setup.

## Prerequisites

Before starting, ensure you have the following:

- A server or virtual machine with at least 8 GB of RAM and 4 vCPUs.
- Ubuntu 20.04 or a compatible Linux distribution installed.
- `git`, `curl`, and `docker` installed.
- Root or sudo privileges on the server.

## Features

- Automated installation scripts.
- Pre-configured settings for optimal performance.
- Dockerized deployment for ease of management.
- Seamless integration between components.

## Installation

### Step 1: Clone the Repository

```bash
git clone https://github.com/yourusername/automated-wazuh-setup.git
cd automated-wazuh-setup
```

### Step 2: Configure Environment Variables

Edit the `.env` file to configure settings specific to your environment:

```bash
cp .env.example .env
nano .env
```

Set values such as admin credentials, network settings, and storage paths.

### Step 3: Run the Installer

Run the installation script to deploy all components:

```bash
python3 deploy.py
```

The script will:

- Install Docker and Docker Compose (if not already installed).
- Pull and configure necessary Docker images.
- Start all services.

## Components Overview

### Wazuh
Wazuh provides real-time monitoring, log analysis, and threat detection. After installation, access the Wazuh web interface at `http://<your-server-ip>:5601`. 
To display the Wazuh admin password, use the following command:

 ```bash
  grep "admin" /var/ossec/etc/wazuh_passwords.log
  ```

### Graylog
Graylog enables centralized log management and analysis. Access Graylog's web interface at `http://<your-server-ip>:9000`.
Default user: Admin and the password is define in the .env file

### Shuffle
Shuffle automates workflows and playbooks for security operations. Access Shuffle at `http://<your-server-ip>:3000`.

### DFIR-IRIS
DFIR-IRs includes tools for digital forensics and incident response. These tools are available via CLI and integrate with the other components.

**Administrator Credentials**:
- **Username**: `administrator`
- **Password**: Retrieve the password by running the following command:

  ```bash
  docker logs iriswebapp_app 2>&1 | grep "WARNING :: post_init :: create_safe_admin"
  ```

## Usage

1. Access the web interfaces for Wazuh, Graylog, and Shuffle using the provided URLs.
2. Use the default credentials specified in the `.env` file.
3. Begin configuring your monitoring, logging, and automation workflows.

## Troubleshooting

- **Services not starting**: Check Docker logs using `docker logs <container-name>`.
- **Connection issues**: Ensure firewall rules allow access to required ports.
- **Missing dependencies**: Re-run the installation script to resolve any dependency issues.

## Contributing

We welcome contributions to enhance this project. To contribute:

1. Fork the repository.
2. Create a new branch for your feature or bug fix.
3. Submit a pull request with a detailed description of your changes.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

Feel free to submit issues or suggestions to improve this repository. Happy automating!

