# Component Reference

<details>
<summary>Relevant source files</summary>

The following files were used as context for generating this wiki page:

- [setup-jmeter-lab.sh](setup-jmeter-lab.sh)
- [test-data-distribute.sh](test-data-distribute.sh)

</details>



This page provides a comprehensive reference for all scripts, configuration files, and system components in the automated distributed load testing system. It serves as a central index of the codebase's key elements and their relationships.

For detailed documentation of specific component categories, see:
- Main orchestration script: [Main Orchestration Script](#8.1)  
- Helper utilities: [Helper Scripts](#8.2)
- Configuration files: [Configuration Files Reference](#8.3)

## System Component Overview

The following diagram maps the natural language system components to their actual code entities and file locations:

```mermaid
graph TB
    subgraph "Entry_Points"
        setup_script["setup-jmeter-lab.sh<br/>Main Orchestrator"]
        jmeter_script["jmeter.sh<br/>Test Executor"]
    end
    
    subgraph "Helper_Scripts"
        spinup["spinup-slaves.sh<br/>ASG Management"]
        get_ip["get-asg-ip.sh<br/>IP Discovery"] 
        distribute["test-data-distribute.sh<br/>Data Distribution"]
    end
    
    subgraph "Configuration_Management"
        ansible_cfg["ansible.cfg<br/>Ansible Configuration"]
        ansible_vars["group_vars/all<br/>Ansible Variables"]
        hosts_file["hosts<br/>Inventory File"]
        playbook["jmeter-slaves.yml<br/>Slave Provisioning"]
    end
    
    subgraph "Test_Assets"
        test_plan["test.jmx<br/>JMeter Test Plan"]
        jmeter_props["jmeter.properties<br/>JMeter Configuration"]
        test_data["*.csv<br/>Test Data Files"]
    end
    
    subgraph "AWS_Resources"
        asg_name["slaves-{master-ip}<br/>Auto Scaling Group"]
        launch_config["perf-jmeter-slaves<br/>Launch Configuration"]
        s3_bucket["s3://bucket-name/scenario/<br/>S3 Test Data"]
    end
    
    setup_script --> spinup
    setup_script --> get_ip
    setup_script --> distribute
    setup_script --> hosts_file
    setup_script --> jmeter_props
    
    get_ip --> hosts_file
    distribute --> test_data
    hosts_file --> playbook
    
    spinup --> asg_name
    asg_name --> launch_config
    distribute --> s3_bucket
```

**Sources:** [setup-jmeter-lab.sh:1-43](), [test-data-distribute.sh:1-27]()

## Script Execution Flow

This diagram shows the execution flow and dependencies between the main components:

```mermaid
sequenceDiagram
    participant user as "User"
    participant setup as "setup-jmeter-lab.sh"
    participant spinup as "spinup-slaves.sh"
    participant get_ip as "get-asg-ip.sh"
    participant distribute as "test-data-distribute.sh"
    participant ansible as "ansible-playbook"
    participant jmeter as "jmeter.sh"
    
    user->>setup: "Execute with parameters $1-$5"
    setup->>setup: "Create ASG slaves-$asg"
    setup->>spinup: "sh spinup-slaves.sh $1"
    setup->>get_ip: "sh get-asg-ip.sh"
    get_ip-->>setup: "Return slave IPs"
    setup->>setup: "Write IPs to ansible-jmeter-slaves/hosts"
    setup->>distribute: "sh test-data-distribute.sh $5"
    distribute->>distribute: "Download from s3://<bucket-name>/$1/"
    distribute->>distribute: "Split CSV files by slave count"
    setup->>ansible: "ansible-playbook jmeter-slaves.yml"
    setup->>setup: "Update jmeter.properties remote_hosts"
    setup->>setup: "git pull latest changes"
    user->>jmeter: "Execute distributed test"
```

**Sources:** [setup-jmeter-lab.sh:6-43](), [test-data-distribute.sh:6-26]()

## Component Categories

### Entry Point Scripts

| Script | Purpose | Parameters |
|--------|---------|------------|
| `setup-jmeter-lab.sh` | Primary orchestration script that provisions infrastructure and configures the distributed testing environment | `$1`: slave count, `$2`: git_user, `$3`: git_pass, `$4`: git_branch, `$5`: S3 scenario folder |
| `jmeter.sh` | Executes distributed JMeter tests using configured master-slave setup | Test plan and execution parameters |

### Helper Scripts

| Script | Function | Key Operations |
|--------|----------|----------------|
| `spinup-slaves.sh` | Manages Auto Scaling Group capacity to provision slave instances | Updates ASG min/max/desired counts |
| `get-asg-ip.sh` | Discovers IP addresses of provisioned slave instances | Queries AWS ASG for instance details |
| `test-data-distribute.sh` | Partitions test data across slave instances to prevent duplication | Downloads from S3, splits CSV files, distributes to slave-specific directories |

**Sources:** [setup-jmeter-lab.sh:19](), [setup-jmeter-lab.sh:26](), [test-data-distribute.sh:1-27]()

### Configuration Management Files

| File Path | Purpose | Key Settings |
|-----------|---------|--------------|
| `ansible-jmeter-slaves/ansible.cfg` | Ansible configuration for slave management | SSH settings, inventory location |
| `ansible-jmeter-slaves/group_vars/all` | Global variables for Ansible playbooks | Environment-specific settings |
| `ansible-jmeter-slaves/hosts` | Dynamic inventory of slave IP addresses | Populated by `get-asg-ip.sh` output |
| `ansible-jmeter-slaves/jmeter-slaves.yml` | Playbook for configuring JMeter slaves | Repository cloning, service startup |

### Test Assets

| Asset Type | Location | Configuration |
|------------|----------|---------------|
| JMeter Test Plans | `*.jmx` files | Test scenarios and load patterns |
| JMeter Properties | `jmeter/apache-jmeter-5.4.2/bin/jmeter.properties` | `remote_hosts` configuration updated by setup script |
| Test Data | S3 bucket paths, local `/tmp/datadir/` partitions | CSV files distributed per slave |

**Sources:** [setup-jmeter-lab.sh:32](), [setup-jmeter-lab.sh:40](), [test-data-distribute.sh:6-10]()

## File System Layout

The following diagram shows the key file system locations used during test execution:

```mermaid
graph TD
    subgraph "Master_Instance"
        repo_root["/Repository Root"]
        ansible_dir["/ansible-jmeter-slaves/"]
        jmeter_dir["/jmeter/apache-jmeter-5.4.2/"]
        tmp_datadir["/tmp/datadir/"]
    end
    
    subgraph "Key_Files"
        setup_script_file["setup-jmeter-lab.sh"]
        hosts_inventory["hosts"]
        jmeter_props_file["jmeter.properties"]
        playbook_file["jmeter-slaves.yml"]
    end
    
    subgraph "Data_Distribution"
        slave_dirs["/tmp/datadir/slave{N}/"]
        csv_partitions["partitioned CSV files"]
    end
    
    repo_root --> setup_script_file
    repo_root --> ansible_dir
    repo_root --> jmeter_dir
    
    ansible_dir --> hosts_inventory
    ansible_dir --> playbook_file
    jmeter_dir --> jmeter_props_file
    
    tmp_datadir --> slave_dirs
    slave_dirs --> csv_partitions
```

**Sources:** [setup-jmeter-lab.sh:26](), [setup-jmeter-lab.sh:40](), [test-data-distribute.sh:6](), [test-data-distribute.sh:10]()

The system uses a combination of shell scripts for orchestration, Ansible for configuration management, and AWS services for infrastructure provisioning. Each component is designed to work together in a coordinated workflow that provisions, configures, and executes distributed load tests.

For implementation details of specific components, refer to the dedicated sections: [Main Orchestration Script](#8.1), [Helper Scripts](#8.2), and [Configuration Files Reference](#8.3).
