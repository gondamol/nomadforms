# NomadForms runtime.
#
# The package declares R (>= 4.0.0). Pinning the base image is what makes that
# claim enforceable rather than aspirational -- host R versions vary widely and
# the code does not run on 3.x.
FROM rocker/r-ver:4.4.0

# libpq is required to build RPostgres from source; libsodium backs the
# at-rest encryption helpers. Installed here so contributors never need
# root on their own machine.
RUN apt-get update && apt-get install -y --no-install-recommends \
        libpq-dev \
        libssl-dev \
        libxml2-dev \
        libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

# rocker images point at Posit Package Manager, so these resolve to
# precompiled binaries instead of triggering a long source build.
RUN install2.r --error --skipinstalled \
        DBI \
        RPostgres \
        jsonlite \
        htmltools \
        plumber \
        testthat

WORKDIR /app
COPY survey-runtime /app/survey-runtime
COPY api /app/api
COPY database /app/database

RUN R CMD INSTALL /app/survey-runtime

EXPOSE 8000
CMD ["Rscript", "/app/api/run_api.R"]
