# Test Execution

<details>
<summary>Relevant source files</summary>

The following files were used as context for generating this wiki page:

- [README.md](README.md)
- [jmeter/scripts/test.jmx](jmeter/scripts/test.jmx)

</details>



This document covers the test execution phase of the automated distributed load testing system, including the workflow for running JMeter test plans across distributed slave instances and the coordination between master and slave nodes. For detailed information about JMeter test plan structure, see [JMeter Test Plans](#7.1). For specific execution procedures, see [Running Distributed Tests](#7.2).

## Overview

Test execution in this distributed load testing system involves a master JMeter instance coordinating test execution across multiple slave instances. The master instance distributes the test plan to all slaves, aggregates results, and manages the overall test lifecycle. Each slave instance executes its portion of the load generation independently while reporting back to the master.

The execution process occurs after infrastructure provisioning and configuration management have completed, typically initiated by running the `jmeter.sh` script on the master instance with appropriate parameters.

## Test Execution Workflow

The distributed test execution follows a coordinated workflow between the master and slave instances:

```mermaid
sequenceDiagram
    participant User as "User"
    participant Master as "JMeter Master"
    participant jmeter_sh as "jmeter.sh"
    participant jmeter_props as "jmeter.properties"
    participant Slave1 as "JMeter Slave 1"
    participant Slave2 as "JMeter Slave 2"
    participant SlaveN as "JMeter Slave N"
    participant SUT as "System Under Test"
    
    User->>Master: "Execute jmeter.sh with test plan"
    Master->>jmeter_sh: "Load test execution script"
    jmeter_sh->>jmeter_props: "Read remote_hosts configuration"
    
    Note over Master,SlaveN: "Test Plan Distribution Phase"
    Master->>Slave1: "Distribute test.jmx"
    Master->>Slave2: "Distribute test.jmx"
    Master->>SlaveN: "Distribute test.jmx"
    
    Note over Master,SlaveN: "Synchronized Load Generation Phase"
    Master->>Slave1: "Start test execution"
    Master->>Slave2: "Start test execution"
    Master->>SlaveN: "Start test execution"
    
    par "Parallel Load Generation"
        Slave1->>SUT: "HTTP requests with partition 1 data"
        Slave2->>SUT: "HTTP requests with partition 2 data"
        SlaveN->>SUT: "HTTP requests with partition N data"
    end
    
    Note over Master,SlaveN: "Results Collection Phase"
    Slave1->>Master: "Return test results"
    Slave2->>Master: "Return test results"
    SlaveN->>Master: "Return test results"
    
    Master->>jmeter_sh: "Aggregate results into .jtl file"
    jmeter_sh->>User: "Complete with consolidated results"
```

Sources: [README.md:42-46]()

## Master-Slave Coordination Architecture

The JMeter master-slave coordination relies on specific configuration and communication protocols:

```mermaid
graph TB
    subgraph MasterNode["Master Instance Components"]
        jmeter_sh["jmeter.sh<br/>Execution Script"]
        test_jmx["test.jmx<br/>Test Plan File"]
        jmeter_props["jmeter.properties<br/>remote_hosts config"]
        results_jtl["results/*.jtl<br/>Aggregated Results"]
    end
    
    subgraph SlaveNode1["Slave Instance 1"]
        jmeter_server1["jmeter-server<br/>Daemon Process"]
        partition1["Partition 1<br/>Test Data"]
    end
    
    subgraph SlaveNode2["Slave Instance 2"]
        jmeter_server2["jmeter-server<br/>Daemon Process"]
        partition2["Partition 2<br/>Test Data"]
    end
    
    subgraph SlaveNodeN["Slave Instance N"]
        jmeter_serverN["jmeter-server<br/>Daemon Process"]
        partitionN["Partition N<br/>Test Data"]
    end
    
    subgraph ExecutionFlow["Test Execution Flow"]
        distribute["Test Plan Distribution"]
        execute["Synchronized Execution"]
        collect["Results Aggregation"]
    end
    
    jmeter_sh --> test_jmx
    jmeter_sh --> jmeter_props
    jmeter_props --> distribute
    
    distribute --> jmeter_server1
    distribute --> jmeter_server2
    distribute --> jmeter_serverN
    
    execute --> jmeter_server1
    execute --> jmeter_server2
    execute --> jmeter_serverN
    
    jmeter_server1 --> partition1
    jmeter_server2 --> partition2
    jmeter_serverN --> partitionN
    
    jmeter_server1 --> collect
    jmeter_server2 --> collect
    jmeter_serverN --> collect
    
    collect --> results_jtl
```

Sources: [README.md:42-46]()

## Test Plan Execution Process

Test execution begins after the infrastructure setup and configuration phases are complete. The process involves several key components working together:

### Execution Command Structure

The test execution is initiated using the `jmeter.sh` script with specific parameters that control the distributed test behavior:

| Parameter | Purpose | Example Value |
|-----------|---------|---------------|
| `-n` | Non-GUI mode execution | Required for automation |
| `-t` | Test plan file path | `../../scripts/test.jmx` |
| `-r` | Remote execution on all slaves | Enables distributed testing |
| `-l` | Results log file path | `/home/ubuntu/results/test-results.jtl` |

The complete execution command follows this pattern as shown in [README.md:45]():
```bash
nohup sh jmeter.sh -n -t ../../scripts/<filename>.jmx -r -l /home/ubuntu/results/<result-filename>.jtl &
```

### Configuration Requirements

Before test execution, the master instance must have properly configured:

1. **Remote Hosts Configuration**: The `jmeter.properties` file contains the `remote_hosts` property listing all slave IP addresses
2. **Test Plan Availability**: The `.jmx` test plan file must be present in the `scripts` directory
3. **Slave Readiness**: All `jmeter-server` processes must be running on slave instances
4. **Data Distribution**: Test data must be partitioned and distributed to slaves

### Execution Coordination

During execution, the master coordinates with slaves through the following sequence:

```mermaid
graph LR
    subgraph ExecutionPhases["Test Execution Phases"]
        init["Initialization<br/>Load test.jmx"]
        validate["Validation<br/>Check slave connectivity"]
        distribute["Distribution<br/>Send test plan to slaves"]
        sync["Synchronization<br/>Coordinate start time"]
        execute["Execution<br/>Generate load"]
        collect["Collection<br/>Aggregate results"]
    end
    
    subgraph MasterActions["Master Actions"]
        read_config["Read jmeter.properties"]
        parse_jmx["Parse test.jmx"]
        check_slaves["Ping slave instances"]
        send_plan["Transmit test plan"]
        start_signal["Send start command"]
        gather_results["Collect .jtl data"]
    end
    
    subgraph SlaveActions["Slave Actions"]
        receive_plan["Receive test plan"]
        load_data["Load partitioned data"]
        start_test["Begin load generation"]
        send_results["Return results"]
    end
    
    init --> validate
    validate --> distribute
    distribute --> sync
    sync --> execute
    execute --> collect
    
    read_config --> init
    parse_jmx --> init
    check_slaves --> validate
    send_plan --> distribute
    start_signal --> sync
    gather_results --> collect
    
    receive_plan --> distribute
    load_data --> sync
    start_test --> execute
    send_results --> collect
```

Sources: [README.md:42-46]()

## Results Collection and Aggregation

The master instance collects individual results from each slave and aggregates them into a single JTL (JMeter Test Log) file. This aggregated file contains:

- Response times from all slaves
- Throughput metrics across the distributed load
- Error rates and failure details
- Timestamp-synchronized data for accurate analysis

The results are stored in the `/home/ubuntu/results/` directory on the master instance, with filenames specified during execution.

Sources: [README.md:45](), [jmeter/scripts/test.jmx:1]()
