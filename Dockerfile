FROM jupyter/datascience-notebook

COPY requirements.jl requirements.R /tmp/

# Install required R Modules
RUN Rscript /tmp/requirements.R

# Install required Julia Modules
RUN julia /tmp/requirements.jl

# Install additional fonts (ArialMT)
RUN mkdir /tmp/.fonts
RUN wget -O /tmp/.fonts/Arial.ttf https://github.com/matomo-org/travis-scripts/raw/master/fonts/Arial.ttf 
# Rebuild the font cache.
RUN fc-cache -fv /tmp/.fonts

# Needed for running Rcall in Julia
# RUN mkdir /home/jovyan/lib && mkdir /home/jovyan/lib/julia && cp /usr/lib/x86_64-linux-gnu/libstdc++.so.6 /home/jovyan/lib/julia/
USER root
RUN cp /usr/lib/x86_64-linux-gnu/libstdc++.so.6 /opt/julia-1.5.3/lib/julia/
USER jovyan 
