// AWS ACCOUNT LAYER
data "aws_caller_identity" "current" {}
// NETWORK LAYER
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Name = var.name
  }
}

resource "aws_subnet" "subnet_a" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.subnets_cidr_blocks[0]
  availability_zone = var.availability_zones[0]
}

resource "aws_subnet" "subnet_b" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.subnets_cidr_blocks[1]
  availability_zone = var.availability_zones[1]
}

resource "aws_subnet" "subnet_c" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.subnets_cidr_blocks[2]
  availability_zone = var.availability_zones[0]
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.vpc.id
  service_name = "com.amazonaws.${var.region}.s3"
}

resource "aws_vpc_endpoint_route_table_association" "private_s3" {
  route_table_id  = aws_vpc.vpc.main_route_table_id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

resource "aws_security_group" "docdb" {
  name   = var.name
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_peering_connection" "peer" {
  peer_vpc_id = aws_vpc.vpc.id
  vpc_id      = var.peered_vpc
  auto_accept = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = var.name
  }
}

resource "aws_route" "route_peer" {
  route_table_id            = aws_vpc.vpc.main_route_table_id
  destination_cidr_block    = var.peered_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  depends_on                = [aws_vpc_peering_connection.peer]
}

resource "aws_route" "route_igw" {
  route_table_id         = aws_vpc.vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route" "route_peered" {
  route_table_id            = var.peered_vpc_route_table_id
  destination_cidr_block    = var.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  depends_on                = [aws_vpc_peering_connection.peer]
}

resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.subnet_a.id
  depends_on    = [aws_internet_gateway.igw, aws_eip.nat]

  tags = {
    Name = var.name
  }
}

resource "aws_route_table" "nat" {
  vpc_id     = aws_vpc.vpc.id
  depends_on = [aws_nat_gateway.nat]

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private"
  }
}

resource "aws_route_table_association" "nat" {
  subnet_id      = aws_subnet.subnet_c.id
  route_table_id = aws_route_table.nat.id
}

resource "null_resource" "setup_network" {
  depends_on = [
    aws_vpc.vpc,
    aws_subnet.subnet_a,
    aws_subnet.subnet_b,
    aws_subnet.subnet_c,
    aws_security_group.docdb,
    aws_vpc_peering_connection.peer,
    aws_internet_gateway.igw,
    aws_eip.nat,
    aws_nat_gateway.nat,
    aws_route.route_peer,
    aws_route.route_igw,
    aws_route.route_peered,
    aws_route_table.nat,
    aws_route_table_association.nat
  ]
}
// MONGODB DATA LAYER
resource "aws_docdb_subnet_group" "docdb" {
  name       = var.name
  subnet_ids = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
}

resource "aws_docdb_cluster_instance" "docdb" {
  count              = 1
  identifier         = "${var.name}-${count.index}"
  cluster_identifier = aws_docdb_cluster.docdb.id
  instance_class     = var.instance_class
  apply_immediately  = var.apply_immediately
  depends_on         = [null_resource.setup_network]
}

resource "aws_docdb_cluster" "docdb" {
  cluster_identifier              = var.name
  master_username                 = var.master_username
  master_password                 = var.master_password
  backup_retention_period         = var.retention_period
  preferred_backup_window         = var.preferred_backup_window
  skip_final_snapshot             = var.skip_final_snapshot
  apply_immediately               = var.apply_immediately
  availability_zones              = var.availability_zones
  engine                          = var.engine
  port                            = var.db_port
  storage_encrypted               = var.storage_encrypted
  vpc_security_group_ids          = [aws_security_group.docdb.id]
  db_subnet_group_name            = aws_docdb_subnet_group.docdb.name
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.docdb.name
  depends_on                      = [null_resource.setup_network]
}

resource "aws_docdb_cluster_parameter_group" "docdb" {
  family = "docdb3.6"
  name   = var.name

  parameter {
    name  = "tls"
    value = "disabled"
  }
}

