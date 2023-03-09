#!/usr/bin/env bash
# a modified version of https://github.com/rocky-linux/sig-core-toolkit/blob/devel/sync/import-snapshot-publish-aws.sh

name="$1"
raw="$1"
raw_file_path="$2"

usage() {
  echo "usage: $0 $raw ($0 uuid.body ~/work/uuid.body)"
}

aws() {
  command aws --region eu-central-1 --output text $@
}

DATE=$(date +%Y%m%d)

if [[ -z $raw ]]; then
  usage
  exit 1
fi

exists() {
  aws s3 ls $2/$1 &>/dev/null
  return $?
}

S3_BUCKET="s3://custom-software-bucket"
S3_KEY="ami"

process-upload() {
  if exists $raw $S3_BUCKET/$S3_KEY; then
    echo "Found existing upload in $S3_BUCKET/$S3_KEY"
    return 0
  fi
  aws s3 cp $raw_file_path $S3_BUCKET/$S3_KEY/
}

initiate-upload() {
  echo "Uploading raw image back to s3"
  if ! process-upload; then
    echo "Failed to upload"
    exit
  fi
}

begin-job() {
  import_task_id="$(aws ec2 import-snapshot --description "${name}" --disk-container Format=raw,Url="${S3_BUCKET}/${S3_KEY}/${raw}" --query 'ImportTaskId')"
  if [[ -z $import_task_id ]]; then
    echo "Failed to import $json"
    return 1
  fi
  echo $import_task_id
  return 0
}

is-snapshot-imported() {
  snapshot_id=$(aws ec2 describe-import-snapshot-tasks --query 'ImportSnapshotTasks[].SnapshotTaskDetail.SnapshotId[]' --import-task-ids $1)
  if [[ -z "$snapshot_id" ]]; then
    return 1
  fi
  return 0
}

register-image() {
  # Given a snapshot id, register the image
  name=$1
  snapshot_id=$2

  ami_id=$(aws --query "ImageId" ec2 register-image --name "$name" --description "$name" --block-device-mappings DeviceName="/dev/sda1",Ebs={SnapshotId="$snapshot_id"} --root-device-name "/dev/sda1" --virtualization-type hvm --architecture x86_64 --ena-support)

  if [[ -z "$ami_id" ]]; then
    return 1
  fi
  return 0
}

tag-resources() {
  local resources="$1"
  local tags="$2"
  if [[ -z $resources || -z $tags ]]; then
    echo "Need to provide tags and resources to tag"
    return 1
  fi
  aws ec2 create-tags --resources $resources --tags $tags
}

image-exists() {
  local AMI_ACCOUNT_ID=xxxxxxxxxxxx
  local query="$(printf 'Images[?Name==`%s`].[ImageId,Name][]' "${1}")"
  mapfile -t res < <(aws ec2 describe-images --owners $AMI_ACCOUNT_ID --query "${query}" 2>/dev/null)
  res=($res)
  if [[ ${#res[@]} -eq 0 ]]; then
    # Skip empty results
    return 1 #not found
  fi
  id=${res[0]//\"/}
  name=${res[@]/$id/}
  found_image_id=$id
  return 0 # found
}

snapshot-exists() {
  local AMI_ACCOUNT_ID=xxxxxxxxxxxx
  local filter="$(printf 'Name=tag:Name,Values=%s' "${1}")"
  local query='Snapshots[].[SnapshotId][]'
  mapfile -t res < <(aws ec2 describe-snapshots --owner-ids $AMI_ACCOUNT_ID --filter "${filter}" --query "${query}" 2>/dev/null)
  res=($res)
  if [[ ${#res[@]} -eq 0 ]]; then
    # Skip empty results
    return 1 #not found
  fi
  id=${res[0]//\"/}
  found_snapshot_id=$id
  return 0 # found
}

if image-exists $name; then
  echo "Found existing AMI in eu-central-1. Skipping. ($found_image_id,$name)"
  continue
fi

if snapshot-exists $name; then
  # If the snapshot exists, we can skip the import task and just do the image registration
  echo "Found existing snapshot: ($found_snapshot_id,$name)"
  snapshot_ids[$name]="${found_snapshot_id}"
  continue
fi

# Upload to the proper bucket
echo "Upload artifacts for $name"
initiate-upload

import_task_id=$(begin-job)
echo "Beginning snapshot import task with id $jobid"

# wait for import job to complete, then tag the resultant image
finished=false
while ! $finished; do
  if ! is-snapshot-imported $import_task_id; then
    echo "Snapshot for $import_task_id ($name) is not yet finished"
    continue
  fi

  # await finalization
  sleep 2

  if [[ -z $snapshot_id ]]; then
    echo "Snapshot ID is null.. exiting"
    exit 2
  fi

  echo "Tagging snapshot with name"
  tag-resources $snapshot_id "Key=Name,Value=$name"

  finished=true
  break
done

finished=false
while ! $finished; do
  echo "Creating AMI from snapshot $snapshot_id ($name)"
  if ! register-image $name $snapshot_id; then
    echo "ERROR: Failed to create image for $name with snapshot id $snapshot_id"
    continue
  fi

  echo "Tagging AMI - Name=$name"
  tag-resources $ami_id "Key=Name,Value=$name"

  if [[ -z $ami_id ]]; then
    echo "AMI ID is null. continuing..."
    continue
  fi

  finished=true
  break
done

res="$(printf '%s\t%s\n' $name $ami_id)"
printf "$res\n"