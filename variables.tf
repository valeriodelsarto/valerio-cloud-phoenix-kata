variable "region" {
  type        = string
  description = "AWS region"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones"
}

variable "vpc_cidr_block" {
  type        = string
  description = "VPC CIDR block"
}

variable "subnets_cidr_blocks" {
  type        = list(string)
  description = "List of VPC subnets CIDR blocks"
}

variable "dns_domain" {
  type        = string
  description = "Route53 domain name. It should already exist as a hosted domain"
}


variable "dns_zone_id" {
  type        = string
  description = "Route53 parent zone ID. It should already exist in the hosted domain"
}

variable "name" {
  type        = string
  description = "Name of the application"
}

variable "description" {
  type        = string
  description = "Short description of the Environment"
}

variable "instance_class" {
  type        = string
  default     = "db.r4.large"
  description = "The instance class to use. For more details, see https://docs.aws.amazon.com/documentdb/latest/developerguide/db-instance-classes.html#db-instance-class-specs"
}

variable "db_port" {
  type        = number
  default     = 27017
  description = "DocumentDB port"
}

variable "master_username" {
  type        = string
  default     = "admin1"
  description = "(Required unless a snapshot_identifier is provided) Username for the master DB user"
}

variable "master_password" {
  type        = string
  default     = ""
  description = "(Required unless a snapshot_identifier is provided) Password for the master DB user. Note that this may show up in logs, and it will be stored in the state file. Please refer to the DocumentDB Naming Constraints"
}

variable "retention_period" {
  type        = number
  default     = 5
  description = "Number of days to retain backups for"
}

variable "preferred_backup_window" {
  type        = string
  default     = "07:00-09:00"
  description = "Daily time range during which the backups happen"
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Determines whether a final DB snapshot is created before the DB cluster is deleted"
  default     = true
}

variable "apply_immediately" {
  type        = bool
  description = "Specifies whether any cluster modifications are applied immediately, or during the next maintenance window"
  default     = true
}

variable "engine" {
  type        = string
  default     = "docdb"
  description = "The name of the database engine to be used for this DB cluster. Defaults to `docdb`. Valid values: `docdb`"
}

variable "storage_encrypted" {
  type        = bool
  description = "Specifies whether the DB cluster is encrypted"
  default     = true
}

variable "solution_stack_name" {
  type        = string
  description = "Elastic Beanstalk stack, e.g. Docker, Go, Node, Java, IIS. For more info, see https://docs.aws.amazon.com/elasticbeanstalk/latest/platforms/platforms-supported.html"
}

variable "s3_bucket" {
  type        = string
  description = "Name of the S3 bucket that contains the application sources"
}

variable "s3_keyfile" {
  type        = string
  description = "Path of the S3 bucket object that contains the application sources"
}

variable "local_eb_file" {
  type        = string
  description = "Local EB file that contains the application bundle or the Dockerrun.aws.json"
}

variable "s3_keyfile_build" {
  type        = string
  description = "Path of the S3 bucket object that will contain the application package"
}

variable "local_build_file" {
  type        = string
  description = "Local archive file that contains the application package"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key that you want to use for EC2 EB instances"
}

variable "instance_type" {
  type        = string
  description = "Instances type"
}

variable "availability_zone_selector" {
  type        = string
  description = "Availability Zone selector"
}

variable "autoscale_min" {
  type        = number
  description = "Minumum instances to launch"
}

variable "autoscale_max" {
  type        = number
  description = "Maximum instances to launch"
}

variable "rolling_update_enabled" {
  type        = bool
  description = "Whether to enable rolling update"
}

variable "rolling_update_type" {
  type        = string
  description = "`Health` or `Immutable`. Set it to `Immutable` to apply the configuration change to a fresh group of instances"
}

variable "updating_min_in_service" {
  type        = number
  description = "Minimum number of instances in service during update"
}

variable "updating_max_batch" {
  type        = number
  description = "Maximum number of instances to update at once"
}

variable "elb_scheme" {
  type        = string
  description = "Specify `internal` if you want to create an internal load balancer in your Amazon VPC so that your Elastic Beanstalk application cannot be accessed from outside your Amazon VPC"
}

variable "autoscale_measure_name" {
  type        = string
  description = "Metric used for your Auto Scaling trigger"
}

variable "autoscale_statistic" {
  type        = string
  description = "Statistic the trigger should use, such as Average"
}

variable "autoscale_unit" {
  type        = string
  description = "Unit for the trigger measurement, such as Bytes"
}

variable "autoscale_lower_bound" {
  type        = number
  description = "Minimum level of autoscale metric to remove an instance"
}

variable "autoscale_lower_increment" {
  type        = number
  description = "How many Amazon EC2 instances to remove when performing a scaling activity."
}

variable "autoscale_upper_bound" {
  type        = number
  description = "Maximum level of autoscale metric to add an instance"
}

variable "autoscale_upper_increment" {
  type        = number
  description = "How many Amazon EC2 instances to add when performing a scaling activity"
}

variable "autoscale_period" {
  type        = number
  description = "Specifies how frequently Amazon CloudWatch measures the metrics for your trigger. The value is the number of minutes between two consecutive periods"
}

variable "peered_vpc" {
  type        = string
  default     = ""
  description = "Existing VPC to be peered to the created VPC where DocumentDB and Elastic Beanstalk will run"
}

variable "peered_vpc_cidr" {
  type        = string
  default     = ""
  description = "CIDR of the existing VPC to be peered to the created VPC where DocumentDB and Elastic Beanstalk will run"
}

variable "peered_vpc_route_table_id" {
  type        = string
  default     = ""
  description = "Route Table ID of the existing VPC to be peered to the created VPC where DocumentDB and Elastic Beanstalk will run"
}

variable "alarms_email" {
  type        = string
  default     = ""
  description = "The email address that should get the High CPU Usage Notification"
}
