# analysisRMP

Demonstration of the use of robust statistics for morphological cell profiling using high-content imaging.  

## Running the code using Docker

This repository compiles a collection of scripts and Jupyter notebooks. For reproducibility, it is designed to run in a Docker container based on the [jupyter/datascience-notebook image](https://hub.docker.com/r/jupyter/datascience-notebook). The following steps describe how to run the code in the same development environment as intended:

* [Install and run Docker Desktop](https://www.docker.com/get-started) on your machine (the Community Edition is available for free).
* Clone this repository and set its root folder as your working directory.
* Run the following command - which might take some time to download all requirements the first time:

	docker run -p 9999:8888 -v `pwd`:/home/jovyan jupyter/datascience-notebook

* Find the token needed to connect to the Jupyter notebook in the console output and go to the corresponding address in your browser:

	http://127.0.0.1:9999/?token=<yourToken>

* You can now choose a notebook to run.
