#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "usage: $0 dataset_code config_version "
    exit
fi


PART=$1
VERSION=$2

USE_TPU=True
TPU_NAME=$HOSTNAME

PYTHONPATH=$HOME/tpu_models/models
STORAGE_BUCKET=gs://new_tpu_storage

VAL_DATASET=$PART
REGEX="v[0-9]+_(.+)"

if [[ $VAL_DATASET =~ $REGEX ]]
then
    VAL_DATASET="${BASH_REMATCH[1]}"
fi

echo "using validation dataset: $VAL_DATASET"

MODEL_DIR=${STORAGE_BUCKET}/saved/$VERSION-$PART
TRAIN_FILE_PATTERN=${STORAGE_BUCKET}/converted/$PART/train_${PART}*.tfrecord
EVAL_FILE_PATTERN=${STORAGE_BUCKET}/converted/$VAL_DATASET/val*.tfrecord
VAL_JSON_FILE=${STORAGE_BUCKET}/converted/$VAL_DATASET/validation_$VAL_DATASET.json

# gsutil -q stat $TRAIN_FILE_PATTERN
# if (( $? ))
# then
#     echo 'balanced train dataset is not found, using the normal dataset'
#     TRAIN_FILE_PATTERN=${STORAGE_BUCKET}/converted/$PART/train*.tfrecord
# fi

mkdir -p output
gsutil cp $VAL_JSON_FILE output/
LOCAL_VAL_JSON_FILE="output/validation_$VAL_DATASET.json"


NUM_STEPS_PER_EVAL=5000
EVAL_SAMPLES=$(cat $LOCAL_VAL_JSON_FILE | grep width | wc -l)
NUM_CLASSES=$(cat $LOCAL_VAL_JSON_FILE | grep name | wc -l)
((NUM_CLASSES++)) # add background class

if (( $NUM_CLASSES < 20 ))
then
    NUM_STEPS_PER_EVAL=2000
fi


python ../models/official/detection/main.py --use_tpu=$USE_TPU --tpu=$TPU_NAME \
    --num_cores=8 --model_dir=$MODEL_DIR --mode=train_and_eval \
    --params_override="{
        train: {
            train_file_pattern: $TRAIN_FILE_PATTERN
        },
        eval: {
            val_json_file: $VAL_JSON_FILE,
            eval_file_pattern: $EVAL_FILE_PATTERN,
            eval_samples: $EVAL_SAMPLES,
            num_steps_per_eval: $NUM_STEPS_PER_EVAL
        },
        retinanet_head: {
            num_classes: $NUM_CLASSES,
        },
        retinanet_loss: {
            num_classes: $NUM_CLASSES,
        },
        postprocess: {
            num_classes: $NUM_CLASSES,
        }
    }" \
    --config_file `find ../models/official/detection/configs/yaml/ -name $VERSION*.yaml` \
    2>&1 | tee -a ~/$VERSION-$PART.log
