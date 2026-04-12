output "tfstate_bucket_name" {
  value = aws_s3_bucket.tfstate.bucket
}

output "assets_bucket_name" {
  value = aws_s3_bucket.assets.bucket
}
