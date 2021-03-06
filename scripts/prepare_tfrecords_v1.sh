#!/bin/bash

PYTHON=${PYTHON:-python3}
set -e


$PYTHON gen_tfrecords.py \
    --image_dir data/validation/ \
    --output_prefix output/val_human_parts \
    --image_info_file output/validation_human_parts.csv \
    --classes_file output/classes_human_parts.csv \
    --num_shards=1

DISPLAY_ONLY=0

$PYTHON gen_tfrecords.py \
    --display_only=$DISPLAY_ONLY \
    --image_dir data/train/ \
    --min_samples_per_class=100000 \
    --output_prefix output/train_human_parts \
    --image_info_file output/train_human_parts.csv \
    --classes_file output/classes_human_parts.csv \
    --num_shards=10

for i in {0..4}
do
    echo "========================================================================"
    echo "processing part $i"

    $PYTHON gen_tfrecords.py \
        --image_dir data/validation/ \
        --output_prefix output/val_part_$i \
        --image_info_file output/validation_part_$i.csv \
        --classes_file output/classes_part_${i}_of_5.csv \
        --num_shards=1

    $PYTHON gen_tfrecords.py \
        --display_only=$DISPLAY_ONLY \
        --image_dir data/train/ \
        --output_prefix output/train_part_$i \
        --image_info_file output/train_boxes.csv \
        --classes_file output/classes_part_${i}_of_5.csv \
        --num_shards=20
done
