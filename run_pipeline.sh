#!/bin/bash
set -e
REF=ref/GRCh38_subset.fa
DBSNP=ref/dbsnp_subset.vcf.gz

echo "=== STEP 1: Mark duplicates ==="
for SAMPLE in tumor normal; do
    gatk MarkDuplicates -I results/${SAMPLE}.sorted.bam -O results/${SAMPLE}.dedup.bam -M results/${SAMPLE}.dup_metrics.txt
    samtools index results/${SAMPLE}.dedup.bam
done

echo "=== STEP 2: BQSR ==="
for SAMPLE in tumor normal; do
    gatk BaseRecalibrator -I results/${SAMPLE}.dedup.bam -R $REF --known-sites $DBSNP -O results/${SAMPLE}.recal.table
    gatk ApplyBQSR -I results/${SAMPLE}.dedup.bam -R $REF --bqsr-recal-file results/${SAMPLE}.recal.table -O results/${SAMPLE}.bqsr.bam
done

echo "=== STEP 3: Mutect2 ==="
gatk Mutect2 -R $REF -I results/tumor.bqsr.bam -I results/normal.bqsr.bam -normal normal -O results/somatic_raw.vcf.gz

echo "=== STEP 4: Filter ==="
gatk FilterMutectCalls -R $REF -V results/somatic_raw.vcf.gz -O results/somatic_filtered.vcf.gz
bcftools view -f PASS results/somatic_filtered.vcf.gz -Oz -o results/somatic_PASS.vcf.gz
tabix -p vcf results/somatic_PASS.vcf.gz

echo "=== STEP 5: Annotate ==="
java -Xmx4g -jar snpEff/snpEff.jar GRCh38.99 results/somatic_PASS.vcf.gz > results/somatic_annotated.vcf

echo "=== DONE ==="
