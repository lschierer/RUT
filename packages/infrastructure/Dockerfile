# syntax=docker/dockerfile:1

FROM perl:5.40

# Set workdir
WORKDIR /opt/schierer.org

RUN apt-get update && apt-get install -y build-essential

# Copy the frontend application with exploded archives
COPY frontend/ /opt/schierer.org/
# Copy the luke content
COPY content/luke/ /opt/schierer.org/content/luke/

# Install dependencies
RUN cpanm --notest Module::Build
RUN cpanm --notest utf8::all
RUN cpanm --notest --installdeps .

RUN perl Build.PL && ./Build && ./Build install --notest

EXPOSE 3000
CMD ["./schierer.org.pl", "prefork", "-l", "http://*:3000"]
