# BioProfilingNotebooks

Demonstration of the use of [_BioProfiling.jl_](https://github.com/menchelab/BioProfiling.jl) and robust statistics for morphological cell profiling using high-content imaging.  

## Prerequisites 

* Create a subfolder called `fig`, where the generated figures will be saved.
* Create a subfolder called `data`, where the input and intermediate will be stored.
* Copy the transfer list and morphological measurement files in the `data` folder.
* (Optional) Mount or copy the raw images in a folder if you want to use the visual diagnostics features.

## Running the code using Docker

### General instructions

This repository compiles a collection of scripts and Jupyter notebooks. For reproducibility, it is designed to run in a Docker container based on the [jupyter/datascience-notebook image](https://hub.docker.com/r/jupyter/datascience-notebook). The following steps describe how to run the code in the same development environment as intended:

#### Set up your directory
* [Install and run Docker Desktop](https://www.docker.com/get-started) on your machine (the Community Edition is available for free).
* Clone this repository and set its root folder as your working directory.
* Make sure you followed the _Prerequisites_ section and that the input data is in the repository, in the `data` subfolder.

#### Option 1 - Pulling the image from DockerHub [fast]
* You can obtain a pre-built image to run this notebooks from the DockerHub image repository:

		docker pull koalive/bioprofilingnotebooks:v3

#### Option 2 - Building the image from the Dockerfile [robust]
* Alternatively, run the following command the first time you want to run code from this repository - which might take some time to download all requirements:

		docker build --rm -t bioprofilingnotebooks .
		docker tag bioprofilingnotebooks koalive/bioprofilingnotebooks:v3

#### Start a docker container running a Jupyter server	
* Run the following each time you want to start a notebook server to run code from this repository:

		docker run -p 9999:8888 -v `pwd`:/home/jovyan koalive/bioprofilingnotebooks:v3

* (Optional) If you wish to test the visual diagnostic features, you need to specify the folder in which the images can be found:

		docker run -p 9999:8888 -v `pwd`:/home/jovyan -v /Local/Path/To/Images/:/images/ koalive/bioprofilingnotebooks:v3

* Find the token needed to connect to the Jupyter notebook in the console output and go to the corresponding address in your browser:

	http://127.0.0.1:9999/?token=<yourToken&gt;

* You can now choose a notebook to run.

#### Reproducing example analysis

* The following order is recommended:
	* *Fig1_Common_Artifacts.ipynb*
	* *Fig2a_Profiling.ipynb*
	* *Fig2b_HitDetection.ipynb*
	* *FigS1a_Profiling.ipynb*
	* *FigS1b_HitDetection.ipynb*
	* *Fig3_HitEnrichment.ipynb*

* Close the notebook server and the docker container by pressing CTRL+C in your terminal.

#### Warning

The notebooks *Fig2a_Profiling.ipynb* and *FigS1a_Profiling.ipynb* require to load individual cell measurements for whole plates and might run out of memory on a desktop machine. We recommend up to 80GB of memory for these steps.  
Note that without mounting a folder with the raw images, the cells demonstrating the use of the visual diagnostics in these same notebooks cannot be run. The overall analysis should be reproducible nonetheless.

### Note for Windows users

You can follow the same instructions in a PowerShell. After installing Docker desktop, you might need to:

* Run and complete the following procedure:
		
		docker login

* Share the drive in which you cloned this repository in Docker's settings
* Run the notebook server explicitely stating the path to this repository:

		docker run -p 9999:8888 -v C:\<pathOnYourComputer>\BioProfilingNotebooks:/home/jovyan koalive/bioprofilingnotebooks:v3
		
### Note for Linux users

You can follow the general instructions. You might need to run Docker with super-user privileges depending on your setup, *i.e.* using *sudo docker* in all calls to Docker.  
If the following happens when you try to run the notebook server: `PermissionError: [Errno 13] Permission denied: '/home/jovyan/.local'`, try the following options:
`sudo docker run --user $(id -u):$(id -g) --group-add users -p 9999:8888 -v `pwd`:/home/jovyan koalive/bioprofilingnotebooks:v3`

### Note for MacOS users

You can follow the general instructions.

### Note for Singularity users

You can use `singularity pull docker://koalive/bioprofilingnotebooks:v3` to get the image from DockerHub, then convert it to a sandbox with `singularity build --sandbox sandbox/ bioprofilingnotebooks_v3.sif` and run the sandbox with the --no-home and --writable flags on a given port (*6789* in this example), while binding your current directory to `/home/jovyan/`:
```singularity exec -B /your/working/directory/:/home/jovyan --writable --no-home sandbox/ jupyter-notebook --port 6789```
We recommend commenting out the following lines in the notebooks, which requires to load temporary fonts used for plotting results, which will not be available in the singularity sandbox:
```
ttf_import(paths = "/tmp/.fonts/")
loadfonts()
```
