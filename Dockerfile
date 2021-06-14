FROM jupyter/datascience-notebook:julia-1.5.3

COPY requirements.jl requirements.R /tmp/

# Install required R Modules
RUN Rscript /tmp/requirements.R

# Install required Julia Modules
RUN julia /tmp/requirements.jl

# Needed for running Rcall in Julia
USER root
RUN cp /usr/lib/x86_64-linux-gnu/libstdc++.so.6 /opt/julia-1.5.3/lib/julia/
USER jovyan 

# Install additional fonts (ArialMT)
RUN mkdir /tmp/.fonts
RUN wget -O /tmp/.fonts/Arial.ttf https://github.com/matomo-org/travis-scripts/raw/master/fonts/Arial.ttf 
# Rebuild the font cache.
RUN fc-cache -fv /tmp/.fonts
