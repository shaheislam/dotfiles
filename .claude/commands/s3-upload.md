---
name: s3-upload
description: Upload files to S3 bucket
argument-hint: source-path bucket-name
---

Upload files from $ARGUMENTS to S3 with proper permissions and progress tracking. Use aws s3 sync or individual uploads as appropriate.