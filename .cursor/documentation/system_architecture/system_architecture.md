# System Architecture

<details>
<summary>Relevant source files</summary>

The following files were used as context for generating this wiki page:

- [README.md](README.md)
- [setup-jmeter-lab.sh](setup-jmeter-lab.sh)
- [test-data-distribute.sh](test-data-distribute.sh)

</details>



This document explains the overall system design, component relationships, and data flow through the automated distributed JMeter load testing pipeline. The system uses AWS infrastructure with Auto Scaling Groups to provision JMeter slave instances and Ansible for configuration management.

For detailed infrastructure provisioning steps, see [Infrastructure Management](#4). For configuration management specifics, see [Configuration Management](#5). For test execution workflows, see [Test Execution](#7).

## Architecture Overview

The system implements a distributed JMeter testing architecture with a master-slave pattern. A single master EC2 instance orchestrates multiple slave instances that are provisioned through AWS Auto Scaling Groups. The master coordinates test execution while slaves generate the actual load against the target system.

### High-Level System Components

```mermaid
graph TB
    subgraph "Control Plane"
        DEV["Developer/Operator"]
        MASTER["Master EC2 Instance"]
        ORCHESTRATOR["setup-jmeter-lab.sh"]
    end
    
    subgraph "AWS Infrastructure"
        subgraph "Auto Scaling"
            ASG["Auto Scaling Group<br/>slaves-{master-ip}"]
            LC["Launch Configuration<br/>perf-jmeter-slaves"]
        end
        
        subgraph "Compute Fleet"
            SLAVE1["JMeter Slave 1"]
            SLAVE2["JMeter Slave 2"]
            SLAVEN["JMeter Slave N"]
        end
        
        subgraph "Storage"
            AMI["Custom AMI"]
            S3["S3 Bucket<br/>Test Data"]
        end
    end
    
    subgraph "Configuration Management"
        ANSIBLE["Ansible Control"]
        PLAYBOOK["jmeter-slaves.yml"]
        INVENTORY["hosts file"]
    end
    
    subgraph "Test Execution"
        JMETER_PROPS["jmeter.properties"]
        TEST_PLANS["JMX Test Plans"]
        RESULTS["Test Results"]
    end
    
    DEV --> MASTER
    MASTER --> ORCHESTRATOR
    ORCHESTRATOR --> ASG
    ORCHESTRATOR --> ANSIBLE
    
    ASG --> SLAVE1
    ASG --> SLAVE2
    ASG --> SLAVEN
    LC --> AMI
    
    ANSIBLE --> PLAYBOOK
    ANSIBLE --> INVENTORY
    PLAYBOOK --> SLAVE1
    PLAYBOOK --> SLAVE2
    PLAYBOOK --> SLAVEN
    
    S3 --> SLAVE1
    S3 --> SLAVE2
    S3 --> SLAVEN
    
    JMETER_PROPS --> SLAVE1
    JMETER_PROPS --> SLAVE2
    JMETER_PROPS --> SLAVEN
    
    TEST_PLANS --> MASTER
    SLAVE1 --> RESULTS
    SLAVE2 --> RESULTS
    SLAVEN --> RESULTS
```

**Sources:** [README.md:1-47](), [setup-jmeter-lab.sh:1-43]()

## Component Architecture

The system consists of several interconnected components that handle different aspects of the distributed testing pipeline:

| Component Type | Key Files/Scripts | Purpose |
|----------------|------------------|---------|
| **Main Orchestrator** | `setup-jmeter-lab.sh` | Coordinates entire setup process |
| **Infrastructure Management** | `spinup-slaves.sh`, `get-asg-ip.sh` | Manages AWS resources and instance discovery |
| **Data Distribution** | `test-data-distribute.sh` | Partitions test data across slaves |
| **Configuration Management** | `ansible-jmeter-slaves/jmeter-slaves.yml` | Configures JMeter slaves via Ansible |
| **Test Execution** | `jmeter.sh`, `.jmx` files | Executes distributed load tests |

### Infrastructure Provisioning Flow

```mermaid
sequenceDiagram
    participant DEV as "Developer"
    participant MASTER as "Master EC2"
    participant SETUP as "setup-jmeter-lab.sh"
    participant ASG as "Auto Scaling Group"
    participant SLAVES as "JMeter Slaves"
    participant ANSIBLE as "Ansible"
    participant S3 as "S3 Storage"
    
    DEV->>MASTER: "Launch master instance"
    DEV->>SETUP: "Execute with parameters"
    SETUP->>ASG: "Create ASG slaves-{master-ip}"
    SETUP->>ASG: "Set desired capacity"
    ASG->>SLAVES: "Provision N slave instances"
    
    SETUP->>SETUP: "get-asg-ip.sh execution"
    SETUP->>ANSIBLE: "Update hosts inventory"
    SETUP->>S3: "Download test data"
    SETUP->>SETUP: "test-data-distribute.sh"
    SETUP->>ANSIBLE: "Run jmeter-slaves.yml"
    
    ANSIBLE->>SLAVES: "Clone repository"
    ANSIBLE->>SLAVES: "Start jmeter-server"
    SETUP->>MASTER: "Update jmeter.properties"
```

**Sources:** [setup-jmeter-lab.sh:6-43](), [README.md:35-46]()

## Data Flow Architecture

### Test Data Distribution System

The system implements a sophisticated data partitioning mechanism to prevent duplicate data usage across slave instances:

```mermaid
graph TD
    subgraph "S3 Storage"
        S3_BUCKET["S3 Bucket"]
        SCENARIO_FOLDER["s3://bucket/scenario-folder/"]
        CSV_FILES["CSV Test Data Files"]
    end
    
    subgraph "Master Instance Processing"
        DOWNLOAD["AWS S3 CP<br/>/tmp/datadir/"]
        HOSTS_COUNT["Read ansible-jmeter-slaves/hosts<br/>Count slaves"]
        SPLIT_LOGIC["File splitting logic<br/>split -l command"]
        DISTRIBUTE["test-data-distribute.sh"]
    end
    
    subgraph "Partitioned Data"
        SLAVE_DIR1["/tmp/datadir/slave1/"]
        SLAVE_DIR2["/tmp/datadir/slave2/"]
        SLAVE_DIRN["/tmp/datadir/slaveN/"]
    end
    
    subgraph "JMeter Slaves"
        JMETER_SLAVE1["JMeter Slave 1<br/>Uses partition 1"]
        JMETER_SLAVE2["JMeter Slave 2<br/>Uses partition 2"]
        JMETER_SLAVEN["JMeter Slave N<br/>Uses partition N"]
    end
    
    S3_BUCKET --> SCENARIO_FOLDER
    SCENARIO_FOLDER --> CSV_FILES
    CSV_FILES --> DOWNLOAD
    DOWNLOAD --> DISTRIBUTE
    HOSTS_COUNT --> DISTRIBUTE
    DISTRIBUTE --> SPLIT_LOGIC
    
    SPLIT_LOGIC --> SLAVE_DIR1
    SPLIT_LOGIC --> SLAVE_DIR2
    SPLIT_LOGIC --> SLAVE_DIRN
    
    SLAVE_DIR1 --> JMETER_SLAVE1
    SLAVE_DIR2 --> JMETER_SLAVE2
    SLAVE_DIRN --> JMETER_SLAVEN
```

**Sources:** [test-data-distribute.sh:1-27](), [setup-jmeter-lab.sh:29]()

### Data Partitioning Algorithm

The data distribution follows this algorithm implemented in `test-data-distribute.sh`:

1. **Download Phase**: Download all CSV files from S3 to `/tmp/datadir/` [test-data-distribute.sh:7]()
2. **Inventory Reading**: Count slave instances from `ansible-jmeter-slaves/hosts` [test-data-distribute.sh:10-11]()
3. **Directory Creation**: Create subdirectories for each slave [test-data-distribute.sh:10]()
4. **File Processing**: For each CSV file:
   - Calculate lines per partition: `divfilelen=$(($filelen/$len))` [test-data-distribute.sh:18]()
   - Split file using: `split -l $divfilelen $f datafilesdistrib_` [test-data-distribute.sh:19]()
   - Distribute partitions to slave directories [test-data-distribute.sh:22]()

## JMeter Master-Slave Architecture

### JMeter Coordination System

```mermaid
graph TB
    subgraph "JMeter Master"
        TEST_PLAN["Test Plan<br/>test.jmx"]
        MASTER_PROCESS["JMeter Master Process"]
        REMOTE_HOSTS_CONFIG["jmeter.properties<br/>remote_hosts configuration"]
        RESULTS_AGGREGATOR["Results Aggregation<br/>*.jtl files"]
    end
    
    subgraph "JMeter Slaves"
        JMETER_SERVER1["jmeter-server<br/>Slave 1 Process"]
        JMETER_SERVER2["jmeter-server<br/>Slave 2 Process"]
        JMETER_SERVERN["jmeter-server<br/>Slave N Process"]
    end
    
    subgraph "Load Generation"
        HTTP_REQUESTS1["HTTP Requests<br/>from Slave 1"]
        HTTP_REQUESTS2["HTTP Requests<br/>from Slave 2"]
        HTTP_REQUESTSN["HTTP Requests<br/>from Slave N"]
    end
    
    subgraph "Target System"
        SUT["System Under Test"]
        PERFORMANCE_METRICS["Performance Metrics"]
    end
    
    TEST_PLAN --> MASTER_PROCESS
    REMOTE_HOSTS_CONFIG --> MASTER_PROCESS
    MASTER_PROCESS --> JMETER_SERVER1
    MASTER_PROCESS --> JMETER_SERVER2
    MASTER_PROCESS --> JMETER_SERVERN
    
    JMETER_SERVER1 --> HTTP_REQUESTS1
    JMETER_SERVER2 --> HTTP_REQUESTS2
    JMETER_SERVERN --> HTTP_REQUESTSN
    
    HTTP_REQUESTS1 --> SUT
    HTTP_REQUESTS2 --> SUT
    HTTP_REQUESTSN --> SUT
    
    SUT --> PERFORMANCE_METRICS
    PERFORMANCE_METRICS --> RESULTS_AGGREGATOR
```

**Sources:** [setup-jmeter-lab.sh:40](), [README.md:42-46]()

### Remote Hosts Configuration

The master coordinates with slaves through the `remote_hosts` property in `jmeter.properties`. The `setup-jmeter-lab.sh` script dynamically updates this configuration:

```bash
OUT=$(sh $dir/get-asg-ip.sh | awk -F '"' '{print $2}' | awk '{ printf("%s,", $0) }' | rev | cut -c2- | rev)
sed -i "s/remote_hosts=.*/remote_hosts=$OUT/g" $dir/jmeter/apache-jmeter-5.4.2/bin/jmeter.properties
```

This creates a comma-separated list of slave IP addresses that JMeter uses for distributed execution.

**Sources:** [setup-jmeter-lab.sh:36-40]()

## Configuration Management Architecture

### Ansible Integration

The system uses Ansible for automated configuration of slave instances:

```mermaid
graph LR
    subgraph "Ansible Control"
        ANSIBLE_CFG["ansible.cfg"]
        GROUP_VARS["group_vars/all"]
        PLAYBOOK["jmeter-slaves.yml"]
        INVENTORY["hosts file"]
    end
    
    subgraph "Dynamic Inventory"
        GET_ASG_IP["get-asg-ip.sh"]
        SLAVE_IPS["Slave IP Addresses"]
    end
    
    subgraph "Slave Configuration"
        REPO_CLONE["Git Repository Clone"]
        JMETER_SERVER["jmeter-server Startup"]
        DEPENDENCIES["Dependency Installation"]
    end
    
    GET_ASG_IP --> SLAVE_IPS
    SLAVE_IPS --> INVENTORY
    ANSIBLE_CFG --> PLAYBOOK
    GROUP_VARS --> PLAYBOOK
    INVENTORY --> PLAYBOOK
    
    PLAYBOOK --> REPO_CLONE
    PLAYBOOK --> JMETER_SERVER
    PLAYBOOK --> DEPENDENCIES
```

**Sources:** [setup-jmeter-lab.sh:26](), [setup-jmeter-lab.sh:32]()

The Ansible playbook execution includes Git credentials and branch specification:
```bash
ansible-playbook jmeter-slaves.yml -u ubuntu -e "git_user=$2" -e "git_pass=$3" -e "git_branch=$4"
```

## System Integration Points

### Key Integration Interfaces

| Interface | Source Component | Target Component | Protocol/Method |
|-----------|------------------|------------------|-----------------|
| **AWS API** | `setup-jmeter-lab.sh` | Auto Scaling Groups | AWS CLI commands |
| **SSH** | Ansible | JMeter Slaves | SSH with key authentication |
| **JMeter RMI** | JMeter Master | JMeter Slaves | RMI protocol on default ports |
| **Git HTTPS** | All instances | GitHub Repository | HTTPS with credentials |
| **S3 API** | Master instance | S3 Storage | AWS S3 CLI commands |

### Error Handling and Resilience

The system includes several resilience mechanisms:

- **SSH Agent Management**: Ensures SSH connectivity for Ansible [setup-jmeter-lab.sh:13-16]()
- **Wait Intervals**: Built-in delays for resource provisioning [setup-jmeter-lab.sh:21]()
- **Data Cleanup**: Automatic cleanup of temporary data files [test-data-distribute.sh:6]()

**Sources:** [setup-jmeter-lab.sh:1-43](), [test-data-distribute.sh:1-27]()
