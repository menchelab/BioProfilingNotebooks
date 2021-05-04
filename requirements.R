# Set R repository to a fixed backup for repository
options(repos = list(CRAN = 'http://mran.revolutionanalytics.com/snapshot/2021-04-01/'))

# Install packages not present in the Docker image by default
install.packages("extrafont")
install.packages("heatmaply")
install.packages("ggrepel")
install.packages("reticulate")
install.packages("robustbase")
install.packages("ggnewscale")
