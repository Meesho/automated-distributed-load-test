# Overview

<details>
<summary>Relevant source files</summary>

The following files were used as context for generating this wiki page:

- [README.md](README.md)

</details>



## Purpose and Scope

This document provides an overview of the automated distributed load testing system, which automates the setup and execution of JMeter-based distributed load tests on AWS infrastructure. The system orchestrates the provisioning of EC2 instances, configuration management, test data distribution, and load test execution across multiple JMeter slave nodes.

For detailed setup instructions, see [Quick Start Guide](#2). For in-depth architectural details, see [System Architecture](#3). For infrastructure management specifics, see [Infrastructure Management](#4).

## System Purpose

The automated distributed load testing system eliminates the manual overhead of setting up distributed JMeter environments by providing a fully automated solution that:

- **Provisions AWS Infrastructure**: Automatically creates Auto Scaling Groups and EC2 instances for JMeter slaves
- **Manages Configuration**: Uses Ansible to configure JMeter slave instances with necessary dependencies and configurations
- **Distributes Test Data**: Partitions large test data files across slave instances to prevent data duplication during load testing
- **Orchestrates Test Execution**: Coordinates distributed JMeter test execution from a master instance to multiple slave instances
- **Handles Cleanup**: Provides mechanisms to clean up provisioned resources after testing

## High-Level System Architecture

The system follows a master-slave architecture where a single master EC2 instance orchestrates multiple slave instances to generate distributed load against target systems.

```mermaid
graph TB
    subgraph "Control_Layer"
        Developer["Developer"]
        MasterEC2["Master EC2 Instance"]
        setup_script["setup-jmeter-lab.sh"]
    end
    
    subgraph "Infrastructure_Layer"
        ASG["Auto Scaling Group<br/>slaves-{master-ip}"]
        LaunchConfig["Launch Configuration<br/>perf-jmeter-slaves"]
        SlaveInstances["JMeter Slave Instances"]
    end
    
    subgraph "Configuration_Layer"
        AnsibleControl["Ansible Controller"]
        jmeter_playbook["jmeter-slaves.yml"]
        hosts_inventory["hosts inventory"]
    end
    
    subgraph "Data_Layer"
        S3Bucket["S3 Bucket"]
        TestDataFiles["Test Data Files (.csv)"]
        GitRepo["GitHub Repository"]
    end
    
    subgraph "Execution_Layer"
        JMeterMaster["JMeter Master Process"]
        JMeterSlaves["jmeter-server processes"]
        TestPlans["Test Plans (.jmx)"]
    end
    
    subgraph "Target_Layer"
        SystemUnderTest["System Under Test"]
    end
    
    Developer --> MasterEC2
    MasterEC2 --> setup_script
    setup_script --> ASG
    setup_script --> AnsibleControl
    
    ASG --> LaunchConfig
    LaunchConfig --> SlaveInstances
    
    AnsibleControl --> jmeter_playbook
    AnsibleControl --> hosts_inventory
    jmeter_playbook --> SlaveInstances
    
    S3Bucket --> TestDataFiles
    GitRepo --> TestPlans
    TestDataFiles --> SlaveInstances
    TestPlans --> JMeterMaster
    
    JMeterMaster --> JMeterSlaves
    JMeterSlaves --> SystemUnderTest
    
    SlaveInstances --> JMeterSlaves
    MasterEC2 --> JMeterMaster
```

**Sources:** [README.md:1-47]()

## Key Components

The system consists of several interconnected components that work together to provide automated distributed load testing capabilities:

| Component | Purpose | Key Files |
|-----------|---------|-----------|
| **Main Orchestrator** | Primary automation script that coordinates all system components | `setup-jmeter-lab.sh` |
| **Infrastructure Management** | AWS resource provisioning and management | `spinup-slaves.sh`, `get-asg-ip.sh` |
| **Configuration Management** | Ansible-based slave configuration and setup | `jmeter-slaves.yml`, `ansible.cfg` |
| **Data Distribution** | Test data partitioning and distribution to slaves | `test-data-distribute.sh` |
| **Test Execution** | JMeter master-slave coordination and test running | `jmeter.sh`, test plans (`.jmx` files) |

## Workflow Overview

The system implements a sequential workflow that progresses from infrastructure provisioning through test execution:

```mermaid
sequenceDiagram
    participant Dev as "Developer"
    participant Master as "Master EC2"
    participant setup as "setup-jmeter-lab.sh"
    participant spinup as "spinup-slaves.sh"
    participant getip as "get-asg-ip.sh" 
    participant ansible as "Ansible"
    participant distribute as "test-data-distribute.sh"
    participant jmeter as "jmeter.sh"
    participant slaves as "JMeter Slaves"
    
    Dev->>Master: Launch master instance
    Dev->>setup: Execute with parameters
    setup->>spinup: Create ASG and slaves
    spinup->>slaves: Provision N slave instances
    setup->>getip: Discover slave IP addresses
    getip->>setup: Return slave IPs
    setup->>ansible: Update hosts inventory
    setup->>ansible: Run jmeter-slaves.yml
    ansible->>slaves: Configure JMeter servers
    setup->>distribute: Distribute test data
    distribute->>slaves: Partition data files
    setup->>Master: Update jmeter.properties
    Dev->>jmeter: Execute distributed test
    jmeter->>slaves: Coordinate load generation
    slaves->>Dev: Return aggregated results
```

**Sources:** [README.md:25-46]()

## Code Structure Mapping

The system's functionality is distributed across several shell scripts and configuration files that map to specific operational phases:

```mermaid
graph LR
    subgraph "Entry_Points"
        setup_jmeter_lab["setup-jmeter-lab.sh<br/>(Main Entry Point)"]
        jmeter_sh["jmeter.sh<br/>(Test Execution)"]
    end
    
    subgraph "Infrastructure_Scripts"
        spinup_slaves["spinup-slaves.sh<br/>(ASG Creation)"]
        get_asg_ip["get-asg-ip.sh<br/>(IP Discovery)"]
    end
    
    subgraph "Configuration_Files"
        ansible_cfg["ansible.cfg<br/>(Ansible Config)"]
        jmeter_slaves_yml["jmeter-slaves.yml<br/>(Playbook)"]
        hosts_file["hosts<br/>(Inventory)"]
    end
    
    subgraph "Data_Management"
        test_data_distribute["test-data-distribute.sh<br/>(Data Partitioning)"]
    end
    
    subgraph "Test_Assets"
        jmx_files["scripts/*.jmx<br/>(Test Plans)"]
        jmeter_properties["jmeter.properties<br/>(JMeter Config)"]
    end
    
    setup_jmeter_lab --> spinup_slaves
    setup_jmeter_lab --> get_asg_ip
    setup_jmeter_lab --> test_data_distribute
    setup_jmeter_lab --> ansible_cfg
    
    ansible_cfg --> jmeter_slaves_yml
    get_asg_ip --> hosts_file
    
    jmeter_sh --> jmx_files
    jmeter_sh --> jmeter_properties
```

**Sources:** [README.md:35-46]()

The system requires specific prerequisites including AWS IAM permissions, a pre-configured AMI with dependencies, and an S3 bucket for test data storage. The main workflow begins with executing `setup-jmeter-lab.sh` with parameters specifying the number of slaves, Git credentials, and S3 data folder, followed by test execution using `jmeter.sh` with the appropriate test plan.

**Sources:** [README.md:4-21](), [README.md:35-46]()
