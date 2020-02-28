FROM julia:latest

COPY *.toml /app/
COPY credentials /root/.aws/credentials
RUN julia --project=/app -e 'import Pkg; Pkg.instantiate()'
COPY src /app/src
RUN julia --project=/app -e 'import Pkg; Pkg.precompile()'
CMD julia --project=/app -e 'import JuliaSQSEphemerides; JuliaSQSEphemerides.run()'