resource "aws_route53_record" "docdb" {
  zone_id = var.dns_zone_id
  name    = var.name
  type    = "CNAME"
  ttl     = "5"
  records = [aws_docdb_cluster.docdb.endpoint]
}
// AUTOMATED BUILD LAYER
resource "aws_iam_role" "cloudbuild_role" {
  name = "cloudbuild-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codebuild_custom_policy" {
  name       = "cloudbuild-custom-policy"
  role       = aws_iam_role.cloudbuild_role.name
  depends_on = [aws_kms_key.custom_kms]

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "${aws_s3_bucket.bucket.arn}",
        "${aws_s3_bucket.bucket.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
          "kms:DescribeKey",
          "kms:GenerateDataKey*",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:Decrypt",
          "kms:DescribeCustomKeyStores",
          "kms:ListKeys",
          "kms:ListAliases"
      ],
      "Resource": [
          "arn:aws:kms:${var.region}:${data.aws_caller_identity.current.account_id}:key/${aws_kms_key.custom_kms.key_id}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:GetAuthorizationToken",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeDhcpOptions",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVpcs"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterfacePermission"
      ],
      "Resource": "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:network-interface/*",
      "Condition": {
        "StringEquals": {
          "ec2:AuthorizedService": "codebuild.amazonaws.com",
          "ec2:Subnet": [
            "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:subnet/${aws_subnet.subnet_c.id}"
          ]
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "codebuild_ecr_policy_attachment" {
  role       = aws_iam_role.cloudbuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}
// ACCESS TO S3 SHOULD BE RESTRICTED AS NEEDED
resource "aws_iam_role_policy_attachment" "codebuild_ecr_policy_attachment_s3" {
  role       = aws_iam_role.cloudbuild_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

data "local_file" "buildspec_yml" {
  filename = "./buildspec.yml"
}
/* USED TO BUILD THE DOCKER IMAGE LOCALLY BEFORE THE CI PIPELINE SETUP
resource "local_file" "buildspec_yml" {
  content    = data.local_file.buildspec_yml.content
  filename   = "../cloud-phoenix-kata/buildspec.yml"
  depends_on = [data.local_file.buildspec_yml]
}
*/
data "local_file" "dockerfile" {
  filename = "./Dockerfile"
}
/* USED TO BUILD THE DOCKER IMAGE LOCALLY BEFORE THE CI PIPELINE SETUP
resource "local_file" "dockerfile" {
  content    = data.local_file.dockerfile.content
  filename   = "../cloud-phoenix-kata/Dockerfile"
  depends_on = [data.local_file.dockerfile]
}

data "archive_file" "cloud_phoenix_kata_zip" {
  type        = "zip"
  source_dir  = "../cloud-phoenix-kata"
  output_path = var.local_build_file
  depends_on  = [local_file.buildspec_yml, local_file.dockerfile]
}
*/
data "archive_file" "cloud_phoenix_kata_zip" {
  type        = "zip"
  output_path = var.local_build_file
  depends_on  = [data.local_file.buildspec_yml, data.local_file.dockerfile]

  source {
    content  = data.local_file.buildspec_yml.content
    filename = "buildspec.yml"
  }

  source {
    content  = data.local_file.dockerfile.content
    filename = "Dockerfile"
  }
}

resource "aws_kms_key" "custom_kms" {
  description             = var.name
  deletion_window_in_days = 7
}

resource "aws_s3_bucket" "bucket" {
  bucket = var.s3_bucket
  acl    = "bucket-owner-full-control"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.custom_kms.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

resource "aws_s3_bucket_object" "cloud_phoenix_kata" {
  bucket     = aws_s3_bucket.bucket.id
  key        = var.s3_keyfile_build
  source     = var.local_build_file
  depends_on = [data.archive_file.cloud_phoenix_kata_zip]
}

resource "aws_codebuild_project" "docker_image_builder" {
  name          = "docker_image_builder"
  build_timeout = 5
  service_role  = aws_iam_role.cloudbuild_role.arn
  depends_on    = [aws_s3_bucket_object.cloud_phoenix_kata, null_resource.setup_network]

  source {
    type     = "S3"
    location = "${aws_s3_bucket.bucket.id}/${aws_s3_bucket_object.cloud_phoenix_kata.id}"
  }
  /* TEST
  source {
    type                = "GITHUB"
    location            = "https://github.com/xpeppers/cloud-phoenix-kata.git"
    git_clone_depth     = 1
  }
*/
  cache {
    type = "LOCAL"

    modes = [
      "LOCAL_DOCKER_LAYER_CACHE",
      "LOCAL_SOURCE_CACHE",
    ]
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:4.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = "true"

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.region
    }
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
    environment_variable {
      name  = "IMAGE_TAG"
      value = "latest"
    }
    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = var.name
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = var.name
      stream_name = "${var.name}-stream"
    }

    s3_logs {
      status   = "ENABLED"
      location = "${aws_s3_bucket.bucket.id}/build-log"
    }
  }

  vpc_config {
    vpc_id             = aws_vpc.vpc.id
    subnets            = [aws_subnet.subnet_c.id]
    security_group_ids = [aws_security_group.docdb.id]
  }

  tags = {
    "Name" = var.name
  }
}
/* COULD BE USEFUL TO MANAGE A GITHUB WEBOOK TO AUTOMATE CODEBUILD WHEN NEW CODE IS PUSHED TO GITHUB REPO, NOT USED SINCE I'M NOT THE OWNER OF THE SOURCES GIT REPO
resource "aws_codebuild_source_credential" "github_token" {
  auth_type   = "PERSONAL_ACCESS_TOKEN"
  server_type = "GITHUB"
  token       = var.github_token
}

resource "aws_codebuild_webhook" "github_webhook" {
  project_name = aws_codebuild_project.docker_image_builder.name

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }

    filter {
      type    = "HEAD_REF"
      pattern = var.github_branch
    }
  }
}
*/
resource "aws_ecr_repository" "ecr" {
  name                 = var.name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}
/* NOT NEEDED
resource "aws_ecr_repository_policy" "ecr" {
  repository = aws_ecr_repository.ecr.name
  policy     = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                  "AWS": [
                      "arn:aws:iam::*:role/${aws_iam_role.beanstalk_ec2.name}",
                      "arn:aws:iam::*:role/${aws_iam_role.beanstalk_service.name}"
                    ]
            },
            "Action": [
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability"
            ]
        }
    ]
}
EOF
}
*/
// FIRST BUILD CI PIPELINE LAYER
resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "codepipeline_role_ecr" {
  name       = "codepipeline-role-ecr"
  roles      = [aws_iam_role.codepipeline_role.id]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
// ACCESS TO S3 SHOULD BE RESTRICTED AS NEEDED
resource "aws_iam_role_policy_attachment" "codepipeline_role_s3" {
  role       = aws_iam_role.codepipeline_role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "codepipeline_role_sns" {
  role       = aws_iam_role.codepipeline_role.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkRoleSNS"
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name       = "codepipeline_policy"
  role       = aws_iam_role.codepipeline_role.id
  depends_on = [aws_kms_key.custom_kms]

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "${aws_s3_bucket.bucket.arn}",
        "${aws_s3_bucket.bucket.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
          "kms:DescribeKey",
          "kms:GenerateDataKey*",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:Decrypt",
          "kms:DescribeCustomKeyStores",
          "kms:ListKeys",
          "kms:ListAliases"
      ],
      "Resource": [
          "arn:aws:kms:${var.region}:${data.aws_caller_identity.current.account_id}:key/${aws_kms_key.custom_kms.key_id}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
          "codedeploy:CreateDeployment",
          "codedeploy:GetApplicationRevision",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
          "elasticbeanstalk:CreateApplicationVersion",
          "elasticbeanstalk:DescribeApplicationVersions",
          "elasticbeanstalk:DescribeEnvironments",
          "elasticbeanstalk:DescribeEvents",
          "elasticbeanstalk:UpdateEnvironment",
          "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
          "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:ResumeProcesses",
          "autoscaling:SuspendProcesses",
          "cloudformation:GetTemplate",
          "cloudformation:DescribeStackResource",
          "cloudformation:DescribeStackResources",
          "cloudformation:DescribeStackEvents",
          "cloudformation:DescribeStacks",
          "cloudformation:UpdateStack",
          "cloudformation:CancelUpdateStack",
          "ec2:DescribeInstances",
          "ec2:DescribeImages",
          "ec2:DescribeAddresses",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeKeyPairs",
          "elasticloadbalancing:DescribeLoadBalancers",
          "rds:DescribeDBInstances",
          "rds:DescribeOrderableDBInstanceOptions",
          "sns:ListSubscriptionsByTopic",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:PutRetentionPolicy"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}

resource "aws_codepipeline" "build_pipeline" {
  name       = "build-pipeline"
  role_arn   = aws_iam_role.codepipeline_role.arn
  depends_on = [aws_codebuild_project.docker_image_builder, aws_kms_key.custom_kms, null_resource.setup_network]

  artifact_store {
    location = aws_s3_bucket.bucket.bucket
    type     = "S3"

    encryption_key {
      id   = aws_kms_key.custom_kms.arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        S3Bucket    = aws_s3_bucket.bucket.bucket
        S3ObjectKey = aws_s3_bucket_object.cloud_phoenix_kata.id
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.docker_image_builder.name
      }
    }
  }
}

resource "null_resource" "setup_roles_and_docdb_and_cicd" {
  depends_on = [
    aws_iam_role.beanstalk_service,
    aws_iam_instance_profile.beanstalk_service,
    aws_iam_policy_attachment.beanstalk_service,
    aws_iam_policy_attachment.beanstalk_service_health,
    aws_iam_role.beanstalk_ec2,
    aws_iam_instance_profile.beanstalk_ec2,
    aws_iam_policy_attachment.beanstalk_ec2_web,
    aws_docdb_cluster.docdb,
    aws_route53_record.docdb,
    aws_ecr_repository.ecr,
    aws_codebuild_project.docker_image_builder,
    aws_codepipeline.build_pipeline
  ]
}
// APPLICATION LAYER
resource "aws_iam_instance_profile" "beanstalk_service" {
  name = "beanstalk-service-user"
  role = aws_iam_role.beanstalk_service.name
}

resource "aws_iam_instance_profile" "beanstalk_ec2" {
  name = "beanstalk-ec2-user"
  role = aws_iam_role.beanstalk_ec2.name
}

resource "aws_iam_role" "beanstalk_service" {
  name               = "beanstalk-service"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "elasticbeanstalk.amazonaws.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "elasticbeanstalk"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role" "beanstalk_ec2" {
  name               = "beanstalk-ec2"
  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "beanstalk_service" {
  name       = "elastic-beanstalk-service"
  roles      = [aws_iam_role.beanstalk_service.id]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkService"
}

resource "aws_iam_policy_attachment" "beanstalk_service_health" {
  name       = "elastic-beanstalk-service-health"
  roles      = [aws_iam_role.beanstalk_service.id]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth"
}

resource "aws_iam_policy_attachment" "beanstalk_ec2_web" {
  name       = "elastic-beanstalk-ec2-web"
  roles      = [aws_iam_role.beanstalk_ec2.id]
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_policy_attachment" "beanstalk_ec2_ecr" {
  name       = "elastic-beanstalk-ec2-ecr"
  roles      = [aws_iam_role.beanstalk_ec2.id]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_elastic_beanstalk_application" "eb" {
  name        = var.name
  description = var.description

  appversion_lifecycle {
    service_role          = aws_iam_role.beanstalk_service.arn
    max_count             = 10
    delete_source_from_s3 = true
  }
}

resource "aws_key_pair" "key_pair" {
  key_name   = var.name
  public_key = file(var.ssh_public_key)
}

resource "aws_s3_bucket_object" "sources" {
  bucket = aws_s3_bucket.bucket.id
  key    = var.s3_keyfile
  source = var.local_eb_file
}

resource "aws_elastic_beanstalk_application_version" "eb_ver" {
  name        = var.name
  application = aws_elastic_beanstalk_application.eb.name
  description = var.description
  bucket      = aws_s3_bucket.bucket.id
  key         = aws_s3_bucket_object.sources.id
  depends_on  = [aws_s3_bucket_object.sources, aws_s3_bucket.bucket, aws_elastic_beanstalk_application.eb]
}

resource "aws_route53_record" "eb_app" {
  zone_id    = var.dns_zone_id
  name       = "app-${var.name}"
  type       = "CNAME"
  ttl        = "5"
  records    = [aws_elastic_beanstalk_environment.eb_env.cname]
  depends_on = [aws_elastic_beanstalk_environment.eb_env]
}

resource "aws_elastic_beanstalk_environment" "eb_env" {
  name                = var.name
  application         = aws_elastic_beanstalk_application.eb.name
  solution_stack_name = var.solution_stack_name
  //version_label       = aws_elastic_beanstalk_application_version.eb_ver.name
  depends_on = [null_resource.setup_network, null_resource.setup_roles_and_docdb_and_cicd, aws_elastic_beanstalk_application.eb, aws_elastic_beanstalk_application_version.eb_ver]

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = aws_vpc.vpc.id
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = "${aws_subnet.subnet_a.id},${aws_subnet.subnet_b.id}"
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "true"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.beanstalk_ec2.name
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = aws_security_group.docdb.id
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "EC2KeyName"
    value     = aws_key_pair.key_pair.id
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = var.instance_type
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = aws_iam_instance_profile.beanstalk_service.name
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBScheme"
    value     = var.elb_scheme
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBSubnets"
    value     = "${aws_subnet.subnet_a.id},${aws_subnet.subnet_b.id}"
  }
  setting {
    namespace = "aws:elb:loadbalancer"
    name      = "CrossZone"
    value     = "true"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "BatchSize"
    value     = "30"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "BatchSizeType"
    value     = "Percentage"
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "Availability Zones"
    value     = var.availability_zone_selector
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = var.autoscale_min
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = var.autoscale_max
  }
  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name      = "RollingUpdateEnabled"
    value     = var.rolling_update_enabled
  }
  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name      = "RollingUpdateType"
    value     = var.rolling_update_type
  }
  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name      = "MinInstancesInService"
    value     = var.updating_min_in_service
  }
  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name      = "MaxBatchSize"
    value     = var.updating_max_batch
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "MeasureName"
    value     = var.autoscale_measure_name
    resource  = ""
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "Statistic"
    value     = var.autoscale_statistic
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "Unit"
    value     = var.autoscale_unit
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "LowerThreshold"
    value     = var.autoscale_lower_bound
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "LowerBreachScaleIncrement"
    value     = var.autoscale_lower_increment
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "UpperThreshold"
    value     = var.autoscale_upper_bound
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "UpperBreachScaleIncrement"
    value     = var.autoscale_upper_increment
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "Period"
    value     = var.autoscale_period
  }
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "StreamLogs"
    value     = true
  }
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "DeleteOnTerminate"
    value     = true
  }
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "RetentionInDays"
    value     = var.retention_period
  }
  setting {
    namespace = "aws:elasticbeanstalk:sns:topics"
    name      = "Notification Endpoint"
    value     = var.alarms_email
  }
  setting {
    namespace = "aws:elasticbeanstalk:sns:topics"
    name      = "Notification Protocol"
    value     = "email"
  }
}
// FINAL CD PIPELINE LAYER
resource "aws_codepipeline" "deploy_pipeline" {
  name       = "deploy-pipeline"
  role_arn   = aws_iam_role.codepipeline_role.arn
  depends_on = [aws_codepipeline.build_pipeline, aws_elastic_beanstalk_environment.eb_env]

  artifact_store {
    location = aws_s3_bucket.bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        S3Bucket    = aws_s3_bucket.bucket.bucket
        S3ObjectKey = aws_s3_bucket_object.cloud_phoenix_kata.id
      }
    }
  }
