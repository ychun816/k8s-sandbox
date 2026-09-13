FROM nginx:alpine
RUN echo 'nginx v1 — chun' > /usr/share/nginx/html/index.html

### NOTES ###
# https://docs.docker.com/get-started/docker-concepts/building-images/writing-a-dockerfile/
# docker build -t myapp:v1 .
#
# FROM        = the base image this is built ON TOP OF (nginx:alpine = a working
#               web server). Not the same as the name you give your own image.
# -t myapp:v1 = the name/tag of YOUR image, chosen at build time.
# No CMD needed: nginx:alpine already knows how to start nginx.
