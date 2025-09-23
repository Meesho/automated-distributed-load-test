# Configuration Management

<details>
<summary>Relevant source files</summary>

The following files were used as context for generating this wiki page:

- [ansible-jmeter-slaves/ansible.cfg](ansible-jmeter-slaves/ansible.cfg)
- [ansible-jmeter-slaves/jmeter-slaves.yml](ansible-jmeter-slaves/jmeter-slaves.yml)

</details>



## Purpose and Scope

This section covers the Ansible-based configuration management system used to provision and configure JMeter slave instances after they are launched by the Auto Scaling Group. The configuration management layer handles repository synchronization, JMeter server startup, and test data distribution across the distributed testing cluster.

For details on AWS infrastructure provisioning that precedes configuration management, see [Infrastructure Management](#4). For specific Ansible configuration details, see [Ansible Configuration](#5.1), [Inventory Management](#5.2), and [JMeter Slave Provisioning](#5.3).

## Configuration Management Overview

The system uses Ansible to configure JMeter slave instances in a distributed testing environment. After AWS Auto Scaling Groups provision EC2 instances, the configuration management layer ensures each slave is properly configured with the necessary software, repositories, and test data to participate in distributed load testing.

The configuration management approach follows a declarative model where the desired state of each JMeter slave is defined in Ansible playbooks and applied consistently across all instances in the cluster.

## Configuration Management Workflow

```mermaid
flowchart TD
    ASG["Auto Scaling Group"] --> SLAVES["JMeter Slave Instances"]
    SETUP["setup-jmeter-lab.sh"] --> GET_IPS["get-asg-ip.sh"]
    GET_IPS --> UPDATE_HOSTS["Update ansible-jmeter-slaves/hosts"]
    UPDATE_HOSTS --> RUN_ANSIBLE["ansible-playbook jmeter-slaves.yml"]
    
    RUN_ANSIBLE --> WAIT["wait_for_connection task"]
    WAIT --> CLONE["git clone task"]
    CLONE --> START_SERVER["jmeter-server startup task"]
    START_SERVER --> COPY_DATA["copy test data task"]
    
    SLAVES --> WAIT
    COPY_DATA --> CONFIGURED["Configured JMeter Slaves"]
    
    style SETUP fill:#f9f,stroke:#333,stroke-width:2px
    style RUN_ANSIBLE fill:#bbf,stroke:#333,stroke-width:2px
    style CONFIGURED fill:#bfb,stroke:#333,stroke-width:2px
```

Sources: [ansible-jmeter-slaves/jmeter-slaves.yml:1-28]()

## Core Configuration Components

### Ansible Control Configuration

The system uses a minimal Ansible configuration to manage the JMeter slave fleet. The configuration disables host key checking to streamline automated provisioning and uses a dynamic inventory file.

| Component | Purpose | Location |
|-----------|---------|----------|
| `ansible.cfg` | Base Ansible configuration | [ansible-jmeter-slaves/ansible.cfg:1-3]() |
| `hosts` inventory | Dynamic list of slave IP addresses | Referenced in [ansible-jmeter-slaves/ansible.cfg:2]() |
| `jmeter-slaves.yml` | Main configuration playbook | [ansible-jmeter-slaves/jmeter-slaves.yml:1-28]() |

### Playbook Execution Strategy

The `jmeter-slaves.yml` playbook uses the `free` strategy to maximize parallelization when configuring multiple slave instances simultaneously. This reduces the overall configuration time for large slave clusters.

```mermaid
graph LR
    PLAYBOOK["jmeter-slaves.yml"] --> STRATEGY["strategy: free"]
    PLAYBOOK --> BECOME["become: yes"]
    PLAYBOOK --> TASKS["Configuration Tasks"]
    
    TASKS --> WAIT_TASK["wait_for_connection"]
    TASKS --> GIT_TASK["git repository clone"]
    TASKS --> CMD_TASK["jmeter-server startup"]
    TASKS --> COPY_TASK["test data distribution"]
    
    SLAVES1["Slave Instance 1"] --> WAIT_TASK
    SLAVES2["Slave Instance 2"] --> WAIT_TASK  
    SLAVESN["Slave Instance N"] --> WAIT_TASK
    
    style STRATEGY fill:#e1f5fe,stroke:#333,stroke-width:2px
    style BECOME fill:#e1f5fe,stroke:#333,stroke-width:2px
```

Sources: [ansible-jmeter-slaves/jmeter-slaves.yml:3](), [ansible-jmeter-slaves/jmeter-slaves.yml:2]()

## Configuration Tasks and Variables

### Repository Synchronization

The configuration management system clones the latest version of the test repository to each slave instance using parameterized Git credentials and branch specifications.

| Variable | Purpose |
|----------|---------|
| `git_user` | GitHub username for repository access |
| `git_pass` | GitHub access token or password |
| `git_branch` | Target branch to clone |
| `repo_name` | Repository name (defaults to `automated-distributed-load-test`) |

### JMeter Server Process Management

Each slave instance runs a `jmeter-server` process that listens for commands from the JMeter master. The configuration ensures this process starts automatically after repository synchronization.

### Test Data Distribution

The configuration management layer handles copying partitioned test data from the master instance to each slave's working directory. This ensures each slave receives its designated portion of the test dataset.

```mermaid
graph TD
    MASTER_DATA["/tmp/datadir/{{ansible_ssh_host}}/"] --> COPY_TASK["copy task"]
    COPY_TASK --> SLAVE_DIR["/home/ubuntu/{{repo_name}}/jmeter/apache-jmeter-5.4.2/bin"]
    
    ANSIBLE_HOST["ansible_ssh_host variable"] --> MASTER_DATA
    REPO_VAR["repo_name variable"] --> SLAVE_DIR
    
    style COPY_TASK fill:#fff3e0,stroke:#333,stroke-width:2px
    style ANSIBLE_HOST fill:#f3e5f5,stroke:#333,stroke-width:2px
    style REPO_VAR fill:#f3e5f5,stroke:#333,stroke-width:2px
```

Sources: [ansible-jmeter-slaves/jmeter-slaves.yml:24-28](), [ansible-jmeter-slaves/jmeter-slaves.yml:6]()

## Integration with System Components

The configuration management layer operates as a bridge between infrastructure provisioning and test execution:

- **Input**: Receives slave IP addresses from AWS Auto Scaling Group discovery
- **Processing**: Applies consistent configuration across all slave instances  
- **Output**: Provides ready-to-use JMeter slaves for distributed testing

The configuration process is triggered by the main orchestration script after infrastructure provisioning completes and before test execution begins.

Sources: [ansible-jmeter-slaves/ansible.cfg:1-3](), [ansible-jmeter-slaves/jmeter-slaves.yml:1-28]()
