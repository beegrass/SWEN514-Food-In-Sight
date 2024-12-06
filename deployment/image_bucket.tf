resource "random_uuid" "bucket_uuid" {}

#Bucket to store images for rekognition
resource "aws_s3_bucket" "image_bucket" {
  bucket = "imagebucket-${random_uuid.bucket_uuid.result}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "unblock_image_bucket" {
  bucket = aws_s3_bucket.image_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_cors_configuration" "image_bucket_cors_policy" {
  bucket = aws_s3_bucket.image_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = ["*"]
    expose_headers  = ["Content-Type"]
    max_age_seconds = 3000
  }
}


resource "aws_s3_bucket_policy" "file_upload_bucket_policy" {
  bucket = aws_s3_bucket.image_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.image_bucket.arn}/*"
        Principal = "*"
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.unblock_image_bucket
  ]
}


resource "aws_s3_bucket_ownership_controls" "image_bucket_controls" {
  bucket = aws_s3_bucket.image_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "image_bucket_ac1" {
  depends_on = [aws_s3_bucket_ownership_controls.image_bucket_controls]

  bucket = aws_s3_bucket.image_bucket.id
  acl    = "private"
}