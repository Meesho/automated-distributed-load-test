# Ansible Configuration

<details>
<summary>Relevant source files</summary>

The following files were used as context for generating this wiki page:

- [ansible-jmeter-slaves/ansible.cfg](ansible-jmeter-slaves/ansible.cfg)
- [ansible-jmeter-slaves/group_vars/all](ansible-jmeter-slaves/group_vars/all)

</details>



## Purpose and Scope

This page documents the Ansible configuration files used to manage JMeter slave instances in the distributed load testing system. The configuration includes the main Ansible settings and global variables that control how Ansible connects to and manages the slave instances.

For information about the Ansible inventory management, see [Inventory Management](#5.2). For details about the actual JMeter slave provisioning playbook, see [JMeter Slave Provisioning](#5.3).

## Configuration Overview

The Ansible configuration for this system consists of two primary configuration files located in the `ansible-jmeter-slaves/` directory:

| File | Purpose |
|------|---------|
| `ansible.cfg` | Main Ansible configuration settings |
| `group_vars/all` | Global variables applied to all managed hosts |

These configurations are designed to work with Ubuntu-based EC2 instances and handle the specific requirements of managing ephemeral JMeter slave instances in AWS.

## Main Ansible Configuration

The primary Ansible configuration is defined in [ansible-jmeter-slaves/ansible.cfg:1-3](). This file contains essential settings that control Ansible's behavior when managing the JMeter slaves.

### Inventory Configuration

The configuration specifies the inventory file location:
- `inventory = hosts` - Points to the dynamically generated hosts file that contains slave instance IP addresses

### SSH Connection Settings

The configuration includes security and connection settings:
- `host_key_checking = False` - Disables SSH host key verification, necessary for connecting to dynamically provisioned EC2 instances

This setting is crucial because the slave instances are ephemeral and their SSH host keys are not known in advance.

**Sources:** [ansible-jmeter-slaves/ansible.cfg:1-3]()

## Global Variables Configuration

The global variables are defined in [ansible-jmeter-slaves/group_vars/all:1-2]() and apply to all managed hosts in the inventory.

### Python Interpreter Configuration

The configuration specifies the Python interpreter to use on target hosts:
- `ansible_python_interpreter: /usr/bin/python3` - Ensures Ansible uses Python 3 on the slave instances

### User Configuration

The configuration defines the SSH user for connections:
- `ansible_user: ubuntu` - Specifies the default user for connecting to Ubuntu-based EC2 instances

**Sources:** [ansible-jmeter-slaves/group_vars/all:1-2]()

## Ansible Configuration Architecture

```mermaid
graph TB
    subgraph "Ansible Configuration Files"
        ANSIBLE_CFG["ansible.cfg<br/>Main Configuration"]
        GROUP_VARS["group_vars/all<br/>Global Variables"]
    end
    
    subgraph "Configuration Settings"
        INVENTORY_SETTING["inventory = hosts"]
        HOST_KEY_CHECK["host_key_checking = False"]
        PYTHON_INTERP["ansible_python_interpreter: /usr/bin/python3"]
        ANSIBLE_USER["ansible_user: ubuntu"]
    end
    
    subgraph "Target Resources"
        HOSTS_FILE["hosts<br/>Dynamic Inventory"]
        SLAVE_INSTANCES["JMeter Slave Instances<br/>Ubuntu EC2"]
    end
    
    ANSIBLE_CFG --> INVENTORY_SETTING
    ANSIBLE_CFG --> HOST_KEY_CHECK
    GROUP_VARS --> PYTHON_INTERP
    GROUP_VARS --> ANSIBLE_USER
    
    INVENTORY_SETTING --> HOSTS_FILE
    HOST_KEY_CHECK --> SLAVE_INSTANCES
    PYTHON_INTERP --> SLAVE_INSTANCES
    ANSIBLE_USER --> SLAVE_INSTANCES
```

**Sources:** [ansible-jmeter-slaves/ansible.cfg:1-3](), [ansible-jmeter-slaves/group_vars/all:1-2]()

## Configuration Integration Flow

```mermaid
graph LR
    subgraph "Configuration Loading"
        MAIN_SCRIPT["setup-jmeter-lab.sh"]
        ANSIBLE_CMD["ansible-playbook command"]
    end
    
    subgraph "Configuration Files"
        CFG_FILE["ansible.cfg"]
        VARS_FILE["group_vars/all"]
        INVENTORY_FILE["hosts"]
    end
    
    subgraph "Applied Settings"
        SSH_SETTINGS["SSH: ubuntu user<br/>No host key checking"]
        PYTHON_SETTINGS["Python: /usr/bin/python3"]
        INVENTORY_SETTINGS["Inventory: hosts file"]
    end
    
    subgraph "Target Infrastructure"
        EC2_SLAVES["EC2 Slave Instances<br/>Ubuntu AMI"]
    end
    
    MAIN_SCRIPT --> ANSIBLE_CMD
    ANSIBLE_CMD --> CFG_FILE
    ANSIBLE_CMD --> VARS_FILE
    ANSIBLE_CMD --> INVENTORY_FILE
    
    CFG_FILE --> SSH_SETTINGS
    CFG_FILE --> INVENTORY_SETTINGS
    VARS_FILE --> SSH_SETTINGS
    VARS_FILE --> PYTHON_SETTINGS
    
    SSH_SETTINGS --> EC2_SLAVES
    PYTHON_SETTINGS --> EC2_SLAVES
    INVENTORY_SETTINGS --> EC2_SLAVES
```

**Sources:** [ansible-jmeter-slaves/ansible.cfg:1-3](), [ansible-jmeter-slaves/group_vars/all:1-2]()

## Configuration Usage Context

These Ansible configuration files are automatically utilized when the main orchestration script executes Ansible commands to provision JMeter slaves. The configuration ensures that:

1. **Inventory Management**: Ansible knows to read the dynamically generated `hosts` file
2. **Connection Security**: SSH connections bypass host key checking for ephemeral instances
3. **Runtime Environment**: Python 3 is used on target instances for Ansible modules
4. **User Authentication**: Connections use the standard `ubuntu` user for Ubuntu AMI instances

The configuration is designed to work seamlessly with the AWS Auto Scaling Group provisioned instances and requires no manual intervention during the automated setup process.

**Sources:** [ansible-jmeter-slaves/ansible.cfg:1-3](), [ansible-jmeter-slaves/group_vars/all:1-2]()
