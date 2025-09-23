# Configuration Files Reference

<details>
<summary>Relevant source files</summary>

The following files were used as context for generating this wiki page:

- [ansible-jmeter-slaves/ansible.cfg](ansible-jmeter-slaves/ansible.cfg)
- [ansible-jmeter-slaves/group_vars/all](ansible-jmeter-slaves/group_vars/all)
- [jmeter/scripts/test.jmx](jmeter/scripts/test.jmx)

</details>



This document provides a comprehensive reference for all configuration files used in the automated distributed load testing system. These files control system behavior, define infrastructure parameters, manage Ansible automation, and configure JMeter test execution across the distributed environment.

For information about the scripts that use these configuration files, see [Main Orchestration Script](#8.1) and [Helper Scripts](#8.2). For details about how Ansible uses these configurations, see [Configuration Management](#5).

## Configuration File Hierarchy

The system uses several categories of configuration files that work together to orchestrate distributed load testing:

### Configuration File Structure

```mermaid
graph TB
    subgraph "Ansible Configuration"
        ANSIBLE_CFG["ansible.cfg"]
        GROUP_VARS["group_vars/all"]
        HOSTS["hosts"]
    end
    
    subgraph "JMeter Configuration"
        JMETER_PROPS["jmeter.properties"]
        TEST_JMX["test.jmx"]
        CUSTOM_JMX["custom-test-plans.jmx"]
    end
    
    subgraph "System Scripts"
        SETUP_SCRIPT["setup-jmeter-lab.sh"]
        JMETER_SCRIPT["jmeter.sh"]
        DISTRIBUTE_SCRIPT["test-data-distribute.sh"]
    end
    
    subgraph "Runtime Dependencies"
        SLAVE_IPS["Slave IP Addresses"]
        TEST_DATA["Test Data Files"]
        AWS_RESOURCES["AWS Resources"]
    end
    
    ANSIBLE_CFG --> HOSTS
    GROUP_VARS --> HOSTS
    HOSTS --> SLAVE_IPS
    
    SETUP_SCRIPT --> ANSIBLE_CFG
    SETUP_SCRIPT --> JMETER_PROPS
    SETUP_SCRIPT --> TEST_DATA
    
    JMETER_SCRIPT --> TEST_JMX
    JMETER_SCRIPT --> JMETER_PROPS
    
    DISTRIBUTE_SCRIPT --> TEST_DATA
    DISTRIBUTE_SCRIPT --> HOSTS
    
    SLAVE_IPS --> JMETER_PROPS
    AWS_RESOURCES --> SLAVE_IPS
```

Sources: [ansible-jmeter-slaves/ansible.cfg:1-3](), [ansible-jmeter-slaves/group_vars/all:1-2](), [jmeter/scripts/test.jmx:1]()

## Ansible Configuration Files

### ansible.cfg

The main Ansible configuration file that defines basic behavior for slave instance management.

| Setting | Value | Purpose |
|---------|--------|---------|
| `inventory` | `hosts` | Points to the inventory file containing slave instance information |
| `host_key_checking` | `False` | Disables SSH host key verification for automated provisioning |

**File Location**: [ansible-jmeter-slaves/ansible.cfg:1-3]()

```ini
[defaults]
inventory = hosts
host_key_checking = False
```

This configuration enables Ansible to automatically connect to newly provisioned EC2 instances without manual SSH key verification, which is essential for automated slave provisioning.

### group_vars/all

Defines global Ansible variables applied to all managed hosts (JMeter slaves).

| Variable | Value | Purpose |
|----------|--------|---------|
| `ansible_python_interpreter` | `/usr/bin/python3` | Specifies Python 3 as the interpreter for Ansible modules |
| `ansible_user` | `ubuntu` | Sets the SSH user for connecting to Ubuntu-based EC2 instances |

**File Location**: [ansible-jmeter-slaves/group_vars/all:1-2]()

```yaml
ansible_python_interpreter: /usr/bin/python3
ansible_user : ubuntu
```

These variables ensure consistent connectivity across all slave instances using Ubuntu AMIs with Python 3.

### hosts Inventory File

The `hosts` file serves as the dynamic inventory for Ansible, populated automatically by the system scripts with slave instance IP addresses. This file is generated and updated by [get-asg-ip.sh]() during infrastructure provisioning.

**Format Structure**:
```ini
[slaves]
<slave-ip-1>
<slave-ip-2>
<slave-ip-n>
```

Sources: [ansible-jmeter-slaves/ansible.cfg:2](), [ansible-jmeter-slaves/group_vars/all:1-2]()

## JMeter Configuration Files

### jmeter.properties

The JMeter properties file configures the master-slave communication and testing parameters. This file is dynamically updated by [setup-jmeter-lab.sh]() to include the `remote_hosts` configuration.

**Key Configuration Parameters**:

| Property | Purpose | Dynamic Value |
|----------|---------|---------------|
| `remote_hosts` | Comma-separated list of slave IP addresses | Updated with discovered slave IPs |
| `server.rmi.ssl.disable` | Disables SSL for RMI communication | `true` (for simplified setup) |
| `server_port` | JMeter server port for slave communication | `1099` (default) |

**Example Configuration**:
```properties
remote_hosts=10.0.1.100,10.0.1.101,10.0.1.102
server.rmi.ssl.disable=true
server_port=1099
```

The `remote_hosts` property is the critical configuration that enables the JMeter master to discover and coordinate with all provisioned slave instances.

### Test Plan Files (.jmx)

JMeter test plans are XML-based configuration files that define the load testing scenarios, thread groups, and test logic.

**File Location**: [jmeter/scripts/test.jmx:1]()

**Test Plan Structure**:
```mermaid
graph TB
    subgraph "JMeter Test Plan Components"
        TEST_PLAN["TestPlan Root"]
        THREAD_GROUP["ThreadGroup"]
        HTTP_SAMPLER["HTTP Request Sampler"]
        LISTENERS["Result Listeners"]
        CONFIG_ELEMENTS["Configuration Elements"]
    end
    
    subgraph "Data Integration"
        CSV_CONFIG["CSV Data Set Config"]
        TEST_DATA_FILES["Test Data Files"]
        USER_DEFINED_VARS["User Defined Variables"]
    end
    
    subgraph "Result Collection"
        JTL_FILES["Result Files (.jtl)"]
        AGGREGATE_REPORT["Aggregate Report"]
        SUMMARY_REPORT["Summary Report"]
    end
    
    TEST_PLAN --> THREAD_GROUP
    THREAD_GROUP --> HTTP_SAMPLER
    THREAD_GROUP --> CONFIG_ELEMENTS
    CONFIG_ELEMENTS --> CSV_CONFIG
    CSV_CONFIG --> TEST_DATA_FILES
    TEST_PLAN --> USER_DEFINED_VARS
    TEST_PLAN --> LISTENERS
    LISTENERS --> JTL_FILES
    LISTENERS --> AGGREGATE_REPORT
    LISTENERS --> SUMMARY_REPORT
```

Sources: [jmeter/scripts/test.jmx:1]()

## Configuration File Relationships

### Runtime Configuration Flow

```mermaid
sequenceDiagram
    participant SETUP as "setup-jmeter-lab.sh"
    participant ASG as "AWS Auto Scaling Group"
    participant GET_IP as "get-asg-ip.sh"
    participant ANSIBLE_CFG as "ansible.cfg"
    participant HOSTS as "hosts inventory"
    participant JMETER_PROPS as "jmeter.properties"
    participant PLAYBOOK as "jmeter-slaves.yml"
    
    SETUP->>ASG: "Provision slave instances"
    ASG->>GET_IP: "Return instance IPs"
    GET_IP->>HOSTS: "Update inventory with slave IPs"
    ANSIBLE_CFG->>HOSTS: "Read inventory configuration"
    SETUP->>JMETER_PROPS: "Update remote_hosts with slave IPs"
    SETUP->>PLAYBOOK: "Execute with updated inventory"
    PLAYBOOK->>HOSTS: "Apply configuration to slaves"
```

### Configuration Dependencies

| Configuration File | Depends On | Updates | Used By |
|-------------------|------------|---------|---------|
| `ansible.cfg` | Static configuration | None | Ansible playbook execution |
| `group_vars/all` | Static configuration | None | All Ansible tasks |
| `hosts` | Slave IP discovery | `get-asg-ip.sh` | Ansible, test data distribution |
| `jmeter.properties` | Slave IP discovery | `setup-jmeter-lab.sh` | JMeter master execution |
| `test.jmx` | Manual creation/editing | User modifications | JMeter test execution |

## File System Layout

```mermaid
graph TB
    subgraph "Project Root"
        ROOT["/"]
    end
    
    subgraph "Ansible Directory"
        ANSIBLE_DIR["ansible-jmeter-slaves/"]
        ANSIBLE_CFG_FILE["ansible.cfg"]
        GROUP_VARS_DIR["group_vars/"]
        ALL_VARS["all"]
        HOSTS_FILE["hosts"]
        PLAYBOOK_FILE["jmeter-slaves.yml"]
    end
    
    subgraph "JMeter Directory"
        JMETER_DIR["jmeter/"]
        SCRIPTS_DIR["scripts/"]
        TEST_JMX_FILE["test.jmx"]
        JMETER_PROPS_FILE["jmeter.properties"]
    end
    
    subgraph "Shell Scripts"
        SETUP_SH["setup-jmeter-lab.sh"]
        JMETER_SH["jmeter.sh"]
        SPINUP_SH["spinup-slaves.sh"]
        GET_IP_SH["get-asg-ip.sh"]
        DISTRIBUTE_SH["test-data-distribute.sh"]
    end
    
    ROOT --> ANSIBLE_DIR
    ROOT --> JMETER_DIR
    ROOT --> SETUP_SH
    ROOT --> JMETER_SH
    ROOT --> SPINUP_SH
    ROOT --> GET_IP_SH
    ROOT --> DISTRIBUTE_SH
    
    ANSIBLE_DIR --> ANSIBLE_CFG_FILE
    ANSIBLE_DIR --> GROUP_VARS_DIR
    ANSIBLE_DIR --> HOSTS_FILE
    ANSIBLE_DIR --> PLAYBOOK_FILE
    GROUP_VARS_DIR --> ALL_VARS
    
    JMETER_DIR --> SCRIPTS_DIR
    JMETER_DIR --> JMETER_PROPS_FILE
    SCRIPTS_DIR --> TEST_JMX_FILE
```

Sources: [ansible-jmeter-slaves/ansible.cfg:1-3](), [ansible-jmeter-slaves/group_vars/all:1-2](), [jmeter/scripts/test.jmx:1]()

## Configuration Best Practices

### Security Considerations

- **SSH Host Key Checking**: Disabled in `ansible.cfg` for automation, but consider enabling in production environments
- **User Permissions**: The `ubuntu` user in `group_vars/all` requires appropriate sudo permissions on slave instances
- **Network Security**: Ensure security groups properly restrict access to JMeter ports (1099, 4440-4445)

### Maintenance Guidelines

- **Dynamic Updates**: Never manually edit the `hosts` inventory file as it's automatically regenerated
- **Property Synchronization**: Ensure `jmeter.properties` remote_hosts matches the actual provisioned slave count
- **Test Plan Validation**: Validate `.jmx` files in JMeter GUI before using in distributed mode
- **Version Control**: Track test plan changes but exclude dynamic files like `hosts` and updated `jmeter.properties`

Sources: [ansible-jmeter-slaves/ansible.cfg:1-3](), [ansible-jmeter-slaves/group_vars/all:1-2]()
