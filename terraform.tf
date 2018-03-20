#####
# Terraform Script - Automate creating infrastructure in vSphere
# Author - Steve Walker
# Version - 
#####

variable "vsphere_user" {}
variable "vsphere_password" {}
variable "vsphere_server" {}
variable "vm_template" {}
variable "vm_datastore" {}
variable "vm_network" {}
variable "vm_name" {}
variable "iscsi_label_a" {}
variable "iscsi_label_b" {}
variable "vm_resource_pool" {}
variable "node_count" {}
variable "dc" {}
variable "domain" {}
provider "vsphere" {
  user           = "${var.vsphere_user}"
  password       = "${var.vsphere_password}"
  vsphere_server = "${var.vsphere_server}"

  # if you have a self-signed cert
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {
  name = "${var.dc}"
}

data "vsphere_datastore" "datastore" {
  name          = "${var.vm_datastore}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_resource_pool" "pool" {
  name          = "${var.vm_resource_pool}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "network" {
  name          = "${var.vm_network}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "template" {
  name          = "${var.vm_template}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

resource "vsphere_virtual_machine" "k8-nodes" {
  name             = "kubnode${format("%02d", count.index+1)}"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
  datastore_id     = "${data.vsphere_datastore.datastore.id}"

  num_cpus = 2
  memory   = 2048
  guest_id = "${data.vsphere_virtual_machine.template.guest_id}"

  scsi_type = "${data.vsphere_virtual_machine.template.scsi_type}"

  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
  }

  disk {
    label            = "disk0"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"

    customize {
      linux_options {
        host_name = "kubnode${format("%02d", count.index+1)}"
        domain    = "${var.domain}"
      }
      
      network_interface {}

    }
  }
 count = "${var.node_count}"
}

resource "template_file" "k8-invent" {
  count = "${length(split(",","${vsphere_virtual_machine.k8-nodes.*.name}"))}"
  template = "${file("${path.module}/hostname.tpl")}"
  vars {
    extra = "${element(split(",","${vsphere_virtual_machine.k8-nodes.*.name}"),count.index)}"
  }
}
