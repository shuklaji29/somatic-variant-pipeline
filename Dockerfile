FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential wget curl unzip \
    bwa samtools bcftools tabix \
    openjdk-17-jdk python3 python3-pip python-is-python3 \
    fastqc fastp \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q https://github.com/broadinstitute/gatk/releases/download/4.5.0.0/gatk-4.5.0.0.zip \
    && unzip -q gatk-4.5.0.0.zip -d /opt \
    && rm gatk-4.5.0.0.zip
ENV PATH="/opt/gatk-4.5.0.0:${PATH}"

WORKDIR /pipeline
COPY run_pipeline.sh .
RUN chmod +x run_pipeline.sh

ENTRYPOINT ["./run_pipeline.sh"]
