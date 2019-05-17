FROM jupyter/datascience-notebook:abdb27a6dfbb

COPY requirements.txt requirements.R /tmp/

# Install required Python Modules
RUN pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org -r /tmp/requirements.txt

# Install required R Modules
RUN Rscript /tmp/requirements.R