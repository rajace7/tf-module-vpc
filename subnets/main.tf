resource "aws_subnet" "main" {
  // count statement gets as we have 2 subnet blocks
  count             = length(var.cidr_block)
  //vpc_id will take it from tf-module-vpc outputs
  vpc_id            = var.vpc_id
  //cidr_block will take it from terraform-roboshop1->env-dev->main.tfvars
  cidr_block        = var.cidr_block[count.index]
  //azs take it from terraform-roboshop1->env-dev->main.tfvars
  availability_zone = var.azs[count.index]

  tags = merge(var.tags, { Name = "${var.env}-${var.name}-subnet-${count.index + 1}" })

}

resource "aws_route_table" "main" {
  count  = length(var.cidr_block)
  vpc_id = var.vpc_id

  tags = merge(var.tags, { Name = "${var.env}-${var.name}-rt-${count.index + 1}" })
}

resource "aws_route_table_association" "associate" {
  count          = length(var.cidr_block)
  subnet_id      = aws_subnet.main[count.index].id
  route_table_id = aws_route_table.main[count.index].id
}