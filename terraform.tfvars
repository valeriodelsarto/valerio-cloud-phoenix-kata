region = "eu-west-1"

availability_zones = ["eu-west-1a", "eu-west-1b"]

name = "valerio-cloud-phoenix-kata"

description = "cloud-phoenix-kata by valerio"

vpc_cidr_block = "172.16.0.0/16"

subnets_cidr_blocks = ["172.16.0.0/24", "172.16.1.0/24", "172.16.2.0/24"]

peered_vpc = "vpc-c7c741a0"

peered_vpc_cidr = "10.0.1.0/24"

peered_vpc_route_table_id = "rtb-8327c0e5"

# documentdb variables
instance_class = "db.t3.medium"

dns_zone_id = "Z3QGEXWGCL3P6Y"

dns_domain = "valeriodelsarto.it"

db_port = 27017

master_username = "admin_valerio"

master_password = "password_valerio"

retention_period = 7

preferred_backup_window = "07:00-09:00"

engine = "docdb"

storage_encrypted = true

skip_final_snapshot = true

apply_immediately = true

# elastic beanstalk variables
// https://docs.aws.amazon.com/elasticbeanstalk/latest/platforms/platforms-supported.html
// https://docs.aws.amazon.com/elasticbeanstalk/latest/platforms/platforms-supported.html#platforms-supported.docker
solution_stack_name = "64bit Amazon Linux 2018.03 v2.15.4 running Docker 19.03.6-ce"

s3_bucket = "valerio-cloud-phoenix-kata"

s3_keyfile = "eb/Dockerrun.aws.json"

local_eb_file = "Dockerrun.aws.json"

s3_keyfile_build = "build/cloud-phoenix-kata.zip"

local_build_file = "cloud-phoenix-kata.zip"

ssh_public_key = "~/.ssh/valerio_private_euw1.pem.pub"

instance_type = "t3.micro"

availability_zone_selector = "Any 2"

autoscale_min = 1

autoscale_max = 2

rolling_update_enabled = true

rolling_update_type = "Health"

updating_min_in_service = 0

updating_max_batch = 1

elb_scheme = "public"

autoscale_measure_name = "RequestCount"

autoscale_statistic = "Average"

autoscale_unit = "Count"

autoscale_period = 1

autoscale_lower_bound = 300

autoscale_lower_increment = -1

autoscale_upper_bound = 600

autoscale_upper_increment = 1

alarms_email = "valerio.delsarto@gmail.com"
