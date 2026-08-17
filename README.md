# Somatic Variant Calling Pipeline — HCC1395/HCC1395BL

A dockerized, end-to-end somatic variant calling pipeline built and validated on the FDA/SEQC2 reference standard tumor-normal pair (HCC1395 breast cancer cell line vs. HCC1395BL matched normal).

## Pipeline
`run_pipeline.sh` runs the full pipeline from raw FASTQ to annotated VCF in one command — this includes QC, trimming, alignment, and sorting (not just the post-alignment steps).

## Dataset

- **Tumor:** HCC1395 exome (SRA: SRR7890850)
- **Normal:** HCC1395BL matched normal exome (SRA: SRR7890851)
- **Source:** SEQC2 Somatic Mutation Working Group (FDA-led reference standard)
- **Reference:** GRCh38, subset to chr3, chr7, chr10, chr12, chr13, chr17 (covers major cancer genes: TP53, BRCA1, BRCA2, PIK3CA, PTEN, CDK4, EGFR)

**Important scope note:** due to local compute constraints, alignment was restricted to a 6-chromosome reference subset rather than the full genome. Reads from other chromosomes are discarded during alignment. All reported results reflect only these 6 chromosomes — this is **not** a whole-exome or whole-genome analysis.

## Known limitations

This pipeline is intentionally simplified for a first project and does not include:
- `--germline-resource` or `--panel-of-normals` for Mutect2 (recommended in GATK Best Practices for more accurate somatic calling)
- Contamination estimation (`CalculateContamination`)
- Read orientation bias filtering (`LearnReadOrientationModel`)

These would be the next additions for a production-grade pipeline.

## Sample naming

Read groups are set explicitly during alignment: tumor BAM uses `SM:tumor`, normal BAM uses `SM:normal`. Mutect2's `-normal normal` flag matches this. If you substitute different FASTQ files, update the `SM:` tags and the `-normal` flag accordingly — verify with:
```bash
samtools view -H results/normal.bqsr.bam | grep '^@RG'
```

## Results

- 14,702 candidate somatic variants called by Mutect2
- 764 passed quality filtering (FilterMutectCalls)
- Key findings, consistent with published characterization of HCC1395:
  - **TP53** missense mutation (chr17:7675088 C>T), TLOD=292 (high confidence)
  - **BRCA2** stop-gained mutation (chr13:32339132 G>T), TLOD=13.7

## Usage

### 1. Get the data
Download tumor/normal FASTQ from SRA (accessions above) into `data/` as `tumor_1.fastq`, `tumor_2.fastq`, `normal_1.fastq`, `normal_2.fastq`.

Download and prepare the reference:
```bash
# Full GRCh38, then subset to target chromosomes
samtools faidx GRCh38.fa chr17 chr13 chr3 chr10 chr12 chr7 > ref/GRCh38_subset.fa
bwa index ref/GRCh38_subset.fa
samtools faidx ref/GRCh38_subset.fa
gatk CreateSequenceDictionary -R ref/GRCh38_subset.fa

# dbSNP known-sites, subset to same chromosomes
bcftools view -r chr17,chr13,chr3,chr10,chr12,chr7 dbsnp.vcf.gz -Oz -o ref/dbsnp_subset.vcf.gz
tabix -p vcf ref/dbsnp_subset.vcf.gz
```

### 2. Run locally
```bash
bash run_pipeline.sh
```

### 3. Run with Docker
```bash
docker build -t somatic-pipeline:v3 .
docker run -v $(pwd)/ref:/pipeline/ref \
           -v $(pwd)/data:/pipeline/data \
           -v $(pwd)/results:/pipeline/results \
           somatic-pipeline:v3
```
(snpEff and its database are bundled inside the Docker image; no separate mount needed when running via Docker.)

## Requirements (local run)
- BWA, samtools, bcftools, tabix, fastqc, fastp
- GATK 4.5.0.0
- snpEff (with GRCh38.99 database downloaded)
- ~10GB RAM, ~50GB disk (for the 6-chromosome subset workflow)

## Output files
- `results/somatic_filtered.vcf.gz` — all candidate calls with filter status
- `results/somatic_PASS.vcf.gz` — high-confidence calls only
- `results/somatic_annotated.vcf` — PASS calls annotated with gene/effect predictions
