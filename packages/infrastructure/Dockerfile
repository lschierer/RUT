# syntax=docker/dockerfile:1

FROM  perl:5.40

# Set workdir to match container path used in serve-start
WORKDIR /opt/schierer.org

RUN apt-get update && apt-get install -y build-essential

COPY ../frontend /opt/schierer.org
# Install tools without tests
RUN cpanm --notest Module::Build
RUN cpanm --notest utf8::all
RUN cpanm --notest --installdeps .

RUN perl Build.PL && ./Build && ./Build install --notest

EXPOSE 3000
CMD ["./schierer.org.pl", "prefork"]
