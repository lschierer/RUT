FROM perl
WORKDIR /opt/schierer.org

# Copy the frontend application
COPY ./packages/frontend ./
# Copy infrastructure files (if needed)
#COPY ./packages/infrastructure ./infrastructure/

# Install dependencies from the frontend directory
#RUN cpanm --installdeps -n .
RUN ./bin/perldeps.sh

EXPOSE 3000
CMD ./schierer.org.pl prefork
