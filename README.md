# Large Network Emulation

Prepared for UDP connections only.

Will only run on linux.



## Experiment Workflow

1) Develop prototype
2) Containerize
3) Distribute containers over servers
4) Execute applications on containers
5) Extract logs from containers
6) Process logs offline

## Project Structure
- cmd: application code
  - ``simple.go``: a simple libp2p chat application
  - ``pinger.go``: a simple libp2p p2p ping application

- deploy: scripts to deploy experiment
  - scripts:
    - ``lauchcontainer.sh``: script to launch containers
    - dist:
      - ``setupDocker.sh``: script that prepares docker swarm + docker network.
      - ``distributeRRContainers.sh``: distributed containers over swarm hosts in round robin.
      - ``launchRRApps.sh``: starts applications over containers in round robin.
      - ``kilRRApps.sh``: kills all applications in containers  in round robin.
      - ``getLogs.sh``: gets logs stored in containers.
- docker: files to generate docker images
  - dockerfiles:
    - `pinger.dockerfile`: docker file for pinger application
    - `simple.dockerfile`: docker file for simple chat application
  - emulation:
    - `setupClassTcBatch.sh`: applies latency to container for large scenarios
    - `setupTc.sh`: applies latency to container for small scenarios
  - pkg:
    - `install-packages.sh`: debian packages to install in container
  - scripts:
    - `start-simple.sh`: script to start application
- emu: files for emulation
  - config:
    - `classes.txt`: latency classes 
    - `classMat.txt`: class matrix to apply latencies
    - `emuconf.txt`: network configuration (ip container)
    - `ips.txt`: ips and ports of processes to execute
- scripts: helper scripts
  - `build.sh`: build docker image



## How to run
