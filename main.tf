// Create VPC using terraform

resource "aws_vpc" "main" {
  //cidr_block is differnt for dev and prod env, so cidr_block is maintained under roboshop-terraform1->env-dev->main.tfvars
  cidr_block = var.cidr_block
  //enable_dns-support nad hostnames should be set as true as bydefault it is enabled when you do it manually
  enable_dns_support = true
  enable_dns_hostnames = true
  // merge function will dispaly both tags and vpc name
  tags = merge(var.tags, {Name = "${var.env}-vpc"})
}


module "subnets" {
  source = "./subnets"

  for_each   = var.subnets
  vpc_id     = aws_vpc.main.id
  cidr_block = each.value["cidr_block"]
  name       = each.value["name"]
  azs        = each.value["azs"]

  tags = var.tags
  env  = var.env
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, { Name = "${var.env}-igw" })
}

resource "aws_eip" "ngw" {
  //the below statement picks ip based on subnets
  count = length(var.subnets["public"].cidr_block)
  //count = length(lookup(lookup(var.subnets, "public", null), cidr_block, 0)))
  tags  = merge(var.tags, { Name = "${var.env}-ngw" })
}

resource "aws_nat_gateway" "ngw" {
  count         = length(var.subnets["public"].cidr_block)
  allocation_id = aws_eip.ngw[count.index].id
  //public subnet id are created in subnets module, so we need to send them as output
  subnet_id     = module.subnets["public"].subnet_ids[count.index]

  tags = merge(var.tags, { Name = "${var.env}-ngw" })
}

//this block to add internet to route like edit route and entering 0.0.0.0
resource "aws_route" "igw" {
  count                  = length(module.subnets["public"].route_table_ids)
  route_table_id         = module.subnets["public"].route_table_ids[count.index]
  //gateway_id is to add internet gateway to route table
  gateway_id             = aws_internet_gateway.igw.id
  destination_cidr_block = "0.0.0.0/0"
}

//this block to add natgetway to route like edit route and entering 0.0.0.0
resource "aws_route" "ngw" {
  count                  = length(local.all_private_subnet_ids)
  route_table_id         = local.all_private_subnet_ids[count.index]
  nat_gateway_id         = element(aws_nat_gateway.ngw.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_vpc_peering_connection" "peer" {
  peer_vpc_id = var.default_vpc_id
  vpc_id      = aws_vpc.main.id
  auto_accept = true
}

resource "aws_route" "peering_connection_route" {
  count                     = length(local.all_private_subnet_ids)
  route_table_id            = element(local.all_private_subnet_ids, count.index)
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  destination_cidr_block    = var.default_vpc_cidr
}

resource "aws_route" "peering_connection_route_in_default_vpc" {
  route_table_id            = var.default_vpc_rtid
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  destination_cidr_block    = var.cidr_block
}