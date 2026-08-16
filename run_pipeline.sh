#!/bin/bash
# run_pipeline.sh — Full somatic variant calling pipeline
# FASTQ -> FastQC -> fastp -> BWA-MEM -> MarkDuplicates -> BQSR -> Mutect2 -> Filter -> snpEff
set -e

REF=ref/GRCh38_subset.fa
DBSNP=ref/dbsnp_subset.vcf.gz
THREADS=4

mkdir -p results results/fastqc_raw

echo "=== STEP 0: FastQC (raw reads) ==="
fastqc data/tumor_1.fastq data/tumor_2.fastq data/normal_1.fastq data/normal_2.fastq -o results/fastqc_raw

echo "=== STEP 1: fastp (trim/filter reads) ==="
for SAMPLE in tumor normal; do
    fastp -i data/${SAMPLE}_1.fastq -I data/${SAMPLE}_2.fastq \
        -o data/${SAMPLE}_1.trimmed.fastq -O data/${SAMPLE}_2.trimmed.fastq \
        -j results/${SAMPLE}.fastp.json -h results/${SAMPLE}.fastp.html --thread $THREADS
done

echo "=== STEP 2: BWA-MEM alignment + sort ==="
for SAMPLE in tumor normal; do
    bwa mem -t $THREADS -R "@RG\tID:${SAMPLE}\tSM:${SAMPLE}\tPL:ILLUMINA" \
        $REF data/${SAMPLE}_1.trimmed.fastq data/${SAMPLE}_2.trimmed.fastq \
        | samtools sort -@$THREADS -o results/${SAMPLE}.sorted.bam
    samtools index results/${SAMPLE}.sorted.bam
done

echo "=== STEP 3: Mark duplicates ==="
for SAMPLE in tumor normal; do
    gatk MarkDuplicates -I results/${SAMPLE}.sorted.bam -O results/${SAMPLE}.dedup.bam -M results/${SAMPLE}.dup_metrics.txt
    samtools index results/${SAMPLE}.dedup.bam
done

echo "=== STEP 4: BQSR ==="
for SAMPLE in tumor normal; do
    gatk BaseRecalibrator -I results/${SAMPLE}.dedup.bam -R $REF --known-sites $DBSNP -O results/${SAMPLE}.recal.table
    gatk ApplyBQSR -I results/${SAMPLE}.dedup.bam -R $REF --bqsr-recal-file results/${SAMPLE}.recal.table -O results/${SAMPLE}.bqsr.bam
done

echo "=== STEP 5: Mutect2 ==="
# -normal must match the SM: tag set in the read group above ("normal")
gatk Mutect2 -R $REF -I results/tumor.bqsr.bam -I results/normal.bqsr.bam -normal normal -O results/somatic_raw.vcf.gz

echo "=== STEP 6: Filter ==="
gatk FilterMutectCalls -R $REF -V results/somatic_raw.vcf.gz -O results/somatic_filtered.vcf.gz
bcftools view -f PASS results/somatic_filtered.vcf.gz -Oz -o results/somatic_PASS.vcf.gz
tabix -p vcf results/somatic_PASS.vcf.gz

echo "=== STEP 7: Annotate ==="
java -Xmx4g -jar ${SNPEFF_HOME:-snpEff}/snpEff.jar GRCh38.99 results/somatic_PASS.vcf.gz > results/somatic_annotated.vcf

echo "=== PIPELINE COMPLETE ==="
