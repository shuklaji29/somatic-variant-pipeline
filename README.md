# Somatic Variant Calling Pipeline — HCC1395/HCC1395BL

A dockerized somatic variant calling pipeline built and validated on the FDA/SEQC2 reference standard tumor-normal pair (HCC1395 breast cancer cell line vs. HCC1395BL matched normal).

## Pipeline

FastQC → fastp (trim) → BWA-MEM (align) → GATK MarkDuplicates → BQSR → Mutect2 → FilterMutectCalls → snpEff (annotate)

## Dataset

- **Tumor:** HCC1395 exome (SRA: SRR7890850)
- **Normal:** HCC1395BL matched normal exome (SRA: SRR7890851)
- **Source:** SEQC2 Somatic Mutation Working Group (FDA-led reference standard)
- **Reference:** GRCh38, subset to chr3, chr7, chr10, chr12, chr13, chr17 (covers major cancer genes: TP53, BRCA1, BRCA2, PIK3CA, PTEN, CDK4, EGFR)

Reference subset was used due to local compute constraints. Reads from other chromosomes are discarded during alignment; results reflect only genes on these 6 chromosomes.

## Results

- 14,702 candidate somatic variants called by Mutect2
- 764 passed quality filtering (FilterMutectCalls)
- Key findings, consistent with published characterization of HCC1395:
  - **TP53** missense mutation (chr17:7675088 C>T), TLOD=292 (high confidence)
  - **BRCA2** stop-gained mutation (chr13:32339132 G>T), TLOD=13.7

## Usage

### 1. Get the data
Download tumor/normal FASTQ from SRA (accessions above) and place in `data/`.
Download reference genome (GRCh38) and dbSNP known-sites VCF; subset to target chromosomes.

### 2. Run locally
```bash
bash run_pipeline.sh
```

### 3. Run with Docker
```bash
docker build -t somatic-pipeline:v2 .
docker run -v $(pwd)/ref:/pipeline/ref \
           -v $(pwd)/data:/pipeline/data \
           -v $(pwd)/results:/pipeline/results \
           -v $(pwd)/snpEff:/pipeline/snpEff \
           somatic-pipeline:v2
```

## Requirements
- BWA, samtools, bcftools, tabix
- GATK 4.5.0.0
- snpEff
- ~10GB RAM, ~50GB disk (for 6-chromosome subset workflow)

## Output files
- `results/somatic_filtered.vcf.gz` — all candidate calls with filter status
- `results/somatic_PASS.vcf.gz` — high-confidence calls only
- `results/somatic_annotated.vcf` — PASS calls annotated with gene/effect predictions
