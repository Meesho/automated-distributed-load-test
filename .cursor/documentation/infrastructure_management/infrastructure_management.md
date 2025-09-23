# Infrastructure Management

<details>
<summary>Relevant source files</summary>

The following files were used as context for generating this wiki page:

- [get-asg-ip.sh](get-asg-ip.sh)
- [spinup-slaves.sh](spinup-slaves.sh)

</details>



## Purpose and Scope

This document covers the AWS infrastructure components and management strategies used in the automated distributed load testing system. It provides an overview of how EC2 instances, Auto Scaling Groups, and supporting AWS resources are provisioned, configured, and managed throughout the testing lifecycle.

For detailed information about Auto Scaling Group operations, see [Auto Scaling Group Management](#4.1). For instance IP discovery mechanisms, see [Instance Discovery](#4.2). For Ansible-based configuration of provisioned instances, see [Configuration Management](#5).

## Infrastructure Overview

The system uses a master-slave architecture where a single master EC2 instance orchestrates multiple slave instances that are dynamically provisioned using AWS Auto Scaling Groups. The infrastructure is designed to be ephemeral and scalable, allowing for cost-effective load testing at various scales.

### Core Infrastructure Components

| Component | Purpose | Management Method |
|-----------|---------|-------------------|
| Master EC2 Instance | JMeter master, orchestration, result aggregation | Manual launch, persistent during test |
| Slave EC2 Instances | JMeter slave nodes, load generation | Auto Scaling Group, ephemeral |
| Auto Scaling Group | Dynamic slave provisioning and scaling | Programmatic via AWS CLI |
| Custom AMI | Pre-configured slave environment | Referenced in Launch Configuration |
| S3 Storage | Test data distribution and artifact storage | Accessed via AWS CLI |
| VPC/Security Groups | Network isolation and access control | Pre-configured, referenced |

**Infrastructure Component Architecture**

```mermaid
graph TB
    subgraph "Master_Instance"[Master Instance]
        MASTER_IP["master-ip"]
        ORCHESTRATOR["setup-jmeter-lab.sh"]
        ASG_MANAGER["spinup-slaves.sh"]
        IP_DISCOVERY["get-asg-ip.sh"]
    end
    
    subgraph "AWS_Infrastructure"[AWS Infrastructure]
        subgraph "Auto_Scaling"[Auto Scaling]
            ASG_NAME["slaves-{master-ip}"]
            LAUNCH_CONFIG["perf-jmeter-slaves"]
            DESIRED_CAPACITY["--desired-capacity"]
        end
        
        subgraph "Compute_Fleet"[Compute Fleet]
            INSTANCE_IDS["instance-ids"]
            PRIVATE_IPS["PrivateIpAddress"]
            SLAVE_PROCESSES["jmeter-server"]
        end
        
        subgraph "Storage_Network"[Storage & Network]
            CUSTOM_AMI["Custom AMI"]
            S3_BUCKET["s3://bucket/scenario-folder/"]
            VPC_CONFIG["VPC & Security Groups"]
        end
    end
    
    MASTER_IP --> ASG_NAME
    ORCHESTRATOR --> ASG_MANAGER
    ASG_MANAGER --> ASG_NAME
    ASG_MANAGER --> DESIRED_CAPACITY
    
    ASG_NAME --> LAUNCH_CONFIG
    LAUNCH_CONFIG --> CUSTOM_AMI
    ASG_NAME --> INSTANCE_IDS
    
    IP_DISCOVERY --> INSTANCE_IDS
    INSTANCE_IDS --> PRIVATE_IPS
    
    CUSTOM_AMI --> SLAVE_PROCESSES
    S3_BUCKET --> SLAVE_PROCESSES
    VPC_CONFIG --> PRIVATE_IPS
```

Sources: [spinup-slaves.sh:1-8](), [get-asg-ip.sh:1-8]()

## Auto Scaling Group Architecture

The system uses a naming convention where each master instance creates its own Auto Scaling Group using the master's IP address as a unique identifier. This allows multiple concurrent testing environments without resource conflicts.

**Auto Scaling Group Lifecycle**

```mermaid
sequenceDiagram
    participant MASTER as "Master Instance"
    participant SPINUP as "spinup-slaves.sh"
    participant AWS_ASG as "AWS Auto Scaling"
    participant GETIP as "get-asg-ip.sh"
    participant AWS_EC2 as "AWS EC2"
    participant SLAVES as "Slave Instances"
    
    Note over MASTER,SLAVES: Infrastructure Provisioning
    MASTER->>SPINUP: Execute with slave count
    SPINUP->>SPINUP: Get master IP via hostname -I
    SPINUP->>AWS_ASG: update-auto-scaling-group slaves-{master-ip}
    AWS_ASG->>AWS_EC2: Launch instances from AMI
    AWS_EC2->>SLAVES: Provision N slave instances
    
    Note over MASTER,SLAVES: Instance Discovery
    MASTER->>GETIP: Discover slave IPs
    GETIP->>GETIP: Get master IP via hostname -I
    GETIP->>AWS_ASG: describe-auto-scaling-groups slaves-{master-ip}
    AWS_ASG->>GETIP: Return instance IDs
    GETIP->>AWS_EC2: describe-instances for each ID
    AWS_EC2->>GETIP: Return PrivateIpAddress
    GETIP->>MASTER: List of slave private IPs
```

Sources: [spinup-slaves.sh:3-7](), [get-asg-ip.sh:3-8]()

## Instance Management Operations

### Scaling Operations

The `spinup-slaves.sh` script provides dynamic scaling functionality by updating the Auto Scaling Group's capacity parameters:

- **Min Size**: Set to target slave count
- **Desired Capacity**: Set to target slave count  
- **Max Size**: Set to target slave count

This ensures the ASG maintains exactly the specified number of slave instances.

### IP Address Discovery

The `get-asg-ip.sh` script implements a two-stage discovery process:

1. **ASG Query**: Uses the master's IP to construct the ASG name `slaves-{master-ip}` and retrieves all instance IDs
2. **Instance Query**: For each instance ID, queries EC2 to get the private IP address

**IP Discovery Flow**

```mermaid
flowchart TD
    START["get-asg-ip.sh execution"]
    GET_MASTER_IP["hostname -I → master IP"]
    CONSTRUCT_ASG["ASG name: slaves-{master-ip}"]
    DESCRIBE_ASG["aws autoscaling describe-auto-scaling-groups"]
    EXTRACT_IDS["grep + awk → instance IDs"]
    
    subgraph "For_Each_Instance"[For Each Instance ID]
        DESCRIBE_INSTANCE["aws ec2 describe-instances --instance-ids"]
        EXTRACT_IP["grep PrivateIpAddress + awk"]
        OUTPUT_IP["Output private IP"]
    end
    
    START --> GET_MASTER_IP
    GET_MASTER_IP --> CONSTRUCT_ASG
    CONSTRUCT_ASG --> DESCRIBE_ASG
    DESCRIBE_ASG --> EXTRACT_IDS
    EXTRACT_IDS --> For_Each_Instance
    OUTPUT_IP --> END["Complete IP list"]
```

Sources: [get-asg-ip.sh:3-8]()

## Resource Naming and Identification

The system uses consistent naming conventions to ensure proper resource isolation and identification:

| Resource Type | Naming Pattern | Example |
|---------------|----------------|---------|
| Auto Scaling Group | `slaves-{master-ip}` | `slaves-172.31.45.123` |
| Launch Configuration | `perf-jmeter-slaves` | Static name |
| Instance Tags | Inherited from ASG | Auto-applied |

The master IP-based naming ensures that multiple testing environments can coexist without resource conflicts, as each master creates its own isolated set of slave resources.

## Infrastructure Automation Integration

The infrastructure management components integrate with the broader automation system through several key interfaces:

- **Main Orchestrator**: The `setup-jmeter-lab.sh` script calls infrastructure management functions as part of the complete environment setup
- **Ansible Integration**: Instance IPs discovered by `get-asg-ip.sh` are used to populate Ansible inventory files
- **Test Data Distribution**: Infrastructure discovery enables targeted data distribution to specific slave instances

Sources: [spinup-slaves.sh:1-8](), [get-asg-ip.sh:1-8]()
