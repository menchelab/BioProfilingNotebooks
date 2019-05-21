# analysisRMP

Demonstration of the use of robust statistics for morphological cell profiling using high-content imaging.  

## Running the code using Docker

### General instructions

This repository compiles a collection of scripts and Jupyter notebooks. For reproducibility, it is designed to run in a Docker container based on the [jupyter/datascience-notebook image](https://hub.docker.com/r/jupyter/datascience-notebook). The following steps describe how to run the code in the same development environment as intended:

* [Install and run Docker Desktop](https://www.docker.com/get-started) on your machine (the Community Edition is available for free).
* Clone this repository and set its root folder as your working directory.
* Run the following command the first time you want to run code from this repository - which might take some time to download all requirements:

		docker build --rm -t analysisrmp .
	
* Put the required input data in the repository.
* Run the following each time you want to start a notebook server to run code from this repository:

		docker run -p 9999:8888 -v `pwd`:/home/jovyan analysisrmp

* Find the token needed to connect to the Jupyter notebook in the console output and go to the corresponding address in your browser:

	http://127.0.0.1:9999/?token=<yourToken&gt;

* You can now choose a notebook to run.
* Close the notebook server and the docker container by pressing CTRL+C in your terminal.

### Note for Windows users

You can follow the same instructions in a PowerShell. After installing Docker desktop, you might need to:

* Run and complete the following procedure:
		
		docker login

* Share the drive in which you cloned this repository in Docker's settings
* Run the notebook server explicitely stating the path to this repository:

		docker run -p 9999:8888 -v C:\<pathOnYourComputer>\analysisrmp:/home/jovyan analysisrmp
		
### Note for Linux users

You can follow the general instructions. You might need to run Docker with super-user privileges depending on your setup, *i.e.* using *sudo docker* in all calls to Docker.

### Note for MacOS users

You can follow the general instructions.