/* TEST
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "ECR"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ImageTag       = "latest"
        RepositoryName = var.name
      }
    }
  }
*/
  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.docker_image_builder.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ElasticBeanstalk"
      input_artifacts = ["source_output"]
      version         = "1"

      configuration = {
        ApplicationName = aws_elastic_beanstalk_application.eb.name
        EnvironmentName = aws_elastic_beanstalk_environment.eb_env.name
      }
    }
  }
}
/* TESTS WITH AWS SNS AND CLOUDWATCH ALARMS
resource "aws_sns_topic" "alarm" {
  name = "alarms-topic"

  delivery_policy = <<EOF
{
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultThrottlePolicy": {
      "maxReceivesPerSecond": 1
    }
  }
}
EOF

  provisioner "local-exec" {
    command = "aws sns subscribe --topic-arn ${self.arn} --protocol email --notification-endpoint ${var.alarms_email}"
  }
}

aws sns subscribe --topic-arn ${self.arn} --protocol email --notification-endpoint ${var.alarms_email}

resource "aws_cloudwatch_metric_alarm" "cpu-utilization" {
  alarm_name          = "high-cpu-utilization-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_sns_topic.alarm.arn]

  dimensions {
    InstanceId = aws_elastic_beanstalk_environment.eb_env.instances.id[0]
  }
}

resource "aws_cloudwatch_metric_alarm" "instance-health-check" {
  alarm_name          = "instance-health-check"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "This metric monitors ec2 health status"
  alarm_actions       = [aws_sns_topic.alarm.arn]

  dimensions {
    InstanceId = aws_elastic_beanstalk_environment.eb_env.instances.id[0]
  }
}
*/