# create-custom-rocky-linux-ami

Run this script from a Fedora 37 Workstation with [imagefactory](https://github.com/redhat-imaging/imagefactory) and
[awscli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) installed.

Usage:
```bash
./run_empanadas.sh bash
```
inside container:
```bash
imagefactory --debug --verbose --timeout 3600 base_image --parameter generate_icicle false --parameter oz_overrides "{'libvirt': {'memory': 2048}, 'custom': {'useuefi': 'no'}}" --file-parameter install_script /transfer/kickstarts/Rocky-9-EC2-Base.ks /transfer/iso-template.xml 2>&1 | tee /transfer/run-output-iso.txt
```

Custom inline policy `allow-access-to-custom-software-bucket` for the `arn:aws:iam::AWS_ACCOUNT_ID:user/ami-uploader` user.
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "VisualEditor0",
      "Effect": "Allow",
      "Action": [
        "ec2:CreateTags",
        "ec2:ImportSnapshot",
        "s3:ListBucket",
        "ec2:ImportImage",
        "ec2:RegisterImage"
      ],
      "Resource": [
        "arn:aws:ec2:*:AWS_ACCOUNT_ID:import-snapshot-task/*",
        "arn:aws:ec2:*::snapshot/*",
        "arn:aws:ec2:*:AWS_ACCOUNT_ID:import-image-task/*",
        "arn:aws:ec2:*::image/*",
        "arn:aws:s3:::custom-software-bucket"
      ]
    },
    {
      "Sid": "VisualEditor1",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::custom-software-bucket/*"
    },
    {
      "Sid": "VisualEditor2",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeImportImageTasks",
        "ec2:DescribeImportSnapshotTasks"
      ],
      "Resource": "*"
    }
  ]
}
```
